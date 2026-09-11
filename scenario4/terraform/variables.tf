# inputs

variable "plan_name" {
  description = "Name of the AWS Backup plan and prefix for all vaults"
  type        = string
  default     = "euler-backup-plan"
}

variable "schedule" {
  description = "Backup frequency (cron, as required by aws_backup_plan rule.schedule)"
  type        = string
  default     = "cron(0 5 * * ? *)" # daily 05:00 UTC
}

variable "enable_continuous_backup" {
  description = "PITR-style continuous backup for supported resources (RDS/S3)"
  type        = bool
  default     = false
}

variable "retention_days" {
  description = "Retention on the source (prod) vault"
  type        = number
  default     = 35
}

variable "dr_region_retention_days" {
  description = "Retention of the cross-region copies (DR vault)"
  type        = number
  default     = 90
}

variable "backup_account_retention_days" {
  description = "Retention of the cross-account copies (Backup account vault)"
  type        = number
  default     = 180
}

variable "start_window_minutes" {
  description = "Minutes after the scheduled start within which the backup job must start"
  type        = number
  default     = 60
}

variable "completion_window_minutes" {
  description = "Minutes within which the backup job must complete"
  type        = number
  default     = 360
}

# resource selection

variable "selection_name" {
  description = "Name of the tag-based backup selection"
  type        = string
  default     = "tagged-resources"
}

variable "backup_tag_key" {
  description = "Tag key selecting resources to back up"
  type        = string
  default     = "ToBackup"
}

variable "backup_tag_value" {
  description = "Tag value selecting resources to back up"
  type        = string
  default     = "true"
}

variable "owner_tag_key" {
  description = "Tag key identifying the owning team/service (second AND condition)"
  type        = string
  default     = "Owner"
}

variable "owner_tag_value" {
  description = "Tag value identifying the owning team/service"
  type        = string
  default     = "owner@eulerhermes.com"
}

# WORM (Vault Lock)

variable "vault_lock" {
  description = <<-EOT
    Compliance-mode Vault Lock settings, applied to ALL three vaults.
    changeable_for_days = cool-off period, after which the lock is IRREVERSIBLE.
    Keep min <= all retention values <= max.
  EOT
  type = object({
    changeable_for_days = optional(number, 7)
    min_retention_days  = optional(number, 7)
    max_retention_days  = optional(number, 365)
  })
  default = {
    changeable_for_days = 7
    min_retention_days  = 7
    max_retention_days  = 365
  }
}

# topology

variable "backup_account_id" {
  description = "Cross-account copy target (Backup account)"
  type        = string
}

variable "kms_deletion_window_days" {
  description = "Days KMS keys wait (and stay recoverable) before permanent deletion"
  type        = number
  default     = 30
}
