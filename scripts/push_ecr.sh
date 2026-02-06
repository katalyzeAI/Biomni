#!/usr/bin/env bash
# Build and push the Biomni Docker image to ECR.
#
# Usage:
#   bash scripts/push_ecr.sh              # uses default tag "e1"
#   bash scripts/push_ecr.sh latest       # custom tag
#
# Prerequisites:
#   - AWS CLI configured with appropriate permissions
#   - Docker running
#   - Terraform outputs available (or set ECR_REPO_URL manually)
set -euo pipefail

TAG="${1:-e1}"
REGION="${AWS_REGION:-us-east-1}"

# Get ECR repo URL from terraform output or environment
if [ -n "${ECR_REPO_URL:-}" ]; then
    REPO_URL="$ECR_REPO_URL"
elif command -v terraform &>/dev/null && [ -d terraform ]; then
    REPO_URL=$(cd terraform && terraform output -raw ecr_repository_url)
else
    echo "ERROR: Set ECR_REPO_URL or run from the repo root with terraform/ present."
    exit 1
fi

ACCOUNT_ID=$(echo "$REPO_URL" | cut -d. -f1)
REGISTRY="${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com"

echo "==> Authenticating Docker with ECR..."
aws ecr get-login-password --region "$REGION" | \
    docker login --username AWS --password-stdin "$REGISTRY"

echo "==> Building image biomni:${TAG}..."
docker build -t "biomni:${TAG}" .

echo "==> Tagging and pushing to ${REPO_URL}:${TAG}..."
docker tag "biomni:${TAG}" "${REPO_URL}:${TAG}"
docker push "${REPO_URL}:${TAG}"

echo "==> Done. Image pushed to ${REPO_URL}:${TAG}"
