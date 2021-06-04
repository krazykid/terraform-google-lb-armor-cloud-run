data "google_project" "project" {
  project_id = var.project_id
}

locals {
  gcp_services = [
    "cloudbuild.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "containerregistry.googleapis.com",
    "containerscanning.googleapis.com",
    "containerthreatdetection.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "run.googleapis.com",
    "stackdriver.googleapis.com",

  ]
}


resource "google_project_service" "project_services" {
  project    = data.google_project.project.project_id
  depends_on = [data.google_project.project]

  for_each                   = toset(local.gcp_services)
  service                    = each.value
  disable_dependent_services = true
}


# Allow Cloud Build to execute Cloud Run and Service Account things
resource "google_project_iam_member" "add_cloud_build_svc_roles" {
  project = data.google_project.project.project_id
  member  = "serviceAccount:${data.google_project.project.number}@cloudbuild.gserviceaccount.com"

  for_each = toset([
    "roles/run.admin",
    "roles/iam.serviceAccountUser",
  ])
  role = each.value

  depends_on = [
    google_project_service.project_services,
  ]
}


resource "google_service_account" "svc_acct_resource" {
  project      = data.google_project.project.project_id
  account_id   = var.service_acct_id
  display_name = var.service_acct_display_name
  count        = var.create_service_acct_bool ? 1 : 0

  depends_on = [
    data.google_project.project,
    google_project_service.project_services
  ]
}

data "google_service_account" "svc_acct_data" {
  project    = data.google_project.project.project_id
  account_id = var.service_acct_id
  count      = var.create_service_acct_bool ? 0 : 1

  depends_on = [
    data.google_project.project,
    google_project_service.project_services
  ]
}

locals {
  svc_acct_email = var.create_service_acct_bool ? google_service_account.svc_acct_resource[0].email : data.google_service_account.svc_acct_data[0].email

  build_base_env_vars = {
    PROJECT_ID      = data.google_project.project.project_id
    CR_SERVICE_NAME = var.cr_service_name_str
    REGION          = var.cr_region_str
    SERVICE_ACCT    = local.svc_acct_email
    TAG             = "initial"
  }

  build_env_vars = merge(local.build_base_env_vars, var.build_env_vars_dict)

  svc_acct_roles_list = [
    "roles/cloudbuild.builds.editor",
    "roles/iam.serviceAccountUser",
    "roles/run.admin",
  ]
}

resource "google_project_iam_member" "assign_svc_role" {
  project = data.google_project.project.project_id

  for_each = toset(local.svc_acct_roles_list)
  role     = each.value
  member   = "serviceAccount:${local.svc_acct_email}"

  depends_on = [
    google_project_service.project_services
  ]
}

resource "null_resource" "build_cr_service" {
  provisioner "local-exec" {
    environment = local.build_env_vars
    command     = var.build_command
  }

  depends_on = [
    google_project_service.project_services,
    google_service_account.svc_acct_resource,
    google_project_iam_member.assign_svc_role,
    google_project_iam_member.add_cloud_build_svc_roles,
    data.google_service_account.svc_acct_data,
  ]
}

data "google_cloud_run_service" "cr_service" {
  project  = data.google_project.project.project_id
  name     = var.cr_service_name_str
  location = var.cr_region_str
  depends_on = [
    null_resource.build_cr_service
  ]
}

#=============================================================================
#
# Get an IP

resource "google_compute_global_address" "cr_public_address" {
  project      = data.google_project.project.project_id
  name         = "${data.google_cloud_run_service.cr_service.name}-external-ip"
  ip_version   = "IPV4"
  address_type = "EXTERNAL"
}

//resource "google_dns_record_set" "api_dns_record" {
//  project      = var.dns_project_id
//  managed_zone = data.google_dns_managed_zone.base_domain_zone.name
//  name         = "${local.api_fqdn}."
//  rrdatas = [
//  google_compute_global_address.api_public_address.address]
//  ttl  = 60
//  type = "A"
//}
//

resource "google_compute_managed_ssl_certificate" "cr_service_cert" {
  provider = google-beta
  project  = data.google_project.project.project_id

  name = "${data.google_cloud_run_service.cr_service.name}-cert"
  managed {
    domains = var.cr_fqdn_list
  }
}

#=============================================================================
#
# Setup load balancer and Cloud Armor in front of the API service
# TF, CR, Load balancer: https://cloud.google.com/blog/topics/developers-practitioners/serverless-load-balancing-terraform-hard-way

resource "google_compute_region_network_endpoint_group" "cr_service_neg" {
  provider              = google-beta
  project               = data.google_project.project.project_id
  name                  = "${data.google_cloud_run_service.cr_service.name}-neg"
  network_endpoint_type = "SERVERLESS"
  region                = var.cr_region_str
  cloud_run {
    service = data.google_cloud_run_service.cr_service.name
  }
}

// https://gitlab.jetstack.net/william.squires/glb-demo/-/commit/2f2996e53274687e138020b9608f561a4c2e4a6c?w=1

resource "google_compute_security_policy" "cr_service_cloud_armor" {
  project     = data.google_project.project.project_id
  name        = "${data.google_cloud_run_service.cr_service.name}-cloud-armor"
  description = "Cloud Run API service rules"

  dynamic "rule" {
    for_each = var.cloud_armor_expr_rules
    content {
      description = rule.value.description
      action      = rule.value.action
      priority    = rule.value.priority
      match {
        expr {
          expression = rule.value.match_expr
        }
      }
    }
  }

  dynamic "rule" {
    for_each = var.cloud_armor_versioned_expr_rules
    content {
      description = rule.value.description
      action      = rule.value.action
      priority    = rule.value.priority
      match {
        versioned_expr = rule.value.versioned_expr
        config {
          src_ip_ranges = rule.value.config_src_ip_ranges
        }
      }
    }
  }

}


resource "google_compute_backend_service" "cr_service_bes" {
  provider = google-beta
  project  = data.google_project.project.project_id
  name     = "${data.google_cloud_run_service.cr_service.name}-bes"

  protocol        = "HTTP"
  port_name       = "http"
  timeout_sec     = 30
  security_policy = google_compute_security_policy.cr_service_cloud_armor.self_link

  backend {
    group = google_compute_region_network_endpoint_group.cr_service_neg.id
  }

  log_config {
    enable = true
  }

}


resource "google_compute_url_map" "cr_service_url_map" {
  project = data.google_project.project.project_id
  name    = "${data.google_cloud_run_service.cr_service.name}-urlmap"

  default_service = google_compute_backend_service.cr_service_bes.id
}


resource "google_compute_target_https_proxy" "cr_service_https_proxy" {
  project = data.google_project.project.project_id
  name    = "${data.google_cloud_run_service.cr_service.name}-https-proxy"

  url_map = google_compute_url_map.cr_service_url_map.id
  ssl_certificates = [
    google_compute_managed_ssl_certificate.cr_service_cert.id
  ]
}


resource "google_compute_global_forwarding_rule" "default" {
  project = data.google_project.project.project_id
  name    = "${data.google_cloud_run_service.cr_service.name}-lb"

  target     = google_compute_target_https_proxy.cr_service_https_proxy.id
  port_range = "443"
  ip_address = google_compute_global_address.cr_public_address.address
}


