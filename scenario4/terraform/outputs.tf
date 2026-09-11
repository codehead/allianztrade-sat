output "source_vault_arn" {
  description = "Source vault (prod/Frankfurt) holding the plan's primary recovery points"
  value       = aws_backup_vault.source.arn
}

output "dr_vault_arn" {
  description = "Cross-region copy vault (prod account, DR region)"
  value       = aws_backup_vault.dr.arn
}

output "cross_account_vault_arn" {
  description = "Cross-account copy vault (Backup account)"
  value       = aws_backup_vault.dest.arn
}

output "backup_plan_arn" {
  description = "ARN of the backup plan with source rule and both copy actions"
  value       = aws_backup_plan.this.arn
}

output "backup_role_arn" {
  description = "IAM role used by AWS Backup for snapshots and cross-region/account copies"
  value       = aws_iam_role.backup.arn
}

output "vault_locks" {
  description = "WORM state of all three vaults (compliance mode after the cool-off)"
  value = {
    source        = aws_backup_vault_lock_configuration.source.backup_vault_name
    dr            = aws_backup_vault_lock_configuration.dr.backup_vault_name
    cross_account = aws_backup_vault_lock_configuration.dest.backup_vault_name
  }
}
