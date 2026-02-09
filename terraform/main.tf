# ══════════════════════════════════════════════════════════════
# Biomni — ECS Fargate Deployment
# ══════════════════════════════════════════════════════════════

module "networking" {
  source = "./modules/networking"

  project_name       = var.project_name
  environment        = var.environment
  vpc_cidr           = var.vpc_cidr
  availability_zones = var.availability_zones
}

module "ecr" {
  source = "./modules/ecr"

  project_name = var.project_name
  environment  = var.environment
}

module "secrets" {
  source = "./modules/secrets"

  project_name       = var.project_name
  environment        = var.environment
  anthropic_api_key  = var.anthropic_api_key
  openai_api_key     = var.openai_api_key
  tailscale_auth_key = var.tailscale_auth_key
}

module "alb" {
  source = "./modules/alb"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  subnet_ids            = module.networking.private_subnet_ids
  internal              = true
  alb_security_group_id = module.networking.alb_security_group_id
  certificate_arn       = var.certificate_arn
}

module "tailscale" {
  source = "./modules/tailscale"

  project_name           = var.project_name
  environment            = var.environment
  vpc_id                 = module.networking.vpc_id
  vpc_cidr               = var.vpc_cidr
  aws_region             = var.aws_region
  subnet_id              = module.networking.public_subnet_ids[0]
  tailscale_auth_key_arn = module.secrets.tailscale_auth_key_arn
}

module "ecs" {
  source = "./modules/ecs"

  project_name          = var.project_name
  environment           = var.environment
  aws_region            = var.aws_region
  private_subnet_ids    = module.networking.private_subnet_ids
  ecs_security_group_id = module.networking.ecs_security_group_id

  # Container
  ecr_repository_url    = module.ecr.repository_url
  container_image_tag   = var.container_image_tag
  task_cpu              = var.task_cpu
  task_memory           = var.task_memory
  ephemeral_storage_gib = var.ephemeral_storage_gib
  desired_count         = var.desired_count

  # Load balancer
  gradio_target_group_arn   = module.alb.gradio_target_group_arn
  api_target_group_arn      = module.alb.api_target_group_arn
  health_check_grace_period = var.health_check_grace_period

  # EBS data lake
  data_lake_snapshot_id = var.data_lake_snapshot_id
  data_lake_size_gib    = var.data_lake_size_gib

  # Agent config
  biomni_llm             = var.biomni_llm
  biomni_timeout_seconds = var.biomni_timeout_seconds

  # Secrets
  anthropic_api_key_arn = module.secrets.anthropic_api_key_arn
  openai_api_key_arn    = module.secrets.openai_api_key_arn
}
