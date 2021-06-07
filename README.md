# `terraform-google-lb-ca-cloud-run`

## Introduction
This module deploys a Cloud Run service behind a GCP load balancer with Cloud Armor rules.

## Input Variables

| `variable`                      |Required?| Type            | Default                | Description                          |
|:--------------------------------|:-------:|:----------------|:----------------------:|:-------------------------------------|
| `project_id`                    | Yes     | String          | (None)                 | GCP project ID to set up in          |
| `build_env_vars_dict`           | Yes     | String          | (None)                 | Environment variables to set during the initial build of the CR container |
| `cr_service_name_str`           | Yes     | String          | (None)                 | Cloud Run service name               |
| `cr_region_str`                 | Yes     | String          | (None)                 | GCP region to run the CR service in  |
| `build_command`                 | Yes     | String          | (None)                 | Path to the cloud build script       |
| `create_service_acct_bool`      | Yes     | String          | (None)                 | Boolean on whether or not to create a service account for the CR service |
| `service_acct_id`               | Yes     | String          | (None)                 | Service account id                   |
| `service_acct_display_name`     | Yes     | String          | (None)                 | Display name for the new service account |
| `cr_fqdn_list`                  | Yes     | list(string)    | (None)                 | FQDNs to put on to the SSL certificate |
| `cloud_armor_preview_bool`      | Yes     | bool            | (None)                 | Boolean on whether Cloud Armor rules should run in preview mode |
| `cloud_armor_expr_rules`        | No      | list(map(any))  | OWASP Rules            | List of dictionaries that describe the Cloud Armor rules |
| `cloud_armor_versioned_expr_rules` | No   | list(map(any))  | Allow Allow (last rule) | List of dictionaries that describe Cloud Armor versioned_expr rules |
| `cr_allow_all_users_bool`       | No      | bool            | true                   | Determines if GCP `allUsers` has access to CR service |
| `cr_allow_all_authenticated_users_bool` | No      | bool    | false                  | Determines if GCP `allAuthenticatedUsers` has access to CR service |


## Output
|Output Variable Name|Description|
|:------------------:|:------------------------------------------------------------------------------------------------|
| cr_public_address  | Public IP address of the load balancer. You should point your DNS A records to this IP address  |
| cr_service_url_map | Internal Cloud Run service URL                                                                  |
