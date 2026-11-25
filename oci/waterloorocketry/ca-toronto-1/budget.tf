resource "oci_budget_budget" "tenancy_monthly" {
  compartment_id = var.tenancy_ocid
  display_name   = "overall-budget"
  description    = "Overall Budget for Waterloo Rocketry Oracle Cloud"
  amount         = 5
  reset_period   = "MONTHLY"
  target_type    = "COMPARTMENT"
  targets        = [var.tenancy_ocid]

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

# The console stored each rule's recipients a little differently: one has a trailing newline,
# and one lists the addresses in reverse order. The expressions below reproduce the stored
# strings exactly, so importing changes nothing. A later PR can make them identical.

resource "oci_budget_alert_rule" "actual_over_budget" {
  budget_id      = oci_budget_budget.tenancy_monthly.id
  display_name   = "alertrule20260603055843"
  type           = "ACTUAL"
  threshold      = 100
  threshold_type = "PERCENTAGE"
  recipients     = join("\n", var.budget_alert_recipients)
  message        = "Oracle Cloud budget exceeded!"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_budget_alert_rule" "forecast_at_75_percent" {
  budget_id      = oci_budget_budget.tenancy_monthly.id
  display_name   = "alertrule20260603055752"
  type           = "FORECAST"
  threshold      = 75
  threshold_type = "PERCENTAGE"
  recipients     = "${join("\n", var.budget_alert_recipients)}\n"
  message        = "Oracle Cloud budget exceeded! Are you sure you are only using free / low-cost services?"

  lifecycle {
    ignore_changes = [defined_tags]
  }
}

resource "oci_budget_alert_rule" "forecast_at_150_percent" {
  budget_id      = oci_budget_budget.tenancy_monthly.id
  display_name   = "alertrule20260604062308"
  type           = "FORECAST"
  threshold      = 150
  threshold_type = "PERCENTAGE"
  recipients     = join("\n", reverse(var.budget_alert_recipients))

  lifecycle {
    ignore_changes = [defined_tags]
  }
}
