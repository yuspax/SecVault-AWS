resource "aws_cloudwatch_log_group" "juice_shop_logs" {
  name              = "/ecs/juice-shop"
  retention_in_days = 7
}

# Internet-facing ALB is the intended, WAF-protected entry point.
#tfsec:ignore:aws-elb-alb-not-public
resource "aws_lb" "main" {
  name                       = "juice-shop-alb"
  internal                   = false
  load_balancer_type         = "application"
  security_groups            = [aws_security_group.alb_sg.id]
  subnets                    = [aws_subnet.public_a.id, aws_subnet.public_b.id]
  drop_invalid_header_fields = true
}

resource "aws_lb_target_group" "main" {
  name        = "juice-shop-tg"
  port        = 3000
  protocol    = "HTTP"
  vpc_id      = aws_vpc.main.id
  target_type = "ip"

  health_check {
    path    = "/"
    matcher = "200-399"
  }
}

# HTTP is a documented lab exception in README.md until a domain and
# ACM certificate exist.
#tfsec:ignore:aws-elb-http-not-used
resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

resource "aws_ecs_cluster" "main" {
  name = "juice-shop-cluster"
}

resource "aws_iam_role" "ecs_execution_role" {
  name = "juice_shop_ecs_execution_role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  role       = aws_iam_role.ecs_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_ecs_task_definition" "app" {
  family                   = "juice-shop-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = 512
  memory                   = 1024
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  runtime_platform {
    cpu_architecture        = "X86_64"
    operating_system_family = "LINUX"
  }

  container_definitions = jsonencode([
    {
      name         = "juice-shop"
      image        = trimspace(file("${path.module}/juice-shop-image.txt"))
      essential    = true
      portMappings = [{ containerPort = 3000, hostPort = 3000 }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.juice_shop_logs.name
          "awslogs-region"        = "eu-central-1"
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "main" {
  name                              = "juice-shop-service"
  cluster                           = aws_ecs_cluster.main.id
  task_definition                   = aws_ecs_task_definition.app.arn
  desired_count                     = 1
  launch_type                       = "FARGATE"
  health_check_grace_period_seconds = 60
  wait_for_steady_state             = true

  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }

  network_configuration {
    subnets          = [aws_subnet.private_a.id, aws_subnet.private_b.id]
    security_groups  = [aws_security_group.ecs_sg.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "juice-shop"
    container_port   = 3000
  }

  depends_on = [
    aws_lb_listener.front_end,
    aws_wafv2_web_acl_association.main,
    aws_iam_role_policy_attachment.ecs_execution_role_policy,
    aws_security_group_rule.alb_http,
    aws_security_group_rule.alb_to_ecs,
    aws_security_group_rule.ecs_from_alb,
    aws_security_group_rule.ecs_https,
    aws_route_table_association.a,
    aws_route_table_association.private_a,
    aws_route_table_association.private_b,
  ]
}
