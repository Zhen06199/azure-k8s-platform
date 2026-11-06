variable "admin_ssh_cidr" {
  description = "Only this IP range may SSH to the VM (e.g. 1.2.3.4/32)"
  type        = string
}

variable "vm_ssh_public_key" {
  description = "SSH public key content for the VM admin user"
  type        = string
}

# 单独的 VNet：VM 和 AKS 网络隔离，出问题互不影响
resource "azurerm_virtual_network" "ops" {
  name                = "vnet-ops"
  address_space       = ["10.20.0.0/16"]
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
}

resource "azurerm_subnet" "ops" {
  name                 = "snet-ops"
  resource_group_name  = azurerm_resource_group.platform.name
  virtual_network_name = azurerm_virtual_network.ops.name
  address_prefixes     = ["10.20.1.0/24"]
}

# NSG：只允许你的 IP 访问 22 端口；其余入站流量被 Azure 默认规则拒绝
resource "azurerm_network_security_group" "ops" {
  name                = "nsg-ops"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name

  security_rule {
    name                       = "allow-ssh-from-admin"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.admin_ssh_cidr
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "ops" {
  name                = "pip-ops"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_network_interface" "ops" {
  name                = "nic-ops"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.ops.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.ops.id
  }
}

resource "azurerm_network_interface_security_group_association" "ops" {
  network_interface_id      = azurerm_network_interface.ops.id
  network_security_group_id = azurerm_network_security_group.ops.id
}

resource "azurerm_linux_virtual_machine" "ops" {
  name                            = "vm-ops"
  location                        = azurerm_resource_group.platform.location
  resource_group_name             = azurerm_resource_group.platform.name
  size                            = "Standard_D2ls_v7" # B 系列在本订阅的这个区域不可用
  disk_controller_type            = "NVMe"             # v6/v7 系列要求 NVMe 磁盘控制器
  admin_username                  = "azureuser"
  network_interface_ids           = [azurerm_network_interface.ops.id]
  disable_password_authentication = true # 只允许 SSH 密钥登录

  admin_ssh_key {
    username   = "azureuser"
    public_key = var.vm_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

output "vm_public_ip" {
  value = azurerm_public_ip.ops.ip_address
}
