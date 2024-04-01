variable "external_network_id" {
  description = "ID of the external network for router gateway"
}

variable "image_name" {
  description = "Name of the image to use for the instance"
}

variable "flavor_name" {
  description = "Flavor to use for the instance"
}

variable "public_network" {
    description = "Name of the public network"
}

variable "keypair_name" {
    description = "Name of the keypair to use for the instance"
}