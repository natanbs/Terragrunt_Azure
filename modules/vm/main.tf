# Create virtual network
/* resource "azurerm_virtual_network" "vnet" {
  name                = "${var.env}-${var.region_name}-${var.instance}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = var.region
  resource_group_name = "${var.env}-${var.region_name}-${var.instance}-rg"
} */

# Create subnet
/* resource "azurerm_subnet" "subnet" {
  name                 = "${var.env}-${var.region_name}-${var.instance}-subnet"
  resource_group_name  = "${var.env}-${var.region_name}-${var.instance}-rg"
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
} */

resource "azurerm_subnet" "subnet" {
  for_each = var.subnets
  resource_group_name  = "${var.env}-${var.region_name}-${var.project}-${var.instance}-rg"
  virtual_network_name = "${var.env}-${var.region_name}-${var.project}-${var.instance}-vnet"
  name                 = each.value["name"]
  address_prefixes     = each.value["address_prefixes"] 
}

# Create public IPs
resource "azurerm_public_ip" "pubIP" {
  name                = "${var.env}-${var.region_name}-${var.project}-${var.instance}-pubIP"
  location            = var.region
  resource_group_name = "${var.env}-${var.region_name}-${var.project}-${var.instance}-rg"
  allocation_method   = "Dynamic"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "nsg" {
  name                = "${var.env}-${var.region_name}-${var.project}-${var.instance}-nsg"
  location            = var.region
  resource_group_name = "${var.env}-${var.region_name}-${var.project}-${var.instance}-rg"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "nic" {
  name                = "${var.env}-${var.region_name}-${var.project}-${var.instance}-nic"
  location            = var.region
  resource_group_name = "${var.env}-${var.region_name}-${var.project}-${var.instance}-rg"
  ip_configuration {
    name                          ="ipConf"
    subnet_id                     = azurerm_subnet.subnet["vm_subnet"].id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.pubIP.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "nsga" {
  network_interface_id      = azurerm_network_interface.nic.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

/* 
# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${var.env}-${var.region_name}-${var.instance}-rg"
  }

  byte_length = 8
} */

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "sa" {
  name                     = "${var.env}${var.region_name}${var.project}${var.instance}sa"
  location                 = var.region
  resource_group_name      = "${var.env}-${var.region_name}-${var.project}-${var.instance}-rg"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "vm" {
  name                  = "${var.env}-${var.region_name}-${var.project}-${var.instance}-vm"
  location              = var.region
  resource_group_name   = "${var.env}-${var.region_name}-${var.project}-${var.instance}-rg"
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = "Standard_A1_v2"
  tags = {
    environment = var.env
    region      = var.region
    project     = var.project
    instance    = var.instance
  }
  
  os_disk {
    name                 = "${var.env}-${var.region_name}-${var.project}-${var.instance}-osDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }

  computer_name                   = "${var.env}-${var.region_name}-${var.project}-${var.instance}-vm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
    username   = "azureuser"
    public_key = tls_private_key.ssh.public_key_openssh
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.sa.primary_blob_endpoint
  }
}
