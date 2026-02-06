locals {
  name_prefix    = "${var.project_name}-${var.environment}"
  container_name = var.project_name
  log_group      = "/ecs/${var.project_name}"
}

data "aws_caller_identity" "current" {}

# ──── ECS Cluster ────────────────────────────────────────────

resource "aws_ecs_cluster" "main" {
  name = "${local.name_prefix}-cluster"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = { Name = "${local.name_prefix}-cluster" }
}

# ──── CloudWatch Log Group ───────────────────────────────────

resource "aws_cloudwatch_log_group" "ecs" {
  name              = local.log_group
  retention_in_days = 30

  tags = { Name = "${local.name_prefix}-logs" }
}

# ──── IAM: Task Execution Role ───────────────────────────────
# Used by the ECS agent to pull images, write logs, read secrets.

resource "aws_iam_role" "task_execution" {
  name = "${local.name_prefix}-task-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "task_execution_base" {
  role       = aws_iam_role.task_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy" "task_execution_secrets" {
  name = "${local.name_prefix}-secrets-read"
  role = aws_iam_role.task_execution.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "secretsmanager:GetSecretValue"
      ]
      Resource = [
        var.anthropic_api_key_arn,
        var.openai_api_key_arn,
      ]
    }]
  })
}

# ──── IAM: Task Role ─────────────────────────────────────────
# Permissions available to the running container.

resource "aws_iam_role" "task" {
  name = "${local.name_prefix}-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs-tasks.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "task_s3_read" {
  name = "${local.name_prefix}-s3-read"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:ListBucket",
      ]
      Resource = [
        "arn:aws:s3:::biomni-release",
        "arn:aws:s3:::biomni-release/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy" "task_logs" {
  name = "${local.name_prefix}-logs-write"
  role = aws_iam_role.task.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents",
      ]
      Resource = "${aws_cloudwatch_log_group.ecs.arn}:*"
    }]
  })
}

# ──── IAM: EBS Infrastructure Role ───────────────────────────
# Required for ECS-managed EBS volumes (configuredAtLaunch).

resource "aws_iam_role" "ebs_infrastructure" {
  name = "${local.name_prefix}-ebs-infra"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ecs.amazonaws.com" }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = data.aws_caller_identity.current.account_id
        }
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "ebs_infrastructure" {
  role       = aws_iam_role.ebs_infrastructure.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSInfrastructureRolePolicyForVolumes"
}

# ──── Task Definition ────────────────────────────────────────

resource "aws_ecs_task_definition" "biomni" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = aws_iam_role.task_execution.arn
  task_role_arn            = aws_iam_role.task.arn

  ephemeral_storage {
    size_in_gib = var.ephemeral_storage_gib
  }

  # EBS volume configured at launch (created from snapshot, deleted on task stop)
  volume {
    name = "data-lake"

    configure_at_launch = true
  }

  container_definitions = jsonencode([
    {
      name      = local.container_name
      image     = "${var.ecr_repository_url}:${var.container_image_tag}"
      essential = true
      command   = ["python", "/app/scripts/entrypoint.py"]

      portMappings = [
        { containerPort = 7860, protocol = "tcp" },
        { containerPort = 8000, protocol = "tcp" },
      ]

      environment = [
        { name = "BIOMNI_DATA_PATH", value = "/mnt/data" },
        { name = "BIOMNI_LLM", value = var.biomni_llm },
        { name = "BIOMNI_TIMEOUT_SECONDS", value = tostring(var.biomni_timeout_seconds) },
      ]

      secrets = [
        {
          name      = "ANTHROPIC_API_KEY"
          valueFrom = var.anthropic_api_key_arn
        },
        {
          name      = "OPENAI_API_KEY"
          valueFrom = var.openai_api_key_arn
        },
      ]

      mountPoints = [
        {
          sourceVolume  = "data-lake"
          containerPath = "/mnt/data"
          readOnly      = false
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = local.log_group
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    }
  ])

  tags = { Name = "${local.name_prefix}-task-def" }
}

# ──── ECS Service ────────────────────────────────────────────

resource "aws_ecs_service" "biomni" {
  name            = "${local.name_prefix}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.biomni.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  health_check_grace_period_seconds = var.health_check_grace_period

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [var.ecs_security_group_id]
    assign_public_ip = false
  }

  # Gradio target group
  load_balancer {
    target_group_arn = var.gradio_target_group_arn
    container_name   = local.container_name
    container_port   = 7860
  }

  # FastAPI target group
  load_balancer {
    target_group_arn = var.api_target_group_arn
    container_name   = local.container_name
    container_port   = 8000
  }

  # EBS volume from snapshot
  volume_configuration {
    name = "data-lake"

    managed_ebs_volume {
      role_arn        = aws_iam_role.ebs_infrastructure.arn
      snapshot_id     = var.data_lake_snapshot_id
      volume_type     = "gp3"
      size_in_gb      = var.data_lake_size_gib
      encrypted       = true
      file_system_type = "ext4"
    }
  }

  depends_on = [
    aws_iam_role_policy_attachment.task_execution_base,
    aws_iam_role_policy.task_execution_secrets,
  ]

  tags = { Name = "${local.name_prefix}-service" }
}
