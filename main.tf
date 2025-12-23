
############################################################
# 1) Identity: Tenancy & Compartments
############################################################

# Get tenancy details
data "oci_identity_tenancy" "this" {
  tenancy_id = var.tenancy_ocid
}

# List all compartments (optionally include sub-tree)
data "oci_identity_compartments" "all" {
  compartment_id            = var.tenancy_ocid
  compartment_id_in_subtree = var.include_compartments_in_subtree
  access_level              = "ACCESSIBLE"
}

locals {
  # Root compartment (tenancy) + active compartments
  compartments = concat(
    [
      {
        id               = var.tenancy_ocid
        name             = data.oci_identity_tenancy.this.name
        description      = "Tenancy root compartment"
        state  = "ACTIVE"
      }
    ],
    [
      for c in data.oci_identity_compartments.all.compartments :
      {
        id              = c.id
        name            = c.name
        description     = c.description
        state = c.state
      }
      if c.state == "ACTIVE"
    ]
  )

  compartment_ids = [for c in local.compartments : c.id]
}

############################################################
# 2) Core Networking: VCNs & Subnets
############################################################

data "oci_core_vcns" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
}

data "oci_core_subnets" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
}

############################################################
# 3) Compute: Instances
############################################################

data "oci_core_instances" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
  # Optional filters:
  # lifecycle_state = "RUNNING"
}

############################################################
# 4) Block Storage: Volumes & Boot Volumes
############################################################

data "oci_core_volumes" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
}

data "oci_core_boot_volumes" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
}

############################################################
# 5) Load Balancing
############################################################

data "oci_load_balancer_load_balancers" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
}

############################################################
# 6) Object Storage: Buckets (per namespace)
############################################################

# Get the Object Storage namespace for the tenancy
data "oci_objectstorage_namespace" "ns" {
  compartment_id = var.tenancy_ocid
}

# Buckets are compartment-scoped but require namespace_name
data "oci_objectstorage_bucket_summaries" "by_comp" {
  for_each       = toset(local.compartment_ids)
  compartment_id = each.key
  namespace      = data.oci_objectstorage_namespace.ns.namespace
}

############################################################
# 7) Identity: Users, Groups, Policies (tenancy-level)
############################################################

data "oci_identity_users" "all" {
  compartment_id = var.tenancy_ocid
}

data "oci_identity_groups" "all" {
  compartment_id = var.tenancy_ocid
}

data "oci_identity_policies" "all" {
  compartment_id = var.tenancy_ocid
}

############################################################
# 8) Consolidated Locals for Output
############################################################

locals {
  vcns = flatten([
    for cid, vcns in data.oci_core_vcns.by_comp :
    [
      for v in vcns.virtual_networks :
      {
        id              = v.id
        name            = v.display_name
        cidr_block      = v.cidr_block
        compartment_id  = v.compartment_id
        state           = v.state
        dns_label       = v.dns_label
        time_created    = v.time_created
      }
    ]
  ])

  subnets = flatten([
    for cid, subs in data.oci_core_subnets.by_comp :
    [
      for s in subs.subnets :
      {
        id              = s.id
        name            = s.display_name
        cidr_block      = s.cidr_block
        compartment_id  = s.compartment_id
        vcn_id          = s.vcn_id
        route_table_id  = s.route_table_id
        dhcp_options_id = s.dhcp_options_id
        security_list_ids = s.security_list_ids
        time_created    = s.time_created
        state           = s.state
      }
    ]
  ])

  instances = flatten([
    for cid, insts in data.oci_core_instances.by_comp :
    [
      for i in insts.instances :
      {
        id              = i.id
        name            = i.display_name
        compartment_id  = i.compartment_id
        shape           = i.shape
        state           = i.state
        time_created    = i.time_created
        availability_domain = i.availability_domain
        region          = var.region
        freeform_tags   = i.freeform_tags
        defined_tags    = i.defined_tags
      }
    ]
  ])

  volumes = flatten([
    for cid, vols in data.oci_core_volumes.by_comp :
    [
      for v in vols.volumes :
      {
        id              = v.id
        name            = v.display_name
        size_in_gbs     = v.size_in_gbs
        compartment_id  = v.compartment_id
        state           = v.state
        time_created    = v.time_created
      }
    ]
  ])

  boot_volumes = flatten([
    for cid, bvs in data.oci_core_boot_volumes.by_comp :
    [
      for b in bvs.boot_volumes :
      {
        id              = b.id
        size_in_gbs     = b.size_in_gbs
        compartment_id  = b.compartment_id
        state           = b.state
        time_created    = b.time_created
        availability_domain = b.availability_domain
      }
    ]
  ])

  load_balancers = flatten([
    for cid, lbs in data.oci_load_balancer_load_balancers.by_comp :
    [
      for lb in lbs.load_balancers :
      {
        id              = lb.id
        name            = lb.display_name
        compartment_id  = lb.compartment_id
        shape           = lb.shape_name
        ip_addresses    = lb.ip_addresses
        is_private      = lb.is_private
        state           = lb.state
        time_created    = lb.time_created
      }
    ]
  ])

  buckets = flatten([
    for cid, bs in data.oci_objectstorage_bucket_summaries.by_comp :
    [
      for b in bs.bucket_summaries:
      {
        name            = b.name
        compartment_id  = b.compartment_id
        namespace       = data.oci_objectstorage_namespace.ns.namespace
        storage_tier    = b.storage_tier
        public_access   = b.access_type
        kms_key_id      = b.kms_key_id
        time_created    = b.time_created
        defined_tags    = b.defined_tags
        freeform_tags   = b.freeform_tags

      }
    ]
  ])

  users = [
    for u in data.oci_identity_users.all.users :
    {
      id           = u.id
      name         = u.name
      description  = u.description
      state        = u.state
      time_created = u.time_created
    }
  ]

  groups = [
    for g in data.oci_identity_groups.all.groups :
    {
      id           = g.id
      name         = g.name
      description  = g.description
      state        = g.state
      time_created = g.time_created
    }
  ]

  policies = [
    for p in data.oci_identity_policies.all.policies :
    {
      id              = p.id
      name            = p.name
      compartment_id  = p.compartment_id
      statements      = p.statements
      description     = p.description
      time_created    = p.time_created
      version_date    = p.version_date
      state           = p.state
    }
  ]
}
