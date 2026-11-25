# Waterloo Rocketry Cloud IaC

Terraform for Waterloo Rocketry's cloud infrastructure. Changes go through a pull request, CI plans them, and CI applies them after approval.

## Layout

```text
<provider>/<tenancy>/<region>/   one Terraform stack: one root module, one state file
```

Each stack's state key is its folder path plus `/terraform.tfstate`. State lives in an OCI Object Storage bucket, named in each stack's `backend.tf`. The bucket has object versioning on. Terraform's `oci` backend locks the state with a `<key>.lock` object during every apply. CI plans skip the lock, because they never write state.

The state bucket and the CI users, groups and policy are created by hand, not by Terraform. They are what Terraform runs on, so a bad apply must not be able to change them.

To add a stack, create a folder with a `backend.tf` whose `key` matches the folder path. CI finds it automatically.

## How a change gets applied

1. Open a PR. CI plans every stack with the read-only `waterloorocketry-terraform-ci-plan` user and posts each plan as a PR comment.
2. If a plan deletes or replaces a resource, CI fails unless the PR has the `allow-destroy` label.
3. After merge, CI plans again on `main`, waits for approval in the `oci-apply` environment, then applies that saved plan with `waterloorocketry-terraform-ci-apply`.
4. CI posts the result as a comment on the merged PR. A daily `drift` workflow opens an issue if the cloud no longer matches `main`.

Do not change Terraform-managed resources in the OCI console. The next plan will try to undo the change.

The [playbooks in `docs/`](docs/README.md) cover the details: [applying changes and checking their status](docs/applying-changes.md), [GitHub settings](docs/github-settings.md), [OCI manual operations](docs/oci/manual-operations.md) and [OCI troubleshooting](docs/oci/troubleshooting.md).

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
