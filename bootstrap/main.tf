# storage account 的名字在全球范围内必须唯一，所以加一个随机后缀
resource "random_string" "suffix" {
  length  = 6
  upper   = false # storage account 的名字只能包含小写字母和数字
  special = false
}

resource "azurerm_resource_group" "tfstate" {
  name     = "rg-tfstate"
  location = var.location
}

resource "azurerm_storage_account" "tfstate" {
  name                            = "sttfstate${random_string.suffix.result}" # 3 到 24 个字符
  resource_group_name             = azurerm_resource_group.tfstate.name
  location                        = azurerm_resource_group.tfstate.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS" # 同一个数据中心内保存 3 份副本，最便宜
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false # 禁止任何 container 或 blob 被公开访问

  blob_properties {
    versioning_enabled = true # state 文件被改坏或误删时，可以恢复到之前的版本
  }
}

resource "azurerm_storage_container" "tfstate" {
  name                  = "tfstate"
  storage_account_id    = azurerm_storage_account.tfstate.id # 新的写法，不再使用 storage_account_name
  container_access_type = "private"
}
