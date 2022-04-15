provider "helm" {
  kubernetes {
    config_path = local_file.kube_config.filename
  }
}
resource "helm_release" "ingress" {
  name       = "ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "default"
}

resource "helm_release" "be" {
  depends_on = [
    azurerm_kubernetes_cluster.aks, null_resource.docker_push
  ]
  name    = "backend"
  chart   = "${path.module}/chart-be"
  version = "latest"

  values = [
    "${file("${path.module}/chart-be/values.yaml")}"
  ]
  set {
    name  = "be_image"
    value = docker_image.be.name
  }
  
  set {
    name  = "fe_image"
    value = docker_image.fe.name
  }
  set {
    name  = "env.host"
    value = azurerm_postgresql_server.example.fqdn
  }

  set {
    name  = "env.db_name"
    value = azurerm_postgresql_database.pg_db.name
  }

  set {
    name  = "env.pg_user"
    value = "${azurerm_postgresql_server.example.administrator_login}@${azurerm_postgresql_server.example.name}"
  }
  set {
    name  = "env.pg_pass"
    value = azurerm_postgresql_server.example.administrator_login_password
  }

  set {
    name  = "cluster.enabled"
    value = "true"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
}

resource "helm_release" "fe" {
  depends_on = [
    azurerm_kubernetes_cluster.aks, null_resource.docker_push
  ]
  name    = "frontend"
  chart   = "${path.module}/chart-fe"
  version = "latest"

  values = [
    "${file("${path.module}/chart-fe/values.yaml")}"
  ]
  set {
    name  = "fe_image"
    value = docker_image.fe.name
  }

  set {
    name  = "cluster.enabled"
    value = "true"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
}

resource "helm_release" "phppgadmin" {
  depends_on = [
    azurerm_kubernetes_cluster.aks
  ]
  name    = "my-phpadmin"
  chart   = "${path.module}/charts-phppgadmin"
  version = "latest"

  values = [
    "${file("${path.module}/charts-phppgadmin/values.yaml")}"
  ]

  set {
    name  = "cluster.enabled"
    value = "true"
  }

  set {
    name  = "metrics.enabled"
    value = "true"
  }

  set {
    name  = "service.annotations.prometheus\\.io/port"
    value = "9127"
    type  = "string"
  }
  set {
    name  = "phppgadmin.serverHost"
    value = azurerm_postgresql_server.example.fqdn
  }
}
