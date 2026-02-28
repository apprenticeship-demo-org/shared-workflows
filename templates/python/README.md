# Python Lab Repository — Setup Guide

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
| `requirements.txt` | Python dependencies |
| `main.py` | Starter application module |
| `test_main.py` | Starter unit test |
| `setup.cfg` | flake8, isort, and pytest configuration |
| `.pre-commit-config.yaml` | Local pre-commit hooks |
| `.vscode/extensions.json` | Recommended VS Code extensions |
| `.vscode/settings.json` | VS Code editor and formatter settings |
| `.trivyignore` | CVE suppressions for Trivy security scanner |
| `.gitignore` | Standard Python ignores |
| `.github/ISSUE_TEMPLATE/` | Bug report and feature request templates |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR checklist |

---

## 2. Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| Python | 3.10+ | https://python.org |
| pip | Any recent | Bundled with Python |
| Git | Any recent | https://git-scm.com |
| pre-commit | 3.x | `pip install pre-commit` |
| VS Code | Any recent | https://code.visualstudio.com |

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

### 3.3 Update ci-profile.yml

The file must contain exactly:

```yaml
profile: python
```

### 3.4 Set up your virtual environment

```bash
python -m venv .venv
source .venv/bin/activate    # Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

Add your real dependencies to `requirements.txt`. Keep test tools (`pytest`,
`pytest-cov`, `flake8`, `black`, `isort`) as they are — the pipeline needs them.

### 3.5 Install pre-commit hooks

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### 3.6 Open in VS Code and install extensions

Open the folder in VS Code. Click **"Install recommended extensions?"** when
prompted. Or open the Extensions panel, filter by **@recommended**, and install.

---

## 4. CI pipeline walkthrough

Every push and pull request to `main` or `master` triggers the pipeline.

```
read-profile → cache-warmer → python-profile → trivy → sonarqube → copilot-review
```

### Step-by-step: python profile

| # | Step name | What it does |
|---|---|---|
| 1 | Checkout | Downloads your code onto the runner |
| 2 | Setup Python 3.12 | Installs Python; pip cache is restored |
| 3 | Install dependencies | `pip install -r requirements.txt` |
| 4 | Lint — flake8 | Checks PEP 8 compliance and common errors (max line 120) |
| 5 | Format check — Black | `black --check .` — fails if any file needs reformatting |
| 6 | Import order — isort | `isort --check-only .` — fails if imports are unsorted |
| 7 | Type check — mypy | `mypy .` — static type checking (warnings only) |
| 8 | Security — Bandit | `bandit -r . -ll` — flags high-severity code patterns |
| 9 | Test — pytest + coverage | Runs all tests; generates `coverage.xml` for SonarQube |
| 10 | Coverage summary | Writes a coverage table to the Actions job summary |
| 11 | Upload build artifacts | Archives coverage report so SonarQube can use it |

### Trivy

Scans `requirements.txt` and installed packages against the NVD CVE database.
Results appear in **Security → Code scanning** as SARIF alerts.

### SonarQube

Downloads build artifacts and sends source + `coverage.xml` to SonarQube.
Polls the quality gate (up to 5 minutes). Fails the pipeline on `ERROR`.

---

## 5. Hard failures vs warnings

| Condition | Effect |
|---|---|
| flake8 violation | ❌ Pipeline fails |
| Black formatting not applied | ❌ Pipeline fails |
| isort check fails | ❌ Pipeline fails |
| Test failure | ❌ Pipeline fails |
| No tests found (empty test suite) | ⚠️ Warning — pipeline continues |
| Coverage below 80 % | ⚠️ Warning annotation on commit — pipeline continues |
| SonarQube quality gate ERROR | ❌ Pipeline fails |
| Trivy CVE found | ⚠️ SARIF alert — pipeline continues |

> **Why does Black fail the pipeline?** The pipeline runs `black --check`, it
> never modifies files. Run `black .` locally (or let VS Code's format-on-save
> do it) **before** pushing.

---

## 6. Reading pipeline results

### Actions job summary

1. GitHub → **Actions** → click the latest run.
2. Click the **python** job → scroll to **Summary** for the coverage table.

### Security tab

1. Repo → **Security → Code scanning alerts**.
2. Fix by upgrading the package in `requirements.txt`.
3. Suppress justified false positives in `.trivyignore`.

### SonarQube dashboard

Navigate to your SonarQube server → find the project → review bugs,
vulnerabilities, code smells, coverage, and duplications.

---

## 7. VS Code extensions

| Extension | Why you need it |
|---|---|
| **Python** (`ms-python.python`) | IntelliSense, debugger, test runner |
| **Pylance** (`ms-python.pylance`) | Fast type inference and completions |
| **SonarLint** (`SonarSource.sonarlint-vscode`) | Inline SonarQube issues before you push |
| **Black Formatter** (`ms-python.black-formatter`) | Format-on-save with Black |
| **isort** (`ms-python.isort`) | Sort imports on save |
| **Flake8** (`ms-python.flake8`) | Inline lint violations |
| **GitLens** (`eamodio.gitlens`) | Git blame, history, diffs |

### Connecting SonarLint to SonarQube

1. VS Code settings → search `sonarlint connected`.
2. Add your SonarQube server URL and user token.
3. Local analysis will now use the same rules as CI.

### Interpreter setup

Press `Ctrl+Shift+P` → **Python: Select interpreter** → choose
`.venv/bin/python` (the virtual environment you created in step 3.4).

---

## 8. Pre-commit hooks

### Install

```bash
pip install pre-commit
pre-commit install
```

### What runs on every commit

| Hook | What it checks |
|---|---|
| `trailing-whitespace` | Removes trailing spaces |
| `end-of-file-fixer` | Ensures every file ends with newline |
| `debug-statements` | Blocks `pdb.set_trace()` and `breakpoint()` |
| `detect-private-key` | Blocks private keys |
| `no-commit-to-branch` | Prevents direct commits to `main`/`master` |
| `isort` | Auto-sorts imports |
| `black` | Auto-formats code |
| `flake8` | Lints for PEP 8 violations |
| `detect-secrets` | Scans for passwords, tokens, API keys |

> **isort and Black auto-fix files.** After they run, stage the modified files
> with `git add` and commit again.

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
| `requirements.txt` | Add / remove dependencies |
| `main.py` and `test_main.py` | Replace with your actual application code |
| `setup.cfg` | Adjust flake8 rules, mypy strictness, pytest options |
| `.trivyignore` | Add CVE suppressions with justification |
| `.gitignore` | Add project-specific ignores |
| `.pre-commit-config.yaml` | Bump versions, add hooks |
| `.vscode/settings.json` | Personal editor preferences |
| `README.md` | Replace with your project documentation |

### ⛔ Do NOT change

| File | Why |
|---|---|
| `ci-profile.yml` | Must stay `profile: python` |
| `.github/workflows/ci.yml` | Calls the shared pipeline — don't break the connection |
| `requirements.txt` — test tool versions | Pipeline depends on specific pytest/coverage options |

---

## 10. Common mistakes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `black --check` fails in CI | Code not formatted | Run `black .` locally and push |
| `isort --check-only` fails | Imports not sorted | Run `isort .` locally |
| `No tests found` warning | No file matches `test_*.py` pattern | Rename `tests.py` → `test_main.py` |
| `ModuleNotFoundError` in CI | Dependency missing from `requirements.txt` | Add the package to `requirements.txt` |
| SonarQube step skipped | Secrets not configured | Add `SONAR_TOKEN` and `SONAR_HOST_URL` |
| `detect-secrets` fails on commit | New potential secret detected | Run `detect-secrets audit .secrets.baseline` to review |
