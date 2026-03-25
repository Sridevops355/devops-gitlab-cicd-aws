# GitLab CI/CD Pipeline → AWS ECS Fargate

![Pipeline](https://img.shields.io/badge/CI%2FCD-GitLab-FC6D26?logo=gitlab)
![AWS](https://img.shields.io/badge/Cloud-AWS-FF9900?logo=amazonaws)
![Docker](https://img.shields.io/badge/Container-Docker-2496ED?logo=docker)
![Python](https://img.shields.io/badge/App-Python%203.11-3776AB?logo=python)

**Built by Srikanth Nannapaneni**


---

## Why I built this

When I started transitioning into DevOps and cloud engineering, I kept hearing the
same thing from senior engineers: "Anyone can run a tutorial pipeline. Show me one
that actually handles failure, promotes images properly, and doesn't let broken code
near production."

So I built this. It's a 7-stage GitLab CI/CD pipeline that takes a Python Flask app
from a developer's push all the way to a live AWS ECS Fargate deployment with lint
checks, unit tests, a Docker image security scan, a staging environment, smoke tests,
and a manual gate before anything touches production.

Every decision in this pipeline has a reason behind it. I'll explain those reasons below.

---

## What the pipeline does -->
```
Developer pushes code
        │
        ▼
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  VALIDATE   │────▶│    TEST     │────▶│    BUILD    │────▶│    SCAN     │
│             │     │             │     │             │     │             │
│ Is the code │     │ Do all the  │     │ Package the │     │ Does the    │
│ well written│     │ tests pass? │     │ app into a  │     │ image have  │
│ and safe to │     │ Is coverage │     │ Docker image│     │ any known   │
│ build?      │     │ above 70%?  │     │ push to ECR │     │ CVEs in it? │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                                                     │
        ┌────────────────────────────────────────────────────────────┘
        ▼
┌──────────────────┐     ┌──────────────────┐     ┌──────────────────────┐
│  DEPLOY STAGING  │────▶│ INTEGRATION TEST │────▶│  DEPLOY PRODUCTION   │
│                  │     │                  │     │                      │
│ Push the image   │     │ Hit the staging  │     │ Someone has to       │
│ to a real AWS    │     │ URL and confirm  │     │ physically click     │
│ environment      │     │ the app actually │     │ "Deploy" — nothing   │
│ first            │     │ responds         │     │ auto-deploys to prod │
└──────────────────┘     └──────────────────┘     └──────────────────────┘
```

---

## The decisions I made and why

### Why GitLab CI/CD and not GitHub Actions?
GitLab has built-in container scanning, environment tracking, and deployment
approvals in the free tier. For a team running their own infrastructure like
most enterprise environments GitLab gives you more control without paying for
third-party integrations.

### Why tag Docker images with the Git commit SHA?
Every build gets a unique tag like `abc1234f`. This means:
- You can always trace exactly what code is running in production
- Rolling back is just pointing the ECS service at the previous SHA tag
- You never accidentally overwrite a working image

I also push `:latest` as a convenience tag, but production always uses the SHA tag.

### Why a manual gate before production?
Automation should handle repetitive, predictable work. The decision to push
something to production is not repetitive or predictable it's a human judgement
call. A senior engineer should look at what's being deployed and make that call.
Removing that gate is how incidents happen on a Friday afternoon.

### Why Trivy for security scanning?
Trivy scans the Docker image against known CVE databases before it ever reaches
a real environment. I configured it to warn on HIGH severity but fail the pipeline
on CRITICAL. The idea is: don't let a critical vulnerability reach even staging.

### Why does the pipeline use YAML anchors (`&aws_setup`)?
I hate repeating myself. The AWS CLI setup and ECR login steps are identical across
three stages. YAML anchors let me define that once and reference it everywhere.
If the region changes, I update one place and every stage picks it up.

### Why `minimumHealthyPercent=100` on the production deployment?
This means ECS will never take a running task down until a replacement is healthy.
It's the difference between zero-downtime deployments and users seeing 502 errors
during a release. The tradeoff is you need slightly more capacity during deploys
worth it.

---

## Tech stack

| What | Why I chose it |
|---|---|
| GitLab CI/CD | Native container scanning, environment tracking, approval gates |
| Python Flask | Lightweight, easy to test, representative of real microservices |
| Docker + AWS ECR | Immutable, portable images — same artifact runs in every environment |
| AWS ECS Fargate | No servers to manage, scales automatically, cost-effective for small workloads |
| Trivy | Free, fast, integrates natively with GitLab security dashboard |
| Prometheus + Grafana | Local observability stack — same concept as CloudWatch but visible locally |

---

## Project structure

```
devops-gitlab-cicd-aws/
├── .gitlab-ci.yml              ← The whole pipeline lives here
├── .gitlab-ci/
│   └── variables.md            ← What to set in GitLab Settings → CI/CD → Variables
├── .aws/
│   └── task-definition.json    ← ECS task definition (Fargate config)
├── app/
│   ├── app.py                  ← Flask app with /health and /ready endpoints
│   └── requirements.txt
├── tests/
│   └── test_app.py             ← 7 unit tests, all passing
├── scripts/
│   ├── bootstrap-aws.sh        ← One-time setup: creates ECR repo, ECS cluster, log groups
│   └── prometheus.yml          ← Prometheus scrape config for local monitoring
├── Dockerfile                  ← Multi-stage build, runs as non-root user
└── docker-compose.yml          ← Run everything locally: app + Prometheus + Grafana
```

---

## Running it locally

```bash
# Clone
git clone https://gitlab.com/sridevops3551/devops-gitlab-cicd-aws.git
cd devops-gitlab-cicd-aws

# Start the full local stack
docker compose up --build

# App:        http://localhost:5000
# Prometheus: http://localhost:9090
# Grafana:    http://localhost:3000  (login: admin / admin)
```

---

## Setting it up on GitLab

**Step 1 — Bootstrap AWS (run once)**
```bash
export AWS_DEFAULT_REGION=ap-southeast-2
./scripts/bootstrap-aws.sh staging
./scripts/bootstrap-aws.sh production
```
This creates the ECR repository, ECS clusters, and CloudWatch log groups.
You only need to run this once per environment.

**Step 2 — Set your CI/CD variables**
In GitLab: Settings → CI/CD → Variables

| Variable | What it is | Mask it? |
|---|---|---|
| `AWS_ACCOUNT_ID` | Your 12-digit AWS account ID | No |
| `AWS_DEFAULT_REGION` | e.g. `ap-southeast-2` | No |
| `AWS_ACCESS_KEY_ID` | From your IAM CI user | Yes |
| `AWS_SECRET_ACCESS_KEY` | From your IAM CI user | Yes |
| `STAGING_ALB_DNS` | Load balancer DNS after Terraform apply | No |
| `PROD_ALB_DNS` | Production load balancer DNS | No |
| `SLACK_WEBHOOK_URL` | For failure notifications | Yes |

**Step 3 — Push and watch it run**
```bash
git checkout -b develop
git push origin develop
# The pipeline triggers automatically
```

---

## Branch strategy

| Branch | What triggers | Where it deploys |
|---|---|---|
| `feature/*` | Validate + test only | Nowhere — just checks |
| `develop` | Full pipeline | Staging (automatic) |
| `main` | Full pipeline | Staging (auto) → Production (manual click) |

---

## What I learned building this

The hardest part wasn't the pipeline syntax  it was understanding **why** certain
patterns exist. Why do you register a new ECS task definition instead of just
updating the image tag? Because ECS needs an immutable record of exactly what ran
at any point in time for rollback and audit purposes.

Why do you wait for `services-stable` before running integration tests? Because
ECS does rolling deployments  the old task is still running while the new one
starts. If you hit the load balancer immediately, you might be testing the old version.

These are the kinds of things you only understand when you build it yourself and
watch it break.

---

## What's next

This pipeline deploys to ECS Fargate. The next version will add:
- Terraform to provision all of this AWS infrastructure as code — see
  [devops-terraform-aws-infra](https://gitlab.com/sridevops3551/devops-terraform-aws-infra)
- Kubernetes deployment option — see
  [devops-kubernetes-deployment](https://gitlab.com/sridevops3551/devops-kubernetes-deployment)
- Full monitoring with CloudWatch alarms and SNS alerting — see
  [devops-monitoring-alerting-aws](https://gitlab.com/sridevops3551/devops-monitoring-alerting-aws)

---
