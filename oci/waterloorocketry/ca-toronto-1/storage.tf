resource "oci_objectstorage_bucket" "misc_services" {
  compartment_id = var.tenancy_ocid
  namespace      = "yzpwk4utrxdv"
  name           = "waterloorocketry-misc-svc-ressources"
  access_type    = "NoPublicAccess"
  storage_tier   = "Standard"
  versioning     = "Disabled"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [defined_tags]
  }
}
