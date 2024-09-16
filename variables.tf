variable "vpc_id" {
  description = "ID of the VPC of the EKS cluster"
  type        = string
  default     = ""
}

variable "region" {
  description = "AWS Region"
  type        = string
  default     = "eu-west-3"
}

variable "cluster_name" {
  description = "Name of the EKS cluster"
  type        = string
  default     = "eks-cluster01"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_route_table_id" {
  description = "ID of public route table (associated to the Internet Gateway)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Cluster tags"
  type        = map(string)
  default     = {}
}