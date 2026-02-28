# DevOps Lab Repository — Setup Guide

This guide explains every file in this template, walks through the full CI
pipeline step by step, and shows you how to set up your local tooling so you
catch problems **before** they land in the pipeline.

---

## Table of contents

1. [What you get](#1-what-you-get)
2. [Prerequisites](#2-prerequisites)
3. [One-time setup](#3-one-time-setup)
4. [CI pipeline walkthrough](#4-ci-pipeline-walkthrough)
5. [Hard failures vs warnings](#5-hard-failures-vs-warnings)
6. [Reading pipeline results](#6-reading-pipeline-results)
7. [VS Code extensions](#7-vs-code-extensions)
8. [Pre-commit hooks](#8-pre-commit-hooks)
9. [Files to change vs files NOT to change](#9-files-to-change-vs-files-not-to-change)
10. [Common mistakes and fixes](#10-common-mistakes-and-fixes)

---

## 1. What you get

| File / folder | Purpose |
|---|---|
| `ci-profile.yml` | Tells the shared pipeline which profile to run |
| `.github/workflows/ci.yml` | Calls the shared pipeline |
| `.yamllint.yml` | YAML linting rules |
| `.pre-commit-config.yaml` | Local pre-commit hooks |
| `.vscode/extensions.json` | Recommended VS Code extensions |
| `.vscode/settings.json` | VS Code editor and formatter settings |
| `.trivyignore` | CVE / misconfiguration suppressions |
| `.gitignore` | Standard DevOps / infra ignores |
| `.github/ISSUE_TEMPLATE/` | Bug report and feature request templates |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR checklist |

> **Optional infrastructure files** — add these as your project grows:
> - `Dockerfile` — container image definition
> - `terraform/` — Terraform root module
> - `charts/` — Helm chart
> - `Jenkinsfile` — Jenkins declarative pipeline

---

## 2. Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| Git | Any recent | https://git-scm.com |
| Python | 3.8+ | https://python.org (needed for pre-commit + yamllint) |
| pre-commit | 3.x | `pip install pre-commit` |
| yamllint | 1.35+ | `pip install yamllint` |
| Docker | 24+ | https://docs.docker.com/get-docker/ |
| Terraform | 1.5+ | https://developer.hashicorp.com/terraform/downloads |
| TFLint | 0.50+ | https://github.com/terraform-linters/tflint |
| Helm | 3.x | https://helm.sh/docs/intro/install/ |
| VS Code | Any recent | https://code.visualstudio.com |
| hadolint | 2.x | https://github.com/hadolint/hadolint |

> Install only the tools relevant to your project (e.g. skip Terraform if you
> have no `.tf` files).

---

## 3. One-time setup

### 3.1 Create your GitHub repository

1. Create a new **private** repository on GitHub.
2. Copy all files from this template into the root of your new repo.
3. Commit and push.

### 3.2 Configure repository secrets

Go to **Settings → Secrets and variables → Actions** and add:

| Secret name | Value |
|---|---|
| `SONAR_TOKEN` | Token from SonarQube → My Account → Security |
| `SONAR_HOST_URL` | e.g. `https://sonarqube.your-org.com` |

For Terraform remote state (if applicable):

| Secret name | Value |
|---|---|
| `TF_BACKEND_…` | Your backend credentials (varies by provider) |

### 3.3 Update ci-profile.yml

The file must contain exactly:

```yaml
profile: devops
```

### 3.4 Install pre-commit hooks

```bash
pip install pre-commit yamllint
pre-commit install
pre-commit run --all-files
```

### 3.5 Open in VS Code and install extensions

Open the folder in VS Code → click **"Install recommended extensions?"** → or
filter Extensions by **@recommended**.

---

## 4. CI pipeline walkthrough

Every push and pull request to `main` or `master` triggers the pipeline.

```
read-profile → cache-warmer → devops-profile → trivy → sonarqube → copilot-review
```

### Step-by-step: devops profile

The pipeline auto-detects which infrastructure files exist and skips steps for
tools that are not present.

| # | Step name | Condition | What it does |
|---|---|---|---|
| 1 | Checkout | always | Downloads your code |
| 2 | Detect workspace contents | always | Scans for Dockerfile, `.tf` files, Helm chart, Jenkinsfile |
| 3 | YAML lint | always | `yamllint -c .yamllint.yml .` — validates all YAML files |
| 4 | Dockerfile lint — hadolint | Dockerfile exists | `hadolint Dockerfile` — Dockerfile best practices |
| 5 | Terraform init | `.tf` files exist | `terraform init -backend=false` |
| 6 | Terraform validate | `.tf` files exist | `terraform validate` |
| 7 | Terraform fmt check | `.tf` files exist | `terraform fmt -check -recursive` |
| 8 | TFLint | `.tf` files exist | `tflint --recursive` |
| 9 | Helm lint | `Chart.yaml` exists | `helm lint ./charts/` (or detected chart path) |
| 10 | Jenkinsfile syntax | `Jenkinsfile` exists | Checks for common declarative syntax errors |
| 11–19 | Upload reports | always | Archives linting outputs for SonarQube |

### Trivy

Scans your **Dockerfile** for:
- Misconfiguration and best-practice violations (always)
- Base image CVEs (if a `FROM` instruction is detected)

Results appear in **Security → Code scanning** as SARIF alerts.

### SonarQube

Sends YAML and Terraform source to SonarQube for code smell and security
hotspot analysis. Polls the quality gate (up to 5 minutes).

---

## 5. Hard failures vs warnings

| Condition | Effect |
|---|---|
| YAML lint error | ❌ Pipeline fails |
| Dockerfile hadolint ERROR | ❌ Pipeline fails |
| `terraform validate` failure | ❌ Pipeline fails |
| `terraform fmt` check failure | ❌ Pipeline fails |
| TFLint error | ❌ Pipeline fails |
| Helm lint error | ❌ Pipeline fails |
| Trivy Dockerfile misconfiguration | ⚠️ SARIF alert — pipeline continues |
| Trivy image CVE found | ⚠️ SARIF alert — pipeline continues |
| SonarQube quality gate ERROR | ❌ Pipeline fails |

> **yamllint and `.github/` files**: The `.yamllint.yml` config ignores `.github/`
> to avoid false positives from `on:` triggers in GitHub Actions workflow files.
> Do not remove that `ignore:` block.

---

## 6. Reading pipeline results

### Actions job summary

1. GitHub → **Actions** → click the latest run.
2. Click the **devops** job to see which steps ran and which were skipped.

### Security tab

1. Repo → **Security → Code scanning alerts**.
2. Trivy alerts include: the exact Dockerfile instruction causing the issue,
   the relevant CIS/AVD rule ID, and a suggested fix.
3. Suppress justified issues in `.trivyignore` using the `AVD-` or `CVE-` ID.

### SonarQube dashboard

Navigate to your SonarQube server → find the project → review
YAML/Terraform/Jenkinsfile issues.

---

## 7. VS Code extensions

| Extension | Why you need it |
|---|---|
| **YAML** (`redhat.vscode-yaml`) | Schema validation for k8s, GitHub Actions, Docker Compose |
| **Terraform** (`HashiCorp.terraform`) | HCL syntax, formatting, validation |
| **Docker** (`ms-azuretools.vscode-docker`) | Dockerfile syntax, compose support, container management |
| **SonarLint** (`SonarSource.sonarlint-vscode`) | Inline SonarQube issues before you push |
| **GitLens** (`eamodio.gitlens`) | Git blame, history, diffs |
| **Hadolint** (`exiasr.hadolint`) | Inline Dockerfile lint |
| **Helm Intellisense** (`Tim-Koehler.helm-intellisense`) | Helm chart completion and validation |

### YAML schema support

`.vscode/settings.json` configures automatic schema validation for:
- `.github/workflows/*.yml` → GitHub Actions schema
- `docker-compose*.yml` → Docker Compose schema

VS Code will highlight invalid keys and missing required fields as you type.

### Connecting SonarLint to SonarQube

1. VS Code settings → search `sonarlint connected`.
2. Add your SonarQube URL and user token.
3. Local analysis will use the same rules as CI.

---

## 8. Pre-commit hooks

### Install

```bash
pip install pre-commit yamllint
pre-commit install
```

### What runs on every commit

| Hook | What it checks |
|---|---|
| `trailing-whitespace` | Removes trailing spaces |
| `end-of-file-fixer` | Ensures newline at end of file |
| `check-yaml` (pre-commit-hooks) | Quick YAML parse check |
| `check-json` | Validates JSON files |
| `detect-private-key` | Blocks private keys and certificates |
| `no-commit-to-branch` | Prevents direct commits to `main`/`master` |
| `yamllint` | Full YAML lint using `.yamllint.yml` config |
| `hadolint-docker` | Lints Dockerfiles |
| `terraform-fmt` | Auto-formats `.tf` files with `terraform fmt` |
| `terraform-validate` | Validates Terraform configuration |
| `detect-secrets` | Scans for passwords, tokens, API keys |

> **terraform-fmt auto-fixes files.** After it runs, stage with `git add` and
> commit again.

### Run all hooks manually

```bash
pre-commit run --all-files
```

### Initialise the secrets baseline

```bash
pip install detect-secrets
detect-secrets scan > .secrets.baseline
git add .secrets.baseline
```

---

## 9. Files to change vs files NOT to change

### ✅ Safe to change

| File | What to change |
|---|---|
| `Dockerfile` | Add your application layers |
| `terraform/` | Create your modules, variables, and outputs |
| `charts/` | Build your Helm chart |
| `Jenkinsfile` | Define your Jenkins pipeline stages |
| `.yamllint.yml` | Adjust YAML rules; do not remove `.github/` ignore |
| `.trivyignore` | Add CVE/AVD suppressions with justification |
| `.gitignore` | Add project-specific ignores |
| `.pre-commit-config.yaml` | Bump versions, add hooks |
| `.vscode/settings.json` | Personal editor preferences |
| `README.md` | Replace with your project documentation |

### ⛔ Do NOT change

| File | Why |
|---|---|
| `ci-profile.yml` | Must stay `profile: devops` |
| `.github/workflows/ci.yml` | Calls the shared pipeline |
| `.yamllint.yml` — `.github/` ignore block | Removing it causes false positives on Actions `on:` triggers |

---

## 10. Common mistakes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| YAML lint passes locally but fails with `on:` | yamllint `ignore:` block missing | Make sure `.yamllint.yml` has `ignore: .github/` |
| `terraform fmt -check` fails | Terraform files not formatted | Run `terraform fmt -recursive` and commit |
| `terraform validate` fails | Syntax error in `.tf` file | Run `terraform validate` locally and fix errors |
| Trivy AVD alert for unencrypted S3 bucket | Terraform resource missing encryption config | Add `server_side_encryption_configuration` block or suppress in `.trivyignore` |
| hadolint `DL3007` — Using latest tag | `FROM image:latest` in Dockerfile | Pin the base image to a specific digest or version |
| SonarQube step skipped | Secrets not configured | Add `SONAR_TOKEN` and `SONAR_HOST_URL` in repo settings |
| `detect-secrets` blocks `terraform.tfvars` | File contains real secrets | Never commit `.tfvars` with real values; use CI secrets instead |
