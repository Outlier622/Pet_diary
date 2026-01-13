resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 3 
  min_capacity       = 1 
  resource_id        = "service/${aws_ecs_cluster.pet_cluster.name}/${aws_ecs_service.pet_service.name}"
  service_namespace  = "ecs"
  scalable_dimension = "ecs:service:DesiredCount"
}

resource "aws_appautoscaling_policy" "cpu_scale_up_policy" {
  name               = "cpu-utilization-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value = 70.0 
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
}