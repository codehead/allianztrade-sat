# AWS Backup policy module

A Terraform module that provisions a complete, WORM-protected AWS Backup posture:
a **source vault** in the prod account, a **cross-region copy vault** (DR region, same
account), and a **cross-account copy vault** (central backup account)  all three
**Vault-Locked in compliance mode**, fronted by a single backup plan with two copy
actions and tag-based resource selection.

Designed for the Scenario#4 requirements: daily backups of everything tagged
`ToBackup=true` **and** `Owner=<owner>`, 35-day source retention, copies to a DR region
(90 days) and to a separate Backup account (180 days), each location encrypted with its
own KMS key.

Tested with [Terraform](https://github.com/hashicorp/terraform) v1.16.2 and [OpenTofu](https://github.com/opentofu/opentofu) v1.12.6, and validated -as much as was possible- using [floci](https://floci.io/)

## Example usage

A ready-to-run root module lives in [`example/`](./example/). It wires the three
provider configurations the module expects — prod/source `eu-central-1` (default),
prod/DR `eu-west-1` (`aws.dr`), and the Backup account via an organization
assume-role (`aws.dest`) — and instantiates the module with the scenario defaults.

```shell
cd example

# Edit main.tf and replace the placeholders:
#    - the Backup account ID in the aws.dest assume-role ARN and in backup_account_id
#    - optionally, your real DR region on the aws.dr provider
terraform init
terraform plan
terraform apply
```

Notes:

- The example creates **real, billable resources in three locations** (two regions,
  two accounts). Point it at a scratch account first.
- **Teardown is gated by Vault Lock**: the lock configurations can only be deleted
  within the cool-off window (`changeable_for_days`, default 7 days). Destroy the
  stack within that window. After it lapses, **the compliance-mode lock is permanent and
  the vaults cannot be removed**.
- 
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.6.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | ~> 6.63 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 6.64.0 |
| <a name="provider_aws.dest"></a> [aws.dest](#provider\_aws.dest) | 6.64.0 |
| <a name="provider_aws.dr"></a> [aws.dr](#provider\_aws.dr) | 6.64.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_backup_plan.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_plan) | resource |
| [aws_backup_selection.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_selection) | resource |
| [aws_backup_vault.dest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault.dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault.source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault) | resource |
| [aws_backup_vault_lock_configuration.dest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_lock_configuration.dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_lock_configuration.source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_lock_configuration) | resource |
| [aws_backup_vault_policy.dest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/backup_vault_policy) | resource |
| [aws_iam_role.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.copies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.restore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_backup](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_iam_role_policy_attachment.s3_restore](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |
| [aws_kms_key.dest](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.dr](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_kms_key.source](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |
| [aws_iam_policy_document.copies](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dest_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.dest_vault](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_iam_policy_document.source_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/iam_policy_document) | data source |
| [aws_partition.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/partition) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_backup_account_id"></a> [backup\_account\_id](#input\_backup\_account\_id) | Cross-account copy target (Backup account) | `string` | n/a | yes |
| <a name="input_backup_account_retention_days"></a> [backup\_account\_retention\_days](#input\_backup\_account\_retention\_days) | Retention of the cross-account copies (Backup account vault) | `number` | `180` | no |
| <a name="input_backup_tag_key"></a> [backup\_tag\_key](#input\_backup\_tag\_key) | Tag key selecting resources to back up | `string` | `"ToBackup"` | no |
| <a name="input_backup_tag_value"></a> [backup\_tag\_value](#input\_backup\_tag\_value) | Tag value selecting resources to back up | `string` | `"true"` | no |
| <a name="input_completion_window_minutes"></a> [completion\_window\_minutes](#input\_completion\_window\_minutes) | Minutes within which the backup job must complete | `number` | `360` | no |
| <a name="input_dr_region_retention_days"></a> [dr\_region\_retention\_days](#input\_dr\_region\_retention\_days) | Retention of the cross-region copies (DR vault) | `number` | `90` | no |
| <a name="input_enable_continuous_backup"></a> [enable\_continuous\_backup](#input\_enable\_continuous\_backup) | PITR-style continuous backup for supported resources (RDS/S3) | `bool` | `false` | no |
| <a name="input_kms_deletion_window_days"></a> [kms\_deletion\_window\_days](#input\_kms\_deletion\_window\_days) | Days KMS keys wait (and stay recoverable) before permanent deletion | `number` | `30` | no |
| <a name="input_owner_tag_key"></a> [owner\_tag\_key](#input\_owner\_tag\_key) | Tag key identifying the owning team/service (second AND condition) | `string` | `"Owner"` | no |
| <a name="input_owner_tag_value"></a> [owner\_tag\_value](#input\_owner\_tag\_value) | Tag value identifying the owning team/service | `string` | `"owner@eulerhermes.com"` | no |
| <a name="input_plan_name"></a> [plan\_name](#input\_plan\_name) | Name of the AWS Backup plan and prefix for all vaults | `string` | `"euler-backup-plan"` | no |
| <a name="input_retention_days"></a> [retention\_days](#input\_retention\_days) | Retention on the source (prod) vault | `number` | `35` | no |
| <a name="input_schedule"></a> [schedule](#input\_schedule) | Backup frequency (cron, as required by aws\_backup\_plan rule.schedule) | `string` | `"cron(0 5 * * ? *)"` | no |
| <a name="input_selection_name"></a> [selection\_name](#input\_selection\_name) | Name of the tag-based backup selection | `string` | `"tagged-resources"` | no |
| <a name="input_start_window_minutes"></a> [start\_window\_minutes](#input\_start\_window\_minutes) | Minutes after the scheduled start within which the backup job must start | `number` | `60` | no |
| <a name="input_vault_lock"></a> [vault\_lock](#input\_vault\_lock) | Compliance-mode Vault Lock settings, applied to ALL three vaults.<br/>changeable\_for\_days = cool-off period, after which the lock is IRREVERSIBLE.<br/>Keep min <= all retention values <= max. | <pre>object({<br/>    changeable_for_days = optional(number, 7)<br/>    min_retention_days  = optional(number, 7)<br/>    max_retention_days  = optional(number, 365)<br/>  })</pre> | <pre>{<br/>  "changeable_for_days": 7,<br/>  "max_retention_days": 365,<br/>  "min_retention_days": 7<br/>}</pre> | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_backup_plan_arn"></a> [backup\_plan\_arn](#output\_backup\_plan\_arn) | ARN of the backup plan with source rule and both copy actions |
| <a name="output_backup_role_arn"></a> [backup\_role\_arn](#output\_backup\_role\_arn) | IAM role used by AWS Backup for snapshots and cross-region/account copies |
| <a name="output_cross_account_vault_arn"></a> [cross\_account\_vault\_arn](#output\_cross\_account\_vault\_arn) | Cross-account copy vault (Backup account) |
| <a name="output_dr_vault_arn"></a> [dr\_vault\_arn](#output\_dr\_vault\_arn) | Cross-region copy vault (prod account, DR region) |
| <a name="output_source_vault_arn"></a> [source\_vault\_arn](#output\_source\_vault\_arn) | Source vault (prod/Frankfurt) holding the plan's primary recovery points |
| <a name="output_vault_locks"></a> [vault\_locks](#output\_vault\_locks) | WORM state of all three vaults (compliance mode after the cool-off) |
