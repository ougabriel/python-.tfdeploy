# main.tf

# Import the random provider for unique naming where required
resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

# Create Virtual Network
resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  address_space       = var.vnet_address_space
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Create Subnet
resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = var.subnet_prefixes
}

# Create Network Security Group (NSG)
resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
}

# Allow SSH Access Only from Your IP
resource "azurerm_network_security_rule" "ssh_rule" {
  name                        = "AllowSSH"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.my_ip_address
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Allow HTTP/HTTPS Access from Anywhere
resource "azurerm_network_security_rule" "http_rule" {
  name                        = "AllowHTTP"
  priority                    = 200
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.rg.name
  network_security_group_name = azurerm_network_security_group.nsg.name
}

# Create Public IP
resource "azurerm_public_ip" "public_ip" {
  name                = var.public_ip_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Dynamic"
}

# Create Network Interface
resource "azurerm_network_interface" "nic" {
  name                = var.nic_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.public_ip.id
  }
}

# Associate NSG with Subnet
resource "azurerm_subnet_network_security_group_association" "subnet_nsg" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

# Create Virtual Machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username

  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key_path)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  # Enable Managed Identity
  identity {
    type = "SystemAssigned"
  }
}

# Custom Script Extension to Install Docker
resource "azurerm_virtual_machine_extension" "install_docker" {
  name                 = "InstallDocker"
  virtual_machine_id   = azurerm_linux_virtual_machine.vm.id
  publisher            = "Microsoft.Azure.Extensions"
  type                 = "CustomScript"
  type_handler_version = "2.1"

#   settings = <<SETTINGS
#     {
#       "fileUris": ["${local.docker_install_script_path}"],
#       "commandToExecute": "sh install_docker.sh"
#     }
#   SETTINGS
# }
  settings = <<SETTINGS
    {
      "commandToExecute": "sudo apt-get update && sudo apt-get install -y docker.io && sudo usermod -aG docker ${azurerm_linux_virtual_machine.vm.admin_username} && sudo systemctl enable docker && sudo systemctl start docker"
    }
  SETTINGS
}

# Create Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = "${var.acr_name}${random_integer.ri.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  sku                 = "Basic"
  admin_enabled       = true
}

# Assign Role to VM's Managed Identity for ACR Pull
resource "azurerm_role_assignment" "vm_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}

# Create Storage Account
resource "azurerm_storage_account" "storage" {
  name                     = "${var.storage_account_name}${random_integer.ri.result}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Assign Role to VM's Managed Identity for Storage Access
resource "azurerm_role_assignment" "storage_blob_reader" {
  scope                = azurerm_storage_account.storage.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = azurerm_linux_virtual_machine.vm.identity[0].principal_id
}

# Create Azure Kubernetes Service (AKS)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = var.aks_cluster_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "devopsAKS"

  default_node_pool {
    name       = "default"
    node_count = var.aks_node_count
    vm_size    = var.aks_node_size
  }

  identity {
    type = "SystemAssigned"
  }
}

# Grant AKS Access to ACR
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
}

# Create Log Analytics Workspace
resource "azurerm_log_analytics_workspace" "law" {
  name                = var.log_analytics_workspace_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

# Enable Diagnostics on VM
resource "azurerm_monitor_diagnostic_setting" "vm_diagnostic" {
  name               = "vmDiagnosticSetting"
  target_resource_id = azurerm_linux_virtual_machine.vm.id

  log_analytics_workspace_id = azurerm_log_analytics_workspace.law.id

  metric {
    category = "AllMetrics"
    enabled  = true

    retention_policy {
      enabled = false
    }
  }
}

# Create Action Group for Alerting
resource "azurerm_monitor_action_group" "ag" {
  name                = "devopsActionGroup"
  resource_group_name = azurerm_resource_group.rg.name
  short_name          = "devopsAG"

  email_receiver {
    name                   = "Admin"
    email_address          = var.alert_email_address
    use_common_alert_schema = true
  }
}

# Create Alert Rule for CPU Usage
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "HighCPUUsage"
  resource_group_name = azurerm_resource_group.rg.name
  severity            = 3
  description         = "Alert when CPU usage exceeds 80%"
  frequency           = "PT1M"
  window_size         = "PT5M"
  scopes              = [azurerm_linux_virtual_machine.vm.id]

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}