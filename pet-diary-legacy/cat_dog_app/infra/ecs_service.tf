resource "aws_lb" "pet_alb" {
  name               = "pet-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.public_a.id, aws_subnet.public_b.id] 
}

resource "aws_lb_target_group" "pet_tg" {
  port     = 5000
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/health" 
    matcher = "200"
  }
}


resource "aws_ecs_service" "pet_service" {
  name            = "pet-classification-service"
  cluster         = aws_ecs_cluster.pet_cluster.id
  task_definition = aws_ecs_task_definition.pet_task.arn
  desired_count   = 1 
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = [aws_subnet.public_a.id, aws_subnet.public_b.id]
    security_groups = [aws_security_group.ecs_tasks_sg.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.pet_tg.arn
    container_name   = "pet-api"
    container_port   = 5000
  }
}