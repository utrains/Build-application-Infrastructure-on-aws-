terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "5.36.0"
    }
  }
}

# Configure the AWS provider

provider "aws" {
  region = var.region
}


# Create VPC

resource "aws_vpc" "vpc" {
  cidr_block           = var.VPC_cidr
  enable_dns_hostnames = true
  tags = {
    Name = var.vpc-name
  }

}

# Create IGW for internet connection 

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.vpc.id

}

# Create local variables

locals {
  private_subnet = {
    private_1a = {cidr_block = "${var.subnet_priv1a_cidr}" , availability_zone = "${var.AZ1}", routetab = "public_1"},
    private_1b = {cidr_block = "${var.subnet_priv1b_cidr}" , availability_zone = "${var.AZ1}", routetab = "public_1"},
    private_2a = {cidr_block = "${var.subnet_priv2a_cidr}" , availability_zone = "${var.AZ2}", routetab = "public_2"},
    private_2b = {cidr_block = "${var.subnet_priv2b_cidr}" , availability_zone = "${var.AZ2}", routetab = "public_2"},
    private_3a = {cidr_block = "${var.subnet_priv3b_cidr}" , availability_zone = "${var.AZ3}", routetab = "public_3"},
    private_3b = {cidr_block = "${var.subnet_priv3a_cidr}" , availability_zone = "${var.AZ3}", routetab = "public_3"}
  
  }

  public_subnet = {

    public_1 = {cidr_block = "${var.subnet_pub1_cidr}", availability_zone = "${var.AZ1}", nat_gw = "nat-gw1", routetab = "private1"},
    public_2 = {cidr_block = "${var.subnet_pub2_cidr}", availability_zone = "${var.AZ2}", nat_gw = "nat-gw2", routetab = "private2"},
    public_3 = {cidr_block = "${var.subnet_pub3_cidr}", availability_zone = "${var.AZ3}", nat_gw = "nat-gw3", routetab = "private3"}
  }

}

# Create  two private subnets per zones for the three availability zones

resource "aws_subnet" "private_subnet" {
  for_each          = local.private_subnet
  vpc_id            = aws_vpc.vpc.id
  cidr_block        = each.value.cidr_block
  availability_zone = each.value.availability_zone

  tags = {
    "Name" = each.key
  }
}

# Create public subnets in the three availability zones

resource "aws_subnet" "public_subnet" {
  for_each                = local.public_subnet  
  vpc_id                  = aws_vpc.vpc.id
  cidr_block              = each.value.cidr_block
  availability_zone       = each.value.availability_zone
  map_public_ip_on_launch = true

  tags = {
    "Name" = each.key
  }
}

# Create NAT Gateway and associate with private subnets along with Elastic IP address to provide Internet access

resource "aws_eip" "eip" {
  for_each  = local.public_subnet
  domain    = "vpc"
  tags = {
    Name = each.key
  }
}

resource "aws_nat_gateway" "nat_gw" {
  for_each                = local.public_subnet
  allocation_id           = aws_eip.eip[each.key].id
  subnet_id               = aws_subnet.public_subnet[each.key].id

  tags = {
    Name = each.value.nat_gw
  }

  depends_on = [aws_internet_gateway.igw]

}

# Creating Private Route table 

resource "aws_route_table" "private" {
  for_each         = local.public_subnet  
  vpc_id           = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_gw[each.key].id
  }

  tags = {
    Name = each.value.routetab
  }

}

# Creating Public Route table 

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }

  tags = {
    Name = "public"
  }

  depends_on = [aws_internet_gateway.igw]
}

# Associate the route table previously created with the subnets

resource "aws_route_table_association" "private" {
  for_each       = local.private_subnet
  subnet_id      = aws_subnet.private_subnet[each.key].id
  route_table_id = aws_route_table.private[each.value.routetab].id
}

resource "aws_route_table_association" "public" {
  for_each       = local.public_subnet
  subnet_id      = aws_subnet.public_subnet[each.key].id
  route_table_id = aws_route_table.public.id
}

# Security group for Elastic LoadBalancer

resource "aws_security_group" "elb_sg" {


  ingress {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "sg_elb"
  }
}

# Security group for The Bastion Host

resource "aws_security_group" "bastion_sg" {


 ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "bastion-sg"
  }
}

# Security group for The app server

resource "aws_security_group" "app_server_sg" {

 vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = ["${aws_security_group.elb_sg.id}"]
  }

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = ["${aws_security_group.bastion_sg.id}"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app_server_sg"
  }

}

# Security group for The DataBase

