module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "3.14.0"

  # VPC Basic Details
  name = "${local.name}-vpc"
  cidr = var.vpc_cidr_block   
  azs                 = ["eu-west-2a", "eu-west-2b"]
  private_subnets     = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets      = ["10.0.101.0/24", "10.0.102.0/24"]

  # Database Subnets
  create_database_subnet_group = true
  create_database_subnet_route_table= true
  database_subnets    = ["10.0.151.0/24", "10.0.152.0/24"]


  # NAT Gateways - Outbound Communication
  enable_nat_gateway = true
  single_nat_gateway = false

  # VPC DNS Parameters
  enable_dns_hostnames = true
  enable_dns_support = true

  public_subnet_tags = {
    Type = "public-subnets"
  }

  private_subnet_tags = {
    Type = "private-subnets"
  }

  database_subnet_tags = {
    Type = "database-subnets"
  }

  tags = {
    environment_type = var.environment_type
  }

  vpc_tags = {
    Name = local.name
  }
}