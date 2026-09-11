output "backup_plan_arn" {
  description = "ARN of the deployed backup plan"
  value       = module.backup_policy.backup_plan_arn
}

output "vault_arns" {
  description = "The three Vault-Locked vaults: source, cross-region (DR), cross-account"
  value = {
    source        = module.backup_policy.source_vault_arn
    dr            = module.backup_policy.dr_vault_arn
    cross_account = module.backup_policy.cross_account_vault_arn
  }
}
