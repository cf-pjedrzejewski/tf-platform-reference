mock_provider "azurerm" {}

variables {
  name                = "dbw-test-001"
  resource_group_name = "rg-test"
  location            = "westeurope"
}

run "workspace_has_no_public_ip" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.custom_parameters[0].no_public_ip == true
    error_message = "The workspace must be deployed without public IPs."
  }
}

run "sku_defaults_to_premium" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.sku == "premium"
    error_message = "The default sku must be premium."
  }
}

run "sku_can_be_standard" {
  command = plan

  variables {
    sku = "standard"
  }

  assert {
    condition     = azurerm_databricks_workspace.this.sku == "standard"
    error_message = "sku = standard must be passed through."
  }
}

run "rejects_unknown_sku" {
  command = plan

  variables {
    sku = "basic"
  }

  expect_failures = [var.sku]
}

run "managed_resource_group_name_is_derived_from_name" {
  command = plan

  assert {
    condition     = azurerm_databricks_workspace.this.managed_resource_group_name == "rg-test-dbw-test-001-managed"
    error_message = "The managed resource group must be named from the resource group and workspace name."
  }
}