resource "aws_security_group" "db_sg" {


  ingress {
    description = "MYSQL"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  vpc_id = aws_vpc.vpc.id
  tags = {
    Name = "db-sg"
  }
}

# Create Security Group for the efs  

resource "aws_security_group" "efs_sg" {
  vpc_id      = aws_vpc.vpc.id

  ingress {
    from_port       = 2049
    to_port         = 2049
    protocol        = "tcp"
    security_groups = [aws_security_group.app_server_sg.id]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.app_server_sg.id]
  }

  tags = {
    "Name" = "efs_sg"
  }
}

# Generate a secure key using a rsa algorithm

resource "tls_private_key" "app_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# Creating the keypair in aws

resource "aws_key_pair" "app_key" {
  key_name   = var.keypair_name                 
  public_key = tls_private_key.app_key.public_key_openssh 
}

# Save the .pem file locally for remote connection

resource "local_file" "ssh_key" {
  filename        = var.keypair_location
  content         = tls_private_key.app_key.private_key_pem
  file_permission = "0400"
}

# Create an ec2 instance for the Bastion Host

resource "aws_instance" "bastion" {
  for_each               = local.public_subnet
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public_subnet[each.key].id
  vpc_security_group_ids = ["${aws_security_group.bastion_sg.id}"]
  key_name               = aws_key_pair.app_key.key_name
    
  connection {
    type        = "ssh"
    host        = self.public_ip
    user        = "ec2-user"
    private_key = file(var.keypair_location) # Location of the Private Key
    timeout     = "4m"
  }

  provisioner "file" {
    source      = "${var.keypair_location}"
    destination = "${var.keypair_location}"
  
  }  

  provisioner "file" {
    source      = "~/.aws/credentials"
    destination = "~/.aws/credentials"
  }
  
  provisioner "file" {
    source      = "efs_mount.sh"
    destination = "efs_mount.sh"
  }

  tags = {
    Name = each.key
  }

 }
 
 # Create EFS File system 

resource "aws_efs_file_system" "efs" {
  creation_token   = "efs"
  performance_mode = "generalPurpose"
  throughput_mode  = "bursting"
  lifecycle_policy {
    transition_to_ia = "AFTER_30_DAYS"
  }
  tags = {
    Name = "utc-efs"
  }
}

# Create EFS mount target in AZ1

resource "aws_efs_mount_target" "mount_tg1" {
  subnet_id       = aws_subnet.private_subnet["private_1a"].id
  file_system_id  = aws_efs_file_system.efs.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Create EFS mount target in AZ2

resource "aws_efs_mount_target" "mount_tg2" {
  subnet_id       = aws_subnet.private_subnet["private_2a"].id
  file_system_id  = aws_efs_file_system.efs.id
  security_groups = [aws_security_group.efs_sg.id]
}

# Generating Script for Mounting EFS

resource "null_resource" "generate_efs_mount_script" {

  provisioner "local-exec" {
    command = templatefile("efs_mount.tpl", {
      efs_mount_point = var.efs_mount_point
      file_system_id  = aws_efs_file_system.efs.id
    })
    interpreter = [
      "bash",
      "-c"
    ]
  }
}

# Clean Up Existing Script 

resource "null_resource" "clean_up" {

  provisioner "local-exec" {
    when    = destroy
    command = "rm -rf efs_mount.sh"
  }
}

# Create an ec2 instance for the app server in AZ private 1

resource "aws_instance" "app_server1" {
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet["private_1a"].id
  vpc_security_group_ids = ["${aws_security_group.app_server_sg.id}"]
  user_data              = "${file("userdata.sh")}"
  key_name               = aws_key_pair.app_key.key_name
  tags = {
    Name = "app-server-AZ1"
  }
  depends_on = [ 
    null_resource.generate_efs_mount_script, aws_instance.bastion["public_1"], aws_efs_mount_target.mount_tg1 , aws_s3_bucket.bucket
  ]

  connection {
    type        = "ssh"
    host        = self.private_ip
    user        = "ec2-user"
    private_key = file(var.keypair_location) # Location of the Private Key
    timeout     = "4m"
    bastion_user = "ec2-user"
    bastion_host = aws_instance.bastion["public_1"].public_ip
    bastion_host_key = file(var.keypair_location)
  }

  provisioner "file" {
    source      = "~/.aws/credentials"
    destination = "~/.aws/credentials"
  }

  provisioner "file" {
    source      = "efs_mount.sh"
    destination = "efs_mount.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "bash efs_mount.sh",
    ]
  }

 }

 # Create an ec2 instance for the app server in AZ private 2

