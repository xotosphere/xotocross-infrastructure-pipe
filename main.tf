####################### PROVIDER

terraform {
  backend "s3" {}
}

####################### VARIABLE

variable "region" { default = "eu-west-3" }
variable "environment" { default = "staging" }
variable "xtcross-account-id" {}
variable "xtcross-container-portlist" { default = "80,8081" } 
variable "xtcross-host-portlist" { default = "8080,8081" } 
variable "xtcross-cluster-name" { default = "xtcross-staging-ecs" }
variable "xtcross-organization" { default = "xotosphere" }
variable "xtcross-domain-name" { default = "xotosphere" }
variable "xtcross-service-name" { default = "demo" }
variable "xtcross-service-version" {}
variable "xtcross-healthcheck-interval" { default = 60 }
variable "xtcross-password" {}
variable "xtcross-enable-monitor" { default = false }
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
  xtcross-container-portlist-decoded = split(",", var.xtcross-container-portlist)
  xtcross-host-portlist-decoded = split(",", var.xtcross-host-portlist)
  
  xtcross-container-front = jsondecode(templatefile("${path.module}/aws/task-container.tpl", {
    xtcross-container-name                  = "xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}front"
    xtcross-container-image                 = "ghcr.io/${var.xtcross-organization}/${var.xtcross-service-name}-${var.xtcross-service-name}front:latest"
    xtcross-container-cpu                   = 128
    xtcross-container-memory                = 256
    xtcross-container-essential             = true
    xtcross-container-portmap               = jsonencode([{ containerPort = local.xtcross-container-portlist-decoded[0], hostPort = local.xtcross-host-portlist-decoded[0], protocol = "tcp" }])
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
    xtcross-container-portmap               = jsonencode([{ containerPort = local.xtcross-container-portlist-decoded[1], hostPort = local.xtcross-host-portlist-decoded[1], protocol = "tcp" }])
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

  xtcross-container-definition = [local.xtcross-container-front, local.xtcross-container-back]
  xtcross-healthcheck-pathlist = ["/", "/item-list"]
  xtcross-listener-hostlist = [
    "${var.xtcross-service-name}front-${var.xtcross-service-name}.${var.environment}.${var.xtcross-domain-name}.com",
    "${var.xtcross-service-name}back-${var.xtcross-service-name}.${var.environment}.${var.xtcross-domain-name}.com"
  ]
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
  xtcross-container-portlist = [for port in local.xtcross-container-portlist-decoded : jsondecode(port)]
  xtcross-host-portlist = [for port in local.xtcross-host-portlist-decoded : jsondecode(port)]
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
  xtcross-task-count      = 1
  xtcross-service-name    = "xtcross-${var.xtcross-service-name}-${var.environment}-service"
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
  container_name_list = [
    "xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}front",
    "xtcross-${var.xtcross-service-name}-${var.xtcross-service-name}back"
  ]
}

