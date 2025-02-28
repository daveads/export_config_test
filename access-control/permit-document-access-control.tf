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
resource "permitio_resource" "document" {
  name        = "Document"
  description = "A document in the system"
  key         = "document"

  actions = {
    "read" = { name = "Read" }
    "write" = { name = "Write" }
    "delete" = { name = "Delete" }
    "share" = { name = "Share" }
  }

  attributes = {
    "classification" = {
      name = "Classification"
      type = "string"
    }
    "department" = {
      name = "Department"
      type = "string"
    }
  }
}

resource "permitio_resource" "folder" {
  name        = "Folder"
  description = "A folder containing documents"
  key         = "folder"

  actions = {
    "read" = { name = "Read" }
    "write" = { name = "Write" }
    "manage" = { name = "Manage" }
  }

  attributes = {
    "department" = {
      name = "Department"
      type = "string"
    }
  }
}

# User attributes
resource "permitio_user_attribute" "department" {
  key         = "department"
  type        = "string"
  description = "User's department"
}

resource "permitio_user_attribute" "clearance_level" {
  key         = "clearance_level"
  type        = "number"
  description = "User's security clearance level"
}

# Roles
resource "permitio_role" "document_viewer" {
  key         = "document_viewer"
  name        = "Document Viewer"
  description = "Can view documents"
  resource    = permitio_resource.document.key
  permissions = ["read"]
  depends_on  = [permitio_resource.document]
}

resource "permitio_role" "document_editor" {
  key         = "document_editor"
  name        = "Document Editor"
  description = "Can view and edit documents"
  resource    = permitio_resource.document.key
  permissions = ["read", "write"]
  depends_on  = [permitio_resource.document]
}

resource "permitio_role" "folder_manager" {
  key         = "folder_manager"
  name        = "Folder Manager"
  description = "Can manage folders"
  resource    = permitio_resource.folder.key
  permissions = ["read", "write", "manage"]
  depends_on  = [permitio_resource.folder]
}

# Relations
resource "permitio_relation" "folder_contains_document" {
  key              = "contains"
  name             = "Folder Contains Document"
  subject_resource = permitio_resource.folder.key
  object_resource  = permitio_resource.document.key
  depends_on = [
    permitio_resource.folder,
    permitio_resource.document
  ]
}

# UserSet
resource "permitio_user_set" "example_users" {
  key  = "example_users"
  name = "Example Users"
  conditions = jsonencode({
    "allOf" = [
      {
        "subject.email" = {
          contains = "@example.com"
        }
      }
    ]
  })
}

# ResourceSets
resource "permitio_resource_set" "finance_documents" {
  name       = "Finance Documents"
  key        = "finance_documents"
  resource   = permitio_resource.document.key
  conditions = jsonencode({
    "allOf" = [
      {
        "resource.department" = {
          equals = "finance"
        }
      }
    ]
  })
  depends_on = [permitio_resource.document]
}

resource "permitio_resource_set" "confidential_documents" {
  name       = "Confidential Documents"
  key        = "confidential_documents"
  resource   = permitio_resource.document.key
  conditions = jsonencode({
    "allOf" = [
      {
        "resource.classification" = {
          equals = "confidential"
        }
      }
    ]
  })
  depends_on = [permitio_resource.document]
}

# Role Derivations
resource "permitio_role_derivation" "folder_manager_to_document_editor" {
  role        = permitio_role.folder_manager.key
  on_resource = permitio_resource.folder.key
  to_role     = permitio_role.document_editor.key
  resource    = permitio_resource.document.key
  linked_by   = permitio_relation.folder_contains_document.key
  depends_on = [
    permitio_role.folder_manager,
    permitio_resource.folder,
    permitio_role.document_editor,
    permitio_resource.document,
    permitio_relation.folder_contains_document
  ]
}

# Condition Set
resource "permitio_condition_set_rule" "example_users_can_read_confidential" {
  user_set     = permitio_user_set.example_users.key
  permission   = "document:read"
  resource_set = permitio_resource_set.confidential_documents.key
}
