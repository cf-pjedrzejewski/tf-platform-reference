mock_provider "azurerm" {}

variables {
  name                       = "adf-test-001"
  resource_group_name        = "rg-test"
  location                   = "westeurope"
  log_analytics_workspace_id = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.OperationalInsights/workspaces/log-test"
  linked_storage_accounts = {
    raw = "https://sttest.dfs.core.windows.net"
  }
}

run "factory_uses_a_system_assigned_identity" {
  command = plan

  assert {
    condition     = azurerm_data_factory.this.identity[0].type == "SystemAssigned"
    error_message = "The factory must use a system-assigned managed identity."
  }
}

run "public_network_can_be_turned_off" {
  command = plan

  variables {
    public_network_enabled = false
  }

  assert {
    condition     = azurerm_data_factory.this.public_network_enabled == false
    error_message = "public_network_enabled = false must turn public network access off."
  }
}

run "creates_one_linked_service_per_storage_account" {
  command = plan

  variables {
    linked_storage_accounts = {
      raw     = "https://sttest.dfs.core.windows.net"
      curated = "https://stcurated.dfs.core.windows.net"
    }
  }

  assert {
    condition     = length(azurerm_data_factory_linked_service_data_lake_storage_gen2.this) == 2
    error_message = "Expected one linked service for each storage account."
  }

  assert {
    condition     = azurerm_data_factory_linked_service_data_lake_storage_gen2.this["curated"].use_managed_identity == true
    error_message = "Linked storage must authenticate with the managed identity."
  }
}

run "diagnostic_setting_sends_pipeline_and_activity_logs" {
  command = plan

  assert {
    condition     = length(azurerm_monitor_diagnostic_setting.this.enabled_log) == 2
    error_message = "Expected PipelineRuns and ActivityRuns logs to be enabled."
  }
}
