provider "aws" {
    region = var.AWS_REGION
    access_key = var.AWS_ACCESS_KEY
    secret_key = var.AWS_SECRET_KEY
}

# 1. create vpc
resource "aws_vpc" "production" {
  cidr_block    = "10.0.0.0/16"
  

  tags = {
    Name = "Production"
    }
}

# 2. create Internet Gateway

resource "aws_internet_gateway" "Production-IGW" {
  vpc_id = aws_vpc.production.id

  tags = {
    Name = "Production-IGW"
  }
}

# 3.creating 2 subnets in different region

resource "aws_subnet" "Production-subnet1" {
  vpc_id     = aws_vpc.production.id
  cidr_block = "10.0.0.0/23"
  availability_zone = "us-east-1a"

  tags = {
    Name = "Production-subnet1"
  }
}

resource "aws_subnet" "Production-subnet2" {
  vpc_id     = aws_vpc.production.id
  cidr_block = "10.0.2.0/23"
  availability_zone = "us-east-1b"

  tags = {
    Name = "Production-subnet2"
  }
}

# 4. create custom routing table

resource "aws_route_table" "Production-route-table" {
  vpc_id = aws_vpc.production.id

  route {
    # target
    cidr_block = "0.0.0.0/0"
    # destination
    gateway_id = aws_internet_gateway.Production-IGW.id
  }

  route {
    # target
    ipv6_cidr_block        = "::/0"
    # destination 
    gateway_id = aws_internet_gateway.Production-IGW.id
  }

  tags = {
    Name = "Production-route-table"
  }
}

# 5. Associate subnet with routing table

resource "aws_route_table_association" "RT_Association_with_Production-subnet1" {
  subnet_id      = aws_subnet.Production-subnet1.id
  route_table_id = aws_route_table.Production-route-table.id
}

resource "aws_route_table_association" "RT_Association_with_Production-subnet2" {
  subnet_id      = aws_subnet.Production-subnet2.id
  route_table_id = aws_route_table.Production-route-table.id
}

#6. create security group to allow port 443, 80, 20

resource "aws_security_group" "web-server-sg" {
  name        = "webserver-sg"
  description = "This SG is created for web-server"
  vpc_id      = aws_vpc.production.id

  ingress {
    description = "open to 443 (HTTPS) from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "open to 80 (HTTP) from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "open to ssh from anywhere"
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

  tags = {
    Name = "allow-web-traffic"
  }
}

#7. create Launch configuration for web servers

resource "aws_launch_configuration" "webserver-launchconfigs" {
  # name = "webserver-launchconfigs"

  image_id = "ami-02fe94dee086c0c37" # ubuntu 18.04 AMI in N.virginia region
  instance_type = "t2.micro"
  key_name = var.keypair

  security_groups = [ aws_security_group.web-server-sg.id ]
  associate_public_ip_address = true

  user_data = <<-EOF
              #!/bin/sh
              sudo apt-get update -y
              sudo apt-get install -y apache2
              sudo systemctl start apache2
              sudo systemctl enable apache2.service
              sudo echo "<html>
                         <h1>Hello world</h2>
                         <body>
                         <h3 id = "\"time\"">
                         <script>
                         document.getElementById("\"time\"").innerHTML = Date();
                         </script>
                         </h4>
                         </body>
                         </html>" > /var/www/html/index.html
                EOF

  lifecycle {
    create_before_destroy = true  # This option is set to true hence it will create new instance before destroying the old one
  }
}

#8. create Load balncer for web servers
    # -> creating SG for Load balancer
resource "aws_security_group" "Elb-sg" {
  name        = "Elb-sg"
  description = "This SG will allow the traffic to Ec2 instances through LoadBalancer"
  vpc_id      = aws_vpc.production.id

  ingress {
    description = "open to 80 (HTTP) from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    cidr_blocks     = ["0.0.0.0/0"]
  }

  tags = {
    Name = "security group for ELB"
  }
}
# creating Load balancer and associate with Loadbalancer SG

resource "aws_elb" "webserver-elb" {
  name = "webserver-elb"
  security_groups = [
    aws_security_group.Elb-sg.id
  ]
  subnets = [
    aws_subnet.Production-subnet1.id,
    aws_subnet.Production-subnet2.id
  ]

  cross_zone_load_balancing   = true
  tags = {
    Name = "elb for webserver"
  }
  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    interval = 30
    target = "HTTP:80/"
  }

  listener {
    lb_port = 80
    lb_protocol = "http"
    instance_port = "80"
    instance_protocol = "http"
  }

}

#9. creating Auto Scaling Group

