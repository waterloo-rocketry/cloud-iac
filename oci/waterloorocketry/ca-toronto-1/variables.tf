variable "tenancy_ocid" {
  type        = string
  description = "OCID of the waterloorocketry tenancy. Its root compartment holds every resource in this stack."
}

variable "budget_alert_recipients" {
  type        = list(string)
  description = "Email addresses that receive budget alerts, in the order the console stored them. Set from the BUDGET_ALERT_RECIPIENTS secret in CI."
}
