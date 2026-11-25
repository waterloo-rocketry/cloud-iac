# Oracle sets the Oracle-Tags.CreatedBy and Oracle-Tags.CreatedOn tag defaults on every resource,
# so each resource here ignores defined_tags instead of repeating those values.

resource "oci_core_vcn" "main" {
  compartment_id = var.tenancy_ocid
  display_name   = "vcn-20231012-2028"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "vcn10122029"

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [defined_tags]
  }
}

resource "oci_core_internet_gateway" "main" {
  compartment_id = var.tenancy_ocid
  vcn_id         = oci_core_vcn.main.id
  display_name   = "Internet Gateway vcn-20231012-2028"
  enabled        = true

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_default_route_table" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_route_table_id
  compartment_id             = var.tenancy_ocid
  display_name               = "Default Route Table for vcn-20231012-2028"

  route_rules {
    destination       = "0.0.0.0/0"
    destination_type  = "CIDR_BLOCK"
    network_entity_id = oci_core_internet_gateway.main.id
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_default_security_list" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_security_list_id
  compartment_id             = var.tenancy_ocid
  display_name               = "Default Security List for vcn-20231012-2028"

  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # ICMP "destination unreachable" from inside the VCN.
  ingress_security_rules {
    source   = "10.0.0.0/16"
    protocol = "1"

    icmp_options {
      type = 3
    }
  }

  # ICMP "fragmentation needed" from anywhere, for path MTU discovery.
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "1"

    icmp_options {
      type = 3
      code = 4
    }
  }

  # SSH
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"

    tcp_options {
      min = 22
      max = 22
    }
  }

  # HTTPS
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"

    tcp_options {
      min = 443
      max = 443
    }
  }

  # HTTP
  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"

    tcp_options {
      min = 80
      max = 80
    }
  }

  ingress_security_rules {
    source   = "0.0.0.0/0"
    protocol = "6"

    tcp_options {
      min = 8000
      max = 9000
    }
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_default_dhcp_options" "main" {
  manage_default_resource_id = oci_core_vcn.main.default_dhcp_options_id
  compartment_id             = var.tenancy_ocid
  display_name               = "Default DHCP Options for vcn-20231012-2028"
  domain_name_type           = "CUSTOM_DOMAIN"

  options {
    type                = "SearchDomain"
    search_domain_names = ["vcn10122029.oraclevcn.com"]
  }

  options {
    type        = "DomainNameServer"
    server_type = "VcnLocalPlusInternet"
  }

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_core_subnet" "public" {
  compartment_id             = var.tenancy_ocid
  vcn_id                     = oci_core_vcn.main.id
  display_name               = "subnet-20231012-2028"
  cidr_block                 = "10.0.0.0/24"
  dns_label                  = "subnet10122029"
  prohibit_public_ip_on_vnic = false
  route_table_id             = oci_core_default_route_table.main.id
  dhcp_options_id            = oci_core_default_dhcp_options.main.id
  security_list_ids          = [oci_core_default_security_list.main.id]

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [defined_tags]
  }
}
