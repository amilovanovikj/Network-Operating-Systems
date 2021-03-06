data "azurerm_resource_group" "rg" {
  name = "Network-Operating-Systems"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "mos-vnet"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["172.16.32.0/24"]
  dns_servers         = ["172.16.32.4"]
}

resource "azurerm_network_security_group" "dc_nsg" {
  name                = "mos-dc-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "rdp"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${chomp(data.http.myip.body)}/32"
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet" "dc_subnet" {
  name                 = "mos-vnet-dc-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.32.0/27"]

  depends_on = [
    azurerm_network_security_group.dc_nsg
  ]
}

resource "azurerm_subnet_network_security_group_association" "dc_subnet_assoc" {
  subnet_id                 = azurerm_subnet.dc_subnet.id
  network_security_group_id = azurerm_network_security_group.dc_nsg.id

  depends_on = [
    azurerm_subnet.dc_subnet
  ]
}

resource "azurerm_network_security_group" "vm_nsg" {
  name                = "mos-vm-nsg"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  security_rule {
    name                       = "ssh"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${chomp(data.http.myip.body)}/32"
    destination_address_prefix = "*"
  }

  depends_on = [
    azurerm_subnet_network_security_group_association.dc_subnet_assoc
  ]
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "mos-vnet-vm-subnet"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.32.32/27"]

  depends_on = [
    azurerm_network_security_group.vm_nsg
  ]
}

resource "azurerm_subnet_network_security_group_association" "vm_subnet_assoc" {
  subnet_id                 = azurerm_subnet.vm_subnet.id
  network_security_group_id = azurerm_network_security_group.vm_nsg.id
  
  depends_on = [
    azurerm_subnet.vm_subnet
  ]
}

resource "azurerm_network_interface" "vm_client_nic" {
  name                = "mos-vm-ubuntu-client-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mos-vm-ubuntu-client-ip-config"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    public_ip_address_id          = azurerm_public_ip.vm_client_ip.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.16.32.36"
  }
}

resource "azurerm_public_ip" "vm_client_ip" {
  name                = "mos-vm-ubuntu-client-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "vm_client" {
  name                = "mos-vm-ubuntu-client"
  computer_name       = "mos-client"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  admin_username      = var.linux_username
  size                = "Standard_B1s"
  
  network_interface_ids = [
    azurerm_network_interface.vm_client_nic.id,
  ]

  admin_ssh_key {
    username   = var.linux_username
    public_key = var.ssh_key_client
  }

  os_disk {
    name                 = "mos-vm-ubuntu-client-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "vm_mail_nic" {
  name                = "mos-vm-ubuntu-mail-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mos-vm-ubuntu-mail-ip-config"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    public_ip_address_id          = azurerm_public_ip.vm_mail_ip.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.16.32.37"
  }
}

resource "azurerm_public_ip" "vm_mail_ip" {
  name                = "mos-vm-ubuntu-mail-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "vm_mail" {
  name                = "mos-vm-ubuntu-mail"
  computer_name       = "mos-mail"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  admin_username      = var.linux_username
  size                = "Standard_B1s"
  
  network_interface_ids = [
    azurerm_network_interface.vm_mail_nic.id,
  ]

  admin_ssh_key {
    username   = var.linux_username
    public_key = var.ssh_key_mail
  }

  os_disk {
    name                 = "mos-vm-ubuntu-mail-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }
}

resource "azurerm_network_interface" "vm_dc_nic" {
  name                = "mos-vm-windows-dc-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mos-vm-windows-dc-ip-config"
    subnet_id                     = azurerm_subnet.dc_subnet.id
    public_ip_address_id          = azurerm_public_ip.vm_dc_ip.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "172.16.32.4"
  }
}

resource "azurerm_public_ip" "vm_dc_ip" {
  name                = "mos-vm-windows-dc-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_windows_virtual_machine" "vm_dc" {
  name                = "mos-vm-windows-dc"
  computer_name       = "mos-dc"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = var.windows_username
  admin_password      = var.windows_password
  network_interface_ids = [
    azurerm_network_interface.vm_dc_nic.id,
  ]

  os_disk {
    name                 = "mos-vm-windows-dc-disk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

output "vm_client_ip_addr" {
  value = "${azurerm_public_ip.vm_client_ip.ip_address}"
}

output "vm_mail_ip_addr" {
  value = "${azurerm_public_ip.vm_mail_ip.ip_address}"
}

output "vm_dc_ip_addr" {
  value = "${azurerm_public_ip.vm_dc_ip.ip_address}"
}