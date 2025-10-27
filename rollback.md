# Rollback Guide

This document describes how to roll back a deployment for **dog-cat-category**, 
supporting both **local Docker Compose** and **AWS ECS** modes.

---

## 1. AWS ECS Rollback

### Step 1. Check Current and Previous Task Definitions
```bash
aws ecs describe-services --cluster <CLUSTER> --services <SERVICE> \
  --query 'services[0].taskDefinition' --output text

aws ecs list-task-definitions --family-prefix <TASK_FAMILY> --region <REGION>

### Step 2. Update Service to Previous Revision
aws ecs update-service \
  --cluster <CLUSTER> \
  --service <SERVICE> \
  --task-definition <TASK_FAMILY>:<REVISION>

aws ecs wait services-stable --cluster <CLUSTER> --services <SERVICE>

### Step 3. Verify Health
curl -fsS https://<ALB-DOMAIN>/healthz

### Step 4. Rollback to a Specific Image (If Revision Unknown)
aws ecs describe-task-definition --task-definition <CURRENT_TD_ARN> \
  --query 'taskDefinition' > /tmp/td.json

cat /tmp/td.json \
  | jq '.containerDefinitions |= map(.image="<IMAGE_FROM_RELEASE>") 
        | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)' \
  > /tmp/td-new.json

NEW_ARN=$(aws ecs register-task-definition --cli-input-json file:///tmp/td-new.json \
  --query 'taskDefinition.taskDefinitionArn' --output text)

aws ecs update-service --cluster <CLUSTER> --service <SERVICE> --task-definition "$NEW_ARN"
aws ecs wait services-stable --cluster <CLUSTER> --services <SERVICE>

## 2. Local Docker Compose Rollback
docker compose down
export IMAGE_TAG=<OLD_TAG>
docker compose up -d
curl -fsS http://localhost:8000/healthz

