provider "aws" {
  region = "eu-west-3"  # You can change this to your preferred region
}

# Data source to fetch the existing Route53 zone
data "aws_route53_zone" "selected" {
  name         = "monservice.com."  # Replace with your domain name, don't forget the trailing dot
  private_zone = false
}

# Data source to get information about the first instance
data "aws_instance" "web1" {
  filter {
    name   = "tag:Name"
    values = ["Web Server 1"]
  }
  filter {
    name = "instance-state-name"
    values = ["running", "pending", "rebooting", "stopping", "stopped"]
  }
  
}

# Data source to get information about the second instance
data "aws_instance" "web2" {
  filter {
    name   = "tag:Name"
    values = ["Web Server 2"]
  }
  filter {
    name = "instance-state-name"
    values = ["running", "pending", "rebooting", "stopping", "stopped"]
  }
}

# Data source to get information about the third instance
data "aws_instance" "web3" {
  filter {
    name   = "tag:Name"
    values = ["Web Server 3"]
  }
  filter {
    name = "instance-state-name"
    values = ["running", "pending", "rebooting", "stopping", "stopped"]
  }
}

# Create A record with weighted routing policy for the first IP
resource "aws_route53_record" "www_1" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "onprem.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "1"
  records = [data.aws_instance.web1.public_ip]
  set_identifier = "web_1"
  weighted_routing_policy {
    weight = 50
  }
  health_check_id = aws_route53_health_check.web1.id
}

# Create A record with weighted routing policy for the second IP
resource "aws_route53_record" "www_2" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "onprem.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "1"
  records = [data.aws_instance.web2.public_ip]
  set_identifier = "web_2"
  weighted_routing_policy {
    weight = 50
  }
  health_check_id = aws_route53_health_check.web2.id
}

# Create A record with weighted routing policy for the second IP
resource "aws_route53_record" "www_3" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "dr.${data.aws_route53_zone.selected.name}"
  type    = "A"
  ttl     = "1"
  records = [data.aws_instance.web3.public_ip]
}


# Health check for the first IP
resource "aws_route53_health_check" "web1" {
  ip_address      = data.aws_instance.web1.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "10"

  tags = {
    Name = "health-check-web1"
  }
}

# Health check for the second IP
resource "aws_route53_health_check" "web2" {
  ip_address      = data.aws_instance.web2.public_ip
  port              = 80
  type              = "HTTP"
  resource_path     = "/"
  failure_threshold = "3"
  request_interval  = "10"

  tags = {
    Name = "health-check-web2"
  }
}

# Calculated health check based on the two other health checks
resource "aws_route53_health_check" "calculated" {
  type                   = "CALCULATED"
  child_health_threshold = 1
  child_healthchecks     = [
    aws_route53_health_check.web1.id,
    aws_route53_health_check.web2.id
  ]

  tags = {
    Name = "health-check-calculated"
  }
}

# Create the failover CNAME record (primary)
resource "aws_route53_record" "failover_primary" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www.${data.aws_route53_zone.selected.name}"
  type    = "CNAME"
  ttl     = "1"
  records = ["onprem.${data.aws_route53_zone.selected.name}"]

  failover_routing_policy {
    type = "PRIMARY"
  }

  set_identifier = "primary"
  health_check_id = aws_route53_health_check.calculated.id
}

# Create the failover CNAME record (secondary)
resource "aws_route53_record" "failover_secondary" {
  zone_id = data.aws_route53_zone.selected.zone_id
  name    = "www.${data.aws_route53_zone.selected.name}"
  type    = "CNAME"
  ttl     = "1"
  records = ["dr.${data.aws_route53_zone.selected.name}"]

  failover_routing_policy {
    type = "SECONDARY"
  }

  set_identifier = "secondary"
}
