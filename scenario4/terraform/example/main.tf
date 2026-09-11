# Usage example (root module) — providers for the three locations in the diagram.
# Deploy once per prod account; instantiate per account at scale via your
# account-factory pipeline (or AWS Organizations backup policies as a complement).

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
  }
}

# Prod account, Frankfurt (source)
provider "aws" {
  region = "eu-central-1"
}

# Prod account, Ireland (cross-region copy vault)
provider "aws" {
  alias  = "dr"
  region = "eu-west-1"
}

# Backup account, Frankfurt (cross-account copy vault) via an org account-assume role
provider "aws" {
  alias  = "backup_account"
  region = "eu-central-1"
  assume_role {
    role_arn = "arn:aws:iam::222233334444:role/OrganizationAccountAccessRole"
  }
}

module "backup_policy" {
  source = "../"

  providers = {
    aws      = aws
    aws.dr   = aws.dr
    aws.dest = aws.backup_account
  }

  backup_account_id = "222233334444"

  plan_name                     = "euler-backup-plan"
  schedule                      = "cron(0 5 * * ? *)"
  retention_days                = 35
  dr_region_retention_days      = 90
  backup_account_retention_days = 180

  vault_lock = {
    changeable_for_days = 7 # compliance lock is IRREVERSIBLE after 7 days
    min_retention_days  = 7
    max_retention_days  = 365
  }

  backup_tag_key   = "ToBackup"
  backup_tag_value = "true"
  owner_tag_key    = "Owner"
  owner_tag_value  = "owner@eulerhermes.com"
}
