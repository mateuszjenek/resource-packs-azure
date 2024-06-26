# Service principal used by Humanitec to provision resources
data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

resource "azuread_application" "humanitec_provisioner" {
  display_name = var.name
}

resource "azuread_service_principal" "humanitec_provisioner" {
  client_id = azuread_application.humanitec_provisioner.client_id
}

resource "azuread_service_principal_password" "humanitec_provisioner" {
  service_principal_id = azuread_service_principal.humanitec_provisioner.object_id
}

resource "azurerm_role_assignment" "resource_group_workload" {
  scope                = data.azurerm_resource_group.main.id
  role_definition_name = "Contributor"
  principal_id         = azuread_service_principal.humanitec_provisioner.object_id
}

resource "humanitec_resource_account" "humanitec_provisioner" {
  id   = var.name
  name = var.name
  type = "azure"

  credentials = jsonencode({
    "appId" : azuread_service_principal.humanitec_provisioner.client_id,
    "displayName" : azuread_application.humanitec_provisioner.display_name,
    "password" : azuread_service_principal_password.humanitec_provisioner.value,
    "tenant" : azuread_service_principal.humanitec_provisioner.application_tenant_id
  })

  depends_on = [
    # Otherwise the account looses permissions before the resources are deleted
    azurerm_role_assignment.resource_group_workload
  ]
}

# Example application and resource definition criteria
resource "humanitec_application" "example" {
  id   = var.name
  name = var.name
}

module "dns" {
  source = "../../humanitec-resource-defs/redis/basic"

  resource_packs_azure_url = var.resource_packs_azure_url
  resource_packs_azure_rev = var.resource_packs_azure_rev
  append_logs_to_error     = true
  prefix                   = var.prefix
  driver_account           = humanitec_resource_account.humanitec_provisioner.id
  subscription_id          = var.subscription_id
  resource_group_name      = var.resource_group_name
}

resource "humanitec_resource_definition_criteria" "redis" {
  resource_definition_id = module.dns.id
  app_id                 = humanitec_application.example.id
}
