# Applying changes

Every change to Terraform-managed infrastructure goes through a pull request. CI plans it, a person approves it, and CI applies the exact plan that was approved. Do not change Terraform-managed resources in a cloud console: the next plan tries to undo the change, and the nightly drift check opens an issue.

## 1. Open a pull request

1. Create a branch and edit the stack, for example `oci/waterloorocketry/ca-toronto-1/compute.tf`.
2. Optional: run a plan locally first. See [Running Terraform locally](../README.md#running-terraform-locally).
3. Open the PR. The `terraform` workflow runs for every stack:
   - `terraform fmt -check`, `init` and `validate`
   - `terraform plan` with the read-only CI user
   - a sticky PR comment, `Terraform plan: <stack> at <commit>`, with the summary line and the full plan. Email addresses are redacted, because the repo is public. If the plan fails, the comment is replaced with `Terraform plan failed`, so an older plan never looks current.
   - the `oci-plan-status` check, which the `main` ruleset requires. It fails if any plan failed.
4. Read the plan comment. Check the summary line first:

   | Summary | Meaning |
   | --- | --- |
   | `No changes.` | Nothing in the cloud changes. |
   | `N to import` | Existing resources are adopted. Nothing changes in the cloud. |
   | `N to add` | New resources are created. |
   | `N to change` | Existing resources are updated in place. |
   | `N to destroy` | Resources are deleted, or replaced (deleted, then created again). |

5. If the plan deletes or replaces anything, CI fails on purpose. If that is intended, add the `allow-destroy` label to the PR, and say in the PR why. CI plans again when the label is added.

PRs from forks get no secrets, so their plan fails. Push the branch to this repo instead.

## 2. Merge and approve the apply

1. Get one approving review, then merge the PR. The `main` ruleset requires both the review and a passing `oci-plan-status` check. Repository admins can merge without them; use that only when needed.
2. The merge starts the `terraform` workflow on `main`. It plans again on the merged code, runs the same deletion check, and saves the plan. If this plan fails, nothing is applied, and CI opens a `Terraform plan failed on main: <stack>` issue.
3. The `apply` job then waits for approval in the `oci-apply` environment. The required reviewers are listed in [GitHub settings](github-settings.md#environments).
4. To approve: open the run (**Actions** > **terraform** > the run for your merge commit), click **Review deployments**, tick `oci-apply`, and click **Approve and deploy**. Before approving, check that the plan on the run's summary page matches the plan you reviewed in the PR.

   From a terminal:

   ```sh
   run_id=$(gh run list --workflow terraform.yml --branch main --limit 1 --json databaseId -q '.[0].databaseId')
   gh api "repos/waterloo-rocketry/cloud-iac/actions/runs/$run_id/pending_deployments" \
     --jq '.[] | "\(.environment.name) \(.environment.id)"'
   gh api -X POST "repos/waterloo-rocketry/cloud-iac/actions/runs/$run_id/pending_deployments" \
     -F 'environment_ids[]=<ID from the line above>' -f state=approved -f comment="Plan reviewed"
   ```

5. To refuse an apply, click **Reject** instead. Nothing is applied, and the merged change stays on `main` until a later plan is approved, or until a revert PR is merged.

Only merges that touch `oci/**` or `.github/workflows/terraform.yml` start an apply.

### Merging a stack of PRs

With stacked PRs (for example made with git-spice), merge one PR at a time, from the bottom of the stack. Wait for each apply to finish before merging the next one. Then move the next PR onto `main`:

```sh
git-spice repo sync --restack
git-spice stack submit
```

If two merges overlap, the second apply fails with `Saved plan is stale`. That is safe: re-run all jobs of that run, which plans again on the new state.

## 3. Check the apply status

| Where | What it shows |
| --- | --- |
| The merged PR | A sticky comment, `Terraform apply succeeded: <stack>` or `Terraform apply failed: <stack>`, with the resource counts and the full output |
| The run's summary page | The plan and the apply result for each stack |
| **Issues** with label `apply-failed` | One issue for each failed apply, or failed plan on `main`, with a link to the run |
| **Issues** with label `drift` | Stacks whose real resources no longer match `main` |

From a terminal:

```sh
gh run list --workflow terraform.yml --branch main --limit 5   # recent plans and applies
gh run watch <run-id>                                          # follow a running apply
gh run view <run-id> --log-failed                              # log of the failed steps
gh issue list --label apply-failed                             # open apply failures
gh issue list --label drift                                    # open drift reports
```

A successful apply ends with `Apply complete! Resources: X imported, Y added, Z changed, W destroyed.` If an apply failed, follow [troubleshooting](oci/troubleshooting.md).

## 4. Check for drift

The `drift` workflow plans every stack once a day (the `cron` line in `drift.yml` sets the time) with the read-only user. When the cloud no longer matches `main`, it opens an issue titled `Drift detected: <stack>`, or comments on the open one. To run it now: **Actions** > **drift** > **Run workflow**, or `gh workflow run drift.yml`.

To fix drift, either open a PR that makes the code match the change, or undo the change in the console. Close the issue when the next drift run passes.
