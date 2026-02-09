locals {
  name_prefix = "${var.project_name}-${var.environment}"
  has_cert    = var.certificate_arn != ""
}

# ──── Application Load Balancer ──────────────────────────────

resource "aws_lb" "main" {
  name               = "${local.name_prefix}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.alb_security_group_id]
  subnets            = var.subnet_ids

  # Critical: Gradio uses WebSockets for streaming. Default 60s would
  # kill long-running agent tasks. Set to 1 hour.
  idle_timeout = 3600

  tags = { Name = "${local.name_prefix}-alb" }
}

# ──── Target Groups ──────────────────────────────────────────

resource "aws_lb_target_group" "gradio" {
  name        = "${local.name_prefix}-gradio"
  port        = 7860
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/"
    port                = "7860"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 30
    interval            = 60
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = { Name = "${local.name_prefix}-gradio-tg" }
}

resource "aws_lb_target_group" "api" {
  name        = "${local.name_prefix}-api"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/api/health"
    port                = "8000"
    healthy_threshold   = 2
    unhealthy_threshold = 5
    timeout             = 10
    interval            = 30
    matcher             = "200"
  }

  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = true
  }

  tags = { Name = "${local.name_prefix}-api-tg" }
}

# ──── HTTPS Listener (when certificate is provided) ─────────

resource "aws_lb_listener" "https" {
  count             = local.has_cert ? 1 : 0
  load_balancer_arn = aws_lb.main.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-2021-06"
  certificate_arn   = var.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.gradio.arn
  }
}

resource "aws_lb_listener_rule" "https_api" {
  count        = local.has_cert ? 1 : 0
  listener_arn = aws_lb_listener.https[0].arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern { values = ["/api/*"] }
  }
}

# ──── HTTP Listener ──────────────────────────────────────────
# When a cert exists: redirect HTTP → HTTPS
# When no cert: forward HTTP directly (development use)

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type = local.has_cert ? "redirect" : "forward"

    # Redirect config (only used when has_cert = true)
    dynamic "redirect" {
      for_each = local.has_cert ? [1] : []
      content {
        port        = "443"
        protocol    = "HTTPS"
        status_code = "HTTP_301"
      }
    }

    # Forward config (only used when has_cert = false, i.e. dev mode)
    target_group_arn = local.has_cert ? null : aws_lb_target_group.gradio.arn
  }
}

resource "aws_lb_listener_rule" "http_api" {
  count        = local.has_cert ? 0 : 1
  listener_arn = aws_lb_listener.http.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.api.arn
  }

  condition {
    path_pattern { values = ["/api/*"] }
  }
}
