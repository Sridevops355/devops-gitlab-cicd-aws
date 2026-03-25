#!/bin/bash
# bootstrap-aws.sh
# Creates the ECR repo and ECS cluster needed before the first pipeline run
# Usage: ./scripts/bootstrap-aws.sh <environment>

set -euo pipefail

ENV=${1:-staging}
APP_NAME="devops-cicd-demo"
REGION=${AWS_DEFAULT_REGION:-ap-southeast-2}
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "======================================"
echo " Bootstrap: ${APP_NAME} [${ENV}]"
echo " Region:    ${REGION}"
echo " Account:   ${ACCOUNT_ID}"
echo "======================================"

# 1. Create ECR repository
echo "[1/4] Creating ECR repository..."
aws ecr describe-repositories --repository-names "${APP_NAME}" --region "${REGION}" 2>/dev/null || \
aws ecr create-repository \
  --repository-name "${APP_NAME}" \
  --region "${REGION}" \
  --image-scanning-configuration scanOnPush=true \
  --encryption-configuration encryptionType=AES256
echo "ECR repo ready: ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${APP_NAME}"

# 2. Create ECS cluster
echo "[2/4] Creating ECS cluster..."
aws ecs create-cluster \
  --cluster-name "${APP_NAME}-${ENV}" \
  --capacity-providers FARGATE \
  --region "${REGION}" 2>/dev/null || echo "Cluster already exists."

# 3. Create CloudWatch log group
echo "[3/4] Creating CloudWatch log group..."
aws logs create-log-group \
  --log-group-name "/ecs/${APP_NAME}" \
  --region "${REGION}" 2>/dev/null || echo "Log group already exists."

aws logs put-retention-policy \
  --log-group-name "/ecs/${APP_NAME}" \
  --retention-in-days 30 \
  --region "${REGION}"

# 4. Register initial task definition
echo "[4/4] Registering initial task definition..."
sed "s|\${AWS_ACCOUNT_ID}|${ACCOUNT_ID}|g; s|\${AWS_DEFAULT_REGION}|${REGION}|g; s|\${ECR_REGISTRY}|${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com|g" \
  .aws/task-definition.json > /tmp/task-def-resolved.json

aws ecs register-task-definition \
  --cli-input-json file:///tmp/task-def-resolved.json \
  --region "${REGION}"

echo ""
echo "======================================"
echo " Bootstrap complete for [${ENV}]"
echo " Next: Run your GitLab pipeline"
echo "======================================"
