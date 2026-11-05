# ---------- GitHub 仓库信息 ----------
variable "github_repo" {
  type    = string
  default = "Zhen06199/azure-k8s-platform"
}

variable "github_owner_id" {
  type    = string
  default = "183380435"
}

variable "github_repo_id" {
  type    = string
  default = "1444370562"
}

locals {
  gh_owner = split("/", var.github_repo)[0]
  gh_name  = split("/", var.github_repo)[1]
  # GitHub OIDC 的 subject 带有不可变的数字 ID：repo:owner@owner_id/repo@repo_id:...
  gh_sub_prefix = "repo:${local.gh_owner}@${var.github_owner_id}/${local.gh_name}@${var.github_repo_id}"
}

# 当前执行 terraform 的身份，也就是你自己
data "azurerm_client_config" "current" {}

# ---------- CI 身份 ----------
resource "azuread_application" "gha" {
  display_name = "gha-azure-k8s-platform"
}

resource "azuread_service_principal" "gha" {
  client_id = azuread_application.gha.client_id
}

# 只有 main 分支上的 workflow 能换到 token
resource "azuread_application_federated_identity_credential" "main" {
  application_id = azuread_application.gha.id
  display_name   = "github-main"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "${local.gh_sub_prefix}:ref:refs/heads/main"
}

# PR 上的 workflow（只执行 terraform plan）
resource "azuread_application_federated_identity_credential" "pr" {
  application_id = azuread_application.gha.id
  display_name   = "github-pr"
  audiences      = ["api://AzureADTokenExchange"]
  issuer         = "https://token.actions.githubusercontent.com"
  subject        = "${local.gh_sub_prefix}:pull_request"
}

# ---------- 权限 ----------
# CI：在订阅上只能读取，所以 PR 只能 plan，不能 apply
resource "azurerm_role_assignment" "gha_reader" {
  scope                = "/subscriptions/${var.subscription_id}"
  role_definition_name = "Reader"
  principal_id         = azuread_service_principal.gha.object_id
}

# CI：通过 Entra 身份读写 state，不使用 storage key
resource "azurerm_role_assignment" "gha_state" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azuread_service_principal.gha.object_id
}

# 你自己：infra 改成 use_azuread_auth 后，你的账号也需要这个数据层权限
resource "azurerm_role_assignment" "me_state" {
  scope                = azurerm_storage_account.tfstate.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = data.azurerm_client_config.current.object_id
}

# ---------- 输出：GitHub 变量和 infra 会用到 ----------
output "client_id" { value = azuread_application.gha.client_id }
output "tenant_id" { value = data.azurerm_client_config.current.tenant_id }
output "ci_principal_id" { value = azuread_service_principal.gha.object_id }
