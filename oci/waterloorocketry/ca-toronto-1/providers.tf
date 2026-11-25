# Credentials come from the DEFAULT profile in ~/.oci/config.
# CI writes that file from the oci-plan or oci-apply environment.
provider "oci" {
  region = "ca-toronto-1"
}
