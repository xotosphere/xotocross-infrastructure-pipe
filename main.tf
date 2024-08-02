####################### PROVIDER

terraform {
  backend "s3" {}
}

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
variable "xtcross-healthcheck-interval" {}
variable "xtcross-password" {}
variable "xtcross-path-list" {}
variable "xtcross-enable-monitor" {}
variable "xtcross-enable-front" {}
variable "xtcross-enable-back" {}
variable "xtcross-username" {}

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
    values = ["xtcross-${var.environment}-securitygroup"]
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

####################### LOCAL

locals {
  xtcross-container-portlist-array = [for port in split(",", var.xtcross-container-portlist) : tonumber(port)]
  xtcross-host-portlist-array      = [for port in split(",", var.xtcross-host-portlist) : tonumber(port)]
  xtcross-path-list-array      = [for port in split(",", var.xtcross-path-list) : port]
  
  xtcross-container-front = jsondecode(templatefile("${path.module}/aws/task-container.tpl", {
    xtcross-container-name                  = "xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}front"
    xtcross-container-image                 = "ghcr.io/${var.xtcross-organization}/${var.xtcross-service-name}-${var.xtcross-service-name}front:latest"
    xtcross-container-cpu                   = 128
    xtcross-container-memory                = 256
    xtcross-container-essential             = true
    xtcross-container-portmap               = jsonencode([{ containerPort = local.xtcross-container-portlist-array[0], hostPort = local.xtcross-host-portlist-array[0], protocol = "tcp" }])
    xtcross-container-environment           = jsonencode([{ name = "environment", value = var.environment }, { name = "BACKEND_URL", value = "https://demoback-${var.xtcross-service-name}.${var.environment}.${var.xtcross-domain-name}.com" }])
    xtcross-container-loggroup              = "/aws/ecs/xtcross-${var.xtcross-service-name}-${var.environment}-log"
    xtcross-container-region                = var.region
    xtcross-container-command               = jsonencode([])
    xtcross-container-dependency            = jsonencode([])
    xtcross-container-entrypoint            = jsonencode([])
    xtcross-container-firelensconfiguration = "null"
    xtcross-container-healthcheck           = "null"
    xtcross-container-mountpoint            = jsonencode([])
  }))

  xtcross-container-back = jsondecode(templatefile("${path.module}/aws/task-container.tpl", {
    xtcross-container-name                  = "xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}back"
    xtcross-container-image                 = "ghcr.io/${var.xtcross-organization}/${var.xtcross-service-name}-${var.xtcross-service-name}back:latest"
    xtcross-container-cpu                   = 128
    xtcross-container-memory                = 256
    xtcross-container-essential             = true
    xtcross-container-portmap               = jsonencode([{ containerPort = local.xtcross-container-portlist-array[1], hostPort = local.xtcross-host-portlist-array[1], protocol = "tcp" }])
    xtcross-container-environment           = jsonencode([{ name = "environment", value = var.environment }])
    xtcross-container-loggroup              = "/aws/ecs/xtcross-${var.xtcross-service-name}-${var.environment}-log"
    xtcross-container-region                = var.region
    xtcross-container-command               = jsonencode([])
    xtcross-container-dependency            = jsonencode([])
    xtcross-container-entrypoint            = jsonencode([])
    xtcross-container-firelensconfiguration = "null"
    xtcross-container-healthcheck           = "null"
    xtcross-container-mountpoint            = jsonencode([])
  }))

  xtcross-container-definition = concat(tobool(var.xtcross-enable-front) ? [local.xtcross-container-front] : [], tobool(var.xtcross-enable-back) ? [local.xtcross-container-back] : [])
  xtcross-healthcheck-pathlist = local.xtcross-path-list-array
  xtcross-listener-hostlist = concat(
    tobool(var.xtcross-enable-front) ? ["${var.xtcross-service-name}front-${var.xtcross-service-name}.${var.environment}.${var.xtcross-domain-name}.com"] : [],
    tobool(var.xtcross-enable-back) ? ["${var.xtcross-service-name}back-${var.xtcross-service-name}.${var.environment}.${var.xtcross-domain-name}.com"] : []
  )
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
  xtcross-container-definition = local.xtcross-container-definition
  xtcross-healthcheck-pathlist = local.xtcross-healthcheck-pathlist
  xtcross-listener-hostlist    = local.xtcross-listener-hostlist
  xtcross-container-portlist   = [for port in local.xtcross-container-portlist-array : jsondecode(port)]
  xtcross-host-portlist        = [for port in local.xtcross-host-portlist-array : jsondecode(port)]
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
  xtcross-healthcheck-interval      = var.xtcross-healthcheck-interval
  xtcross-domain-name               = var.xtcross-domain-name
  xtcross-healthcheck-pathlist      = module.fluentbit.xtcross-healthcheck-pathlist
  xtcross-healthcheck-timeout       = floor(var.xtcross-healthcheck-interval / 2)
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
  xtcross-listener-hostlist = local.xtcross-listener-hostlist
}

module "scheduletask" {
  source                  = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/scheduletask"
  environment             = var.environment
  xtcross-lambda-role-arn = data.aws_iam_role.xtcross-lambda-role.arn
  xtcross-function-name   = "xtcross-${var.xtcross-service-name}-${var.environment}-scheduletask"
}

module "grafana" {
  source               = "github.com/xotosphere/xotocross-infrastructure-ecs//modules/cross/grafana"
  environment          = var.environment
  xtcross-service-name = var.xtcross-service-name
  xtcross-domain-name  = var.xtcross-domain-name
  xtcross-password     = var.xtcross-password
  xtcross-username     = var.xtcross-username
  xtcross-container-namelist = concat(
    tobool(var.xtcross-enable-front) ? ["xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}front"] : [],
    tobool(var.xtcross-enable-back) ? ["xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}back"] : []
  )
}

