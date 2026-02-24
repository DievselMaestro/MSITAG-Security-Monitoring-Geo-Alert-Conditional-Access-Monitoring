# ==============================================================================
# Allgemeine Variablen
# ==============================================================================

variable "subscription_id" {
  description = "Azure Subscription ID des Kunden"
  type        = string
}

variable "tenant_id" {
  description = "Azure AD Tenant ID des Kunden"
  type        = string
}

variable "location" {
  description = "Azure Region für alle Ressourcen"
  type        = string
  default     = "switzerlandnorth"
}

variable "customer_name" {
  description = "Kurzname des Kunden (wird in Ressourcennamen verwendet, z.B. 'contoso')"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9-]{2,20}$", var.customer_name))
    error_message = "customer_name darf nur Kleinbuchstaben, Zahlen und Bindestriche enthalten (2-20 Zeichen)."
  }
}

variable "environment" {
  description = "Umgebung (prod, dev, staging)"
  type        = string
  default     = "prod"
}

# ==============================================================================
# Geo-Alert Konfiguration
# ==============================================================================

variable "allowed_countries" {
  description = "Liste der erlaubten Ländercodes (ISO 3166-1 Alpha-2). Anmeldungen aus allen anderen Ländern lösen einen Alert aus."
  type        = list(string)
  default = [
    "CH", # Schweiz
    "DE", # Deutschland
    "AT", # Österreich
    "FR", # Frankreich
    "IT", # Italien
    "LI", # Liechtenstein
    "NL", # Niederlande
    "BE", # Belgien
    "LU", # Luxemburg
    "ES", # Spanien
    "PT", # Portugal
    "PL", # Polen
    "CZ", # Tschechien
    "DK", # Dänemark
    "SE", # Schweden
    "NO", # Norwegen
    "FI", # Finnland
    "IE", # Irland
    "GR", # Griechenland
    "HU", # Ungarn
    "RO", # Rumänien
    "BG", # Bulgarien
    "HR", # Kroatien
    "SK", # Slowakei
    "SI", # Slowenien
    "EE", # Estland
    "LV", # Lettland
    "LT", # Litauen
    "MT", # Malta
    "CY", # Zypern
    "GB"  # Grossbritannien
  ]
}

variable "excluded_users" {
  description = "Liste von UPNs die von der Überwachung ausgeschlossen werden (z.B. Break-Glass-Accounts)"
  type        = list(string)
  default     = []
}

# ==============================================================================
# Alert Konfiguration
# ==============================================================================

variable "alert_email_recipients" {
  description = "Liste der E-Mail-Adressen die bei einem Alert benachrichtigt werden"
  type        = list(string)
}

variable "alert_frequency_minutes" {
  description = "Wie oft die Abfrage ausgeführt wird (in Minuten)"
  type        = number
  default     = 5
}

variable "alert_lookback_minutes" {
  description = "Zeitfenster das die Abfrage abdeckt (in Minuten)"
  type        = number
  default     = 5
}

variable "alert_severity" {
  description = "Schweregrad des Alerts (0 = Critical, 1 = Error, 2 = Warning, 3 = Informational, 4 = Verbose)"
  type        = number
  default     = 1
}

# ==============================================================================
# Log Analytics Konfiguration
# ==============================================================================

variable "log_retention_days" {
  description = "Aufbewahrungsdauer der Logs in Tagen (30-730)"
  type        = number
  default     = 30

  validation {
    condition     = var.log_retention_days >= 30 && var.log_retention_days <= 730
    error_message = "log_retention_days muss zwischen 30 und 730 liegen."
  }
}

# ==============================================================================
# Tags
# ==============================================================================

variable "tags" {
  description = "Zusätzliche Tags für alle Ressourcen"
  type        = map(string)
  default     = {}
}
