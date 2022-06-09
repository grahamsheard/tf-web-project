variable "environment_name" {
  type = string
  default = "web-app-project"
}

variable "environment_type" {
  type = string
  default = "dev"
}

variable "vpc_cidr_block" {
  type    = string
  default = "10.0.0.0/16"
}

variable "instance_type" {
  type    = string
  default = "t3.medium"
}