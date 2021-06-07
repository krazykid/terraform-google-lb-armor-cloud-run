output "cr_public_address" {
  value = google_compute_global_address.cr_public_address.address
}

output "cr_service_url_map" {
  value = google_compute_url_map.cr_service_url_map.id
}

output "svc_acct_email" {
  value = local.svc_acct_email
}