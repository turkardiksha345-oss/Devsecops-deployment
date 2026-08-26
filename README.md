# Reusable GitHub Actions CI/CD Pipeline with Security Scanning and EC2 Deployment

[![CI/CD Pipeline](https://img.shields.io/badge/CI%2FCD-GitHub%20Actions-blue.svg)](https://github.com/features/actions)
[![Python](https://img.shields.io/badge/Python-3.11-3776AB.svg?logo=python&logoColor=white)](https://www.python.org/)
[![Flask](https://img.shields.io/badge/Framework-Flask%203.0-black.svg?logo=flask)](https://flask.palletsprojects.com/)
[![Docker](https://img.shields.io/badge/Container-Docker-2496ED.svg?logo=docker&logoColor=white)](https://www.docker.com/)
[![AWS EC2](https://img.shields.io/badge/Cloud-AWS%20EC2-FF9900.svg?logo=amazon-aws&logoColor=white)](https://aws.amazon.com/ec2/)
[![Security Scans](https://img.shields.io/badge/DevSecOps-SonarQube%20%7C%20Trivy%20%7C%20Snyk%20%7C%20ZAP-success.svg)](https://owasp.org/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A production-grade, enterprise-ready DevOps implementation featuring a Python Flask application deployed to AWS EC2 using a modular, **reusable GitHub Actions CI/CD architecture**. The pipeline integrates comprehensive automated security scanning (SonarQube SAST, Trivy Container/FS Vulnerability Scanner, Snyk Dependency SCA, and OWASP ZAP DAST) and publishes continuous security dashboards to GitHub Pages.

---

## Architecture Diagram

```
Developer
   ↓
Feature Branch
   ↓
PR
   ↓
GitHub Required Checks
   ↓
Protected Main
   ↓
Main Pipeline
   ├── Reusable Build
   ├── Reusable Test
   ├── Reusable Docker Build
   ├── Reusable Security Scan
   │      ├── SonarQube
   │      ├── Trivy
   │      ├── Snyk
   │      └── OWASP ZAP
   └── Reusable Deployment
          ↓
        AWS EC2
          ↓
      Python Application

GitHub Pages
   ├── SonarQube Report
   ├── Trivy Report
   ├── Snyk Report
   └── OWASP ZAP Report
```

```mermaid
flowchart TD
    subgraph DevWorkspace["Developer Lifecycle"]
        DEV([Developer]) -->|git checkout -b feature/xxx| FB[Feature Branch]
        FB -->|git push| GH_PR[Pull Request to main]
    end

    subgraph PR_Checks["GitHub Actions CI (PR / Feature Branch)"]
        GH_PR --> C_BUILD[Reusable Build]
        C_BUILD --> C_TEST[Reusable Test & Lint]
        C_TEST --> C_DOCKER[Reusable Docker Build (dry-run)]
        C_DOCKER --> C_SEC[Reusable Security Scans]
        C_SEC -->|Report Status| PR_STATUS{All Checks Passed?}
    end

    PR_STATUS -->|No| REJECT[Block Merge]
    PR_STATUS -->|Yes + 2 Approvals| MERGE([Merge into Main])

    subgraph CD_Pipeline["Main Branch CD Pipeline (On Merge)"]
        MERGE --> M_BUILD[1. Build Application]
        M_BUILD --> M_TEST[2. Pytest & Linters]
        M_TEST --> M_DOCKER[3. Docker Build & Push to GHCR]
        M_DOCKER --> M_SEC[4. Multi-Scanner Security Suite]
        
        subgraph Scanners["Security Tools"]
            M_SEC --> S_SONAR[SonarQube SAST]
            M_SEC --> S_TRIVY[Trivy Vulnerability Scan]
            M_SEC --> S_SNYK[Snyk SCA & Deps]
            M_SEC --> S_ZAP[OWASP ZAP DAST]
        end

        M_SEC --> M_PAGES[5. Publish Security Portal to GitHub Pages]
        M_SEC --> M_DEPLOY[6. Reusable EC2 Deployment]
    end

    subgraph AWS["AWS Cloud Infrastructure"]
        M_DEPLOY -->|SSH + Pull GHCR| EC2[AWS EC2 Ubuntu Instance]
        EC2 --> DOCKER_HOST[Docker Engine]
        DOCKER_HOST --> APP_CONTAINER[Flask Container :5000]
        APP_CONTAINER --> HEALTHCHECK{Healthcheck /health}
        HEALTHCHECK -->|HTTP 200| LIVE[Traffic Served]
        HEALTHCHECK -->|Failure| ROLLBACK[Auto-Rollback to Previous Image]
    end

    subgraph StaticPages["GitHub Pages Security Intelligence"]
        M_PAGES --> P_MAIN["/reports/index.html"]
        M_PAGES --> P_SONAR["/reports/sonarqube/"]
        M_PAGES --> P_TRIVY["/reports/trivy/"]
        M_PAGES --> P_SNYK["/reports/snyk/"]
        M_PAGES --> P_ZAP["/reports/owasp/"]
    end
```

---

## 1. Project Architecture

This project adopts an end-to-end DevSecOps philosophy:
- **Codebase**: Python 3.11 with Flask, Gunicorn WSGI server, and psutil for observability.
- **Continuous Integration**: GitHub Actions broken down into single-responsibility, reusable workflows.
- **Quality & Security Gates**: Static code quality (SonarQube), static security linting (Bandit, Flake8, Pylint), container and filesystem vulnerability analysis (Trivy), software composition analysis (Snyk), and live runtime dynamic penetration testing (OWASP ZAP).
- **Continuous Delivery**: Automated, zero-downtime SSH-based Docker deployment onto an AWS EC2 instance with automated health validation and instant fallback rollback.
- **Reporting**: Automated static security site generation deployed to GitHub Pages.

---

## 2. Application Architecture

The application is structured inside `app/` following modern Flask factory patterns:

```
app/
├── __init__.py        # Application version & package init
├── app.py             # Application factory, endpoints, middleware, error handlers
├── config.py          # Environment configuration (Dev, Test, Prod)
└── templates/
    ├── base.html      # Responsive glassmorphism layout & theme
    └── index.html     # Real-time metrics dashboard & endpoint directory
```

### Endpoints:
- `GET /`: Modern responsive web dashboard displaying runtime statistics, memory, CPU, and CI/CD status.
- `GET /health`: JSON endpoint returning `{ "status": "UP", "uptime_seconds": ..., "checks": { ... } }` for AWS Target Groups, Docker `HEALTHCHECK`, and pipeline verifications.
- `GET /api/status`: JSON endpoint returning deep process diagnostics (PID, memory RSS, thread count, disk utilization).
- `GET /api/info`: Architectural metadata, pipeline capabilities, and active DevSecOps scanner checklist.
- `GET /api/version`: Semantic versioning output.

---

## 3. GitHub Actions Architecture

Rather than maintaining a monolithic YAML file, the pipeline uses **Reusable Workflows (`workflow_call`)**. This achieves:
- **Separation of Concerns**: Each stage is an independent, version-controlled unit.
- **Maintainability**: Security scanning updates or build changes do not impact deployment logic.
- **Composability**: Workflows can be called by other repositories in an organization.
- **Security**: Granular permission scopes per job and secret isolation.

```
.github/workflows/
├── reusable-build.yml          # Stage 1: Build & byte-compilation
├── reusable-test.yml           # Stage 2: Unit tests, coverage, linters
├── reusable-image-build.yml    # Stage 3: Docker Buildx & GHCR publish
├── reusable-security-scan.yml  # Stage 4: SonarQube, Trivy, Snyk, ZAP
├── reusable-deploy.yml         # Stage 5: Secure EC2 deployment & rollback
└── main-pipeline.yml           # Orchestrator Workflow
```

---

## 4. Reusable Workflows Specification

### 1. `reusable-build.yml`
- **Trigger**: `on: workflow_call`
- **Inputs**: `python-version` (default: `'3.11'`)
- **Outputs**: `build-status`, `artifact-name`
- **Behavior**: Configures Python with pip dependency caching, installs dependencies, compiles byte code (`python -m compileall app/`), packages build archive `dist/app-package.tar.gz`, and uploads the build artifact.

### 2. `reusable-test.yml`
- **Trigger**: `on: workflow_call`
- **Inputs**: `python-version` (default: `'3.11'`)
- **Outputs**: `test-status`
- **Behavior**: Executes `flake8`, `pylint`, `bandit` security linter, and runs `pytest` with JUnit XML (`test-results.xml`) and coverage XML (`coverage.xml`). Generates HTML coverage reports in `htmlcov/` and uploads test artifacts.

### 3. `reusable-image-build.yml`
- **Trigger**: `on: workflow_call`
- **Inputs**: `image-name`, `push` (boolean), `registry` (default: `'ghcr.io'`)
- **Secrets**: `registry-token`
- **Outputs**: `image-tag`, `image-uri`
- **Behavior**: Configures Docker Buildx, creates semantic metadata tags (Git SHA + `latest`), authenticates to GHCR, builds multi-stage container with GHA caching, pushes image when `push: true`, and exports image URI.

### 4. `reusable-security-scan.yml`
- **Trigger**: `on: workflow_call`
- **Inputs**: `image-tag`, `image-uri`
- **Secrets**: `sonar-token`, `sonar-host-url`, `snyk-token`
- **Outputs**: `scan-status`
- **Behavior**: Executes SonarQube SAST, Trivy Container/Filesystem scanning (SARIF + JSON), Snyk SCA dependency analysis, and OWASP ZAP DAST against a live local container. Consolidates all outputs into `reports/` via `scripts/generate-reports.py`.

### 5. `reusable-deploy.yml`
- **Trigger**: `on: workflow_call`
- **Inputs**: `image-uri`, `app-port` (default: `'5000'`), `environment`
- **Secrets**: `ec2-host`, `ec2-user`, `ec2-ssh-key`, `ghcr-token`, AWS credentials
- **Outputs**: `deployment-status`
- **Behavior**: Validates `github.ref == 'refs/heads/main'`, connects to EC2 via SSH, executes `scripts/deploy-remote.sh`, pulls GHCR image, performs zero-downtime swap, runs automated healthcheck polling against `http://$EC2_HOST:$PORT/health`, and triggers rollback if unhealthy.

---

## 5. Feature Branch Flow

```
Push to feature/*
  ↓
Stage 1: Reusable Build
  ↓
Stage 2: Reusable Test & Lint
  ↓
Stage 3: Reusable Docker Image Build (dry-run, push: false)
  ↓
Stage 4: Reusable Security Scans (SonarQube, Trivy, Snyk, ZAP)
  ↓
STOP (Deployment is strictly skipped)
```

---

## 6. Pull Request Flow

When a PR is opened targeting `main`:
1. GitHub Actions triggers `main-pipeline.yml`.
2. All validation jobs run automatically.
3. Pull Request Status Checks report green checkmarks for `Stage 1: Build Application`, `Stage 2: Tests & Linting`, `Stage 3: Docker Container Build`, and `Stage 4: Security Scans`.
4. Branch Protection ensures merge is blocked until all required checks pass and 2 peer approvals are submitted.

---

## 7. Main Branch Deployment Flow

When a Pull Request is merged into `main`:
```
Merge into main
  ↓
Stage 1: Build
  ↓
Stage 2: Tests & Linting
  ↓
Stage 3: Docker Image Build & Push to GHCR (Tagged with Git SHA & latest)
  ↓
Stage 4: DevSecOps Security Scans (SonarQube, Trivy, Snyk, ZAP)
  ↓
  ├── Stage 5: Publish Security Dashboard to GitHub Pages
  └── Stage 6: Deploy to AWS EC2 (SSH Remote Execution & Healthcheck)
```

---

## 8. Branch Protection Configuration

To enforce compliance, configure GitHub Branch Protection on the `main` branch:

### Manual Setup in GitHub Web UI:
1. Navigate to your repository on GitHub.
2. Click **Settings** $\rightarrow$ **Branches** $\rightarrow$ **Add branch protection rule**.
3. Set **Branch name pattern** to `main`.
4. Enable the following settings:
   - [x] **Require a pull request before merging**
     - [x] **Require approvals**: Set to `2`
     - [x] **Dismiss stale pull request approvals when new commits are pushed**
     - [x] **Require review from Code Owners**
   - [x] **Require status checks to pass before merging**
     - [x] **Require branches to be up to date before merging**
     - Add status checks:
       - `Stage 1: Build Application / build`
       - `Stage 2: Tests & Linting / test`
       - `Stage 3: Docker Container Build / image-build`
       - `Stage 4: Security Scans (SonarQube, Trivy, Snyk, ZAP) / security-scans`
   - [x] **Do not allow bypassing the above settings**
   - [x] **Restrict who can push to matching branches**: Prevent direct pushes.
   - [x] **Block force pushes** & **Block deletions**.

---

## 9. AWS EC2 Setup & Hardening Guide

### Step 1: Launch EC2 Instance
- **AMI**: Ubuntu Server 22.04 LTS (HVM), SSD Volume Type
- **Instance Type**: `t2.micro` or `t3.small`
- **Key Pair**: Create or select an existing `.pem` key pair (e.g. `devsecops-key.pem`).

### Step 2: Configure EC2 Security Group
Configure strict inbound security group rules:
| Type | Protocol | Port Range | Source | Reason |
| :--- | :--- | :--- | :--- | :--- |
| **SSH** | TCP | 22 | `YOUR_ADMIN_IP/32` | Administrative access only (**Never use 0.0.0.0/0**) |
| **HTTP** | TCP | 80 | `0.0.0.0/0` | Web traffic / reverse proxy |
| **Custom TCP**| TCP | 5000 | `0.0.0.0/0` | Direct Flask Application Port |
| **HTTPS** | TCP | 443 | `0.0.0.0/0` | Secure SSL Web Traffic |

### Step 3: Run Automated EC2 Provisioning
Connect to your EC2 instance via SSH:
```bash
ssh -i /path/to/devsecops-key.pem ubuntu@<EC2_PUBLIC_IP>
```

Clone the repository and run the provisioning script:
```bash
git clone https://github.com/turkardiksha345-oss/Devsecops-deployment.git
cd Devsecops-deployment
chmod +x scripts/ec2-setup.sh
./scripts/ec2-setup.sh
```

Log out and back in to activate docker group permissions:
```bash
exit
ssh -i /path/to/devsecops-key.pem ubuntu@<EC2_PUBLIC_IP>
docker ps
```

---

## 10. GitHub Secrets Reference

Configure the following secrets in **Settings** $\rightarrow$ **Secrets and variables** $\rightarrow$ **Actions**:

| Secret Name | Description | Example / Format | Required By |
| :--- | :--- | :--- | :--- |
| `EC2_HOST` | Public IPv4 address or DNS of EC2 | `54.210.35.120` | `reusable-deploy.yml` |
| `EC2_USER` | Default Linux user on EC2 | `ubuntu` | `reusable-deploy.yml` |
| `EC2_SSH_KEY` | Private OpenSSH Key content (PEM) | `-----BEGIN OPENSSH PRIVATE KEY----- ...` | `reusable-deploy.yml` |
| `GHCR_TOKEN` | GitHub Personal Access Token (with `read:packages`) | `ghp_xxxxxxxxxxxx` | `reusable-deploy.yml` |
| `SONAR_TOKEN` | SonarQube / SonarCloud authentication token | `squ_xxxxxxxxxxxx` | `reusable-security-scan.yml` |
| `SONAR_HOST_URL`| SonarQube Server URL (or SonarCloud) | `https://sonarcloud.io` | `reusable-security-scan.yml` |
| `SNYK_TOKEN` | Snyk API Token from Snyk Account Settings | `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx` | `reusable-security-scan.yml` |
| `AWS_ACCESS_KEY_ID` | AWS IAM Access Key (if using AWS CLI) | `AKIAXXXXXXXXXXXXXXXX` | Optional / `reusable-deploy.yml` |
| `AWS_SECRET_ACCESS_KEY`| AWS IAM Secret Key | `wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY` | Optional / `reusable-deploy.yml` |
| `AWS_REGION` | AWS Region | `us-east-1` | Optional |

> [!TIP]
> **AWS OIDC (Recommended for Production):** Instead of long-lived access keys, use GitHub OIDC with AWS IAM Role federation (`aws-actions/configure-aws-credentials@v4`).

---

## 11. SonarQube Setup

The repository includes `sonar-project.properties`:
```properties
sonar.projectKey=python-ec2-cicd
sonar.projectName=Python EC2 CI/CD Application
sonar.sources=app
sonar.tests=tests
sonar.python.coverage.reportPaths=coverage.xml
sonar.python.xunit.reportPath=test-results.xml
```

### Setup Steps:
1. Create a project on [SonarCloud.io](https://sonarcloud.io) or your private SonarQube instance.
2. Generate an analysis token and add it as `SONAR_TOKEN` in GitHub Secrets.
3. If using self-hosted SonarQube, add `SONAR_HOST_URL` (e.g., `https://sonarqube.yourdomain.com`).

---

## 12. Trivy Setup

Trivy runs automatically in `reusable-security-scan.yml`:
1. **Container Scanning**: Analyzes container image `scan-target-app:latest` for known CVEs in base OS packages.
2. **Filesystem Scanning**: Analyzes application dependencies in `requirements.txt`.
3. **SARIF Generation**: Uploads findings to GitHub Security tab under **Code Scanning alerts**.
4. **HTML Report**: Generates `reports/trivy/index.html` for GitHub Pages.

---

## 13. Snyk Setup

1. Sign up at [Snyk.io](https://snyk.io).
2. Retrieve your API Token under **Account Settings** $\rightarrow$ **General**.
3. Save it as `SNYK_TOKEN` in GitHub Secrets.
4. Snyk scans `requirements.txt` and flags high/critical vulnerabilities and license violations.

---

## 14. OWASP ZAP Setup

OWASP ZAP Dynamic Application Security Testing (DAST) runs as follows:
1. Launches the Flask container on port 5000.
2. Waits for `http://localhost:5000/health` to return `UP`.
3. Executes `zaproxy/action-baseline` scanning for OWASP Top 10 vulnerabilities (SQLi, XSS, insecure headers, CSRF).
4. Generates an HTML report preserved in `reports/owasp/index.html`.

---

## 15. GitHub Pages Security Reporting

The pipeline generates an interactive security portal:

```
reports/
├── index.html                  # Master DevSecOps Intelligence Dashboard
├── sonarqube/
│   └── index.html              # SonarQube SAST & Quality Gate
├── trivy/
│   └── index.html              # Trivy CVE & Container Scan Report
├── snyk/
│   └── index.html              # Snyk SCA & Dependency Report
└── owasp/
    └── index.html              # OWASP ZAP DAST Vulnerability Scan
```

### URLs on GitHub Pages:
- **Dashboard**: `https://<github-username>.github.io/<repository>/`
- **SonarQube**: `https://<github-username>.github.io/<repository>/reports/sonarqube/`
- **Trivy**: `https://<github-username>.github.io/<repository>/reports/trivy/`
- **Snyk**: `https://<github-username>.github.io/<repository>/reports/snyk/`
- **OWASP ZAP**: `https://<github-username>.github.io/<repository>/reports/owasp/`

### Enable GitHub Pages in Repository:
1. Go to **Settings** $\rightarrow$ **Pages**.
2. Under **Build and deployment** $\rightarrow$ **Source**, choose **GitHub Actions**.

---

## 16. How to Run Locally

### 1. Set Up Virtual Environment:
```bash
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements-dev.txt
```

### 2. Run Test Suite:
```bash
pytest
```

### 3. Run Static Linters:
```bash
flake8 app/ tests/
pylint app/
bandit -r app/
```

### 4. Start Local Development Server:
```bash
python app/app.py
```
Open `http://localhost:5000` in your browser.

### 5. Build and Run Docker Container Locally:
```bash
docker build -t devsecops-flask:latest .
docker run -p 5000:5000 devsecops-flask:latest
```

---

## 17. How to Create a Feature Branch

```bash
git checkout main
git pull origin main
git checkout -b feature/add-new-api-endpoint

# Make code modifications in app/ or tests/
git add .
git commit -m "feat: implement new status metrics endpoint"
git push origin feature/add-new-api-endpoint
```

---

## 18. How to Create a PR

1. Navigate to GitHub and click **Compare & pull request**.
2. Set base to `main` and compare to `feature/add-new-api-endpoint`.
3. Provide description of changes.
4. Submit PR.
5. GitHub Actions runs CI checks (Build $\rightarrow$ Test $\rightarrow$ Docker Build $\rightarrow$ Security Scans).
6. Request review from team members.

---

## 19. How Deployment Happens After Merge

1. Reviewer approves PR.
2. Click **Merge Pull Request**.
3. `main-pipeline.yml` executes on `main` branch:
   - Builds production container.
   - Pushes image tagged with SHA and `latest` to GitHub Container Registry.
   - Executes multi-scanner security suite.
   - Publishes static report portal to GitHub Pages.
   - Connects to AWS EC2 via SSH and executes `scripts/deploy-remote.sh`.
   - Verifies container health against `http://<EC2_HOST>:5000/health`.

---

## 20. Troubleshooting Common Failures

### 1. SSH Connection Timeout / Permission Denied
- **Fix**: Ensure `EC2_HOST` is correct, `EC2_USER` is `ubuntu`, and `EC2_SSH_KEY` contains the exact PEM key including `-----BEGIN ...` and `-----END ...` headers without extra spaces. Ensure AWS Security Group allows inbound port 22.

### 2. GitHub Pages Deployment 404
- **Fix**: Verify **Settings** $\rightarrow$ **Pages** has Source set to **GitHub Actions**.

### 3. Docker Healthcheck Fails on EC2
- **Fix**: Check EC2 logs by running:
  ```bash
  ssh -i key.pem ubuntu@<EC2_HOST> "docker logs devsecops-flask-app"
  ```

### 4. SonarQube / Snyk Scans Skipped
- **Fix**: Ensure `SONAR_TOKEN` and `SNYK_TOKEN` secrets are configured in GitHub repository settings.

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
