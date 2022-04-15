
# resource "tls_private_key" "linux_key" {
#   algorithm = "RSA"
#   rsa_bits  = 4096
# }

# We want to save the private key to our machine
# We can then use this key to connect to our Linux VM

# resource "local_file" "linuxkey" {
#   filename = "linuxkey.pem"
#   content  = tls_private_key.linux_key.private_key_pem
# }

# Create a resource group
resource "azurerm_resource_group" "resourcegroup" {
  name     = var.tower_rg_name
  location = var.tower_location
}

#Create a virtual network
resource "azurerm_virtual_network" "azvnet" {
  name                = "assign3-vnet"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  address_space       = [element(var.address_space, 0)]
}

#Create  subnet
resource "azurerm_subnet" "azsubnet" {
  name                 = "assign3-subnet"
  resource_group_name  = azurerm_resource_group.resourcegroup.name
  virtual_network_name = azurerm_virtual_network.azvnet.name
  address_prefixes     = [element(var.address_space, 1)]
}

#Create public ip
resource "azurerm_public_ip" "publicip" {
  name                = "assign3-publicip"
  resource_group_name = azurerm_resource_group.resourcegroup.name
  location            = azurerm_resource_group.resourcegroup.location
  allocation_method   = "Static"
}

#Create network interface card
resource "azurerm_network_interface" "nic" {
  name                = "assig3vm-nic"
  location            = azurerm_resource_group.resourcegroup.location
  resource_group_name = azurerm_resource_group.resourcegroup.name

  ip_configuration {
    name                          = "config_ip"
    subnet_id                     = azurerm_subnet.azsubnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.publicip.id
  }
}

resource "azurerm_linux_virtual_machine" "tower_linux_vm" {
  name                            = "assign3-tower-ansible"
  resource_group_name             = azurerm_resource_group.resourcegroup.name
  location                        = azurerm_resource_group.resourcegroup.location
  size                            = "Standard_B2ms"
  admin_username                  = "adminuser"
  admin_password                  = "Phamngocsang113"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "OpenLogic"
    offer     = "CentOS"
    sku       = "8_5-gen2"
    version   = "latest"
  }
}

resource "null_resource" "install_tower" {

  connection {
    type     = "ssh"
    user     = azurerm_linux_virtual_machine.tower_linux_vm.admin_username
    password = azurerm_linux_virtual_machine.tower_linux_vm.admin_password
    host     = azurerm_linux_virtual_machine.tower_linux_vm.public_ip_address
  }

  provisioner "file" {
    source      = "${path.module}/install_tower.sh"
    destination = "/home/${azurerm_linux_virtual_machine.tower_linux_vm.admin_username}/install_tower.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "cd /home/${azurerm_linux_virtual_machine.tower_linux_vm.admin_username}",
      "chmod a+x install_tower.sh",
      "sudo sh install_tower.sh"
    ]
  }
}