resource "aws_autoscaling_group" "webserver-asg" {
  name = "webserver-asg"

  min_size             = 3
  desired_capacity     = 4
  max_size             = 5
  
  health_check_type    = "ELB"
  load_balancers = [
    aws_elb.webserver-elb.id
  ]

  launch_configuration = aws_launch_configuration.webserver-launchconfigs.name

  enabled_metrics = [
    "GroupMinSize",
    "GroupMaxSize",
    "GroupDesiredCapacity",
    "GroupInServiceInstances",
    "GroupTotalInstances"
  ]

  metrics_granularity = "1Minute"

  vpc_zone_identifier  = [
    aws_subnet.Production-subnet1.id,
    aws_subnet.Production-subnet2.id
  ]

  
  lifecycle {
    create_before_destroy = true  # This option is enabled so that it will create a new instance before deleting the old instance
  }

  tag {
    key                 = "Name"
    value               = "webserver"
    propagate_at_launch = true
  }

}


# in order to dynamically upscale or downscale the infrastructure(ec2 instances) 
# we need to create Auto-scaling policies and some metrics with the cloud watch alaram


#10 creating Autoscaling Policies

# Autoscaling policies for scaling-up the instances

resource "aws_autoscaling_policy" "webserver_scaleup_policy" {
  name = "webserver_scaleup_policy"
  scaling_adjustment = 1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.webserver-asg.name
}

# creating alaram for scale up based on cpu utilization

resource "aws_cloudwatch_metric_alarm" "websever_scaleup_cpualaram" {
  alarm_name = "websever_scaleup_cpualaram"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "50"
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  #alarm_actions = [ aws_autoscaling_policy.webserver_scaleup_policy.arn ]
  alarm_actions = [ aws_sns_topic.sns_topic.arn, aws_autoscaling_policy.webserver_scaleup_policy.arn ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webserver-asg.name
  }
}

# Autoscaling policies for scaledown the instances

resource "aws_autoscaling_policy" "webserver_scaledown_policy" {
  name = "webserver_scaledown_policy"
  scaling_adjustment = -1
  adjustment_type = "ChangeInCapacity"
  cooldown = 300
  autoscaling_group_name = aws_autoscaling_group.webserver-asg.name
}

# creating alaram for scale down based on cpu utilization

resource "aws_cloudwatch_metric_alarm" "websever_scaledown_cpualaram" {
  alarm_name = "websever_scaledown_cpualaram"
  comparison_operator = "LessThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "CPUUtilization"
  namespace = "AWS/EC2"
  period = "120"
  statistic = "Average"
  threshold = "20"
  alarm_description = "This metric monitor EC2 instance CPU utilization"
  #alarm_actions = [ aws_autoscaling_policy.webserver_scaledown_policy.arn ]
  alarm_actions = [ aws_sns_topic.sns_topic.arn, aws_autoscaling_policy.webserver_scaledown_policy.arn ]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.webserver-asg.name
  }
}

#creating sns topic and email subscription to monitor healthy targets throuugh load balancer

resource "aws_sns_topic" "sns_topic" {
    name = "Hello-world_sns_topic"

    provisioner "local-exec" {
        command = "aws --no-verify-ssl sns subscribe --topic-arn ${self.arn} --protocol ${var.protocol} --notification-endpoint ${var.notification_endpoint}"
    }
}

resource "aws_sns_topic_policy" "sns_topic_policy" {
  arn = aws_sns_topic.sns_topic.arn

  policy = <<POLICY
{
    "Version": "2012-10-17",
    "Id": "default",
    "Statement":[{
      "Sid": "AllowToPublish",
      "Effect": "Allow",
      "Principal": {
        "AWS": "*"
      },
      "Action": "SNS:Publish",
      "Resource": "${aws_sns_topic.sns_topic.arn}"    
    }]
}
POLICY
}
resource "aws_cloudwatch_metric_alarm" "elb_healthyhosts" {
  alarm_name          = "elb_healthyhosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/NetworkELB"
  period              = "60"
  statistic           = "Average"
  threshold           = 3
  alarm_description   = "Number of healthy nodes in Target Group"
  actions_enabled     = "true"
  alarm_actions       = [aws_sns_topic.sns_topic.arn]
  ok_actions          = [aws_sns_topic.sns_topic.arn]
  dimensions = {
    LoadBalancer = aws_elb.webserver-elb.arn
  }
}



# getting the output values of launch-configuration,autoscaling-group,auto-scaling-policy-scale-up/scale-down,ElasticLoadBalancer_DNS_Name to validate the infra setup

output "launch-configuration" {
  value = aws_launch_configuration.webserver-launchconfigs.name
}

output "autoscaling-group" {
  value = aws_autoscaling_group.webserver-asg.name
}

output "auto-scaling-policy-scale-up" {
  value = aws_autoscaling_policy.webserver_scaleup_policy.name
}

output "auto-scaling-policy-scale-down" {
  value = aws_autoscaling_policy.webserver_scaledown_policy.name
}

output "ElasticLoadBalancer_DNS_Name" {
  value = aws_elb.webserver-elb.dns_name
}

output "SNS_Notifications_email" {
  value = var.notification_endpoint
}