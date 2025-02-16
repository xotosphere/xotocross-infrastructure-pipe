
####################### DATA

data "aws_vpc" "xtcross-vpc" {
  filter {
    name   = "tag:Name"
    values = ["${var.xtcross-cluster-name}"]
  }
}
