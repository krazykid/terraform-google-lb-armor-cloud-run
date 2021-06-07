variable "project_id" {
  type        = string
  description = "GCP project ID to set up in"
}

variable "build_env_vars_dict" {
  type        = map(string)
  description = "Environment variables to set during the initial build of the CR container"
}

variable "cr_service_name_str" {
  type        = string
  description = "Cloud Run service name"
}

variable "cr_region_str" {
  type        = string
  description = "GCP region to run the CR service in"
}

variable "build_command" {
  type        = string
  description = "Path to the cloud build script"
}

variable "create_service_acct_bool" {
  type        = bool
  description = "Boolean on whether or not to create a service account for the CR service"
}

variable "service_acct_id" {
  type        = string
  description = "Service account id"
}

variable "service_acct_display_name" {
  type        = string
  description = "Display name for the new service account"
}

variable "cr_fqdn_list" {
  type        = list(string)
  description = "FQDNs to put on to the SSL certificate"
}

variable "cloud_armor_preview_bool" {
  type        = bool
  description = "Boolean on whether Cloud Armor rules should run in preview mode"
}

variable "cloud_armor_expr_rules" {
  type = list(object({
    description = string
    action      = string
    priority    = number
    match_expr  = string
  }))
  description = "List of dictionaries that describe the Cloud Armor rules"
  default = [
    {
      description = "Deny SQL Injection Attacks"
      action      = "deny(403)"
      priority    = 1
      match_expr  = "evaluatePreconfiguredExpr('sqli-stable', ['owasp-crs-v030001-id942251-sqli', 'owasp-crs-v030001-id942420-sqli', 'owasp-crs-v030001-id942431-sqli', 'owasp-crs-v030001-id942460-sqli', 'owasp-crs-v030001-id942421-sqli', 'owasp-crs-v030001-id942432-sqli', 'owasp-crs-v030001-id942200-sqli', 'owasp-crs-v030001-id942260-sqli', 'owasp-crs-v030001-id942340-sqli', 'owasp-crs-v030001-id942430-sqli'])"
    },
    {
      description = "Deny XSS Attacks"
      action      = "deny(403)"
      priority    = 2
      match_expr  = "evaluatePreconfiguredExpr('xss-stable')"
    },
    {
      description = "Deny Local File Inclusion Attacks"
      action      = "deny(403)"
      priority    = 3
      match_expr  = "evaluatePreconfiguredExpr('lfi-stable')"
    },
    {
      description = "Deny Remote Code Execution Attacks"
      action      = "deny(403)"
      priority    = 4
      match_expr  = "evaluatePreconfiguredExpr('rce-stable')"
    },
    {
      description = "Deny Remote File Inclusion Attacks"
      action      = "deny(403)"
      priority    = 5
      match_expr  = "evaluatePreconfiguredExpr('rfi-stable')"
    },
  ]
}

variable "cloud_armor_versioned_expr_rules" {
  type = list(object({
    description          = string
    action               = string
    priority             = number
    versioned_expr       = string
    config_src_ip_ranges = list(string)
  }))
  description = "List of dictionaries that describe Cloud Armor versioned_expr rules"

  default = [
    {
      description    = "Default allow rule"
      action         = "allow"
      priority       = 2147483647
      versioned_expr = "SRC_IPS_V1"
      config_src_ip_ranges = [
        "*"
      ]
    }
  ]
}

variable "cr_allow_all_users_bool" {
  type = bool
  description = "Allow GCP `allUsers` access to CR service"
  default = true
}

variable "cr_allow_all_authenticated_users_bool" {
  type = bool
  description = "Allow GCP `allAuthenticatedUsers` access to CR service"
  default = false
}