# Java Lab Repository — Setup Guide

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
| `pom.xml` | Maven build, Checkstyle, JaCoCo, Surefire config |
| `mvnw` + `.mvn/` | Local Maven wrapper — no global Maven install needed |
| `src/main/java/com/example/App.java` | Starter application class |
| `src/test/java/com/example/AppTest.java` | Starter unit test |
| `checkstyle-suppressions.xml` | Suppress Checkstyle rules for test files |
| `.pre-commit-config.yaml` | Local pre-commit hooks |
| `.vscode/extensions.json` | Recommended VS Code extensions |
| `.vscode/settings.json` | VS Code editor and formatter settings |
| `.trivyignore` | CVE suppressions for Trivy security scanner |
| `.gitignore` | Standard Java / Maven ignores |
| `.github/ISSUE_TEMPLATE/` | Bug report and feature request templates |
| `.github/PULL_REQUEST_TEMPLATE.md` | PR checklist |

---

## 2. Prerequisites

Install these tools **once** on your machine.

| Tool | Minimum version | Install |
|---|---|---|
| Java (JDK) | 21 | https://adoptium.net/ |
| Git | Any recent | https://git-scm.com |
| Python | 3.8+ | https://python.org (needed for pre-commit) |
| pre-commit | 3.x | `pip install pre-commit` |
| VS Code | Any recent | https://code.visualstudio.com |

> **You do NOT need Maven installed globally.** The `mvnw` wrapper downloads
> the correct Maven version automatically on first use.

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

