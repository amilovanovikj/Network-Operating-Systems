data "azurerm_resource_group" "rg" {
  name = "Network-Operating-Systems"
}

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "mos-vnet-171033"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = ["172.16.32.0/24"]
  dns_servers         = ["172.16.32.4"]
}

resource "azurerm_subnet" "dc_subnet" {
  name                 = "mos-vnet-dc-subnet-171033"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.32.0/27"]
}

resource "azurerm_subnet" "vm_subnet" {
  name                 = "mos-vnet-vm-subnet-171033"
  resource_group_name  = data.azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["172.16.32.32/27"]
}

resource "azurerm_network_security_group" "windows_nsg" {
  name                = "mos-windows-nsg-171033"
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

resource "azurerm_network_security_group" "linux_nsg" {
  name                = "mos-linux-nsg-171033"
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
}

resource "azurerm_network_interface" "vm_client_nic" {
  name                = "mos-vm-ubuntu-client-171033-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mos-vm-ubuntu-client-171033-ip-config"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    public_ip_address_id          = azurerm_public_ip.vm_client_ip.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "vm_client_ip" {
  name                = "mos-vm-ubuntu-client-171033-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "vm_client" {
  name                = "mos-vm-ubuntu-client-171033"
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
    name                 = "mos-vm-ubuntu-client-171033-disk"
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

resource "azurerm_network_interface" "vm_ftp_mail_nic" {
  name                = "mos-vm-ubuntu-ftp-mail-171033-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mos-vm-ubuntu-ftp-mail-171033-ip-config"
    subnet_id                     = azurerm_subnet.vm_subnet.id
    public_ip_address_id          = azurerm_public_ip.vm_ftp_mail_ip.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "vm_ftp_mail_ip" {
  name                = "mos-vm-ubuntu-ftp-mail-171033-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_linux_virtual_machine" "vm_ftp_mail" {
  name                = "mos-vm-ubuntu-ftp-mail-171033"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  admin_username      = var.linux_username
  size                = "Standard_B1s"
  
  network_interface_ids = [
    azurerm_network_interface.vm_ftp_mail_nic.id,
  ]

  admin_ssh_key {
    username   = var.linux_username
    public_key = var.ssh_key_ftp_mail
  }

  os_disk {
    name                 = "mos-vm-ubuntu-ftp-mail-171033-disk"
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
  name                = "mos-vm-windows-dc-171033-nic"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "mos-vm-windows-dc-171033-ip-config"
    subnet_id                     = azurerm_subnet.dc_subnet.id
    public_ip_address_id          = azurerm_public_ip.vm_dc_ip.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_public_ip" "vm_dc_ip" {
  name                = "mos-vm-windows-dc-171033-ip"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  allocation_method   = "Dynamic"
}

resource "azurerm_windows_virtual_machine" "vm_dc" {
  name                = "mos-vm-windows-dc-171033"
  computer_name       = "mos-dc-171033"
  resource_group_name = data.azurerm_resource_group.rg.name
  location            = data.azurerm_resource_group.rg.location
  size                = "Standard_B2s"
  admin_username      = var.windows_username
  admin_password      = var.windows_password
  network_interface_ids = [
    azurerm_network_interface.vm_dc_nic.id,
  ]

  os_disk {
    name                 = "mos-vm-windows-dc-171033-disk"
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