# ==============================================================================
# Lokale Variablen & KQL-Abfragen
# ==============================================================================

locals {
  # Ressourcen-Namenskonvention: {typ}-{kunde}-{zweck}-{umgebung}
  resource_group_name    = "rg-${var.customer_name}-security-monitoring-${var.environment}"
  log_analytics_name     = "log-${var.customer_name}-signin-monitor-${var.environment}"
  action_group_name      = "ag-${var.customer_name}-security-alerts-${var.environment}"
  alert_geo_name         = "alert-${var.customer_name}-foreign-signin-detected-${var.environment}"
  alert_ca_reportonly    = "alert-${var.customer_name}-ca-reportonly-triggered-${var.environment}"

  # Standard-Tags für alle Ressourcen
  default_tags = merge(var.tags, {
    managed_by  = "terraform"
    customer    = var.customer_name
    environment = var.environment
    purpose     = "security-monitoring"
    deployed_by = "microsys-sacker-it-ag"
  })

  # Länder-Whitelist als KQL-kompatibles Format
  allowed_countries_kql = join("\", \"", var.allowed_countries)
  excluded_users_kql    = join("\", \"", var.excluded_users)

  # ------------------------------------------------------------------
  # KQL: Erfolgreiche Anmeldungen ausserhalb erlaubter Länder
  # ------------------------------------------------------------------
  kql_geo_alert = <<-KQL
    let AllowedCountries = dynamic(["${local.allowed_countries_kql}"]);
    let ExcludedUsers = dynamic(["${local.excluded_users_kql}"]);
    SigninLogs
    | where TimeGenerated > ago(${var.alert_lookback_minutes}m)
    | where ResultType == 0
    | where Location !in (AllowedCountries)
    | where Location != ""
    | where UserPrincipalName !in (ExcludedUsers)
    | project TimeGenerated, UserPrincipalName, AppDisplayName, Location, IPAddress, DeviceDetail, ClientAppUsed
    | order by TimeGenerated desc
  KQL

  # ------------------------------------------------------------------
  # KQL: Conditional Access Report-Only Policies die gegriffen hätten
  # ------------------------------------------------------------------
  kql_ca_reportonly = <<-KQL
    SigninLogs
    | where TimeGenerated > ago(${var.alert_lookback_minutes}m)
    | mv-expand CAPolicy = parse_json(ConditionalAccessPolicies)
    | where CAPolicy.result == "reportOnlyFailure"
    | project TimeGenerated, UserPrincipalName, AppDisplayName, tostring(CAPolicy.displayName), tostring(CAPolicy.result)
    | order by TimeGenerated desc
  KQL
}
