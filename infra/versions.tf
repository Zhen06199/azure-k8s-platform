terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # 和 bootstrap 不同：infra 的 state 存在远程，也就是 bootstrap 创建的那个 storage 里
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "sttfstatenowkz1" # backend 里不能用变量，只能写死
    container_name       = "tfstate"
    key                  = "platform.tfstate" # state 在 container 里的文件名
    use_azuread_auth     = true
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}
