# GitLab CI/CD Variables Setup
# Settings → CI/CD → Variables → Add the following:

# AWS credentials (mark as Protected + Masked)
AWS_ACCOUNT_ID         = your-12-digit-aws-account-id
AWS_DEFAULT_REGION     = us-east-1
AWS_ACCESS_KEY_ID      = (from IAM user)          [MASKED]
AWS_SECRET_ACCESS_KEY  = (from IAM user)          [MASKED]

# DNS of Application Load Balancers (set after Terraform apply)
STAGING_ALB_DNS        = staging-alb-xxxx.us-east-1.elb.amazonaws.com
PROD_ALB_DNS           = prod-alb-xxxx.us-east-1.elb.amazonaws.com

# Slack webhook for failure notifications (optional)
SLACK_WEBHOOK_URL      = https://hooks.slack.com/services/xxx/yyy/zzz  [MASKED]

# IAM permissions needed for the CI user:
# - ecr:GetAuthorizationToken
# - ecr:BatchCheckLayerAvailability
# - ecr:GetDownloadUrlForLayer
# - ecr:PutImage
# - ecr:InitiateLayerUpload
# - ecr:UploadLayerPart
# - ecr:CompleteLayerUpload
# - ecs:RegisterTaskDefinition
# - ecs:UpdateService
# - ecs:DescribeServices
# - ecs:DescribeTaskDefinition
# - iam:PassRole
