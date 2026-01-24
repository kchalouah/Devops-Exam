variable "region" {
  default = "us-east-1"
}

variable "instance_type" {
  default = "t3.small"
}

variable "key_name" {
  description = "Name of the SSH key pair"
  type        = string
  default     = "vockey"
}
