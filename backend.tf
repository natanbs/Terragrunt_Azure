# Generated by Terragrunt. Sig: nIlQXj57tbuaRZEa
terraform {
  backend "azurerm" {
    container_name       = "tfstate"
    key                  = "./terraform.tfstate"
    resource_group_name  = "natan-rg"
    storage_account_name = "natansa"
  }
}
