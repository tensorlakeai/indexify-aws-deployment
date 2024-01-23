/*
# configure terraform cloud

terraform {
  cloud {
    organization = "Your organization"
    workspaces {
      name = "my-workspace"
    }
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.31.0"
    }
  }
}
*/

locals {
  name   = "indexify-cluster"
  region = "us-east-1"

  vpc_cidr = "10.123.0.0/16"
  azs      = ["us-east-1a", "us-east-1b"]

  public_subnets  = ["10.123.1.0/24", "10.123.2.0/24"]
  private_subnets = ["10.123.3.0/24", "10.123.4.0/24"]
  intra_subnets   = ["10.123.5.0/24", "10.123.6.0/24"]

  tags = {
    Name = local.name
  }
}


module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 4.0"

  name = local.name
  cidr = local.vpc_cidr

  azs             = local.azs
  private_subnets = local.private_subnets
  public_subnets  = local.public_subnets
  intra_subnets   = local.intra_subnets

  enable_nat_gateway = true

  # enable for remote access
  map_public_ip_on_launch = true

  public_subnet_tags = {
    "kubernetes.io/role/elb" = 1
  }

  private_subnet_tags = {
    "kubernetes.io/role/internal-elb" = 1
  }
}


module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "19.21.0"

  cluster_name                          = local.name
  cluster_endpoint_private_access       = true
  cluster_endpoint_public_access        = false
  cluster_additional_security_group_ids = [aws_security_group.eks.id]

  cluster_addons = {
    coredns = {
      most_recent = true
    }
    kube-proxy = {
      most_recent = true
    }
    vpc-cni = {
      most_recent = true
    }
  }

  vpc_id                   = module.vpc.vpc_id
  subnet_ids               = module.vpc.private_subnets
  control_plane_subnet_ids = module.vpc.intra_subnets

  eks_managed_node_group_defaults = {
    ami_type               = "AL2_x86_64"
    instance_types         = ["t3.xlarge"]
    vpc_security_group_ids = [aws_security_group.eks.id]
  }

  eks_managed_node_groups = {
    indexify = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]

      tags = {
        Name = "indexify_worker"
      }

      labels = {
        node_role = "indexify"
      }
    }

    indexify_coordinator = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.medium"]

      tags = {
        Name = "indexify_coordinator_worker"
      }

      labels = {
        node_role = "indexify_coordinator"
      }
    }

    indexify_minilml6 = {
      min_size     = 1
      max_size     = 2
      desired_size = 1

      instance_types = ["t3.small"]

      tags = {
        Name = "minilm_l6_worker"
      }

      labels = {
        node_role = "minilm_l6"
      }
    }
  }
}

# subnet groups
resource "aws_db_subnet_group" "db_subnet_group" {
  name       = "${local.name}-db-subnet-group"
  subnet_ids = module.vpc.private_subnets

  tags = {
    Name = "Hub DB Subnet Group"
  }
}

# db instances
resource "aws_db_instance" "indexify_db" {
  allocated_storage      = 20
  storage_type           = "gp2"
  engine                 = "postgres"
  engine_version         = "13"
  instance_class         = var.indexify_db_instance_class
  db_name                = var.indexify_db_name
  username               = var.indexify_db_username
  password               = var.indexify_db_password
  parameter_group_name   = "default.postgres13"
  db_subnet_group_name   = aws_db_subnet_group.db_subnet_group.name
  skip_final_snapshot    = true
  vpc_security_group_ids = [aws_security_group.indexify_rds_sg.id]

  tags = {
    Name = "indexify-db"
  }

  # Enable backups
  backup_retention_period = 7
  backup_window           = "04:00-06:00"
}

# security groups
resource "aws_security_group" "eks" {
  name        = "${local.name} eks sg"
  description = "Allow traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP from ALB"
    from_port   = 80
    to_port     = 3000
    protocol    = "tcp"
    cidr_blocks = [local.vpc_cidr]
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "EKS ${local.name} sg",
    "kubernetes.io/cluster/${local.name}" : "owned"
  }
}

resource "aws_security_group" "indexify_rds_sg" {
  name        = "${local.name} indexify rds sg"
  description = "Allow traffic"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.eks.id]
  }

  tags = {
    Name = "RDS ${local.name} sg"
  }
}
