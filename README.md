# Waterloo Rocketry Cloud IaC

Terraform for Waterloo Rocketry's cloud infrastructure. Changes go through a pull request, CI plans them, and CI applies them after approval.

## Layout

```text
<provider>/<tenancy>/<region>/   one Terraform stack: one root module, one state file
```

| Stack | State key |
| --- | --- |
| `oci/waterloorocketry/ca-toronto-1/` | `oci/waterloorocketry/ca-toronto-1/terraform.tfstate` |

State lives in the OCI bucket `waterloorocketry-terraform-state-ca-toronto-1` (namespace `yzpwk4utrxdv`). The bucket has object versioning on. Terraform's `oci` backend locks the state with a `<key>.lock` object during every apply. CI plans skip the lock, because they never write state.

The state bucket and the CI users, groups and policy are created by hand, not by Terraform. They are what Terraform runs on, so a bad apply must not be able to change them.

To add a stack, create a folder with a `backend.tf` whose `key` matches the folder path. CI finds it automatically.

## How a change gets applied

1. Open a PR. CI runs `fmt`, `validate` and `plan` for every stack with the read-only `waterloorocketry-terraform-ci-plan` user, and posts each plan as a PR comment.
2. If a plan deletes or replaces a resource, CI fails unless the PR has the `allow-destroy` label.
3. After merge, CI plans again on `main` and saves the plan.
4. The `apply` job waits for approval in the `oci-apply` environment, then applies that saved plan with `waterloorocketry-terraform-ci-apply`.
5. CI posts the apply result as a comment on the merged PR and on the run's summary page.

Do not change Terraform-managed resources in the OCI console. The next plan will try to undo the change.

## Drift detection

The `drift` workflow plans every stack each day at 09:17 UTC with the read-only user. If the real resources no longer match `main`, it opens an issue titled `Drift detected: <stack>`, or comments on the open one. Fix drift by opening a PR that matches the change, or by undoing the console change. You can also start the workflow by hand from the Actions tab.

## Running Terraform locally

You need Terraform 1.17 and an OCI API key in the `DEFAULT` profile of `~/.oci/config`.

The budget alert recipients are not in the repo. Set them as a JSON list, in the same order as the `BUDGET_ALERT_RECIPIENTS` repository secret:

```sh
export TF_VAR_budget_alert_recipients='["first@example.com", "second@example.com"]'
cd oci/waterloorocketry/ca-toronto-1
terraform init
terraform plan
```

Run `terraform apply` locally only in an emergency. Normal applies go through CI.

## When an apply fails

CI opens an issue titled `Terraform apply failed: <stack>` with a link to the run.

- **The error is temporary** (for example a 429 or 5xx from OCI): re-run the workflow. It makes a new plan, and the apply only does the remaining work.
- **The configuration is wrong:** fix it in a new PR. Terraform has already saved the resources that finished to state.
- **`Saved plan is stale`:** someone applied in between. Re-run the workflow to plan again.
- **`Error acquiring the state lock`:** check that no plan or apply is running in Actions or on a laptop. Then remove the lock with the ID from the error:

  ```sh
  terraform force-unlock <LOCK_ID>
  ```

- **`Failed to save state`:** OCI made the changes, but Terraform could not write the new state. CI retries the upload of `errored.tfstate` 5 times over about 7 minutes; check the run log for `Saved errored.tfstate`. If every retry failed, the state still has the old contents. Updated and deleted resources sort themselves out on the next plan. Created resources do not: Terraform no longer knows they exist and would create them again. To recover:

  1. Find each `Creation complete after ... [id=...]` line in the failed run's log. If a create was interrupted and has no ID, search the OCI console by display name, or by `Oracle-Tags.CreatedBy` set to the apply user within the run's time.
  2. If later runs fail with `Error acquiring the state lock`, remove the lock as described above.
  3. Open a PR that adds one `import` block per created resource, using the address from the log and the ID:

     ```hcl
     import {
       to = oci_core_instance.example
       id = "ocid1.instance.oc1.ca-toronto-1.example"
     }
     ```

  4. The plan must show `N to import, 0 to add`. A `+ create` line means a created resource is still missing.
  5. Merge and approve the apply, then remove the `import` blocks in a follow-up PR.

## Restoring an earlier state

Every state write keeps the previous version in the bucket. In the OCI console, open the bucket, show object versions, and restore the version you need. Run `terraform plan` afterwards and check that it matches the real resources.
