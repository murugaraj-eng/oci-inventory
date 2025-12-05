
variable "tenancy_ocid" {
  description = "Tenancy OCID"
  type        = string
}

variable "user_ocid" {
  description = "User OCID for the API key"
  type        = string
}

variable "fingerprint" {
  description = "API key fingerprint"
  type        = string
}

variable "private_key_path" {
  description = "Path to the private key used for the API key"
  type        = string
}

variable "region" {
  description = "OCI home region (e.g., ap-hyderabad-1)"
  type        = string
}

# Optional filters
variable "include_compartments_in_subtree" {
  description = "Include sub-compartments when listing resources"
  type        = bool
  default     = true
}

variable "compartment_state" {
  description = "Filter compartments by lifecycle_state"
  type        = string
  default     = "ACTIVE"
}
