# Every value here has a sensible default - nothing must be filled in to
# run `terraform apply`. Override any of them with -var, an environment
# variable (TF_VAR_name), or your own terraform.tfvars file.

variable "aws_region" {
  description = "AWS region to deploy into."
  type        = string
  default     = "us-east-1"
}

variable "project_name" {
  description = "Short name used to prefix and tag every resource."
  type        = string
  default     = "system-pulse"
}

variable "instance_type" {
  description = "EC2 size for every server. t3.micro is this account's free-tier-eligible type (confirmed via `aws ec2 describe-instance-types --filters Name=free-tier-eligible,Values=true`) - re-check that command if you use a different AWS account."
  type        = string
  default     = "t3.micro"
}

variable "github_repo_url" {
  description = "Public GitHub repo each server clones and builds at boot."
  type        = string
  default     = "https://github.com/YarinBernstein/system-pulse.git"
}

variable "vpc_cidr" {
  description = "IP address range for the whole private network (VPC)."
  type        = string
  default     = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
  description = "IP range for the public zone (frontend + NAT router)."
  type        = string
  default     = "10.0.1.0/24"
}

variable "private_subnet_cidr" {
  description = "IP range for the private zone (backend + redis)."
  type        = string
  default     = "10.0.2.0/24"
}
