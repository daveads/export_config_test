terraform {
  required_providers {
    permitio = {
      source  = "permitio/permit-io"
      version = "~> 0.0.12"
    }
  }
}

variable "PERMIT_API_KEY" {
  type        = string
  description = "The API key for the Permit.io API"
}

provider "permitio" {
  api_url = "https://api.permit.io"
  api_key = var.PERMIT_API_KEY
  timeout = 60
}

# Resources
resource "permitio_resource" "portfolio" {
  name        = "Portfolio"
  description = "Investment portfolio"
  key         = "portfolio"

  actions = {
    "read" = { name = "Read" }
    "update" = { name = "Update" }
    "delete" = { name = "Delete" }
  }

  attributes = {
    "risk_level" = {
      name = "Risk Level"
      type = "string"
    }
    "value" = {
      name = "Value"
      type = "number"
    }
    "is_active" = {
      name = "Is Active"
      type = "bool"
    }
  }
}

resource "permitio_resource" "transaction" {
  name        = "Transaction"
  description = "Financial transaction"
  key         = "transaction"

  actions = {
    "read" = { name = "Read" }
    "approve" = { name = "Approve" }
    "reject" = { name = "Reject" }
  }

  attributes = {
    "amount" = {
      name = "Amount"
      type = "number"
    }
    "status" = {
      name = "Status"
      type = "string"
    }
  }
}

resource "permitio_resource" "report" {
  name        = "Report"
  description = "Financial report"
  key         = "report"

  actions = {
    "read" = { name = "Read" }
    "export" = { name = "Export" }
  }

  attributes = {
    "classification" = {
      name = "Classification"
      type = "string"
    }
    "quarter" = {
      name = "Quarter"
      type = "string"
    }
  }
}

# User attributes
resource "permitio_user_attribute" "role" {
  key         = "role"
  type        = "string"
  description = "User's role in the organization"
}

resource "permitio_user_attribute" "certification_level" {
  key         = "certification_level"
  type        = "number"
  description = "User's financial certification level"
}

# Roles
resource "permitio_role" "portfolio_manager" {
  key         = "portfolio_manager"
  name        = "Portfolio Manager"
  description = "Can manage portfolios"
  resource    = permitio_resource.portfolio.key
  permissions = ["read", "update"]
  depends_on  = [permitio_resource.portfolio]
}

resource "permitio_role" "portfolio_admin" {
  key         = "portfolio_admin"
  name        = "Portfolio Admin"
  description = "Full access to portfolios"
  resource    = permitio_resource.portfolio.key
  permissions = ["read", "update", "delete"]
  depends_on  = [permitio_resource.portfolio]
}

resource "permitio_role" "transaction_approver" {
  key         = "transaction_approver"
  name        = "Transaction Approver"
  description = "Can approve transactions"
  resource    = permitio_resource.transaction.key
  permissions = ["read", "approve", "reject"]
  depends_on  = [permitio_resource.transaction]
}

resource "permitio_role" "report_viewer" {
  key         = "report_viewer"
  name        = "Report Viewer"
  description = "Can view reports"
  resource    = permitio_resource.report.key
  permissions = ["read"]
  depends_on  = [permitio_resource.report]
}

# Relations
resource "permitio_relation" "portfolio_has_transaction" {
  key              = "has_transaction"
  name             = "Portfolio Has Transaction"
  subject_resource = permitio_resource.portfolio.key
  object_resource  = permitio_resource.transaction.key
  depends_on = [
    permitio_resource.portfolio,
    permitio_resource.transaction
  ]
}

resource "permitio_relation" "portfolio_has_report" {
  key              = "has_report"
  name             = "Portfolio Has Report"
  subject_resource = permitio_resource.portfolio.key
  object_resource  = permitio_resource.report.key
  depends_on = [
    permitio_resource.portfolio,
    permitio_resource.report
  ]
}

# User Set
resource "permitio_user_set" "finance_users" {
  key  = "finance_users"
  name = "Finance Users"
  conditions = jsonencode({
    "allOf" : [
      {
        "subject.email" = {
          contains = "@finance.com"
        }
      }
    ]
  })
}

# Resource Sets
resource "permitio_resource_set" "active_portfolios" {
  name     = "Active Portfolios"
  key      = "active_portfolios"
  resource = permitio_resource.portfolio.key
  conditions = jsonencode({
    "allOf" : [
      {
        "resource.is_active" = {
          equals = true
        }
      }
    ]
  })
  depends_on = [permitio_resource.portfolio]
}

resource "permitio_resource_set" "quarterly_reports" {
  name     = "Quarterly Reports"
  key      = "quarterly_reports"
  resource = permitio_resource.report.key
  conditions = jsonencode({
    "allOf" : [
      {
        "resource.classification" = {
          equals = "quarterly"
        }
      }
    ]
  })
  depends_on = [permitio_resource.report]
}

# Role Derivations
resource "permitio_role_derivation" "portfolio_manager_to_transaction_approver" {
  role        = permitio_role.portfolio_manager.key
  on_resource = permitio_resource.portfolio.key
  to_role     = permitio_role.transaction_approver.key
  resource    = permitio_resource.transaction.key
  linked_by   = permitio_relation.portfolio_has_transaction.key
  depends_on = [
    permitio_role.portfolio_manager,
    permitio_resource.portfolio,
    permitio_role.transaction_approver,
    permitio_resource.transaction,
    permitio_relation.portfolio_has_transaction
  ]
}

resource "permitio_role_derivation" "portfolio_manager_to_report_viewer" {
  role        = permitio_role.portfolio_manager.key
  on_resource = permitio_resource.portfolio.key
  to_role     = permitio_role.report_viewer.key
  resource    = permitio_resource.report.key
  linked_by   = permitio_relation.portfolio_has_report.key
  depends_on = [
    permitio_role.portfolio_manager,
    permitio_resource.portfolio,
    permitio_role.report_viewer,
    permitio_resource.report,
    permitio_relation.portfolio_has_report
  ]
}

# Condition Set
resource "permitio_condition_set_rule" "finance_users_can_view_active_portfolios" {
  user_set     = permitio_user_set.finance_users.key
  permission   = "portfolio:read"
  resource_set = permitio_resource_set.active_portfolios.key
}

resource "permitio_condition_set_rule" "finance_users_can_view_quarterly_reports" {
  user_set     = permitio_user_set.finance_users.key
  permission   = "report:read"
  resource_set = permitio_resource_set.quarterly_reports.key
}
