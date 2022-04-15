
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


#Create a virtual network
resource "azurerm_virtual_network" "jenkins_gitlab_appgw_vnet" {
  name                = "jenkins_gitlab_appgw-vnet"
  resource_group_name = var.rg_name
  location            = var.location
  address_space       = [element(var.address_space, 0)]
}

#Create  subnet
resource "azurerm_subnet" "jenkins_gitlab_appgw_subnet" {
  name                 = "jenkins_gitlab_appgw-subnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name
  address_prefixes     = [element(var.address_space, 1)]
}

#Create public ip
resource "azurerm_public_ip" "jenkins_gitlab_appgw_publicip" {
  name                = "jenkins_gitlab_appgw-publicip"
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
}

#Create network interface card
resource "azurerm_network_interface" "jenkins_gitlab_appgw_nic" {
  name                = "jenkins_gitlab_appgw-nic"
  location            = var.location
  resource_group_name = var.rg_name

  ip_configuration {
    name                          = "config_ip"
    subnet_id                     = azurerm_subnet.jenkins_gitlab_appgw_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.jenkins_gitlab_appgw_publicip.id
  }
}

resource "azurerm_linux_virtual_machine" "gitlab_linux_vm" {
  name                            = "assign3-gitlab-appgw-jenkins"
  resource_group_name             = var.rg_name
  location                        = var.location
  size                            = "Standard_B4ms"
  admin_username                  = "adminuser"
  admin_password                  = "Phamngocsang113"
  disable_password_authentication = false
  network_interface_ids = [
    azurerm_network_interface.jenkins_gitlab_appgw_nic.id,
  ]

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
}

resource "azurerm_subnet" "frontend" {
  name = "fe_subnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name
  address_prefixes     = ["10.2.1.0/24"]
  depends_on = [
    azurerm_virtual_network.jenkins_gitlab_appgw_vnet
  ]
}

resource "azurerm_subnet" "backend" {
  name = "be_subnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name
  address_prefixes     = ["10.2.2.0/24"]

}

resource "azurerm_public_ip" "publicip_agw" {
  name                = "publicip_agw"
  resource_group_name = var.rg_name
  location            = var.location
  allocation_method   = "Static"
  sku                 = "Standard"
}

#&nbsp;since these variables are re-used - a locals block makes this more maintainable
locals {
  gateway_ip_configuration_name  = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-gwic"
  frontend_port_name             = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-fep"
  frontend_ip_configuration_name = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-feip"
  backend_address_pool_name      = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-beap"

  #JENKINS
  backend_http_settings_jenkins     = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-behs-jenkins"
  http_listener_name_jenkins        = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-hl-jenkins"
  request_routing_rule_name_jenkins = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-rqrt-jenkins"
  probe_name_jenkins                = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-probe-jenkins"
  host_name_jenkins                 = "jenkins.sangpham.tk"

  #GITLAB
  backend_http_settings_gitlab     = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-behs-gitlab"
  http_listener_name_gitlab        = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-hl-gitlab"
  request_routing_rule_name_gitlab = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-rqrt-gitlab"
  probe_name_gitlab                = "${azurerm_virtual_network.jenkins_gitlab_appgw_vnet.name}-probe-gitlab"
  host_name_gitlab                 = "gitlab.sangpham.tk"
}

resource "azurerm_application_gateway" "application_gateway" {
  name                = "app_gw"
  resource_group_name = var.rg_name
  location            = var.location

  sku {
    name     = "WAF_v2"
    tier     = "WAF_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = local.gateway_ip_configuration_name
    subnet_id = azurerm_subnet.frontend.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.publicip_agw.id
  }

  backend_address_pool {
    name = local.backend_address_pool_name
    ip_addresses = [
      azurerm_linux_virtual_machine.gitlab_linux_vm.private_ip_address
    ]
  }

  # JENKINS
  backend_http_settings {
    name                  = local.backend_http_settings_jenkins
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 8080
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = local.probe_name_jenkins
  }
  http_listener {
    name                           = local.http_listener_name_jenkins
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
    host_name                      = local.host_name_jenkins
  }
  request_routing_rule {
    name                       = local.request_routing_rule_name_jenkins
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name_jenkins
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.backend_http_settings_jenkins
  }
  probe {
    host                                      = local.host_name_jenkins
    interval                                  = 30
    minimum_servers                           = 0
    name                                      = local.probe_name_jenkins
    path                                      = "/"
    pick_host_name_from_backend_http_settings = false
    protocol                                  = "Http"
    timeout                                   = 30
    unhealthy_threshold                       = 3

    match {
      body = ""
      status_code = [
        "403",
        "200-399",
      ]
    }
  }

  # GTILAB
  backend_http_settings {
    name                  = local.backend_http_settings_gitlab
    cookie_based_affinity = "Disabled"
    path                  = "/"
    port                  = 8012
    protocol              = "Http"
    request_timeout       = 60
    probe_name            = local.probe_name_gitlab
  }
  http_listener {
    name                           = local.http_listener_name_gitlab
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
    host_name                      = local.host_name_gitlab
  }
  request_routing_rule {
    name                       = local.request_routing_rule_name_gitlab
    rule_type                  = "Basic"
    http_listener_name         = local.http_listener_name_gitlab
    backend_address_pool_name  = local.backend_address_pool_name
    backend_http_settings_name = local.backend_http_settings_gitlab
  }
  probe {
    host                                      = local.host_name_gitlab
    interval                                  = 30
    minimum_servers                           = 0
    name                                      = local.probe_name_gitlab
    path                                      = "/"
    pick_host_name_from_backend_http_settings = false
    protocol                                  = "Http"
    timeout                                   = 30
    unhealthy_threshold                       = 3

    match {
      body = ""
      status_code = [
        "403",
        "200-399",
      ]
    }
  }

}





# resource "null_resource" "install_gitlab_jenkins" {
#   connection {
#     type     = "ssh"
#     user     = azurerm_linux_virtual_machine.gitlab_linux_vm.admin_username
#     password = azurerm_linux_virtual_machine.gitlab_linux_vm.admin_password
#     host     = azurerm_linux_virtual_machine.gitlab_linux_vm.public_ip_address
#   }
#     provisioner "file" {
#     source      = "${path.module}/ansible-jenkins-gitlab"
#     destination = "/home/${azurerm_linux_virtual_machine.gitlab_linux_vm.admin_username}/ansible-jenkins-gitlab"
#   }

#   provisioner "remote-exec" {
#     inline = [
#         "",
#         "",
#       "cd /home/${azurerm_linux_virtual_machine.tower_linux_vm.admin_username}/ansible-jenkins-gitlab",
#       "chmod a+x install_tower.sh"
#     ]
#   }
# }


