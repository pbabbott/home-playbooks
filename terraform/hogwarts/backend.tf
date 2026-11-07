# State lives in Postgres on the NAS (db `terraform_state`, schema per root). Connection string comes from the
# environment so no credentials are in git:  source ../../scripts/tfstate-env.sh   (exports PG_CONN_STR)
# One-time (manual) setup of the database/role: ../../docs/TERRAFORM-STATE.md
terraform {
  backend "pg" {
    schema_name = "hogwarts"
  }
}
