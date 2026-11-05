resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_resource_group" "platform" {
  name     = "rg-aks-platform"
  location = var.location
}

resource "azurerm_container_registry" "acr" {
  name                = "acrplatform${random_string.suffix.result}" # ACR 的名字也要全球唯一
  resource_group_name = azurerm_resource_group.platform.name
  location            = azurerm_resource_group.platform.location
  sku                 = "Basic"
  admin_enabled       = false # 不使用用户名和密码，改用身份授权
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-platform"
  location            = azurerm_resource_group.platform.location
  resource_group_name = azurerm_resource_group.platform.name
  dns_prefix          = "aksplatform"

  default_node_pool {
    name       = "system"
    node_count = 1
    vm_size    = "standard_d2s_v7" # 2 vCPU / 8 GB，便宜，之后装监控也够用

    # 上次 plan 一直显示的漂移就是因为这里：Azure 会自动设置 max_surge = 10%，
    # 代码里没写的话，Terraform 每次都想把它删掉。这次把它明确写出来
    upgrade_settings {
      max_surge = "10%"
    }
  }

  identity {
    type = "SystemAssigned" # 由 Azure 自动管理集群的身份，不需要密码
  }
}

# 让 AKS 节点能从 ACR 拉取镜像，不需要任何密码
resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = azurerm_container_registry.acr.id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.aks.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

# CI：可以往 ACR 推送镜像
resource "azurerm_role_assignment" "ci_acr_push" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPush"
  principal_id         = var.ci_principal_id
}

# CI：可以获取 AKS 的 kubeconfig（az aks get-credentials 需要这个权限）
resource "azurerm_role_assignment" "ci_aks_user" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = var.ci_principal_id
}
