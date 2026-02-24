# ==============================================================================
# Resource Group
# ==============================================================================

resource "azurerm_resource_group" "security_monitoring" {
  name     = local.resource_group_name
  location = var.location
  tags     = local.default_tags
}

# ==============================================================================
# Log Analytics Workspace
# ==============================================================================

resource "azurerm_log_analytics_workspace" "signin_monitor" {
  name                = local.log_analytics_name
  location            = azurerm_resource_group.security_monitoring.location
  resource_group_name = azurerm_resource_group.security_monitoring.name
  sku                 = "PerGB2018"
  retention_in_days   = var.log_retention_days
  tags                = local.default_tags
}

# ==============================================================================
# Entra ID Diagnostic Settings – SignIn Logs an Log Analytics senden
# ==============================================================================

resource "azurerm_monitor_aad_diagnostic_setting" "signin_logs" {
  name                       = "diag-${var.customer_name}-signin-to-loganalytics"
  log_analytics_workspace_id = azurerm_log_analytics_workspace.signin_monitor.id

  enabled_log {
    category = "SignInLogs"
    retention_policy {
      enabled = false
      days    = var.log_retention_days
    }
  }

  enabled_log {
    category = "NonInteractiveUserSignInLogs"
    retention_policy {
      enabled = false
      days    = var.log_retention_days
    }
  }

  enabled_log {
    category = "ServicePrincipalSignInLogs"
    retention_policy {
      enabled = false
      days    = var.log_retention_days
    }
  }

  enabled_log {
    category = "AuditLogs"
    retention_policy {
      enabled = false
      days    = var.log_retention_days
    }
  }
}

# ==============================================================================
# Action Group – E-Mail-Benachrichtigungen
# ==============================================================================

resource "azurerm_monitor_action_group" "security_alerts" {
  name                = local.action_group_name
  resource_group_name = azurerm_resource_group.security_monitoring.name
  short_name          = "SecAlerts"
  tags                = local.default_tags

  dynamic "email_receiver" {
    for_each = var.alert_email_recipients
    content {
      name                    = "recipient-${email_receiver.key}"
      email_address           = email_receiver.value
      use_common_alert_schema = true
    }
  }
}

# ==============================================================================
# Alert Rule 1 – Anmeldungen ausserhalb erlaubter Länder
# ==============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "foreign_signin" {
  name                = local.alert_geo_name
  resource_group_name = azurerm_resource_group.security_monitoring.name
  location            = azurerm_resource_group.security_monitoring.location
  tags                = local.default_tags

  display_name = "Anmeldung ausserhalb erlaubter Länder erkannt – ${var.customer_name}"
  description  = "Wird ausgelöst wenn sich ein Benutzer erfolgreich aus einem Land anmeldet, das nicht auf der Whitelist steht. Erlaubte Länder: ${join(", ", var.allowed_countries)}"

  evaluation_frequency = "PT${var.alert_frequency_minutes}M"
  window_duration      = "PT${var.alert_lookback_minutes}M"
  scopes               = [azurerm_log_analytics_workspace.signin_monitor.id]
  severity             = var.alert_severity
  enabled              = true

  criteria {
    query                   = local.kql_geo_alert
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.security_alerts.id]
  }
}

# ==============================================================================
# Alert Rule 2 – Conditional Access Report-Only Policy ausgelöst
# ==============================================================================

resource "azurerm_monitor_scheduled_query_rules_alert_v2" "ca_reportonly" {
  name                = local.alert_ca_reportonly
  resource_group_name = azurerm_resource_group.security_monitoring.name
  location            = azurerm_resource_group.security_monitoring.location
  tags                = local.default_tags

  display_name = "Conditional Access Report-Only Policy ausgelöst – ${var.customer_name}"
  description  = "Wird ausgelöst wenn eine Conditional Access Policy im Report-Only-Modus gegriffen hätte."

  evaluation_frequency = "PT${var.alert_frequency_minutes}M"
  window_duration      = "PT${var.alert_lookback_minutes}M"
  scopes               = [azurerm_log_analytics_workspace.signin_monitor.id]
  severity             = 2 # Warning für Report-Only
  enabled              = true

  criteria {
    query                   = local.kql_ca_reportonly
    time_aggregation_method = "Count"
    operator                = "GreaterThan"
    threshold               = 0

    failing_periods {
      minimum_failing_periods_to_trigger_alert = 1
      number_of_evaluation_periods             = 1
    }
  }

  action {
    action_groups = [azurerm_monitor_action_group.security_alerts.id]
  }
}
