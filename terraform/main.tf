data "aws_vpc" "selected" {
  filter {
    name   = "tag:Name"
    values = ["Default VPC"]
  }
}

data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.selected.id]
  }
}

resource "aws_ecrpublic_repository" "demo-repository" {
  name                 = "container-ecr"
  # image_tag_mutability = "IMMUTABLE"
}

resource "aws_ecrpublic_repository_policy" "demo-repo-policy" {
    repository_name =  = aws_ecrpublic_repository.demo-repository.name

}

module "ecs" {
  source = "terraform-aws-modules/ecs/aws"

  cluster_name = "wang2-ecs-tf" #Change

  fargate_capacity_providers = {
    FARGATE = {
      default_capacity_provider_strategy = {
        weight = 100
      }
    }
  }

  services = {
    wang2-service = { #task def and service name -> #Change
      cpu    = 512
      memory = 1024

      # Container definition(s)
      container_definitions = {

        ecs-sample = { #container name
          essential = true
          image     = "public.ecr.aws/u2q1a2y8/${aws_ecr_repository.demo-repository.name}/simple-app:1.0"
          port_mappings = [
            {
              name          = "ecs-sample" #container name
              containerPort = 9090
              protocol      = "tcp"
            }
          ]
          readonly_root_filesystem = false

        }
      }
      assign_public_ip                   = true
      deployment_minimum_healthy_percent = 100
      subnet_ids                         = flatten(data.aws_subnets.public.ids)
      security_group_ids                 = [aws_security_group.allow_sg.id]
    }
  }
}

resource "aws_security_group" "allow_sg" {
  name        = "wang2-allow_tls"
  description = "Allow traffic"
  vpc_id      = data.aws_vpc.selected.id

  ingress {
    description = "Allow all"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "allow_sg"
  }
}