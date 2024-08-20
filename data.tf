
####################### DATA

data "aws_vpc" "xtcross-vpc" {
  filter {
    name   = "tag:Name"
    values = ["xtcross-${var.environment}-vpc"]
  }
}

data "aws_security_group" "xtcross-securitygroup" {
  vpc_id = data.aws_vpc.xtcross-vpc.id
  filter {
    name   = "tag:Name"
    values = ["xtcross-${var.environment}-securitygroup-${var.xtcross-vpn-security == "public" ? "public" : "private"}"]
  }
}

data "aws_subnets" "xtcross-public-subnetlist" {
  filter {
    name   = "tag:Name"
    values = ["xtcross-${var.environment}-public-subnet-0", "xtcross-${var.environment}-public-subnet-1"]
  }
}

data "aws_subnets" "xtcross-private-subnetlist" {
  filter {
    name   = "tag:Name"
    values = ["xtcross-${var.environment}-private-subnet-0", "xtcross-${var.environment}-private-subnet-1"]
  }
}

data "aws_iam_role" "xtcross-lambda-role" {
  name = "xtcross-${var.environment}-lambda-role"
}