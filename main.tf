# Needed to be able to get list of availiability zones (data.tf)
provider "aws" {
  region = var.region
}

data "aws_availability_zones" "available" {}

# For internet access
module "eks-public-subnets" {
  count                          = var.create_cluster ? 3 : 0
  source                         = "github.com/rafikbahri/tf-aws-public-subnet"
  name                           = "${var.cluster_name}-public-subnet-${count.index + 1}"
  vpc_id                         = var.vpc_id
  availability_zone              = data.aws_availability_zones.available.names[count.index]
  cidr_block                     = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  map_public_ip_on_launch        = true
  has_internet_access            = true
  public_internet_route_table_id = var.public_route_table_id
  tags = {
    group = "eks-cluster"
  }
}

# Private
module "eks-private-subnets" {
  count               = var.create_cluster ? 3 : 0
  source              = "github.com/rafikbahri/tf-aws-private-subnet"
  name                = "${var.cluster_name}-private-subnet-${count.index + 1}"
  vpc_id              = var.vpc_id
  availability_zone   = data.aws_availability_zones.available.names[count.index]
  cidr_block          = cidrsubnet(var.vpc_cidr, 8, count.index + 1)
  public_subnet_id    = module.eks-public-subnets[count.index].subnet_id
  has_internet_access = true
  tags = {
    group = "eks-cluster"
  }
}

module "sg-eks" {
  source      = "github.com/rafikbahri/tf-aws-sg"
  name        = "sg_eks"
  description = "Security group for EKS cluster"
  vpc_id      = var.vpc_id
  egress_rules = [
    {
      description = "Allow SSM traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
      # Required attribues: https://stackoverflow.com/a/69080432/5684155
      ipv6_cidr_blocks = []
      prefix_list_ids  = []
      security_groups  = []
      self             = false
    }
  ]

  tags = {
    Name = "eks-cluster-sg"
  }
}

# EKS Cluster
resource "aws_eks_cluster" "eks_cluster" {
  count    = var.create_cluster ? 1 : 0
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster_role.arn

  vpc_config {
    subnet_ids              = module.eks-private-subnets[*].subnet_id
    endpoint_private_access = true
    endpoint_public_access  = false
    security_group_ids      = [module.sg-eks.sg_id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
    aws_iam_role_policy_attachment.eks_vpc_resource_controller,
  ]
}

# EKS Node Group
resource "aws_eks_node_group" "eks_nodes" {
  count           = var.create_cluster ? 1 : 0
  cluster_name    = var.cluster_name
  node_group_name = var.cluster_node_group_name
  node_role_arn   = aws_iam_role.eks_node_role.arn
  subnet_ids      = module.eks-private-subnets[*].subnet_id

  scaling_config {
    desired_size = 3
    max_size     = 5
    min_size     = 1
  }

  instance_types = ["t2.micro"]

  depends_on = [
    aws_eks_cluster.eks_cluster,
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.ec2_container_registry_read_only,
  ]
}

# IAM Role for EKS Cluster
resource "aws_iam_role" "eks_cluster_role" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "eks.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role for EKS Node Group
resource "aws_iam_role" "eks_node_role" {
  name = "eks-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
}

# IAM Role Policy Attachments
resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_vpc_resource_controller" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController"
  role       = aws_iam_role.eks_cluster_role.name
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_role.name
}

resource "aws_iam_role_policy_attachment" "ec2_container_registry_read_only" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_role.name
}
