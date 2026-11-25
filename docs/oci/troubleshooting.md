# OCI: troubleshooting

Start with the failing run: **Actions** > the run > the red job, or `gh run view <run-id> --log-failed`. Then find the error message below.

## Plan or apply cannot reach OCI

| Error | Cause | Fix |
| --- | --- | --- |
| `401 NotAuthenticated` | The API key in the GitHub environment does not match the user, or the key was deleted | Check `OCI_USER_OCID`, `OCI_FINGERPRINT` and `OCI_PRIVATE_KEY` in that environment. If the key is gone, [rotate it](manual-operations.md#rotate-a-ci-api-key). |
| `404 NotAuthorizedOrNotFound` | The CI user's policy does not cover the resource, or the resource was deleted outside Terraform | For a new kind of resource, [add a policy statement](manual-operations.md#give-ci-access-to-a-new-kind-of-resource). For a deleted resource, see [Drift](#drift). |
| `terraform init` fails with a backend or bucket error | The state bucket is missing, or the CI policy names a different bucket | Check that the bucket named in `backend.tf` exists and that the CI policy names the same bucket. |
| `429 TooManyRequests` or `5xx` | Temporary OCI throttling or outage | Wait a few minutes, then re-run the run. |
| Plan fails on a PR from a fork | Forks get no secrets | Push the branch to this repository instead. |

## The deletion check fails

`This plan deletes or replaces: <addresses>` means the plan would destroy something.

- **Not intended:** usually an argument that OCI cannot change in place, such as an instance's availability domain or a VCN's DNS label. Change the code so the plan shows `~ update in-place`, or keep the old value.
- **Intended:** add the `allow-destroy` label to the PR and explain why in the PR. Resources with `prevent_destroy` in their `lifecycle` block still fail. Remove `prevent_destroy` in the same PR, on purpose.

## The apply fails

CI opens an issue titled `Terraform apply failed: <stack>`, and the merged PR gets a `Terraform apply failed` comment.

### `Saved plan is stale`

State changed after the plan was made, usually because another apply finished first. Nothing was applied. Open the run and choose **Re-run all jobs**. Re-running only the failed `apply` job reuses the stale plan and fails again.

### `Error acquiring the state lock`

An apply, or someone running Terraform on a laptop, holds the lock, or a run died while holding it. CI plans and the drift check never take the lock.

1. Check that nothing is running: **Actions**, `gh run list --status in_progress`, and ask anyone who may be running Terraform locally.
2. If nothing is running, remove the lock. Use the ID from the error, in the stack's folder:

   ```sh
   terraform force-unlock <LOCK_ID>
   ```

3. Re-run all jobs.

### The error is temporary (429, 5xx, timeout)

Re-run all jobs. Terraform already saved the resources that finished, so the new plan only contains the remaining work.

### The configuration is wrong

For example a bad argument value, a quota error, or `Out of host capacity`. Fix it in a new PR. The resources that finished are already in state, so the new plan shows only what is left.

### `Failed to save state`

OCI made the changes, but Terraform could not write the new state to the bucket. CI retries the upload of `errored.tfstate` 5 times over about 5 minutes. If the log shows `Saved errored.tfstate to the backend`, the state is correct. Re-run all jobs if work remains.

If all 5 retries failed, the state still holds the old contents. Updated and deleted resources sort themselves out on the next plan. **Created resources do not:** Terraform no longer knows they exist and would create them again. To recover:

1. In the failed run's log, find each `Creation complete after ... [id=...]` line. If a create was interrupted and has no ID, find the resource in the console by its display name, or by `Oracle-Tags.CreatedBy` set to the apply user within the run's time.
2. If later runs fail with `Error acquiring the state lock`, remove the lock as described above.
3. Open a PR that adds one `import` block per created resource, with the address and ID from the log:

   ```hcl
   import {
     to = oci_core_instance.example
     id = "ocid1.instance.oc1.ca-toronto-1.example"
   }
   ```

4. The plan must show `N to import, 0 to add`. A `+ create` line means a created resource is still missing.
5. Merge and approve the apply, then remove the `import` blocks in a follow-up PR.

### Decrypting the saved plan fails

`bad decrypt` in the apply job means `TF_ARTIFACT_ENCRYPTION_KEY` changed between the plan and the apply. Choose **Re-run all jobs** so the plan is made and encrypted with the current key.

## Drift

The `oci-drift` workflow opened `Drift detected: <stack>`. The run log shows the plan.

| The plan shows | Likely cause | Fix |
| --- | --- | --- |
| `~ update` on a resource | Someone edited it in the console | Undo the edit in the console, or open a PR that makes the code match it |
| `+ create` for a resource that should exist | It was deleted outside Terraform, or Oracle reclaimed (deleted) an idle Always Free instance | Do not apply blindly. Find out what happened. For an instance, decide whether to restore a backup or rebuild first. |
| A change you cannot explain | Provider defaults changed after a provider upgrade | Read the provider changelog. Then add the value to the code, or add it to `ignore_changes` with a comment. |

Close the issue after the next drift run passes.

## Restore an earlier state

Use this only when the state file itself is wrong, for example after a bad `terraform state` command. The bucket keeps every earlier version.

1. Make sure nothing is running, and tell the team not to run Terraform until you finish.
2. List the versions and download the one you want. Take the bucket and key from the stack's `backend.tf`:

   ```sh
   oci os object list-object-versions --bucket-name <bucket> --prefix <key> \
     --query 'data[].{version:"version-id",modified:"time-modified"}' --output table
   oci os object get --bucket-name <bucket> --name <key> \
     --version-id <version-id> --file restored.tfstate
   ```

3. From the stack's folder, push it. `-force` is needed because the old file has a lower serial number:

   ```sh
   terraform state push -force restored.tfstate
   ```

4. Run `terraform plan`. It should match the real resources, or show only the changes you expect.
5. Delete `restored.tfstate`. It contains every resource attribute.

## Running Terraform locally for diagnosis

See [Running Terraform locally](../../README.md#running-terraform-locally). Local runs use your own OCI user and take the state lock, like CI applies. Use `terraform plan -lock=false` so a local plan never blocks an apply. Use `terraform plan` freely. Use `terraform apply` locally only in an emergency, and say so in the team channel first.
