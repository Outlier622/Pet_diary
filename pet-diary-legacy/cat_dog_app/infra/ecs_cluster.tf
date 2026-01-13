resource "aws_ecs_cluster" "pet_cluster" {
  name = "pet-classification-cluster"
}

resource "aws_ecs_task_definition" "pet_task" {
  family                   = "pet-classification-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256" 
  memory                   = "512" 

  container_definitions = jsonencode([
    {
      name      = "pet-api"
      image     = "YOUR_ECR_REPOSITORY_URL:latest" 
      cpu       = 256
      memory    = 512
      essential = true
      portMappings = [
        {
          containerPort = 5000 # Flask 端口
          protocol      = "tcp"
        }
      ]
      environment = [ 
        {
          name  = "FLASK_ENV"
          value = "production"
        }
      ]
      
    }
  ])
}

resource "aws_security_group" "ecs_tasks_sg" {
  vpc_id = aws_vpc.main.id
  ingress {
    protocol    = "tcp"
    from_port   = 5000
    to_port     = 5000
    cidr_blocks = ["0.0.0.0/0"] 
  }
  
}