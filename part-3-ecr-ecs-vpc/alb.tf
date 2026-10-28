resource "aws_lb" "this" {
  name               = substr(replace(local.name, "_", "-"), 0, 32)
  load_balancer_type = "application"
  internal           = false
  security_groups    = [aws_security_group.alb.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "frontend" {
  name        = "tf-p3-frontend-tg"
  port        = 3000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id
  health_check {
    path    = "/"
    matcher = "200-399"
  }
}

resource "aws_lb_target_group" "backend" {
  name        = "tf-p3-backend-tg"
  port        = 5000
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.this.id
  health_check {
    path    = "/api/health"
    matcher = "200"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.this.arn
  port              = 80
  protocol          = "HTTP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.frontend.arn
  }
}

resource "aws_lb_listener_rule" "backend" {
  listener_arn = aws_lb_listener.http.arn
  priority     = 100
  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}
