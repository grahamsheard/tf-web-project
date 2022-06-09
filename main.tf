### EFS file system and mount target ###

resource "aws_efs_file_system" "efs" {

  tags = {
    Name = "${local.name}-efs"
  }
}

resource "aws_security_group" "efs_sg" {
  name        = "${local.name}-efs-sg"
  description = "Allow Traffic for EFS Mount Target"
  vpc_id      = module.vpc.vpc_id

    ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
  }

  egress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-efs-sg"
  }

}

resource "aws_efs_mount_target" "efs_target" {
  count          = length(module.vpc.private_subnets)
  file_system_id = aws_efs_file_system.efs.id
  subnet_id      = element(module.vpc.private_subnets, count.index)
  security_groups = [aws_security_group.efs_sg.id]
}

### ALB ###

resource "aws_alb" "this" {
  name               = "${local.name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.alb.id]

  enable_deletion_protection = true

  tags = {
    Name = "${local.name}-alb"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_alb_listener" "http" {
  load_balancer_arn = aws_alb.this.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "forward"
  }
}

resource "aws_alb_listener_rule" "alb_rule" {
  listener_arn = aws_alb_listener.http.arn

  action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.target_group.arn
  }

  condition {
    host_header {
      values = ["web-app-project.domain.com"]
    }
  }

  tags = {
    Name = "${local.name}-alb-rule"
  }
}

resource "aws_alb_target_group" "target_group" {
  name     = "${local.name}-lb-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id

  tags = {
    Name = "${local.name}-alb"
  }
}

resource "aws_security_group" "alb" {
  name        = "loadbalancer"
  description = "Allow Traffic for Load Balancer"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-alb-sg"
  }
}

### ASG ###
resource "aws_autoscaling_group" "asg" {
  name_prefix = "${local.name}-asg"
  desired_capacity   = 2
  max_size           = 10
  min_size           = 2
  vpc_zone_identifier  = module.vpc.private_subnets
 
  target_group_arns = [aws_alb_target_group.target_group.arn]

  health_check_type = "EC2"
   
  # Launch Template
  launch_template {
    id      = aws_launch_template.launch_template.id
    version = aws_launch_template.launch_template.latest_version
  }

  # Instance Refresh
  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
    }
    triggers = [ "desired_capacity" ]
  }  
    
}

resource "aws_security_group" "asg" {
  name        = "${local.name}-asg-sg"
  description = "Allow Traffic for asg instances"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

    ingress {
    description = "NFS"
    from_port   = 2049
    to_port     = 2049
    protocol    = "tcp"
    security_groups = [aws_security_group.efs_sg.id]
  }

  egress {
    description = "All Traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${local.name}-asg-sg"
  }
}

### Launch Template ###

resource "aws_launch_template" "launch_template" {
  name = "${local.name}-lt"
  description = "${local.name}-Launch Template"

  image_id = data.aws_ami.amzlinux2.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.asg.id] 

  # user_data = file("${path.module}/install.sh")

  user_data = <<-EOF
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
  EOF

  ebs_optimized = true
  update_default_version = true

  block_device_mappings {
    device_name = "/dev/sda1"
    ebs {
      volume_size = 10     
      delete_on_termination = true
      volume_type = "gp2"
     }

  }
  monitoring {
    enabled = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "${local.name}-lt"
    }
  }
}

### RDS Database ###

resource "aws_db_instance" "rds" {
  allocated_storage    = 20
  engine               = "postgres"
  engine_version       = "13.4"
  instance_class       = "db.t3.micro"
  username             = "admin"
  password             = random_password.this.result
  
  db_subnet_group_name = module.vpc.database_subnet_group_name

  tags = {
    Name = "${local.name}-rds-db"
  }
}

resource "aws_security_group" "rds" {
  name        = "${local.name}-postgres"
  description = "Allow postgres traffic from private subnets"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 5432
    to_port     = 5432
    protocol    = "tcp"
    cidr_blocks = module.vpc.private_subnets_cidr_blocks
    description = "Allow postgres traffic"
  }

  tags = {
    Name = "${local.name}-rds-sg"
  }

}

resource "random_password" "this" {
  length  = 16
  special = false
}

resource "aws_secretsmanager_secret" "this" {
  name                    = lower("${var.environment_name}/rds/${var.environment_type}/password")
  description             = "${local.name} Password"
  recovery_window_in_days = 0

  tags = {
    Name = "${local.name}-rds-password"
  }
}

###  CloudWatch ALB alarm ###

resource "aws_cloudwatch_metric_alarm" "Test_Alarm" {
  alarm_name          = "ALB_Alarm"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "1"
  metric_name         = "RequestCount"
  namespace           = "AWS/ApplicationELB"
  period              = "60"
  statistic           = "Sum"
  threshold           = "5"
  alarm_description   = "Test_Alarm_ALB"
  treat_missing_data  = "notBreaching"
  alarm_actions       = ["${aws_sns_topic.sns_topic.arn}"]
  ok_actions          = ["${aws_sns_topic.sns_topic.arn}"]
  dimensions = {
    LoadBalancer = aws_alb.this.arn_suffix
  }
}

# SNS Topic for Errors
resource "aws_sns_topic" "sns_topic" {
  name = "${local.name}-sns_topic"
}

resource "aws_sns_topic_policy" "notify_policy" {
  arn    = aws_sns_topic.sns_topic.arn
  policy = data.aws_iam_policy_document.notify_policy.json
}

