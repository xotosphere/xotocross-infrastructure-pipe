####################### VARIABLE

variable "region" {}
variable "environment" {}
variable "xtcross-account-id" {}
variable "xtcross-container-portlist" {}
variable "xtcross-host-portlist" {}
variable "xtcross-cluster-name" {}
variable "xtcross-organization" {}
variable "xtcross-domain-name" {}
variable "xtcross-service-name" {}
variable "xtcross-service-version" {}
variable "xtcross-password" {}
variable "xtcross-enable-monitor" {}
variable "xtcross-username" {}
variable "xtcross-container-definition" {}
variable "xtcross-healthcheck-pathlist" {}
variable "xtcross-listener-hostlist" {}
variable "xtcross-vpn-security" {}

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

####################### MODULE

module "fluentbit" {
  source                       = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/cross/fluentbit"
  region                       = var.region
  environment                  = var.environment
  xtcross-service-version      = var.xtcross-service-version
  xtcross-service-name         = var.xtcross-service-name
  xtcross-enable-monitor       = tobool(var.xtcross-enable-monitor)
  xtcross-domain-name          = var.xtcross-domain-name
  xtcross-container-definition = var.xtcross-container-definition
  xtcross-healthcheck-pathlist = var.xtcross-healthcheck-pathlist
  xtcross-listener-hostlist    = var.xtcross-listener-hostlist
  xtcross-container-portlist   = var.xtcross-container-portlist
  xtcross-host-portlist        = var.xtcross-host-portlist
}

module "elb" {
  source                            = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/elb"
  environment                       = var.environment
  region                            = var.region
  xtcross-loadbalaner-name          = "xtcross-${var.xtcross-service-name}-${var.environment}-lb"
  xtcross-host-portlist             = module.fluentbit.xtcross-host-portlist
  xtcross-listener-portlist         = module.fluentbit.xtcross-host-portlist
  xtcross-listener-hostlist         = module.fluentbit.xtcross-listener-hostlist
  xtcross-targetgroup-name          = "xtcross-${var.xtcross-service-name}-${var.environment}-tg"
  xtcross-target-type               = "instance"
  xtcross-healthy-threshhold        = 3
  xtcross-loadbalaner-securitygroup = data.aws_security_group.xtcross-securitygroup.id
  xtcross-vpc-id                    = data.aws_vpc.xtcross-vpc.id
  xtcross-public-subnetlist         = data.aws_subnets.xtcross-public-subnetlist.ids
  xtcross-private-subnetlist        = data.aws_subnets.xtcross-private-subnetlist.ids
  xtcross-unhealthy-threshhold      = 5
  xtcross-healthcheck-interval      = 60
  xtcross-domain-name               = var.xtcross-domain-name
  xtcross-healthcheck-pathlist      = module.fluentbit.xtcross-healthcheck-pathlist
  xtcross-healthcheck-timeout       = floor(60 / 2)
}

module "service" {
  source                        = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/service"
  region                        = var.region
  environment                   = var.environment
  xtcross-cluster-name          = var.xtcross-cluster-name
  xtcross-task-family           = "xtcross-${var.xtcross-service-name}-${var.environment}-task"
  xtcross-container-definition  = module.fluentbit.xtcross-container-definition
  xtcross-service-name          = var.xtcross-service-name
  xtcross-desired-count         = 1
  xtcross-deployment-max        = 100
  xtcross-deployment-min        = 0
  xtcross-container-port        = module.fluentbit.xtcross-container-portlist
  xtcross-targetgroup-arnlist   = values(module.elb.xtcross-targetgroup-arnlist)
  xtcross-constraint-placement  = "memberOf"
  xtcross-constraint-expression = "attribute:ecs.availability-zone in [${var.region}a, ${var.region}b]"
  xtcross-execution-role-arn    = "arn:aws:iam::${var.xtcross-account-id}:role/xtcross-${var.environment}-execution-role"
  xtcross-task-role-arn         = "arn:aws:iam::${var.xtcross-account-id}:role/xtcross-${var.environment}-execution-role"
  xtcross-network-mode          = "bridge"
  xtcross-healthcheck-grace     = 60
  xtcross-listener-hostlist     = module.fluentbit.xtcross-listener-hostlist
  xtcross-task-memory           = 512
}

module "cloudwatch" {
  source                     = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/cloudwatch"
  environment                = var.environment
  xtcross-ecs-loggroup-name  = "/aws/ecs/xtcross-${var.xtcross-service-name}-${var.environment}-log"
  xtcross-loggroup-retention = 7
}

module "route53" {
  source                    = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/route53"
  environment               = var.environment
  xtcross-domain-name       = var.xtcross-domain-name
  xtcross-loadbalaner-name  = module.elb.xtcross-loadbalaner-name
  xtcross-listener-hostlist = var.xtcross-listener-hostlist
}

module "scheduletask" {
  source                  = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/scheduletask"
  environment             = var.environment
  xtcross-lambda-role-arn = data.aws_iam_role.xtcross-lambda-role.arn
  xtcross-function-name   = "xtcross-${var.xtcross-service-name}-${var.environment}-scheduletask"
}

module "grafana" {
  source                     = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/cross/grafana"
  environment                = var.environment
  xtcross-service-name       = var.xtcross-service-name
  xtcross-domain-name        = var.xtcross-domain-name
  xtcross-enable-monitor     = tobool(var.xtcross-enable-monitor)
  xtcross-password           = var.xtcross-password
  xtcross-username           = var.xtcross-username
  xtcross-container-namelist = ["xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}front", "xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}back"]
}

