# Security Monitoring – Geo-Alert & Conditional Access Monitoring

Terraform-Modul zur automatisierten Bereitstellung von Sign-In-Überwachung für Kunden der microsys-sacker it ag.

## Übersicht

Dieses Modul erstellt folgende Ressourcen pro Kunde:

| Ressource | Beschreibung |
|---|---|
| **Resource Group** | `rg-{kunde}-security-monitoring-prod` |
| **Log Analytics Workspace** | Sammelt Sign-in Logs aus Entra ID |
| **Diagnostic Settings** | Leitet SignIn-, NonInteractive-, ServicePrincipal- und Audit-Logs weiter |
| **Action Group** | E-Mail-Empfänger für Alarme |
| **Alert Rule 1** | Erkennt erfolgreiche Anmeldungen ausserhalb erlaubter Länder |
| **Alert Rule 2** | Erkennt Conditional Access Policies im Report-Only-Modus die gegriffen hätten |

## Voraussetzungen

- Terraform >= 1.5.0
- Azure CLI (`az login` im Kunden-Tenant)
- Berechtigungen: **Owner** oder **Contributor** auf der Subscription + **Global Administrator** oder **Security Administrator** in Entra ID (für Diagnostic Settings)
- Der Elevated Access muss **nicht** dauerhaft aktiv sein – nur die Subscription-Rolle wird benötigt

## Schnellstart

### 1. Kundenspezifische Variablen erstellen

Pro Kunde eine `.tfvars`-Datei anlegen, z.B. `customers/contoso.tfvars`:

```hcl
# Kunden-Identifikation
subscription_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
tenant_id       = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
customer_name   = "contoso"

# E-Mail-Empfänger für Alerts
alert_email_recipients = [
  "alerts@microsys-sacker.ch",
  "admin@contoso.ch"
]

# Optional: Break-Glass-Accounts ausschliessen
excluded_users = [
  "breakglass@contoso.onmicrosoft.com"
]

# Optional: Zusätzliche Länder erlauben (Standard beinhaltet EU + CH + GB)
# allowed_countries = ["CH", "DE", "AT", "FR", "IT"]

# Optional: Aufbewahrungsdauer anpassen (Standard: 90 Tage)
# log_retention_days = 180

# Optional: Alert-Frequenz anpassen (Standard: 5 Minuten)
# alert_frequency_minutes = 10
# alert_lookback_minutes  = 10

# Optional: Zusätzliche Tags
tags = {
  customer_contact = "max.muster@contoso.ch"
  contract_id      = "MSI-2026-001"
}
```

### 2. Deployment ausführen

```bash
# In den Kunden-Tenant einloggen
az login --tenant <tenant-id>

# Terraform initialisieren
terraform init

# Plan erstellen und prüfen
terraform plan -var-file="customers/contoso.tfvars"

# Deployment ausführen
terraform apply -var-file="customers/contoso.tfvars"
```

### 3. Für weitere Kunden wiederholen

Für jeden Kunden eine eigene `.tfvars`-Datei erstellen und das Deployment mit separatem State ausführen:

```bash
# Eigener State pro Kunde
terraform init -backend-config="key=contoso.tfstate"
terraform apply -var-file="customers/contoso.tfvars"

terraform init -reconfigure -backend-config="key=drawagag.tfstate"
terraform apply -var-file="customers/drawagag.tfvars"
```

## Konfigurationsreferenz

### Erlaubte Länder (Standard)

Die Standard-Whitelist beinhaltet alle EU/EFTA-Länder plus Grossbritannien:

```
CH, DE, AT, FR, IT, LI, NL, BE, LU, ES, PT, PL, CZ, DK, SE, NO, FI,
IE, GR, HU, RO, BG, HR, SK, SI, EE, LV, LT, MT, CY, GB
```

Anpassung über die Variable `allowed_countries` in der `.tfvars`-Datei.

### Alert-Schweregrade

| Wert | Schweregrad | Empfohlener Einsatz |
|------|------------|---------------------|
| 0 | Critical | – |
| 1 | Error | Geo-Alert (Standard) |
| 2 | Warning | CA Report-Only (Standard) |
| 3 | Informational | – |
| 4 | Verbose | – |

## KQL-Abfragen

### Alert 1: Anmeldung ausserhalb erlaubter Länder

```kql
let AllowedCountries = dynamic(["CH", "DE", "AT", ...]);
let ExcludedUsers = dynamic(["breakglass@domain.onmicrosoft.com"]);
SigninLogs
| where TimeGenerated > ago(5m)
| where ResultType == 0
| where Location !in (AllowedCountries)
| where Location != ""
| where UserPrincipalName !in (ExcludedUsers)
| project TimeGenerated, UserPrincipalName, AppDisplayName, Location, IPAddress, DeviceDetail, ClientAppUsed
| order by TimeGenerated desc
```

### Alert 2: Conditional Access Report-Only

```kql
SigninLogs
| where TimeGenerated > ago(5m)
| mv-expand CAPolicy = parse_json(ConditionalAccessPolicies)
| where CAPolicy.result == "reportOnlyFailure"
| project TimeGenerated, UserPrincipalName, AppDisplayName, tostring(CAPolicy.displayName), tostring(CAPolicy.result)
| order by TimeGenerated desc
```

## Kosten

Geschätzte monatliche Kosten pro Kunde (kleiner bis mittlerer Tenant):

| Posten | Geschätzte Kosten |
|---|---|
| Log Ingestion (ca. 1-5 GB/Monat) | CHF 2.50 – 15.00 |
| Retention über 30 Tage | CHF 0.10 / GB / Monat |
| Alert Rules (2 Regeln) | CHF 1.50 / Regel / Monat |
| **Total geschätzt** | **CHF 6.00 – 20.00 / Monat** |

## Deinstallation

```bash
terraform destroy -var-file="customers/contoso.tfvars"
```

> ⚠️ Dies löscht den Log Analytics Workspace und alle gespeicherten Logs. Daten vorher sichern falls benötigt.

---

*Erstellt und gepflegt von microsys-sacker it ag*
