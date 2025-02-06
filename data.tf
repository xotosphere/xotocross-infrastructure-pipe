
####################### DATA

data "aws_vpc" "xtcross-vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.xtcross-cluster-name}"]
  }
}

data "aws_security_group" "xtcross-securitygroup" {
  vpc_id = data.aws_vpc.xtcross-vpc.id
  filter {
    name   = "tag:Name"
    values = ["${var.xtcross-cluster-name}-${var.xtcross-vpn-security == "public" ? "public" : "private"}"]
  }
}

data "aws_subnets" "xtcross-public-subnetlist" {
  filter {
    name   = "tag:Name"
    values = ["${var.xtcross-cluster-name}-public-0", "${var.xtcross-cluster-name}-public-1"]
  }
}

data "aws_subnets" "xtcross-private-subnetlist" {
  filter {
    name   = "tag:Name"
    values = ["${var.xtcross-cluster-name}-private-0", "${var.xtcross-cluster-name}-private-1"]
  }
}

data "aws_iam_role" "xtcross-lambda-role" {
  name = "${var.xtcross-cluster-name}-lambda-role"
}
