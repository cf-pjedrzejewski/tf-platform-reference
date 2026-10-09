mock_provider "azurerm" {}

# The module's external data source runs scripts/build-info.sh during plan.
# Override it so the test does not run the script.
override_data {
  target = data.external.build_info
  values = {
    result = {
      revision = "test"
    }
  }
}

variables {
  name                 = "func-test-001"
  resource_group_name  = "rg-test"
  location             = "westeurope"
  storage_account_name = "sttest001"
  storage_account_id   = "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest001"
}

run "app_uses_https_only_and_tls_12" {
  command = plan

  assert {
    condition     = azurerm_linux_function_app.this.https_only == true
    error_message = "The app must be reachable over HTTPS only."
  }

  assert {
    condition     = azurerm_linux_function_app.this.site_config[0].minimum_tls_version == "1.2"
    error_message = "The app must require TLS 1.2."
  }
}

run "app_uses_managed_identity_for_storage" {
  command = plan

  assert {
    condition     = azurerm_linux_function_app.this.storage_uses_managed_identity == true
    error_message = "The runtime storage must be accessed with the managed identity."
  }

  assert {
    condition     = azurerm_linux_function_app.this.identity[0].type == "SystemAssigned"
    error_message = "The app must use a system-assigned managed identity."
  }
}

run "runtime_identity_gets_blob_owner_on_storage" {
  command = plan

  assert {
    condition     = azurerm_role_assignment.runtime_storage.role_definition_name == "Storage Blob Data Owner"
    error_message = "The runtime identity must get Storage Blob Data Owner on the storage account."
  }

  assert {
    condition     = azurerm_role_assignment.runtime_storage.scope == "/subscriptions/00000000-0000-0000-0000-000000000000/resourceGroups/rg-test/providers/Microsoft.Storage/storageAccounts/sttest001"
    error_message = "The role must be scoped to the given storage account."
  }
}

run "python_version_defaults_to_312" {
  command = plan

  assert {
    condition     = azurerm_linux_function_app.this.site_config[0].application_stack[0].python_version == "3.12"
    error_message = "The default Python version must be 3.12."
  }
}

run "app_settings_keep_given_values_and_build_revision" {
  command = plan

  variables {
    app_settings = {
      FOO = "bar"
    }
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["FOO"] == "bar"
    error_message = "Given app settings must be kept."
  }

  assert {
    condition     = azurerm_linux_function_app.this.app_settings["BUILD_REVISION"] == "test"
    error_message = "BUILD_REVISION must come from the build info."
  }
}