resource "aws_instance" "app_server2" {
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet["private_2a"].id
  vpc_security_group_ids = ["${aws_security_group.app_server_sg.id}"]
  user_data              = "${file("userdata.sh")}"
  key_name               = aws_key_pair.app_key.key_name
  tags = {
    Name = "app-server-AZ1"
  }
  depends_on = [ 
    null_resource.generate_efs_mount_script, aws_instance.bastion["public_2"], aws_efs_mount_target.mount_tg1 , aws_s3_bucket.bucket
  ]

  connection {
    type        = "ssh"
    host        = self.private_ip
    user        = "ec2-user"
    private_key = file(var.keypair_location) # Location of the Private Key
    timeout     = "4m"
    bastion_user = "ec2-user"
    bastion_host = aws_instance.bastion["public_2"].public_ip
    bastion_host_key = file(var.keypair_location)
  }
  
  provisioner "file" {
    source      = "~/.aws/credentials"
    destination = "~/.aws/credentials"
  }

  provisioner "file" {
    source      = "efs_mount.sh"
    destination = "efs_mount.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "bash efs_mount.sh",
    ]
  }

 }

# Create an ec2 instance for the app server in AZ private 3

resource "aws_instance" "app_server3" {
  ami                    = var.aws_ami
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private_subnet["private_3a"].id
  vpc_security_group_ids = ["${aws_security_group.app_server_sg.id}"]
  user_data              = "${file("userdata.sh")}"
  key_name               = aws_key_pair.app_key.key_name
  tags = {
    Name = "app-server-AZ1"
  }
  depends_on = [ 
    null_resource.generate_efs_mount_script, aws_instance.bastion["public_3"], aws_efs_mount_target.mount_tg1 , aws_s3_bucket.bucket
  ]

  connection {
    type        = "ssh"
    host        = self.private_ip
    user        = "ec2-user"
    private_key = file(var.keypair_location) # Location of the Private Key
    timeout     = "4m"
    bastion_user = "ec2-user"
    bastion_host = aws_instance.bastion["public_3"].public_ip
    bastion_host_key = file(var.keypair_location)
  }
  
  provisioner "file" {
    source      = "~/.aws/credentials"
    destination = "~/.aws/credentials"
  }

  provisioner "file" {
    source      = "efs_mount.sh"
    destination = "efs_mount.sh"
  }
  
  provisioner "remote-exec" {
    inline = [
      "bash efs_mount.sh",
    ]
  }

 }

 # Create a target Group

 resource "aws_lb_target_group" "tg" {

   name                = var.tg-name
   target_type         = "instance"
   port                = 80
   protocol            = "HTTP"
   protocol_version    = "HTTP1"
   vpc_id              = aws_vpc.vpc.id
   health_check {
      healthy_threshold   = var.health_check["healthy_threshold"]
      interval            = var.health_check["interval"]
      unhealthy_threshold = var.health_check["unhealthy_threshold"]
      timeout             = var.health_check["timeout"]
      path                = var.health_check["path"]
      port                = var.health_check["port"]
   }
   tags = {
    Name = var.tg-name
   }
}

# Attach the target group to the two instances created before

resource "aws_lb_target_group_attachment" "tg-atch-serv1" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        =  aws_instance.app_server1.id  
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-atch-serv2" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app_server2.id 
  port             = 80
}

resource "aws_lb_target_group_attachment" "tg-atch-serv3" {
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = aws_instance.app_server3.id 
  port             = 80
}

# Create an Hosted Zone in Amazon Route 53

resource "aws_route53_zone" "hosted_zone" {
  name = var.domain_name
  
  vpc {
    vpc_id = aws_vpc.vpc.id
  }

  tags = {
    Name        = var.domain_name
  }
}

# Create an application LoadBalancer

resource "aws_lb" "alb" {
  
  name               = var.lb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.elb_sg.id]
  subnets            = ["${aws_subnet.public_subnet["public_1"].id}" , "${aws_subnet.public_subnet["public_2"].id}", "${aws_subnet.public_subnet["public_3"].id}"]
  enable_deletion_protection = false
  tags = {
    name = var.lb_name
  }

}

# Listener rule for HTTP traffic on each of the ALB

resource "aws_lb_listener" "lb_listener_http" {
   load_balancer_arn    = aws_lb.alb.arn
   port                 = "80"
   protocol             = "HTTP"
   default_action {
    target_group_arn = aws_lb_target_group.tg.arn
    type             = "forward"
  }
}

# Create an RDS Subnet group

resource "aws_db_subnet_group" "rds_subnet_grp" {
    subnet_ids = ["${aws_subnet.private_subnet["private_1a"].id}", "${aws_subnet.private_subnet["private_1b"].id}","${aws_subnet.private_subnet["private_2a"].id}","${aws_subnet.private_subnet["private_2b"].id}", "${aws_subnet.private_subnet["private_3a"].id}","${aws_subnet.private_subnet["private_3b"].id}"] 
}
  
