#!/bin/bash
sudo su
# Install amazon-efs-utils
yum install -y amazon-efs-utils

# Install botocore
yum -y install wget

if [[ "$(python3 -V 2>&1)" =~ ^(Python 3.6.*) ]]; then
    sudo wget https://bootstrap.pypa.io/3.6/get-pip.py -O /tmp/get-pip.py
elif [[ "$(python3 -V 2>&1)" =~ ^(Python 3.5.*) ]]; then
    sudo wget https://bootstrap.pypa.io/3.5/get-pip.py -O /tmp/get-pip.py
elif [[ "$(python3 -V 2>&1)" =~ ^(Python 3.4.*) ]]; then
    sudo wget https://bootstrap.pypa.io/3.4/get-pip.py -O /tmp/get-pip.py
else
    sudo wget https://bootstrap.pypa.io/get-pip.py -O /tmp/get-pip.py
fi

python3 /tmp/get-pip.py
sudo pip3 install botocore

# Mount EFS file system
mkdir efs
mount -t efs -o tls ${aws_efs_file_system.efs.dns_name}:/ efs

# Install httpd and start service
yum update -y
yum install -y httpd.x86_64
systemctl start httpd.service
systemctl enable httpd.service
echo "Hello World from $(hostname -f)" > /var/www/html/index.html
echo "<h1>Deployed via Terraform</h1>" | sudo tee /var/www/html/index.html