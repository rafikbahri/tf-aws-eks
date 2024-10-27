
output "cluster_endpoint" {
  description = "Endpoint for EKS control plane"
  value       = var.create_cluster ? aws_eks_cluster.eks_cluster[0].endpoint : null
}

output "cluster_security_group_id" {
  description = "Security group ID attached to the EKS cluster"
  value       = var.create_cluster ? aws_eks_cluster.eks_cluster[0].vpc_config[0].cluster_security_group_id : null
}

output "cluster_iam_role_name" {
  description = "IAM role name associated with EKS cluster"
  value       = aws_iam_role.eks_cluster_role.name
}

output "cluster_iam_role_arn" {
  description = "IAM role ARN associated with EKS cluster"
  value       = aws_iam_role.eks_cluster_role.arn
}