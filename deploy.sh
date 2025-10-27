set -euo pipefail

# ===== Config (edit or export as envs) =====
APP_NAME="${APP_NAME:-dog-cat-category}"
IMAGE_NAME="${IMAGE_NAME:-$APP_NAME}"
DOCKERFILE_PATH="${DOCKERFILE_PATH:-./Dockerfile}"

# Version tag: prefer git SHA, fallback to timestamp
VERSION="${VERSION:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"
TAG="${TAG:-$VERSION}"

# Mode: local (docker-compose) or ecs
MODE="${MODE:-local}"

# Health check (local default)
HEALTHCHECK_URL="${HEALTHCHECK_URL:-http://localhost:8000/healthz}"
HEALTH_TIMEOUT_SEC="${HEALTH_TIMEOUT_SEC:-60}"

# AWS / ECR / ECS (only used in MODE=ecs)
AWS_PROFILE="${AWS_PROFILE:-default}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ECR_ACCOUNT_ID="${ECR_ACCOUNT_ID:-}"
ECR_REPO="${ECR_REPO:-$APP_NAME}"
ECS_CLUSTER="${ECS_CLUSTER:-$APP_NAME-cluster}"
ECS_SERVICE="${ECS_SERVICE:-$APP_NAME-service}"

RELEASES_DIR="${RELEASES_DIR:-./infra/releases}"
mkdir -p "$RELEASES_DIR"

log() { echo -e "[deploy] $*"; }

require() {
  command -v "$1" >/dev/null 2>&1 || { echo "Missing dependency: $1"; exit 1; }
}

health_check() {
  local url="$1"
  local timeout="$2"
  log "Waiting for healthy: $url (timeout ${timeout}s)"
  SECS=0
  until curl -fsS "$url" >/dev/null 2>&1; do
    sleep 2
    SECS=$((SECS+2))
    if [[ "$SECS" -ge "$timeout" ]]; then
      echo "Health check failed after ${timeout}s"
      exit 1
    fi
  done
  log "Health check OK"
}

record_release() {
  local image="$1"
  local mode="$2"
  local stamp
  stamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "{\"time\":\"$stamp\",\"mode\":\"$mode\",\"image\":\"$image\",\"tag\":\"$TAG\"}" \
    | tee "$RELEASES_DIR/release-$TAG.json" >/dev/null
  ln -sf "release-$TAG.json" "$RELEASES_DIR/latest.json"
  log "Recorded release: $RELEASES_DIR/release-$TAG.json"
}

# ===== Local (docker-compose) =====
deploy_local() {
  require docker
  if [ -f docker-compose.yml ]; then
    COMPOSE_FILE="docker-compose.yml"
  elif [ -f compose.yml ]; then
    COMPOSE_FILE="compose.yml"
  else
    echo "docker-compose.yml not found"
    exit 1
  fi

  log "Building local image: $IMAGE_NAME:$TAG"
  docker build -f "$DOCKERFILE_PATH" -t "$IMAGE_NAME:$TAG" .

  log "Updating compose image tag"
  IMAGE_ENV="IMAGE_TAG=$TAG" docker compose -f "$COMPOSE_FILE" up -d --build

  # Optional: if your compose file references tag via ${IMAGE_TAG}
  # ensure you export IMAGE_TAG before running:
  #   IMAGE_TAG=$TAG docker compose up -d --build

  health_check "$HEALTHCHECK_URL" "$HEALTH_TIMEOUT_SEC"
  record_release "$IMAGE_NAME:$TAG" "local"
  log "Local deploy finished: $IMAGE_NAME:$TAG"
}

# ===== ECS Helpers =====
ecr_login() {
  require aws
  require docker
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecr get-login-password \
    | docker login --username AWS --password-stdin "${ECR_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
}

ensure_repo() {
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecr describe-repositories --repository-names "$ECR_REPO" >/dev/null 2>&1 \
    || aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecr create-repository --repository-name "$ECR_REPO" >/dev/null
}

build_and_push() {
  local full="${ECR_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}:${TAG}"
  log "Building image: $full"
  docker build -f "$DOCKERFILE_PATH" -t "$full" .
  log "Pushing image: $full"
  docker push "$full"
  echo "$full"
}

update_ecs_service() {
  require aws
  require jq
  local image="$1"

  # Fetch current task definition
  local td_arn
  td_arn=$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecs describe-services \
    --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE" \
    --query 'services[0].taskDefinition' --output text)

  # Get JSON, replace image, register new revision
  local td_json
  td_json=$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecs describe-task-definition \
    --task-definition "$td_arn" --query 'taskDefinition')
  echo "$td_json" > "$RELEASES_DIR/taskdef-$TAG.json"

  local new_json
  new_json=$(echo "$td_json" \
    | jq ".containerDefinitions |= map(.image = \"$image\") | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,.compatibilities,.registeredAt,.registeredBy)")

  local new_td_arn
  new_td_arn=$(aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecs register-task-definition \
    --cli-input-json "$new_json" \
    --query 'taskDefinition.taskDefinitionArn' --output text)

  # Update service to new task def
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecs update-service \
    --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE" \
    --task-definition "$new_td_arn" >/dev/null

  # Wait for service stability
  log "Waiting for ECS service stable..."
  aws --profile "$AWS_PROFILE" --region "$AWS_REGION" ecs wait services-stable \
    --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE"

  echo "$new_td_arn" > "$RELEASES_DIR/last-taskdef-arn.txt"
  log "ECS updated to: $new_td_arn"
}

deploy_ecs() {
  : "${ECR_ACCOUNT_ID:?ECR_ACCOUNT_ID required for MODE=ecs}"
  ecr_login
  ensure_repo
  local full_image
  full_image=$(build_and_push)
  update_ecs_service "$full_image"

  # Optional: health check against Load Balancer URL if provided
  if [[ -n "${HEALTHCHECK_URL:-}" ]]; then
    health_check "$HEALTHCHECK_URL" "$HEALTH_TIMEOUT_SEC"
  fi
  record_release "$full_image" "ecs"
  log "ECS deploy finished: $full_image"
}

# ===== Main =====
case "$MODE" in
  local) deploy_local ;;
  ecs)   deploy_ecs   ;;
  *)     echo "Unknown MODE=$MODE (use 'local' or 'ecs')"; exit 1 ;;
esac

log "Done. Tag=$TAG"
