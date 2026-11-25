# Adopts resources created in the OCI console. Remove these blocks after they are applied.

import {
  to = oci_core_vcn.main
  id = "ocid1.vcn.oc1.ca-toronto-1.amaaaaaaxscp5daahxkf42v7ovgpbh4hbyw4sagkjtyl7wafggakfeuou6rq"
}

import {
  to = oci_core_subnet.public
  id = "ocid1.subnet.oc1.ca-toronto-1.aaaaaaaa2iilnhkw63b4r2slslm6pjooysajmes2uum2fggpce74bninc2xq"
}

import {
  to = oci_core_internet_gateway.main
  id = "ocid1.internetgateway.oc1.ca-toronto-1.aaaaaaaaxdpcohrotpsm27s24fgnkxsvi3qjixxic2ng7gvc6s2ghlfkg3ya"
}

import {
  to = oci_core_default_route_table.main
  id = "ocid1.routetable.oc1.ca-toronto-1.aaaaaaaap7k2kx6ko4ubvemc6ppu5akckzf3hkvxdasvahugnivxydj5tdaa"
}

import {
  to = oci_core_default_security_list.main
  id = "ocid1.securitylist.oc1.ca-toronto-1.aaaaaaaaewurqd7vmutguzrmemvesblchvuwg2nqjf4ko3vtlaj3yzj2irca"
}

import {
  to = oci_core_default_dhcp_options.main
  id = "ocid1.dhcpoptions.oc1.ca-toronto-1.aaaaaaaa3foqse4uibrxui6rtdpzf5s432a75tryh3hhocqgafuqe3v5zo4a"
}

import {
  to = oci_core_instance.server
  id = "ocid1.instance.oc1.ca-toronto-1.an2g6ljrxscp5dacdlziyrwan6wjlpepm6hhkrpkcfopdjwdr6xvpugnjwwa"
}

import {
  to = oci_core_instance.daq_staging
  id = "ocid1.instance.oc1.ca-toronto-1.an2g6ljrxscp5dacbgnttmhlfzk2z7omdohrpupumbi4tlibtrmy2pugc6ga"
}

import {
  to = oci_core_image.debian_13_arm64
  id = "ocid1.image.oc1.ca-toronto-1.aaaaaaaaodoh6bw2zz5hr6ebtqshk3jt5jd7rnpgc7yldf75acp74v2ixqkq"
}

import {
  to = oci_core_compute_image_capability_schema.debian_13_arm64
  id = "ocid1.computeimgcapschema.oc1.ca-toronto-1.aaaaaaaauhwqboqasjz5xqdnxvbci5ryhqo3scxejnqndlzxpotwqxj3q65q"
}
