variable "project_name" {
  description = "The name for the project, used for resource tagging."
  type        = string
  default     = "pet-classification"
}

variable "aws_region" {
  description = "The AWS region where resources will be created."
  type        = string
  default     = "us-east-1" 
}

variable "ecr_image_uri" {
  description = "The URI of the Docker image in ECR."
  type        = string
  
}


output "load_balancer_dns" {
  description = "The DNS name of the Application Load Balancer (ALB)."
  value = aws_lb.pet_alb.dns_name
}

output "ecs_service_name" {
  description = "The name of the deployed ECS Service."
  value = aws_ecs_service.pet_service.name
}

provider "aws" {
  region = var.aws_region
}
