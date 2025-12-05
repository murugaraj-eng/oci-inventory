
output "inventory" {
  description = "Consolidated OCI inventory across compartments"
  value = {
    tenancy = {
      id           = data.oci_identity_tenancy.this.id
      name         = data.oci_identity_tenancy.this.name
      home_region  = data.oci_identity_tenancy.this.home_region_key
    }

    compartments  = local.compartments
    networking    = {
      vcns    = local.vcns
      subnets = local.subnets
    }

    compute       = {
      instances = local.instances
    }

    storage       = {
      volumes      = local.volumes
      boot_volumes = local.boot_volumes
      buckets      = local.buckets
    }

    load_balancing = {
      load_balancers = local.load_balancers
    }

    identity = {
      users    = local.users
      groups   = local.groups
      policies = local.policies
    }
  }
  sensitive = true
}
