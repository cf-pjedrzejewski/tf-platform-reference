mock_provider "azurerm" {}

variables {
  name                = "log-test-001"
  resource_group_name = "rg-test"
  location            = "westeurope"
}

run "workspace_uses_pay_as_you_go_sku" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.sku == "PerGB2018"
    error_message = "The workspace must use the PerGB2018 sku."
  }
}

run "retention_defaults_to_30_days" {
  command = plan

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 30
    error_message = "The default retention must be 30 days."
  }
}

run "retention_can_be_changed" {
  command = plan

  variables {
    retention_in_days = 90
  }

  assert {
    condition     = azurerm_log_analytics_workspace.this.retention_in_days == 90
    error_message = "retention_in_days must be passed through."
  }
}
