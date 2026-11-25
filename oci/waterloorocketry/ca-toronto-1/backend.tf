terraform {
  backend "oci" {
    bucket    = "waterloorocketry-terraform-state-ca-toronto-1"
    namespace = "yzpwk4utrxdv"
    region    = "ca-toronto-1"
    key       = "oci/waterloorocketry/ca-toronto-1/terraform.tfstate"
  }
}
