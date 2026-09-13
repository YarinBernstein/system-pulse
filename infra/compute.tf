# -----------------------------------------------------------------------
# Always use the latest official Amazon Linux 2023 image, looked up
# automatically instead of a hardcoded AMI ID (which differs per region
# and goes stale over time).
# -----------------------------------------------------------------------
data "aws_ssm_parameter" "al2023_ami" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64"
}

# -----------------------------------------------------------------------
# Lets the backend server ship its logs to CloudWatch Logs, and nothing
# else - least privilege for the one thing it actually needs to do.
# -----------------------------------------------------------------------
resource "aws_iam_role" "backend" {
  name = "${var.project_name}-backend-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "backend_logs" {
  name = "${var.project_name}-backend-logs-policy"
  role = aws_iam_role.backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "arn:aws:logs:${var.aws_region}:*:log-group:/system-pulse/*"
    }]
  })
}

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project_name}-backend-profile"
  role = aws_iam_role.backend.name
}

# -----------------------------------------------------------------------
# The NAT instance: a small, hand-configured router. Its only job is to
# let the private subnet reach the internet at boot time, replacing
# AWS's managed "NAT Gateway" (a fixed ~$32/month charge) with a normal
# free-tier-eligible server doing the same job.
# -----------------------------------------------------------------------
resource "aws_instance" "nat" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.nat.id]
  source_dest_check           = false # required for any instance that routes traffic on behalf of others
  user_data                   = file("${path.module}/scripts/nat-init.sh")
  user_data_replace_on_change = true # a changed boot script should always mean a fresh instance

  tags = { Name = "${var.project_name}-nat" }
}

resource "aws_route" "private_default" {
  route_table_id         = aws_route_table.private.id
  destination_cidr_block = "0.0.0.0/0"
  network_interface_id   = aws_instance.nat.primary_network_interface_id
}

# -----------------------------------------------------------------------
# Redis: private subnet, official image, nothing custom to build.
# -----------------------------------------------------------------------
resource "aws_instance" "redis" {
  ami                         = data.aws_ssm_parameter.al2023_ami.value
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.private.id
  vpc_security_group_ids      = [aws_security_group.redis.id]
  user_data                   = file("${path.module}/scripts/redis-init.sh")
  user_data_replace_on_change = true

  depends_on = [aws_route.private_default]

  tags = { Name = "${var.project_name}-redis" }
}

# -----------------------------------------------------------------------
# Backend: private subnet, built from this repo's backend/ folder at
# boot, wired up to Redis's private IP and to CloudWatch Logs.
# -----------------------------------------------------------------------
resource "aws_instance" "backend" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.private.id
  vpc_security_group_ids = [aws_security_group.backend.id]
  iam_instance_profile   = aws_iam_instance_profile.backend.name

  user_data = templatefile("${path.module}/scripts/backend-init.sh.tpl", {
    github_repo_url  = var.github_repo_url
    redis_private_ip = aws_instance.redis.private_ip
    aws_region       = var.aws_region
  })
  user_data_replace_on_change = true

  depends_on = [aws_route.private_default]

  tags = { Name = "${var.project_name}-backend" }
}

# -----------------------------------------------------------------------
# Frontend: public subnet, the only server reachable from the internet.
# Proxies /api/ calls to the backend's private address so the backend
# itself never has to face the internet.
# -----------------------------------------------------------------------
resource "aws_instance" "frontend" {
  ami                    = data.aws_ssm_parameter.al2023_ami.value
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.frontend.id]

  user_data = templatefile("${path.module}/scripts/frontend-init.sh.tpl", {
    github_repo_url = var.github_repo_url
    nginx_conf = templatefile("${path.module}/scripts/nginx-proxy.conf.tpl", {
      backend_private_ip = aws_instance.backend.private_ip
    })
  })
  user_data_replace_on_change = true

  tags = { Name = "${var.project_name}-frontend" }
}
