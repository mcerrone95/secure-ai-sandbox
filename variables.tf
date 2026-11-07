variable "region" {
  description = "AWS region. Pick one where your Bedrock model is enabled."
  type        = string
  default     = "us-east-1"
}

variable "project" {
  description = "Project name, used for naming and tagging."
  type        = string
  default     = "secure-ai-sandbox"
}

variable "environment" {
  description = "Environment name."
  type        = string
  default     = "dev"
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC."
  type        = string
  default     = "10.0.0.0/16"
}

variable "private_subnet_cidrs" {
  description = "CIDRs for private subnets (one per AZ)."
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "bedrock_model_id" {
  description = "The ONE Bedrock foundation model the role may invoke. Model access must be enabled in the Bedrock console first."
  type        = string
  default     = "amazon.nova-micro-v1:0"
}

variable "bedrock_inference_profile_id" {
  description = "Inference profile used to call the model."
  type        = string
  default     = "amazon.nova-micro-v1:0"
}
