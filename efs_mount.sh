#! /bin/bash
sudo yum update -y
sudo mkdir -p content/utc/
sudo yum -y install amazon-efs-utils
sudo su -c  "echo 'fs-0c4c5164674de43ca:/ content/utc/ efs _netdev,tls 0 0' >> /etc/fstab"
sudo mount content/utc/
df -k