# OCI: manual operations

These operations are done in the OCI console or with the `oci` CLI, not in Terraform. The `.tf` files under [`oci/`](../../oci) describe everything Terraform manages; change those resources only through a PR (see [Applying changes](../applying-changes.md)).

## What is not managed by Terraform

No code records the resources below, so this list is their record. When you add, rename or remove one of them in the console, update this list in the same change.

Tenancy: `waterloorocketry`. Home region: `ca-toronto-1`. Object Storage namespace: `yzpwk4utrxdv`. Everything is in the root compartment.

### Terraform bootstrap

This repo does not provision these, including the Terraform state bucket. Terraform runs on them: if CI could change them, one bad apply could break every later apply or give CI more access.

| Resource | Name |
| --- | --- |
| State bucket (versioning on, private) | `waterloorocketry-terraform-state-ca-toronto-1` |
| CI users, in the Default identity domain | `waterloorocketry-terraform-ci-plan`, `waterloorocketry-terraform-ci-apply` |
| CI groups, in the Default identity domain | `terraform-ci-plan`, `terraform-ci-apply` |
| CI policy | `policy-waterloorocketry-terraform-ci-allow` |

The CI policy statements:

```text
Allow group 'Default'/'terraform-ci-plan' to read all-resources in tenancy
Allow group 'Default'/'terraform-ci-plan' to read objects in tenancy where target.bucket.name = 'waterloorocketry-terraform-state-ca-toronto-1'
Allow group 'Default'/'terraform-ci-apply' to read all-resources in tenancy
Allow group 'Default'/'terraform-ci-apply' to manage objects in tenancy where target.bucket.name = 'waterloorocketry-terraform-state-ca-toronto-1'
Allow group 'Default'/'terraform-ci-apply' to manage virtual-network-family in tenancy
Allow group 'Default'/'terraform-ci-apply' to manage instance-family in tenancy
Allow group 'Default'/'terraform-ci-apply' to manage buckets in tenancy
Allow group 'Default'/'terraform-ci-apply' to manage usage-budgets in tenancy
```

### Other manual resources

| Area | Resources | Why it stays manual |
| --- | --- | --- |
| Identity | The Default identity domain; its users; groups `Administrators` and `All Domain Users`; policy `Tenant Admin Policy` | A bad apply could lock every admin out. |
| Service policy | `console-iam-policy-20261124-2217`: `Allow service objectstorage-ca-toronto-1 to manage object-family in tenancy` | Lets Object Storage run lifecycle and replication work. Policies stay out of CI's reach. |
| Tags | Tag namespace `Oracle-Tags`, tag defaults `CreatedBy` and `CreatedOn` | Created with the tenancy. Terraform ignores `defined_tags` on every resource. |
| Billing | Payment method, account type, invoices, subscription | The OCI Terraform provider cannot manage them. |
| Inside the VMs | SSH keys, OS packages, services, data | Terraform ignores instance `metadata`. |
| Instance power state | Start, stop, reboot | Not set in the config, so it causes no drift. |
| Oracle-managed | `ManagedCompartmentForPaaS` and policy `PSM-root-policy-compartments`; OS Management Hub sources and profiles; identity domain system apps; the VCN DNS resolver, view and protected zones | Owned by Oracle services. Do not edit them. |

## Rotate a CI API key

Rotate a CI user's key when it may have leaked, or when someone who had it leaves the team. A user can have at most 3 API keys, so the old and new keys can overlap.

1. Generate a key pair on your machine:

   ```sh
   openssl genrsa -out ci-key.pem 2048
   openssl rsa -in ci-key.pem -pubout -out ci-key-public.pem
   ```

2. Add the public key to the user. Console: **Identity & Security** > **Domains** > the user's domain > **Users** > the user > **API keys** > **Add API key** > **Paste a public key**. Or with the CLI:

   ```sh
   oci iam user api-key upload --user-id <user OCID> --key-file ci-key-public.pem
   ```

   Note the fingerprint it shows.

