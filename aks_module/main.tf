terraform {
  required_version = ">=0.12"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "2.16.0"
    }
  }
}

provider "docker" {
  host = "tcp://localhost:2375"

  registry_auth {
    address  = azurerm_container_registry.acr.login_server
    username = azurerm_container_registry.acr.admin_username
    password = azurerm_container_registry.acr.admin_password
  }
}

resource "azurerm_container_registry" "acr" {

  name                = "assign3acr"
  resource_group_name = var.aks_rg_name
  location            = var.aks_location
  sku                 = "Standard"
  admin_enabled       = true
}

resource "docker_image" "fe" {
  name = "${azurerm_container_registry.acr.login_server}/fe"
  build {
    path = "${path.module}/fe"
    tag  = ["${azurerm_container_registry.acr.login_server}/fe:latest"]
  }
}
resource "docker_image" "be" {
  name = "${azurerm_container_registry.acr.login_server}/be"
  build {
    path = "${path.module}/be"
    tag  = ["${azurerm_container_registry.acr.login_server}/be:latest"]
  }
}
resource "null_resource" "docker_push" {
  depends_on = [
    docker_image.be, docker_image.fe
  ]
  provisioner "local-exec" {
    command     = <<EOT
        docker login ${azurerm_container_registry.acr.login_server} --username ${azurerm_container_registry.acr.admin_username} --password ${azurerm_container_registry.acr.admin_password}
        docker push ${docker_image.be.name}
        docker push ${docker_image.fe.name}
  EOT
    interpreter = ["PowerShell", "-Command"]
  }
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "assign3-aks"
  location            = var.aks_location
  resource_group_name = var.aks_rg_name
  dns_prefix          = "exampleaks1"

  default_node_pool {
    name       = "default"
    node_count = 1
    vm_size    = "Standard_B2ms"
  }

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "example" {
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
}

resource "local_file" "kube_config" {
  # kube config
  filename = "aks_config"
  content  = azurerm_kubernetes_cluster.aks.kube_config_raw
}

resource "azurerm_postgresql_server" "example" {
  name                = "pgdgdgs"
  location            = var.aks_location
  resource_group_name = var.aks_rg_name

  administrator_login          = "adminuser"
  administrator_login_password = "Sang@123"

  sku_name   = "B_Gen5_2"
  version    = "9.5"
  storage_mb = 5120

  backup_retention_days        = 7
  geo_redundant_backup_enabled = false
  auto_grow_enabled            = true

  ssl_enforcement_enabled = true
}

resource "azurerm_postgresql_database" "pg_db" {
  name                = "pg_db"
  resource_group_name = var.aks_rg_name
  server_name         = azurerm_postgresql_server.example.name
  charset             = "UTF8"
  collation           = "English_United States.1252"
}

resource "azurerm_postgresql_firewall_rule" "example" {
  name                = "allowall"
  resource_group_name = var.aks_rg_name
  server_name         = azurerm_postgresql_server.example.name
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "255.255.255.255"
}


resource "null_resource" "db_setup" {
  provisioner "local-exec" {

    command = "psql -h ${azurerm_postgresql_server.example.fqdn} -p 5432 -U ${azurerm_postgresql_server.example.administrator_login}@${azurerm_postgresql_server.example.name} -d ${azurerm_postgresql_database.pg_db.name} -f ${path.module}/postgres.sql"
    environment = {
      PGPASSWORD = azurerm_postgresql_server.example.administrator_login_password
    }
  }
}
