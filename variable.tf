variable "region" {
  type = string
  default = "us-east-2"
}
variable "VPC_cidr" {
  type = string
  default = "10.10.0.0/16" 
}
variable "vpc-name" {
  type = string
  default = "utc-vpc"
}
variable "subnet_priv1a_cidr" {
  type = string
  default = "10.10.0.0/20"
}
variable "subnet_priv1b_cidr" {
  type = string
  default = "10.10.112.0/20"
}
variable "subnet_priv2a_cidr" {
  type = string
  default = "10.10.16.0/20"
}
variable "subnet_priv2b_cidr" {
  type = string
  default = "10.10.160.0/20"
}
variable "subnet_priv3a_cidr" {
  type = string
  default = "10.10.32.0/20"
}
variable "subnet_priv3b_cidr" {
  type = string
  default = "10.10.144.0/20"
}
variable "subnet_pub1_cidr" {
  type = string
  default = "10.10.48.0/20"
}  
variable "subnet_pub2_cidr" {
  type = string
  default = "10.10.64.0/20"
} 
variable "subnet_pub3_cidr" {
  type = string
  default = "10.10.80.0/20"
}  
variable "AZ1" {
  type = string
  default = "us-east-2a"
}
variable "AZ2" {
  type = string
  default = "us-east-2b"
}
variable "AZ3" {
  type = string
  default = "us-east-2c"
}
variable "keypair_name" {
  type = string
  default = "utc-key"
}
variable "keypair_location" {
  type = string
  default = "utc-key.pem"
}
variable "aws_ami" {
  type = string
  default = "ami-0866a04d72a1f5479"
}
variable "tg-name" {
  type = string
  default = "utc-target-group"
}
variable "health_check" {
   type = map(string)
   default = {
      "timeout"  = "10"
      "interval" = "20"
      "path"     = "/"
      "port"     = "80"
      "protocol"     = "http"
      "unhealthy_threshold" = "2"
      "healthy_threshold" = "3"
    }
}
variable "domain_name" {
  type = string
  default = "learning.yourdomain"
}
variable "ttl" {
  type = number
  default = 300
}
variable "lb_name" {
  type = string
  default = "utc-lb"
}
variable "instance_type" {
  type = string
  default = "t2.micro"
}
variable "instance_class" {
  type = string
  default = "db.t3.micro"
}
variable "root_volume_size" {
  type = string
  default = "10"
}
variable "db_name" {
  type = string
  default = "utcDB"
}
variable "db_password" {
  type = string
  default = "utcdev12345"
}
variable "db_user" {
  type = string
  default = "utcuser"
}
variable "bucket-name" {
  type = string
  default = "utc-bucket"
}
variable "policy-name" {
  type = string
  default = "AllowS3toEc2"
}
variable "efs_mount_point" {
  description = "Determine the mount point"
  type        = string
  default     = "content/utc/"
}
variable "ami-name" {
  type = string
  default = "utcappserver"
}
variable "launch-tpl" {
  type = string
  default = "utc-launch-template"
}
variable "asg-name" {
  type = string
  default = "utc-auto-scaliing"
}
