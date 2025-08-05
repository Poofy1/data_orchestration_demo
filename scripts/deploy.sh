#!/bin/bash

# Simple deployment script for Investment Analytics Pipeline

echo "Deploying Investment Analytics Pipeline to AWS ECS..."

# Variables
REPO_NAME="investment-analytics-pipeline"
CLUSTER_NAME="dagster-cluster"
SERVICE_NAME="dagster-service"
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-east-1"

# Build and push Docker image to ECR
echo "Building and pushing Docker image..."

# Create ECR repository if it doesn't exist
aws ecr describe-repositories --repository-names $REPO_NAME 2>/dev/null || \
aws ecr create-repository --repository-name $REPO_NAME

# Get ECR login token
aws ecr get-login-password --region $REGION | docker login --username AWS --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build and tag image
docker build -t $REPO_NAME .
docker tag $REPO_NAME:latest $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest

# Push to ECR
docker push $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest

echo "Docker image pushed to ECR"

# Create task definition  
echo "📋 Creating ECS task definition..."
TASK_DEF=$(cat << EOF
{
  "family": "dagster-investment-analytics",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "512",
  "memory": "1024",
  "executionRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "dagster-webserver",
      "image": "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/${REPO_NAME}:latest",
      "portMappings": [{"containerPort": 3000, "protocol": "tcp"}],
      "environment": [{"name": "AWS_DEFAULT_REGION", "value": "${REGION}"}],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/dagster-investment-analytics",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "ecs"
        }
      }
    }
  ]
}
EOF
)

echo "$TASK_DEF" > task-definition.json

# Register task definition
aws ecs register-task-definition --cli-input-json file://task-definition.json

# Create or update ECS service
echo "Creating/updating ECS service..."

# Get default VPC subnets
SUBNETS=$(aws ec2 describe-subnets --filters "Name=default-for-az,Values=true" --query "Subnets[*].SubnetId" --output text | tr '\t' ',')

# Check if service exists
if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME --query 'services[0].serviceName' --output text 2>/dev/null | grep -q $SERVICE_NAME; then
    echo "Updating existing service..."
    aws ecs update-service --cluster $CLUSTER_NAME --service $SERVICE_NAME --task-definition dagster-investment-analytics
else
    echo "Creating new service..."
    aws ecs create-service \
        --cluster $CLUSTER_NAME \
        --service-name $SERVICE_NAME \
        --task-definition dagster-investment-analytics \
        --desired-count 1 \
        --launch-type FARGATE \
        --network-configuration "awsvpcConfiguration={subnets=[$SUBNETS],assignPublicIp=ENABLED}"
fi

echo "Deployment complete!"
echo "Your Dagster instance will be available at the ECS service public IP on port 3000"
echo "Check ECS console: https://console.aws.amazon.com/ecs/home?region=$REGION#/clusters/$CLUSTER_NAME/services"

# Clean up temp files
rm -f task-definition.json

echo "Investment Analytics Pipeline deployed successfully!"