# data sources

data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

# KMS keys (plan: backup encryption)

data "aws_iam_policy_document" "source_key" {
  # prod/Frankfurt and prod/Ireland (same account)
  statement {
    sid       = "RootAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
  statement {
    sid       = "BackupService"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:ReEncrypt*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
}

resource "aws_kms_key" "source" {
  description             = "AWS Backup vault key - prod source"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.source_key.json
}

resource "aws_kms_key" "dr" {
  provider                = aws.dr
  description             = "AWS Backup vault key - Disaster Recovery copy"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.source_key.json
}

# Cross-account key: additionally lets the SOURCE backup role re-encrypt copies into it
data "aws_iam_policy_document" "dest_key" {
  statement {
    sid       = "DestRootAccess"
    effect    = "Allow"
    actions   = ["kms:*"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${var.backup_account_id}:root"]
    }
  }
  statement {
    sid       = "BackupService"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey", "kms:ReEncrypt*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "Service"
      identifiers = ["backup.amazonaws.com"]
    }
  }
  statement {
    sid       = "SourceAccountCopies"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:DescribeKey"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = [aws_iam_role.backup.arn]
    }
  }
}

resource "aws_kms_key" "dest" {
  provider                = aws.dest
  description             = "AWS Backup vault key - cross-account copy"
  deletion_window_in_days = var.kms_deletion_window_days
  enable_key_rotation     = true
  policy                  = data.aws_iam_policy_document.dest_key.json
}

# vaults (all Vault-Locked)

resource "aws_backup_vault" "source" {
  name        = "${var.plan_name}-source"
  kms_key_arn = aws_kms_key.source.arn
}

resource "aws_backup_vault" "dr" {
  provider    = aws.dr
  name        = "${var.plan_name}-dr"
  kms_key_arn = aws_kms_key.dr.arn
}

resource "aws_backup_vault" "dest" {
  provider    = aws.dest
  name        = "${var.plan_name}-cross-account"
  kms_key_arn = aws_kms_key.dest.arn
}

# WORM: Vault Lock, COMPLIANCE mode once the cool-off (`changeable_for_days`) elapses.
# After the cool-off the lock is IRREVERSIBLE - min/max retention cannot be relaxed
# and recovery points cannot be deleted before min retention. All three vaults are
# locked so that copies inherit WORM protection in their final locations.

resource "aws_backup_vault_lock_configuration" "source" {
  backup_vault_name   = aws_backup_vault.source.name
  changeable_for_days = var.vault_lock.changeable_for_days
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
}

resource "aws_backup_vault_lock_configuration" "dr" {
  provider            = aws.dr
  backup_vault_name   = aws_backup_vault.dr.name
  changeable_for_days = var.vault_lock.changeable_for_days
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
}

resource "aws_backup_vault_lock_configuration" "dest" {
  provider            = aws.dest
  backup_vault_name   = aws_backup_vault.dest.name
  changeable_for_days = var.vault_lock.changeable_for_days
  min_retention_days  = var.vault_lock.min_retention_days
  max_retention_days  = var.vault_lock.max_retention_days
}

# Cross-account copies require the destination vault to admit the source account.
# Documented action: backup:CopyIntoBackupVault (vault access policies reject every
# other cross-account action). Cross-REGION copies (same account) need no vault policy.

data "aws_iam_policy_document" "dest_vault" {
  statement {
    sid       = "AllowSourceAccountCopyIn"
    effect    = "Allow"
    actions   = ["backup:CopyIntoBackupVault"]
    resources = ["*"]
    principals {
      type        = "AWS"
      identifiers = ["arn:${data.aws_partition.current.partition}:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
    condition {
      test     = "StringLike"
      variable = "backup:CopyTargetBackupVaultArn"
      values   = [aws_backup_vault.dest.arn]
    }
  }
}

resource "aws_backup_vault_policy" "dest" {
  provider          = aws.dest
  backup_vault_name = aws_backup_vault.dest.name
  policy            = data.aws_iam_policy_document.dest_vault.json
}

# IAM: AWS Backup role

resource "aws_iam_role" "backup" {
  name = "${var.plan_name}-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}
resource "aws_iam_role_policy_attachment" "restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForRestores"
}
resource "aws_iam_role_policy_attachment" "s3_backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Backup"
}
resource "aws_iam_role_policy_attachment" "s3_restore" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/AWSBackupServiceRolePolicyForS3Restore"
}

# Copy permissions: source role starts copy jobs, uses both destination vaults and keys.
data "aws_iam_policy_document" "copies" {
  statement {
    sid    = "CopyJobs"
    effect = "Allow"
    actions = [
      "backup:StartCopyJob",
      "backup:CopyIntoBackupVault",
    ]
    resources = [
      aws_backup_vault.dr.arn,
      aws_backup_vault.dest.arn,
      "arn:${data.aws_partition.current.partition}:backup:*:${var.backup_account_id}:backup-vault:*",
    ]
  }
  statement {
    sid       = "CopyKms"
    effect    = "Allow"
    actions   = ["kms:Decrypt", "kms:Encrypt", "kms:GenerateDataKey*", "kms:ReEncrypt*", "kms:DescribeKey"]
    resources = [aws_kms_key.source.arn, aws_kms_key.dr.arn, aws_kms_key.dest.arn]
  }
}

resource "aws_iam_role_policy" "copies" {
  name   = "cross-region-account-copies"
  role   = aws_iam_role.backup.id
  policy = data.aws_iam_policy_document.copies.json
}

# plan (frequency + retention + copies)

resource "aws_backup_plan" "this" {
  name = var.plan_name

  rule {
    rule_name                = "${var.plan_name}-daily"
    target_vault_name        = aws_backup_vault.source.name
    schedule                 = var.schedule
    start_window             = var.start_window_minutes
    completion_window        = var.completion_window_minutes
    enable_continuous_backup = var.enable_continuous_backup

    lifecycle {
      delete_after = var.retention_days
    }

    # Copy actions run on each rule execution ("defined frequency" = plan schedule);
    # retention per copy location; encryption = destination vault's KMS key.
    copy_action {
      destination_vault_arn = aws_backup_vault.dr.arn
      lifecycle {
        delete_after = var.dr_region_retention_days
      }
    }

    copy_action {
      destination_vault_arn = aws_backup_vault.dest.arn
      lifecycle {
        delete_after = var.backup_account_retention_days
      }
    }
  }

  advanced_backup_setting {
    backup_options = { WindowsVSS = "enabled" }
    resource_type  = "EC2"
  }
}

# selection (tag-based)

resource "aws_backup_selection" "this" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = var.selection_name
  plan_id      = aws_backup_plan.this.id

  # Multiple selection_tag blocks are ANDed:
  # resources must have ToBackup=true AND Owner=<owner>
  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.backup_tag_key
    value = var.backup_tag_value
  }

  selection_tag {
    type  = "STRINGEQUALS"
    key   = var.owner_tag_key
    value = var.owner_tag_value
  }
}
