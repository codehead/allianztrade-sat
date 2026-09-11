# Scenario 4 — AWS Backup policy module
# One module, three Vault-Locked vaults:
#   source (prod/Frankfurt) + cross-region copy vault (prod/Ireland)
#   + cross-account copy vault (backup account/frankfurt).
# Tag-based selection: ToBackup=true AND Owner=<owner>

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.63"
    }
  }
}

# Placeholder provider configs for the aliased providers used by this module.
# The CALLER maps them via the module's `providers` meta-argument
# (aws.dr -> Disaster Recovery region provider, aws.dest -> backup-account provider);
# these empty declarations only let the module stand alone for validation.
provider "aws" {
  alias = "dr"
}

provider "aws" {
  alias = "dest"
}
