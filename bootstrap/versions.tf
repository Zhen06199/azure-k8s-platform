terraform {
  required_version = ">= 1.6"
  required_providers {
    azurerm = { source = "hashicorp/azurerm", version = "~> 4.0" }
    random  = { source = "hashicorp/random", version = "~> 3.6" }
  }
  # 注意：这里没有 backend 块，所以 bootstrap 的 state 保存在本地的 terraform.tfstate 文件里
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

provider "azuread" {} # 新增：直接使用 az login 的身份，不需要额外配置
