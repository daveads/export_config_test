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


resource "permitio_resource" "project" {
  name        = "Project"
  description = "A project within the organization"
  key         = "project"

  actions = {
    "read" = { name = "Read" }
    "update" = { name = "Update" }
  }

  attributes = {
    "is_public" = {
      name = "Is Public"
      type = "bool"
    }
    "priority" = {
      name = "Priority"
      type = "number"
    }
  }
}

resource "permitio_resource" "task" {
  name        = "Task"
  description = "A task within a project"
  key         = "task"

  actions = {
    "read" = { name = "Read" }
    "update" = { name = "Update" }
  }

  attributes = {
    "status" = {
      name = "Status"
      type = "string"
    }
  }
}


resource "permitio_role" "project_viewer" {
  key         = "project_viewer"
  name        = "Project Viewer"
  description = "Can view project information"
  resource    = permitio_resource.project.key
  permissions = ["read"]
  depends_on  = [permitio_resource.project]
}

resource "permitio_role" "task_editor" {
  key         = "task_editor"
  name        = "Task Editor"
  description = "Can view and edit tasks"
  resource    = permitio_resource.task.key
  permissions = ["read", "update"]
  depends_on  = [permitio_resource.task]
}


resource "permitio_role" "task_viewer" {
  key         = "task_viewer"
  name        = "Task Viewer"
  description = "Can view task details"
  resource    = permitio_resource.task.key
  permissions = ["read"]
  depends_on  = [permitio_resource.task]
}


resource "permitio_relation" "project_has_task" {
  key              = "has_task"
  name             = "Project Has Task"
  subject_resource = permitio_resource.project.key  
  object_resource  = permitio_resource.task.key     
  depends_on = [
    permitio_resource.project,
    permitio_resource.task
  ]
}


resource "permitio_relation" "task_belongs_to_project" {
  key              = "belongs_to_project"
  name             = "Task Belongs To Project"
  subject_resource = permitio_resource.task.key
  object_resource  = permitio_resource.project.key  
  depends_on = [
    permitio_resource.project,
    permitio_resource.task
  ]
}

# Resource set
resource "permitio_resource_set" "public_projects" {
  name        = "Public Projects"
  key         = "public_projects"
  resource    = permitio_resource.project.key
  conditions  = jsonencode({
    "allOf": [
      { "resource.is_public": { "equals": true } }
    ]
  })
  depends_on  = [permitio_resource.project]
}

# Project Viewer -> Task Editor derivation
resource "permitio_role_derivation" "project_viewer_to_task_editor" {
  role        = permitio_role.project_viewer.key
  on_resource = permitio_resource.project.key
  to_role     = permitio_role.task_editor.key
  resource    = permitio_resource.task.key
  linked_by   = permitio_relation.project_has_task.key
  depends_on = [
    permitio_role.project_viewer,
    permitio_resource.project,
    permitio_role.task_editor,
    permitio_resource.task,
    permitio_relation.project_has_task
  ]
}


resource "permitio_role_derivation" "task_editor_to_project_viewer" {
  role        = permitio_role.task_editor.key
  on_resource = permitio_resource.task.key
  to_role     = permitio_role.project_viewer.key
  resource    = permitio_resource.project.key
  linked_by   = permitio_relation.task_belongs_to_project.key
  depends_on = [
    permitio_role.task_editor,
    permitio_resource.task,
    permitio_role.project_viewer,
    permitio_resource.project,
    permitio_relation.task_belongs_to_project
  ]
}

# Project Viewer -> Task Viewer derivation
resource "permitio_role_derivation" "project_viewer_to_task_viewer" {
  role        = permitio_role.project_viewer.key
  on_resource = permitio_resource.project.key
  to_role     = permitio_role.task_viewer.key
  resource    = permitio_resource.task.key
  linked_by   = permitio_relation.project_has_task.key
  depends_on = [
    permitio_role.project_viewer,
    permitio_resource.project,
    permitio_role.task_viewer,
    permitio_resource.task,
    permitio_relation.project_has_task
  ]
}