3. Update the GitHub environment for that user (`oci-plan` for the plan user, `oci-apply` for the apply user): set the secret `OCI_PRIVATE_KEY` to the contents of `ci-key.pem`, and the variable `OCI_FINGERPRINT` to the new fingerprint.

   ```sh
   gh secret set OCI_PRIVATE_KEY --env oci-plan < ci-key.pem
   gh variable set OCI_FINGERPRINT --env oci-plan --body "<new fingerprint>"
   ```

4. Check that the key works: for the plan user, re-run the latest `terraform` workflow run, or start the `drift` workflow. For the apply user, the next apply is the check.
5. Delete the old key from the user's **API keys** list.
6. Delete `ci-key.pem` and `ci-key-public.pem` from your machine.

## Give CI access to a new kind of resource

The apply user can only manage the resource types in the [CI policy statements](#terraform-bootstrap). Before merging a PR that adds a resource type they do not cover (for example a load balancer or a vault), add a statement for the apply group, and add it to that list:

```text
Allow group 'Default'/'terraform-ci-apply' to manage load-balancers in tenancy
```

Console: **Identity & Security** > **Policies** > `policy-waterloorocketry-terraform-ci-allow` > **Edit policy statements**. The [policy reference](https://docs.oracle.com/en-us/iaas/Content/Identity/Reference/policyreference.htm) lists the resource-type names. If you skip this step, the apply fails with `404 NotAuthorizedOrNotFound`.

Keep the plan group's statements read-only, because any branch can use its key. CI plans skip the state lock, so the plan group does not need to write to the state bucket. `read all-resources` also lets it read objects in every other bucket, so do not keep secrets in buckets.

Never give either CI group `manage policies`, `manage groups`, `manage users` or `manage all-resources`. With any of these, CI could grant itself full control of the tenancy.

## State bucket

- Keep **Object Versioning** on. It is how an earlier state is restored (see [troubleshooting](troubleshooting.md#restore-an-earlier-state)).
- Keep it private, and do not create pre-authenticated requests. State contains every resource attribute.
- Never delete the bucket or its state objects. Lock objects end in `.lock`. Remove a stale lock with `terraform force-unlock`, not by deleting the object.
- If the bucket is ever recreated under a new name, update `backend.tf` in every stack and the `target.bucket.name` conditions in the CI policy.

## Instances

- **Start, stop or reboot:** **Compute** > **Instances** > the instance > **Start**, **Stop** or **Reboot**. This causes no drift.
- **SSH keys:** change them on the host, in `~/.ssh/authorized_keys`. Terraform ignores instance metadata. A metadata change made through Terraform could recreate the instance.
- **Resize** (OCPUs, memory) or **rename:** use a PR. The plan should show an in-place update.
- **Boot volume backups:** create one before risky work: **Storage** > **Boot volumes** > the volume > **Create boot volume backup**. Backups count toward the Always Free limits.
- **Idle reclamation:** Oracle may reclaim an idle Always Free instance (see the Always Free page below for the rule). If it is stopped, start it again; this causes no drift. If it is deleted, the drift check shows `+ create`. Do not just apply that plan, which creates a new instance from the image without its data. Decide first whether to restore from a backup or rebuild.
- **`Out of host capacity`** when creating an A1 instance: a temporary shortage of Always Free capacity. Try again later.

## Stay in the Always Free tier

Keep every resource within Oracle's [Always Free resources](https://docs.oracle.com/en-us/iaas/Content/FreeTier/freetier_topic-Always_Free_Resources.htm). The limits apply to the whole tenancy, so add up all existing resources, not only the ones in your PR.

- Before adding or resizing a resource, check its shape and size against that page. Compute, block volume (boot volumes included) and Object Storage are the limits most easily passed.
- Check **Billing & Cost Management** > **Cost Analysis** each month. Spend should be $0.00.
- The budget and its alert rules are in Terraform. Change them with a PR.

## Billing and account

Done only in the console, under **Billing & Cost Management**: payment method, account upgrade, invoices and subscription details.
