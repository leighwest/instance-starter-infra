provider "aws" {
  access_key = var.aws_access_key_id
  secret_key = var.aws_secret_access_key
  region     = var.aws_region
}

# -------------------------------------------------
# Security Group
# -------------------------------------------------
resource "aws_security_group" "toy_instances" {
  name        = "instance-starter-toy-sg"
  description = "Allow HTTP and SSH inbound for toy EC2 instances"

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

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
}

# -------------------------------------------------
# User Data Script
# -------------------------------------------------
locals {
  user_data = <<-EOF
    #!/bin/bash
    apt-get update -y
    apt-get install -y nginx curl

    TOKEN=$(curl -s -X PUT "http://169.254.169.254/latest/api/token" \
      -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
    INSTANCE_ID=$(curl -s -H "X-aws-ec2-metadata-token: $TOKEN" \
      http://169.254.169.254/latest/meta-data/instance-id)

    cat > /var/www/html/index.html << HTML
    <!DOCTYPE html>
    <html>
    <head>
      <title>Instance Ready</title>
      <style>
        body {
          font-family: sans-serif;
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
          background: #0f172a;
          color: #f8fafc;
        }
        .card {
          text-align: center;
          padding: 2rem 3rem;
          border: 1px solid #334155;
          border-radius: 8px;
        }
        .instance-id {
          font-family: monospace;
          color: #38bdf8;
          font-size: 1.2rem;
        }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>Instance Ready</h1>
        <p class="instance-id">$INSTANCE_ID</p>
      </div>
    </body>
    </html>
    HTML

    systemctl enable nginx
    systemctl start nginx
  EOF
}

# -------------------------------------------------
# EC2 Instances
# -------------------------------------------------

resource "aws_instance" "toy_1" {
  ami                    = "ami-04e2077861e65d984"
  instance_type          = "t3.nano"
  vpc_security_group_ids = [aws_security_group.toy_instances.id]
  user_data              = local.user_data
  key_name               = "instance-starter-deploy"

  tags = {
    Name = "toy-instance-1"
    Role = "instance-starter-toy"
  }
}

resource "aws_instance" "toy_2" {
  ami                    = "ami-04e2077861e65d984"
  instance_type          = "t3.nano"
  vpc_security_group_ids = [aws_security_group.toy_instances.id]
  user_data              = local.user_data
  key_name               = "instance-starter-deploy"

  tags = {
    Name = "toy-instance-2"
    Role = "instance-starter-toy"
  }
}

resource "time_sleep" "wait_for_user_data" {
  depends_on      = [aws_instance.toy_1, aws_instance.toy_2]
  create_duration = "360s"
}

resource "null_resource" "stop_instances" {
  depends_on = [time_sleep.wait_for_user_data]

  provisioner "local-exec" {
    command = "aws ec2 stop-instances --instance-ids ${aws_instance.toy_1.id} ${aws_instance.toy_2.id} --region ${var.aws_region}"
    environment = {
      AWS_ACCESS_KEY_ID     = var.aws_access_key_id
      AWS_SECRET_ACCESS_KEY = var.aws_secret_access_key
    }
  }
}