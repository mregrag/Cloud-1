variable "aws_region" {
  description = "AWS region where the EC2 instance will be deployed"
  type        = string
  default     = "eu-north-1"
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.small"
}

variable "ami_name_filter" {
  description = "Ubuntu 24.04 AMI name filter"
  type        = string
  default     = "ubuntu/images/hvm-ssd-gp3/ubuntu-noble-24.04-amd64-server-*"
}

variable "instance_name" {
  description = "Name tag for the EC2 instance"
  type        = string
  default     = "cloud-1"
}

variable "ssh_public_key" {
  description = "SSH public key registered with the EC2 instance"
  type        = string
  sensitive   = true
}

variable "allowed_ssh_cidr" {
  description = "IPv4 CIDR allowed to connect over SSH, for example the GitHub Actions runner IP with /32"
  type        = string

  validation {
    condition     = can(cidrnetmask(var.allowed_ssh_cidr))
    error_message = "allowed_ssh_cidr must be a valid IPv4 CIDR block, for example 203.0.113.10/32."
  }
}
