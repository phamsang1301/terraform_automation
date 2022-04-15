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
provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resourcegroup" {
  name     = "aks-resourcename"
  location = "eastasia"
}

module "aks" {
  source       = "./aks_module"
  aks_rg_name  = azurerm_resource_group.resourcegroup.name
  aks_location = azurerm_resource_group.resourcegroup.location
}

module "ansible_tower" {
  source         = "./ansible_tower_module"
  tower_location = "australiaeast"
  tower_rg_name  = "tower_rg"
  address_space  = ["10.0.0.0/16", "10.0.0.0/24", "10.0.2.0/24"]
}

resource "azurerm_resource_group" "resourcegroup2" {
  name     = "gitlab-jenkins-resourcename"
  location = "japaneast"
}

module "gitlab-jenkins" {
  source        = "./jenkins_gitlab_module"
  rg_name       = azurerm_resource_group.resourcegroup2.name
  location      = azurerm_resource_group.resourcegroup2.location
  address_space = ["10.2.0.0/16", "10.2.0.0/24", "10.2.2.0/24"]
}





#sudo apt install python-pip
