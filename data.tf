
####################### DATA

data "aws_vpc" "xtcross-vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-${var.environment}"]
  }
}

data "aws_security_group" "xtcross-securitygroup" {
  vpc_id = data.aws_vpc.xtcross-vpc.id
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-${var.environment}-${var.xtcross-vpn-security == "public" ? "public" : "private"}"]
  }
}

data "aws_subnets" "xtcross-public-subnetlist" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-${var.environment}-public-0", "${var.prefix}-${var.environment}-public-1"]
  }
}

data "aws_subnets" "xtcross-private-subnetlist" {
  filter {
    name   = "tag:Name"
    values = ["${var.prefix}-${var.environment}-private-0", "${var.prefix}-${var.environment}-private-1"]
  }
}

data "aws_iam_role" "xtcross-lambda-role" {
  name = "${var.prefix}-${var.environment}-lambda-role"
}
