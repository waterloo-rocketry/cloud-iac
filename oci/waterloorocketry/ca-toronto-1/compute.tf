# Instances ignore changes to:
# - metadata: SSH keys are managed on the hosts, and editing them here could recreate an instance.
# - source_details and create_vnic_details: they only apply at launch, so OCI cannot change them in place.
# - defined_tags: Oracle sets the Oracle-Tags defaults.

resource "oci_core_instance" "server" {
  compartment_id      = var.tenancy_ocid
  availability_domain = "vilg:CA-TORONTO-1-AD-1"
  fault_domain        = "FAULT-DOMAIN-1"
  display_name        = "waterloorocketry-server"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 2
    memory_in_gbs = 12
  }

  source_details {
    source_type             = "image"
    source_id               = "ocid1.image.oc1.ca-toronto-1.aaaaaaaav4b5wgn6jyzz2wj4n6vbrfp4qxyxjjg3z5u7cyziypsw2hbcrm3a" # Oracle platform image
    boot_volume_size_in_gbs = 47
    boot_volume_vpus_per_gb = 10
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "waterloorocketry-server"
    hostname_label   = "waterloorocketry-server"
    private_ip       = "10.0.0.198"
    assign_public_ip = true
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [metadata, source_details, create_vnic_details, defined_tags]
  }
}

resource "oci_core_instance" "daq_staging" {
  compartment_id      = var.tenancy_ocid
  availability_domain = "vilg:CA-TORONTO-1-AD-1"
  fault_domain        = "FAULT-DOMAIN-2"
  display_name        = "waterloorocketry-daq-staging-aq4gp5"
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 1
    memory_in_gbs = 6
  }

  source_details {
    source_type             = "image"
    source_id               = oci_core_image.debian_13_arm64.id
    boot_volume_size_in_gbs = 47
    boot_volume_vpus_per_gb = 10
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.public.id
    display_name     = "waterloorocketry-vnic-daq-staging-aq4gp5"
    hostname_label   = "waterloorocketry-vnic-daq-staging-aq4gp5"
    private_ip       = "10.0.0.211"
    assign_public_ip = true
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [metadata, source_details, create_vnic_details, defined_tags]
  }
}

# Custom image imported into OCI. OCI keeps its own copy, so it does not depend on any bucket object.
resource "oci_core_image" "debian_13_arm64" {
  compartment_id = var.tenancy_ocid
  display_name   = "debian-13-generic-arm64"
  launch_mode    = "PARAVIRTUALIZED"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [defined_tags]
  }
}

# Boot settings for VMs launched from the custom image: UEFI firmware, paravirtualized storage
# and network, encryption in transit. Created in the console after the image was imported.
# The values are kept as OCI returns them, so the import plans no change.
resource "oci_core_compute_image_capability_schema" "debian_13_arm64" {
  compartment_id                                      = var.tenancy_ocid
  image_id                                            = oci_core_image.debian_13_arm64.id
  display_name                                        = "computeimgcapschema20260421195446"
  compute_global_image_capability_schema_version_name = "a5bfdad8-4867-48be-85e5-5082e94bce9d"

  schema_data = {
    "Compute.AMD_SecureEncryptedVirtualization"      = "{\"descriptorType\":\"boolean\",\"defaultValue\":false,\"source\":\"IMAGE\"}"
    "Compute.Firmware"                               = "{\"descriptorType\":\"enumstring\",\"values\":[\"UEFI_64\"],\"defaultValue\":\"UEFI_64\",\"source\":\"IMAGE\"}"
    "Compute.LaunchMode"                             = "{\"descriptorType\":\"enumstring\",\"values\":[\"NATIVE\",\"EMULATED\",\"VDPA\",\"PARAVIRTUALIZED\",\"CUSTOM\"],\"defaultValue\":\"PARAVIRTUALIZED\",\"source\":\"IMAGE\"}"
    "Compute.SecureBoot"                             = "{\"descriptorType\":\"boolean\",\"defaultValue\":false,\"source\":\"IMAGE\"}"
    "Network.AttachmentType"                         = "{\"descriptorType\":\"enumstring\",\"values\":[\"VFIO\",\"PARAVIRTUALIZED\",\"E1000\",\"VDPA\"],\"defaultValue\":\"PARAVIRTUALIZED\",\"source\":\"IMAGE\"}"
    "Network.IPv6Only"                               = "{\"descriptorType\":\"boolean\",\"defaultValue\":false,\"source\":\"IMAGE\"}"
    "Storage.BootVolumeType"                         = "{\"descriptorType\":\"enumstring\",\"values\":[\"ISCSI\",\"PARAVIRTUALIZED\",\"SCSI\",\"IDE\",\"NVME\"],\"defaultValue\":\"PARAVIRTUALIZED\",\"source\":\"IMAGE\"}"
    "Storage.ConsistentVolumeNaming"                 = "{\"descriptorType\":\"boolean\",\"defaultValue\":true,\"source\":\"IMAGE\"}"
    "Storage.Iscsi.MultipathDeviceSupported"         = "{\"descriptorType\":\"boolean\",\"defaultValue\":false,\"source\":\"IMAGE\"}"
    "Storage.LocalDataVolumeType"                    = "{\"descriptorType\":\"enumstring\",\"values\":[\"ISCSI\",\"PARAVIRTUALIZED\",\"SCSI\",\"IDE\",\"NVME\"],\"defaultValue\":\"PARAVIRTUALIZED\",\"source\":\"IMAGE\"}"
    "Storage.ParaVirtualization.AttachmentVersion"   = "{\"descriptorType\":\"enuminteger\",\"values\":[1,2],\"defaultValue\":2,\"source\":\"IMAGE\"}"
    "Storage.ParaVirtualization.EncryptionInTransit" = "{\"descriptorType\":\"boolean\",\"defaultValue\":true,\"source\":\"IMAGE\"}"
    "Storage.RemoteDataVolumeType"                   = "{\"descriptorType\":\"enumstring\",\"values\":[\"ISCSI\",\"PARAVIRTUALIZED\",\"SCSI\",\"IDE\",\"NVME\"],\"defaultValue\":\"PARAVIRTUALIZED\",\"source\":\"IMAGE\"}"
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}