> Without these two secrets, the SonarQube step will be **skipped** (it won't
> fail the pipeline, but you'll lose code quality insights).

### 3.3 Update ci-profile.yml

Open `ci-profile.yml`. It must contain exactly:

```yaml
profile: java
```

Do **not** change anything else in this file.

### 3.4 Customise pom.xml

Replace these placeholders:

```xml
<groupId>com.example</groupId>          <!-- your organisation / group -->
<artifactId>my-app</artifactId>         <!-- your project name -->
<version>1.0-SNAPSHOT</version>         <!-- your version -->
```

Also update the package name in `App.java` and `AppTest.java` to match your
chosen `groupId`.

### 3.5 Install pre-commit hooks

```bash
pip install pre-commit
pre-commit install          # installs the Git hook
pre-commit run --all-files  # run once to verify everything passes
```

### 3.6 Open in VS Code and install extensions

1. Open the repository folder in VS Code.
2. A notification will appear: **"Install recommended extensions?"** — click
   **Install All**.
3. Or open the Extensions panel, filter by **@recommended**, and install each
   one manually.

---

## 4. CI pipeline walkthrough

Every push and every pull request to `main` or `master` triggers the pipeline.

```
read-profile → cache-warmer → java-profile → trivy → sonarqube → copilot-review
```

### Step-by-step: java profile

| # | Step name | What it does |
|---|---|---|
| 1 | Checkout | Downloads your code onto the runner |
| 2 | Setup Java 21 | Installs the JDK; Maven dependencies are restored from cache |
| 3 | Build — compile | `./mvnw compile` — catches syntax errors and import problems |
| 4 | Test — Surefire + JaCoCo | `./mvnw verify` — runs all unit tests and measures code coverage |
| 5 | Lint — Checkstyle | `./mvnw checkstyle:check` — enforces Google Java Style |
| 6 | Coverage summary | Parses `jacoco.xml`, writes a table to the Actions job summary |
| 7 | Upload build artifacts | Archives `target/` so SonarQube can pick it up |

### Trivy (security scanning)

Runs after the Java profile passes:

- **Dependency CVE scan** — scans `pom.xml` and resolved JARs against the NVD
  database.
- **Results** appear in the **Security → Code scanning** tab as SARIF alerts.

### SonarQube (code quality gate)

Runs after Trivy:

- Downloads the build artifacts uploaded in step 7.
- Sends source + coverage + bytecode to your SonarQube server.
- Polls until the quality gate result arrives (up to 5 minutes).
- **Fails the pipeline** if the SonarQube quality gate is `ERROR`.

---

## 5. Hard failures vs warnings

| Condition | Effect |
|---|---|
| Compile error | ❌ Pipeline fails immediately |
| Unit test failure | ❌ Pipeline fails |
| Checkstyle violation | ❌ Pipeline fails |
| Coverage below 80 % | ⚠️ Warning annotation on the commit — pipeline continues |
| SonarQube quality gate ERROR | ❌ Pipeline fails |
| Trivy CRITICAL/HIGH CVE found | ⚠️ SARIF alert uploaded — pipeline continues |

> **Tip:** Aim to keep coverage ≥ 80 % so the warning never appears. The
> coverage number is visible in the Actions summary tab.

---

## 6. Reading pipeline results

### Actions tab (job summary)

1. Go to your repo on GitHub → **Actions**.
2. Click the latest workflow run.
3. Click the **java** job → scroll down to **Summary** to see the coverage table.

### Security tab (Trivy CVEs)

1. Repo → **Security → Code scanning alerts**.
2. Each alert shows: CVE ID, severity, affected package, and fix version.
3. Fix by upgrading the dependency in `pom.xml`, then push again.
4. To suppress a known false positive: add the CVE ID to `.trivyignore` with a
   comment explaining why.

### SonarQube dashboard

1. Navigate to your SonarQube server.
2. Find the project (named `<org>_<repo>` by default).
3. Review: **Bugs**, **Vulnerabilities**, **Code Smells**, **Coverage**, and
   **Duplications**.

---

## 7. VS Code extensions

The `.vscode/extensions.json` file lists recommended extensions. When you open
the folder VS Code will prompt you to install them.

| Extension | Why you need it |
|---|---|
| **Extension Pack for Java** (`vscjava.vscode-java-pack`) | IntelliSense, debugger, Maven panel, test runner |
| **SonarLint** (`SonarSource.sonarlint-vscode`) | Shows SonarQube issues inline **before** you push |
| **Checkstyle for Java** (`shengchen.vscode-checkstyle`) | Highlights Checkstyle violations as you type |
| **GitLens** (`eamodio.gitlens`) | Inline Git blame, history, and diff tools |
| **XML** (`redhat.vscode-xml`) | Validates and formats `pom.xml` |

### Connecting SonarLint to SonarQube (optional but recommended)

1. Open VS Code settings (`Ctrl+,` or `Cmd+,`).
2. Search for `sonarlint connected`.
3. Add a connection with your SonarQube server URL and a user token.
4. This syncs the server's rule set so local analysis matches CI exactly.

---

## 8. Pre-commit hooks

Pre-commit runs checks automatically every time you run `git commit`. It catches
problems in seconds instead of waiting minutes for CI.

### Install

```bash
pip install pre-commit
pre-commit install
```

### What runs on every commit

| Hook | What it checks |
|---|---|
| `trailing-whitespace` | Removes trailing spaces |
| `end-of-file-fixer` | Ensures every file ends with a newline |
| `check-xml` | Validates `pom.xml` and Checkstyle XML |
| `check-yaml` | Validates YAML files |
| `detect-private-key` | Blocks commits that contain private keys |
| `check-added-large-files` | Blocks files > 1 MB |
| `no-commit-to-branch` | Prevents direct commits to `main` / `master` |
| `detect-secrets` | Scans for passwords, API keys, and tokens |
| `maven-checkstyle` | Runs `./mvnw checkstyle:check` on changed `.java` files |

### Run all hooks manually

```bash
pre-commit run --all-files
```

### Skip a hook temporarily (use sparingly)

```bash
SKIP=maven-checkstyle git commit -m "wip"
```

### Initialise the secrets baseline

The first time you run `detect-secrets` you need a baseline file:

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
| `pom.xml` | `groupId`, `artifactId`, `version`, add dependencies |
| `src/main/java/**` | All your application source code |
| `src/test/java/**` | All your test code |
| `checkstyle-suppressions.xml` | Add suppressions for justified edge cases |
| `.trivyignore` | Add CVE suppressions with justification comments |
| `.gitignore` | Add project-specific ignores |
| `.pre-commit-config.yaml` | Bump hook versions, add project-specific hooks |
| `.vscode/settings.json` | Adjust personal editor preferences |
| `README.md` | Replace this guide with your project documentation |

### ⛔ Do NOT change (without understanding the impact)

| File | Why |
|---|---|
| `ci-profile.yml` | Must stay `profile: java` — changing it routes to the wrong pipeline |
| `.github/workflows/ci.yml` | Wired to the shared pipeline — changing it breaks the connection |
| `pom.xml` — Checkstyle / JaCoCo / Surefire plugin config | Pipeline depends on specific output paths and report formats |
| `mvnw` + `.mvn/wrapper/maven-wrapper.properties` | Required for CI; do not delete or modify |

---

## 10. Common mistakes and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| `./mvnw: Permission denied` | `mvnw` lost executable bit | `chmod +x mvnw` |
| Checkstyle fails on 4-space indent | Google Style requires 2-space indent | Change indent in your `.java` files to 2 spaces |
| `No tests found` warning | Test class not matching `*Test.java` pattern | Rename `MyTests.java` → `MyTest.java` |
| SonarQube step skipped | Secrets not configured | Add `SONAR_TOKEN` and `SONAR_HOST_URL` in repo settings |
| Trivy alert for a dev-only JAR | Scans all JARs by default | Add CVE to `.trivyignore` with justification |
| Pre-commit `detect-secrets` fails | New secret string detected | If false positive: `detect-secrets audit .secrets.baseline` |