# Create RDS instance

resource "aws_db_instance" "db" {
  allocated_storage      = 10
  engine                 = "mysql"
  engine_version         = "5.7"
  instance_class         = var.instance_class
  db_subnet_group_name   = aws_db_subnet_group.rds_subnet_grp.id
  vpc_security_group_ids = ["${aws_security_group.db_sg.id}"]
  db_name                = var.db_name
  username               = var.db_user
  password               = var.db_password
  skip_final_snapshot    = true

 # Make sure rds manual password changes is ignored

  lifecycle {
     ignore_changes = [password]
   }

}

# Change USERDATA varible value after grabbing RDS endpoint info

data "template_file" "user_data" {
  template = file("${path.module}/userdata.tpl")
  vars = {
    db_username      = var.db_user
    db_user_password = var.db_password
    db_name          = var.db_name
    db_RDS           = aws_db_instance.db.endpoint
  }
}

# Create an S3 Bucket 

resource "aws_s3_bucket" "bucket" {
    bucket = var.bucket-name

}

# Creating the IAM Role for S3

resource "aws_iam_role" "iam-role" {
  name = "Ec2AssumeRole"
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

# Granting Access to the S3 Bucket

resource "aws_iam_policy" "iam-policy" {
  name        = var.policy-name
  description = "to give access from ec2 to s3 bucket"
  policy      = jsonencode({
  Version    = "2012-10-17"
  
  Statement = [
      {
        Action   = ["s3:ListBucket"]
        Effect   = "Allow"
        Resource = [aws_s3_bucket.bucket.arn]
      },
      {
        Action   = ["s3:GetObject", "s3:PutObject"]
        Effect   = "Allow"
        Resource = ["${aws_s3_bucket.bucket.arn}/*"]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "policy-atch" {
  role       = aws_iam_role.iam-role.name
  policy_arn = aws_iam_policy.iam-policy.arn
}

# Create an ami for the instances

resource "aws_ami_from_instance" "app-ami" {
  name               = var.ami-name
  source_instance_id = aws_instance.app_server1.id
}

# Create a lunch template for our auto scaling

resource "aws_launch_template" "launch_template" {
  name_prefix   = var.launch-tpl
  image_id      = aws_ami_from_instance.app-ami.id
  instance_type = var.instance_type
}

# Autoscaling Group Resource

resource "aws_autoscaling_group" "asg" {
  availability_zones = ["${var.AZ1}","${var.AZ2}","${var.AZ3}"]
  desired_capacity   = 2
  max_size           = 10
  min_size           = 2

  launch_template {
    id      = aws_launch_template.launch_template.id
    version = "$Latest"

  }
}

# Create Autoscaling policy for the scale up

resource "aws_autoscaling_policy" "app_policy_up" {
  name = "utc_policy_up"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Create a cloudwatch metric alarm to be connected with the Autoscaling policy scale up

resource "aws_cloudwatch_metric_alarm" "app_cpu_alarm_up" {
  alarm_name = "utc_cpu_alarm_up"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "80"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }
  alarm_description = "This metric monitor app-server instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.app_policy_up.arn ]
}

#Create Autoscaling policy for the scale down

resource "aws_autoscaling_policy" "app_policy_down" {
  name = "app_policy_down"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.asg.name
}

# Create a cloudwatch metric alarm to be connected with the Autoscaling policy scale down

resource "aws_cloudwatch_metric_alarm" "app_cpu_alarm_down" {
  alarm_name = "app_cpu_alarm_down"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "10"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.asg.name
  }

  alarm_description = "This metric monitor EC2 instance CPU utilization"
  alarm_actions = [ aws_autoscaling_policy.app_policy_down.arn ]
}

output "elb_dns_name" {
  value = aws_lb.alb.dns_name
}

# Autoscaling Notifications

## SNS - Topic

resource "aws_sns_topic" "asg_sns_topic" {
  name = var.asg-name
}

## SNS - Subscription

resource "aws_sns_topic_subscription" "asg_sns_topic_subscription" {
  topic_arn = aws_sns_topic.asg_sns_topic.arn
  protocol  = "email"
  endpoint  = "darelle.ghomo@utrains.org"
}

## Create Autoscaling Notification Resource

resource "aws_autoscaling_notification" "asg_notifications" {
  group_names = [aws_autoscaling_group.asg.id]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR",
  ]
  topic_arn = aws_sns_topic.asg_sns_topic.arn 
}