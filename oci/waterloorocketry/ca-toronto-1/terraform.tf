terraform {
  required_version = "~> 1.17"

  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 9.14"
    }
  }
}
