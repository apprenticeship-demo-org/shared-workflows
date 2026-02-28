# JavaScript Lab Repository — Setup Guide

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
| `package.json` | NPM project config, scripts, and dev dependencies |
| `src/index.js` | Starter application module |
| `src/index.test.js` | Starter Jest test |
| `.eslintrc.json` | ESLint rules (extends recommended + Jest plugin) |
| `.prettierrc.json` | Prettier formatting config |
| `.pre-commit-config.yaml` | Local pre-commit hooks |
| `.vscode/extensions.json` | Recommended VS Code extensions |
| `.vscode/settings.json` | VS Code editor and formatter settings |
| `.trivyignore` | CVE suppressions for Trivy security scanner |
| `.gitignore` | Standard Node.js / JavaScript ignores |
| `.github/ISSUE_TEMPLATE/` | Bug report and feature request templates |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR checklist |

---

## 2. Prerequisites

| Tool | Minimum version | Install |
|---|---|---|
| Node.js | 20 LTS | https://nodejs.org |
| npm | 10+ | Bundled with Node.js |
| Git | Any recent | https://git-scm.com |
| Python | 3.8+ | https://python.org (needed for pre-commit) |
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
profile: javascript
```

### 3.4 Install dependencies

```bash
npm install
```

This creates `package-lock.json`. **Commit `package-lock.json`** — the CI
pipeline uses `npm ci` which requires it for reproducible installs.

### 3.5 Customise package.json

Replace `"name"`, `"description"`, and `"author"` with your project details.

Keep the `test`, `lint`, and `format:check` scripts — the pipeline calls them
by these exact names.

### 3.6 Install pre-commit hooks

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### 3.7 Open in VS Code and install extensions

Open the folder in VS Code. Click **"Install recommended extensions?"** when
prompted. Or open the Extensions panel, filter by **@recommended**, and install.

---

## 4. CI pipeline walkthrough

Every push and pull request to `main` or `master` triggers the pipeline.

```
read-profile → cache-warmer → javascript-profile → trivy → sonarqube → copilot-review
```

### Step-by-step: javascript profile

| # | Step name | What it does |
|---|---|---|
| 1 | Checkout | Downloads your code onto the runner |
| 2 | Setup Node 20 | Installs Node.js; `npm` cache is restored |
| 3 | Install dependencies | `npm ci` (or `npm install` if no lock file — produces a warning) |
| 4 | Lint — ESLint | `npx eslint .` — enforces code quality rules |
| 5 | Format check — Prettier | `npx prettier --check .` — fails if any file needs formatting |
| 6 | Audit — npm audit | `npm audit --audit-level=high` — checks for known CVEs in deps |
| 7 | Test — Jest + coverage | Runs all tests; generates `coverage/lcov.info` and `coverage-summary.json` |
| 8 | Coverage summary | Reads `coverage-summary.json`, writes table to Actions job summary |
| 9 | Upload build artifacts | Archives `coverage/` so SonarQube can use LCOV data |

### Trivy

Scans `package.json` / `package-lock.json` against the NVD CVE database.
Results appear in **Security → Code scanning** as SARIF alerts.

### SonarQube

Downloads build artifacts and sends source + `lcov.info` to SonarQube.
Polls the quality gate (up to 5 minutes). Fails the pipeline on `ERROR`.

---

## 5. Hard failures vs warnings

| Condition | Effect |
|---|---|
| ESLint violation | ❌ Pipeline fails |
| Prettier formatting not applied | ❌ Pipeline fails |
| `npm audit` high/critical CVE found | ❌ Pipeline fails |
| Test failure | ❌ Pipeline fails |
| No `package-lock.json` | ⚠️ Warning — falls back to `npm install` |
| Coverage below 80 % | ⚠️ Warning annotation on commit — pipeline continues |
| SonarQube quality gate ERROR | ❌ Pipeline fails |
| Trivy CVE found | ⚠️ SARIF alert — pipeline continues |

> **Why does Prettier fail the pipeline?** CI runs `--check` only. Run
> `npx prettier --write .` locally (or let VS Code's format-on-save do it)
> **before** you push.

---

## 6. Reading pipeline results

### Actions job summary

1. GitHub → **Actions** → click the latest run.
2. Click the **javascript** job → scroll to **Summary** for the coverage table.
3. The table shows: statements, branches, functions, and lines coverage.

### Security tab

1. Repo → **Security → Code scanning alerts**.
2. Fix by upgrading the package in `package.json` and running `npm install`.
3. Commit the updated `package-lock.json`.
4. Suppress justified false positives in `.trivyignore`.

### SonarQube dashboard

Navigate to your SonarQube server → find the project → review bugs,
vulnerabilities, code smells, coverage, and duplications.

---

## 7. VS Code extensions

| Extension | Why you need it |
|---|---|
| **ESLint** (`dbaeumer.vscode-eslint`) | Inline lint errors, auto-fix on save |
| **Prettier** (`esbenp.prettier-vscode`) | Format-on-save |
| **SonarLint** (`SonarSource.sonarlint-vscode`) | Inline SonarQube issues before you push |
| **GitLens** (`eamodio.gitlens`) | Git blame, history, diffs |
| **npm Intellisense** (`christian-kohler.npm-intellisense`) | Auto-completes `require()` / `import` paths |
| **Jest** (`Orta.vscode-jest`) | Run and debug tests inline |

### Connecting SonarLint to SonarQube

1. VS Code settings → search `sonarlint connected`.
2. Add your SonarQube URL and user token.
3. Local analysis will use the same rules as CI.

### Format on save

`.vscode/settings.json` already sets Prettier as the default formatter and
enables `editor.formatOnSave`. This means your code is always formatted before
you commit — Prettier in CI will always pass.

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
| `end-of-file-fixer` | Ensures newline at end of file |
| `check-yaml` | Validates YAML files |
| `check-json` | Validates JSON files |
| `detect-private-key` | Blocks private keys |
| `no-commit-to-branch` | Prevents direct commits to `main`/`master` |
| `detect-secrets` | Scans for passwords, tokens, API keys |
| `prettier` | Auto-formats JS/JSON/CSS/Markdown |
| `eslint` | Lints and auto-fixes JS files |

> **Prettier and ESLint auto-fix files.** After they run, stage the modified
> files with `git add` and commit again.

### Run all hooks manually

```bash
pre-commit run --all-files
```

### Initialise the secrets baseline

```bash
pip install detect-secrets
detect-secrets scan --exclude-files 'package-lock\.json' > .secrets.baseline
git add .secrets.baseline
```

---

## 9. Files to change vs files NOT to change

### ✅ Safe to change

| File | What to change |
|---|---|
| `package.json` | `name`, `description`, `author`, add real dependencies |
| `src/index.js` | Replace with your application code |
| `src/index.test.js` | Replace with your tests |
| `.eslintrc.json` | Add or tune rules as the project grows |
| `.prettierrc.json` | Adjust formatting preferences |
| `.trivyignore` | Add CVE suppressions with justification |
| `.gitignore` | Add project-specific ignores |
| `.pre-commit-config.yaml` | Bump versions, add hooks |
| `.vscode/settings.json` | Personal editor preferences |
| `README.md` | Replace with your project documentation |

### ⛔ Do NOT change

| File | Why |
|---|---|
| `ci-profile.yml` | Must stay `profile: javascript` |
| `.github/workflows/ci.yml` | Calls the shared pipeline |
| `package.json` — `test`, `lint`, `format:check` scripts | Pipeline calls these exact script names |
| `package-lock.json` | Required for reproducible `npm ci` in CI — always commit it |

---

## 10. Common mistakes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Prettier check fails in CI | Code not formatted before push | Run `npx prettier --write .` locally |
| ESLint fails in CI | Lint violation | Run `npx eslint --fix .` locally |
| `npm ci` fails — missing lock file | `package-lock.json` not committed | Run `npm install` and commit `package-lock.json` |
| `npm audit` fails | High/critical CVE in dependency | Run `npm audit fix` or upgrade the affected package |
| SonarQube step skipped | Secrets not configured | Add `SONAR_TOKEN` and `SONAR_HOST_URL` in repo settings |
| Coverage lower than expected | Missing test file | Ensure test files match `*.test.js` pattern and are in the right directory |
