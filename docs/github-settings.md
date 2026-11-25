# GitHub settings

CI depends on these repository settings. They are set by hand in **Settings**, not in code. A repo admin changes them.

## Environments

**Settings** > **Environments**.

| Environment | Used by | Protection | Contents |
| --- | --- | --- | --- |
| `oci-plan` | PR plans, plans on `main`, the drift check | None | Secret `OCI_PRIVATE_KEY`; variables `OCI_USER_OCID`, `OCI_FINGERPRINT` for `waterloorocketry-terraform-ci-plan` |
| `oci-apply` | The `apply` job | Required reviewers. Deployment branches: `main` only. | Secret `OCI_PRIVATE_KEY`; variables `OCI_USER_OCID`, `OCI_FINGERPRINT` for `waterloorocketry-terraform-ci-apply` |

To change who can approve applies, edit **Required reviewers** on `oci-apply`. Any one listed reviewer can approve. Keep **Prevent self-review** off while only one person is listed, or nobody can approve their own merges.

Required reviewers and environment secrets need the repo to stay **public** on the GitHub Free plan. If the repo is made private again, the apply gate stops working until the organization moves to a paid plan.

## Repository secrets and variables

**Settings** > **Secrets and variables** > **Actions**.

| Name | Kind | Purpose | How to change it |
| --- | --- | --- | --- |
| `OCI_TENANCY_OCID` | Variable | Tenancy for the OCI config file | Only if the tenancy changes |
| `OCI_REGION` | Variable | Region for the OCI config file | Only if the region changes |
| `BUDGET_ALERT_RECIPIENTS` | Secret | JSON list of budget alert emails, in console order, for example `["a@example.com","b@example.com"]` | See [Budget alert recipients](#budget-alert-recipients) |
| `TF_ARTIFACT_ENCRYPTION_KEY` | Secret | Encrypts the saved plan between the plan and apply jobs. Only CI reads it. | Rotate at any time: `openssl rand -base64 48 \| gh secret set TF_ARTIFACT_ENCRYPTION_KEY`. Do not rotate while an apply waits for approval, or that apply fails to decrypt its plan. |

To rotate the OCI API keys, see [OCI manual operations](oci/manual-operations.md#rotate-a-ci-api-key).

## Labels

| Label | Meaning |
| --- | --- |
| `allow-destroy` | Lets a PR's plan delete or replace resources |
| `apply-failed` | Added by CI to the issue it opens when an apply fails |
| `drift` | Added by CI to the issue it opens when the cloud no longer matches `main` |

CI fails to open issues if `apply-failed` or `drift` is deleted. Recreate the label with the same name.

## Budget alert recipients

The addresses are personal, so they are kept out of the public repo. GitHub secrets cannot be read back, so view the current list in OCI: **Billing & Cost Management** > **Budgets** > the budget > **Alert rules**.

To change the recipients:

1. Set the secret to the new JSON list. Anyone with write access can do this: `gh secret set BUDGET_ALERT_RECIPIENTS --body '["a@example.com","b@example.com"]'`.
2. Nothing is applied yet. Every plan and the daily drift check now show updates to the alert rules (with the addresses redacted).
3. Apply it by merging a PR that touches `oci/`, for example one that edits a comment in the stack's budget file. Approve that apply as usual.

## Ruleset on main

**Settings** > **Rules** > **Rulesets** > `main`. It applies to the default branch:

- Changes must go through a pull request with 1 approving review. A new push dismisses earlier approvals.
- The `oci-plan-status` check must pass. It reports on every PR: it passes when no OCI plan is needed, and fails when any OCI plan failed.
- Force pushes and deleting `main` are blocked.
- Repository admins can bypass these rules, but only by merging a pull request, never by pushing directly.

Merging still does not change OCI by itself: the apply waits for `oci-apply` approval.
