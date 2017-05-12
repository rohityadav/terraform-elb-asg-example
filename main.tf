provider "aws" {
  region = "us-east-1"
}

variable "apache_server_port" {
  default = "80"
}

resource "aws_launch_configuration" "example" {
  image_id = "ami-c58c1dd3"
  instance_type = "t2.micro"
  name = "terraform-example-lauchconfiguration"
  security_groups = ["${aws_security_group.instance.id}"]
  key_name = "test-ec2"

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    yum install httpd -y
    service httpd start
  EOF

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "example" {
  launch_configuration = "${aws_launch_configuration.example.id}"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  min_size = 2
  max_size = 2
  load_balancers = ["${aws_elb.example.name}"]
  health_check_type = "ELB"

  tag {
    key = "Name"
    value = "terraform-example-asg"
    propagate_at_launch = true
  }

}

data "aws_availability_zones" "all" {}

resource "aws_elb" "example" {
  name = "terraform-elb-example"
  availability_zones = ["${data.aws_availability_zones.all.names}"]
  security_groups = ["${aws_security_group.elb-instance.id}"]
  listener {
    instance_port = "${var.apache_server_port}"
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    interval = 30
    target = "TCP:${var.apache_server_port}"
    timeout = 3
  }
}

resource "aws_security_group" "elb-instance" {
  name = "terraform-sg-elb"

  ingress {
    from_port = "${var.apache_server_port}"
    to_port = "${var.apache_server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

variable "ssh_port" {
  default = "22"
}
resource "aws_security_group" "instance" {
  name = "terraform-sg-launchconfig"

  ingress {
    from_port = "${var.apache_server_port}"
    to_port = "${var.apache_server_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port = "${var.ssh_port}"
    to_port = "${var.ssh_port}"
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  lifecycle {create_before_destroy = true}
}

output "elb_dns_name" {
  value = "${aws_elb.example.dns_name}"
}