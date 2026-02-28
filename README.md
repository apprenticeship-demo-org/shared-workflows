# shared-workflows

> **Centralised GitHub Actions CI/CD** for every apprenticeship lab repository — one pipeline definition shared across every tech stack.

![Pipeline](https://img.shields.io/badge/GitHub_Actions-pipeline-2088FF?logo=github-actions&logoColor=white)
![Java](https://img.shields.io/badge/profile-Java_21-ED8B00?logo=openjdk&logoColor=white)
![Python](https://img.shields.io/badge/profile-Python_3.12-3776AB?logo=python&logoColor=white)
![JavaScript](https://img.shields.io/badge/profile-JavaScript_Node_20-F7DF1E?logo=javascript&logoColor=black)
![DevOps](https://img.shields.io/badge/profile-DevOps_IaC-0078D7?logo=terraform&logoColor=white)
![Trivy](https://img.shields.io/badge/security-Trivy-1904DA?logo=aquasecurity&logoColor=white)
![SonarQube](https://img.shields.io/badge/quality-SonarQube-4E9BCD?logo=sonarqube&logoColor=white)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Table of contents

1. [What is this repository?](#1-what-is-this-repository)
2. [Quick start — calling the pipeline from a lab repo](#2-quick-start)
3. [ci-profile.yml contract](#3-ci-profileyml-contract)
4. [Repository layout](#4-repository-layout)
5. [Job execution graph](#5-job-execution-graph)
6. [pipeline.yml — the central orchestrator](#6-pipelineyml)
7. [profiles/java.yml](#7-profilesjavayml)
8. [profiles/python.yml](#8-profilespythonyml)
9. [profiles/javascript.yml](#9-profilesjavascriptyml)
10. [profiles/devops.yml](#10-profilesdevopsyml)
11. [shared/cache-warmer.yml](#11-sharedcache-warmeryml)
12. [shared/trivy.yml](#12-sharedtrivyyml)
13. [shared/sonarqube.yml](#13-sharedsonarqubeyml)
14. [shared/copilot-review.yml](#14-sharedcopilot-reviewyml)
15. [Caching architecture](#15-caching-architecture)
16. [Security scanning architecture](#16-security-scanning-architecture)
17. [Inputs reference](#17-inputs-reference)
18. [Secrets reference](#18-secrets-reference)
19. [Repository access control setup](#19-repository-access-control-setup)
20. [Contributing](#20-contributing)
21. [Lab repository templates](#21-lab-repository-templates)

---

## 1. What is this repository?

`shared-workflows` is a **reusable-workflow library** hosted in a single GitHub repository. Every apprenticeship lab repo (regardless of language) calls `pipeline.yml` with one input — its tech profile — and gets a complete, production-grade CI pipeline with:

- **Language-appropriate lint → build → test** steps
- **Trivy CVE scanning** that blocks the pipeline on CRITICAL/HIGH findings
- **SARIF upload** to the GitHub Security tab for persistent alert tracking
- **SonarQube / SonarCloud** code quality analysis with quality gate polling
- **GitHub Copilot** automated PR review
- **Cache warming** before the profile job runs, so dependency downloads only happen once per unique lock file

Instead of copying YAML into every lab repo, apprentices add two files:

| File | Location | Purpose |
|------|----------|---------|
| `.github/workflows/ci.yml` | lab repo | Calls `pipeline.yml` with `workflow_call` |
| `ci-profile.yml` | lab repo root | Declares the tech profile (`java`, `python`, `javascript`, or `devops`) |

---

## 2. Quick start

### Step 1 — Create `.github/workflows/ci.yml` in the lab repo

```yaml
name: CI

on:
  push:
    branches: [main]
  pull_request:

jobs:
  pipeline:
    uses: <YOUR-ORG>/shared-workflows/.github/workflows/pipeline.yml@main
    secrets: inherit
```

> Replace `<YOUR-ORG>` with the GitHub organisation name. `secrets: inherit` forwards all org/repo secrets to the called workflow automatically.

### Step 2 — Create `ci-profile.yml` at the repo root

```yaml
# ci-profile.yml — placed at the root of the lab repository
profile: java    # one of: java | python | javascript | devops
```

That is the entire integration. The pipeline auto-detects everything else.

---

## 3. `ci-profile.yml` contract

The file must exist **at the repository root** (not inside `.github/`). It contains exactly one key:

```yaml
profile: <value>
```

| Value | What runs |
|-------|-----------|
| `java` | Maven build, Checkstyle, JaCoCo coverage, Trivy w/ Java CVE database |
| `python` | flake8 lint, pip install, pytest + coverage, Trivy library scan |
| `javascript` | Auto-detects package manager + framework + test runner; ESLint, build, test, Trivy |
| `devops` | yamllint, hadolint, Terraform validate/TFLint, Helm lint, Jenkinsfile validate |

`pipeline.yml` reads this file on every run with:

```bash
grep -oP '(?<=^profile:\s)[\w]+' ci-profile.yml
```

This regex extracts the bare value after `profile: ` without any shell variable expansion or YAML parsing, making it robust to leading/trailing whitespace.

---

## 4. Repository layout

```
.github/
└── workflows/
    ├── pipeline.yml              ← Entry point — read profile → warm caches → run profile → shared gates
    ├── profiles/
    │   ├── java.yml              ← Java CI: lint → build → test → scan → upload
    │   ├── python.yml            ← Python CI: lint → install → test → scan → upload
    │   ├── javascript.yml        ← JS/TS CI: detect → install → lint → build → test → scan → upload
    │   └── devops.yml            ← DevOps CI: YAML → Dockerfile → Terraform → Helm → Jenkinsfile
    └── shared/
        ├── cache-warmer.yml      ← Pre-populate caches before the profile job runs
        ├── trivy.yml             ← SARIF upload to Security tab + Dockerfile CVE scanning
        ├── sonarqube.yml         ← SonarQube/SonarCloud analysis + quality gate
        └── copilot-review.yml    ← GitHub Copilot automated PR review (placeholder)
ci-profile.yml                    ← NOT in this repo — lives in each lab repo
```

---

## 5. Job execution graph

```
read-profile
     │
     ▼
cache-warmer
     │
     ├──────────────────────────────────────────────────────────────┐
     ▼                                                              │
java       (needs: cache-warmer, if: profile == 'java')            │
python     (needs: cache-warmer, if: profile == 'python')          │
javascript (needs: cache-warmer, if: profile == 'javascript')      │
devops     (needs: cache-warmer, if: profile == 'devops')          │
     │                                                              │
     └───────────────────────────┬──────────────────────────────────┘
                                 ▼
         trivy          (needs: [java|python|javascript|devops])
         sonarqube      (needs: [java|python|javascript|devops])
         copilot-review (needs: [java|python|javascript|devops])

         Condition on all shared gates:
         always() && !failure() && !cancelled()
```

**Why `always() && !failure() && !cancelled()`?**

GitHub evaluates `needs.X.result` for each listed dependency. When a profile job is *skipped* (because the `if:` condition was false), its result is `skipped` — not `success`. A plain `needs: [java, python, javascript, devops]` gate would therefore never run because three of the four jobs are always skipped. The `!failure() && !cancelled()` guard allows skipped dependencies to pass while still blocking on actual failures and user cancellations.

---

## 6. `pipeline.yml`

**Role:** Orchestrator. Reads `ci-profile.yml`, routes to one profile job, then fans out to the three shared-gate jobs.

### Inputs

| Input | Default | Description |
|-------|---------|-------------|
| `java-version` | `21` | JDK version forwarded to `java.yml` and `cache-warmer.yml` |
| `python-version` | `3.12` | Python version forwarded to `python.yml` and `cache-warmer.yml` |
| `node-version` | `20` | Node.js version forwarded to `javascript.yml` and `cache-warmer.yml` |
| `dockerfile-path` | `Dockerfile` | Forwarded to `devops.yml` for hadolint fallback |
| `terraform-version` | `latest` | Terraform version forwarded to `devops.yml` and `cache-warmer.yml` |
| `sonar-project-key` | `""` | SonarQube project key override; empty = dynamic `{owner}_{repo}` |

### How profile detection works

```yaml
- name: Read ci-profile.yml
  id: read-profile
  run: |
    PROFILE=$(grep -oP '(?<=^profile:\s)[\w]+' ci-profile.yml)
    echo "profile=$PROFILE" >> $GITHUB_OUTPUT
```

Each downstream job then gates itself:

```yaml
java:
  needs: [read-profile, cache-warmer]
  if: needs.read-profile.outputs.profile == 'java'
  uses: ./.github/workflows/profiles/java.yml
```

---

## 7. `profiles/java.yml`

**Role:** Full Java CI — lint → Maven build + test → SNAPSHOT pruning → CVE scan → artifact upload.

### Step-by-step breakdown

| # | Step | Why it runs here |
|---|------|-----------------|
| 1 | **Checkout** | Source tree must exist before any tool runs |
| 2 | **Set up Java (Temurin)** | Installs the JDK; must precede Maven |
| 3 | **Restore Maven wrapper cache** | `~/.m2/wrapper/` — prevents re-download of `mvnw` on every run |
| 4 | **Restore Maven repository cache** | `~/.m2/repository/` — prevents re-download of all project dependencies |
| 5 | **Checkstyle** | Runs before compile so style errors surface first, before a potentially long `verify` |
| 6 | **`mvn verify`** | Compiles, runs unit tests, and generates JaCoCo `jacoco.xml` coverage report |
| 7 | **Prune SNAPSHOT artifacts** | `find ~/.m2 -name "*SNAPSHOT*" -delete` — removes unstable snapshots from the cache before it is saved, preventing stale dev builds being restored on future runs |
| 8 | **Trivy scan** | Pipeline-failing CVE scan (CRITICAL/HIGH → `exit-code: 1`); uses `TRIVY_JAVA_DB_REPOSITORY=ghcr.io/aquasecurity/trivy-java-db` for accurate Maven CVE data |
| 9 | **Upload `java-build` artifact** | Persists `target/` and `target/site/jacoco/jacoco.xml` for `sonarqube.yml` to consume |

### Why `TRIVY_JAVA_DB_REPOSITORY`?

The default Trivy vulnerability database is generic. Java/Maven ecosystems publish CVE data to a separate database maintained by the Aqua Security team at `ghcr.io/aquasecurity/trivy-java-db`. Without this env var, Trivy misses many Maven-specific CVEs. Setting the env var directs Trivy to fetch from the correct source.

### Cache keys

```
{OS}-mvn-wrapper-{sha256(.mvn/wrapper/maven-wrapper.properties)}
{OS}-maven-{sha256(**/pom.xml)}
```

Restore keys (fallback to nearest snapshot):

```
{OS}-mvn-wrapper-
{OS}-maven-
```

---

## 8. `profiles/python.yml`

**Role:** Full Python CI — lint → install → CVE scan → test with coverage → artifact upload.

### Step-by-step breakdown

| # | Step | Why it runs here |
|---|------|-----------------|
| 1 | **Checkout** | Source tree first |
| 2 | **Set up Python** (`cache: pip`) | Installs Python; the built-in `cache: pip` seeds a first-level pip cache automatically |
| 3 | **Restore explicit pip cache** | A second-level pip cache scoped to the Python version and requirements hash; survives across Python minor version bumps |
| 4 | **Restore venv cache** | Caches the full `.venv/` directory so `pip install` only runs on lock file changes |
| 5 | **Pre-warm common packages** | Installs `pytest pytest-cov flake8 requests` into the venv unconditionally so test tooling is always available even when `requirements.txt` is empty or missing |
| 6 | **flake8 lint** | `--max-line-length=120`; runs before `pip install` so style failures are caught without spending time on full dependency resolution |
| 7 | **`pip install -r requirements.txt`** | Full dependency install; idempotent if venv cache was hit |
| 8 | **Trivy scan** | Library CVE scan; `skip-dirs: .venv,venv,env,.env` so virtual environment symlinks do not interfere |
| 9 | **pytest** | `--cov=. --cov-report=xml` generates `coverage.xml` for SonarQube |
| 10 | **Upload `python-build` artifact** | Persists `coverage.xml` |

### Three-layer Python caching explained

```
Layer 1: actions/setup-python cache: pip
         → ~/.cache/pip (wheel cache; keyed on python-version)

Layer 2: explicit pip cache step
         → ~/.cache/pip (same path, finer key)
         → key: {OS}-pip-{pyver}-{hash(**/requirements*.txt)}

Layer 3: venv cache step
         → .venv/ (installed packages; no repeated pip resolve)
         → key: {OS}-venv-{pyver}-{hash(**/requirements*.txt)}
```

Layer 1 is always populated by `setup-python`. Layers 2 and 3 only hit when the lock file hash matches exactly. The net effect: a cold run downloads wheels (Layer 1 seeds), a warm run with same `requirements.txt` skips all network I/O (Layer 3 hit).

---

## 9. `profiles/javascript.yml`

**Role:** Single profile covering every JavaScript/TypeScript frontend stack through automatic detection.

Frameworks supported: **Next.js, Angular, Remix, Nuxt, Vue, React, vanilla JavaScript**.
Package managers supported: **npm, yarn, pnpm, bun**.
Test runners supported: **Jest, Vitest, Karma, Mocha, Playwright, Cypress**.

### The detection system

A single bash step (Step 3) outputs seven values to `GITHUB_OUTPUT`. Every subsequent conditional step reads from `steps.detect.outputs.*` — detection never runs twice.

| Output | Values | Detection logic |
|--------|--------|----------------|
| `pm` | `npm` `yarn` `pnpm` `bun` | Lock file presence; pnpm before npm to avoid npm false positives |
| `framework` | `next` `angular` `remix` `nuxt` `vue` `react` `vanilla` | `package.json` dependency scan; `next` checked before `react` |
| `build_tool` | `angular-cli` `vite` `next` `webpack` `none` | Derived from framework + vite config presence |
| `test_runner` | `jest` `vitest` `karma` `mocha` `playwright` `cypress` `none` | `package.json` dependencies |
| `typescript` | `true` `false` | `tsconfig.json` presence |
| `e2e` | `playwright` `cypress` `none` | `package.json` dependencies |
| `has_eslint` | `true` `false` | `.eslintrc*`, `.eslintrc.json`, `eslint.config.*` presence |

### Step-by-step breakdown

| # | Step | Conditional on | Why it runs here |
|---|------|---------------|-----------------|
| 1 | **Checkout** | — | Source first |
| 2 | **Set up Node.js** | — | Toolchain before detection |
| 3 | **Detect tooling** | — | All detection in one pass; outputs used by all subsequent steps |
| 4 | **Set up PM extras** | `pm == pnpm\|yarn\|bun` | Global install of non-npm managers after detection |
| 5 | **Restore dep cache** | — | PM-specific path cached before install |
| 6 | **Restore E2E cache** | `e2e != none` | Playwright `~/.cache/ms-playwright` or Cypress `~/.cache/Cypress` |
| 7 | **Install dependencies** | — | Frozen install (`npm ci` / `--frozen-lockfile` / `--no-frozen-lockfile` for bun) |
| 8 | **Install E2E binaries** | `e2e != none && cache-hit != true` | Browser binaries only on cache miss |
| 9 | **TypeScript check** | `typescript == true` | `tsc --noEmit`; type errors before lint/build; hard failure |
| 10 | **Lint** | — | Angular: `ng lint`; others: `eslint`; `continue-on-error: has_eslint == false` |
| 11 | **Build** | — | Framework-specific: `next build` / `ng build --prod` / `npm run build` etc. |
| 12 | **Test** | — | Runner case statement; `continue-on-error: test_runner == none` |
| 13 | **Trivy scan** | — | `scan-type: fs`, library CVEs, `.next/.nuxt/.terraform` excluded |
| 14 | **Upload `js-build`** | — | `if: always()`; persists dist/, coverage/ for SonarQube |
| 15 | **Detection summary** | — | `if: always()`; prints every detected value for debugging |

### Why `continue-on-error` is used sparingly

`continue-on-error: true` would hide bugs by masking failures. It is used **only** for lint (when no ESLint config file was found in the repo — the linter cannot run) and test (when no test runner was detected). It is never used for TypeScript type checking, building, or Trivy — those always fail the pipeline.

---

## 10. `profiles/devops.yml`

**Role:** Validation-only pipeline for IaC repos. There are intentionally no build or unit test steps — linting and validation *are* the quality gates for infrastructure code.

### Environment variable

```yaml
env:
  TF_PLUGIN_CACHE_DIR: ~/.terraform.d/plugin-cache
```

Setting this at job level means every `terraform` command automatically reads from and writes to the shared plugin cache without needing `-plugin-dir` flags.

### Step-by-step breakdown

| # | Step | Conditional | Why it runs here |
|---|------|-------------|-----------------|
| 1 | **Checkout** | — | Source first |
| 2 | **Restore pip cache** | — | yamllint is Python; cache before install |
| 3 | **Install yamllint** | — | Broadest linter; runs first to catch YAML syntax before tool-specific validators |
| 4 | **YAML lint** | — | Uses `.yamllint.yml` if present; otherwise defaults |
| 5 | **hadolint** | — | Recursive Dockerfile linter; `failure-threshold: warning` blocks on warnings+ |
| 6 | **Detect Terraform** | — | Sets `has_terraform` output by checking for `*.tf` files |
| 7 | **Restore Terraform cache** | `has_terraform` | Provider plugin cache before `init` |
| 8 | **`mkdir -p ~/.terraform.d/plugin-cache`** | `has_terraform` | Must exist before Terraform writes to it |
| 9 | **setup-terraform** | `has_terraform` | Installs `terraform` binary |
| 10 | **`terraform init -backend=false`** | `has_terraform` | Downloads providers into plugin cache; `-backend=false` skips remote state |
| 11 | **`terraform validate`** | `has_terraform` | Validates HCL syntax and module references |
| 12 | **Restore TFLint cache** | `has_terraform` | TFLint plugin cache before setup |
| 13 | **setup-tflint + `tflint --recursive`** | `has_terraform` | Style and best-practice lint for all `*.tf` files |
| 14 | **Detect Helm** | — | Sets `has_helm` by checking for `Chart.yaml` |
| 15 | **Restore Helm cache** | `has_helm` | Chart dependency cache |
| 16 | **`helm lint`** | `has_helm` | Validates chart structure and templating |
| 17 | **Detect Jenkinsfile** | — | Sets `has_jenkinsfile` by checking for `Jenkinsfile` |
| 18 | **Jenkinsfile validate** | `has_jenkinsfile` | Declarative-linter via Docker; validates pipeline DSL syntax |
| 19 | **Upload `devops-build`** | `always()` | Persists all IaC files for audit download |

### Why `terraform init -backend=false`?

Lab repos do not have access to remote Terraform backends (S3, Azure Blob, GCS). Using `-backend=false` skips backend initialisation so the step succeeds purely as a provider download step for caching and validation purposes.

---

## 11. `shared/cache-warmer.yml`

**Role:** Runs *before* the profile job in `pipeline.yml` to pre-populate every Actions cache the profile will later restore.

### Why caching needs a dedicated warm-up job

GitHub Actions cache saving happens at **job end**, not step end. The flow is:

```
restore-cache step → run install → job finishes → Actions saves updated cache
```

On the very first run there is nothing in the cache. The `cache-warmer` job intentionally front-runs the profile job so that by the time the profile job hits its cache-restore steps, the warm data is already saved. On all subsequent runs the profile job gets immediate cache hits and skips dependency downloads entirely.

### Critical contract

Every cache key in `cache-warmer.yml` must be **byte-for-byte identical** to the corresponding key in the profile workflow. A single character difference stores the warm cache under a wrong key and the profile never finds it.

```
cache-warmer.yml key:     {OS}-maven-{hash(**/pom.xml)}
profiles/java.yml key:    {OS}-maven-{hash(**/pom.xml)}   ← must match exactly
```

### Per-profile cache warm-up details

#### Java

1. `setup-java` (Temurin, same version as `java.yml`)
2. Restore Maven wrapper cache
3. Restore Maven repo cache
4. **`mvn dependency:go-offline dependency:resolve-plugins`** — downloads all transitive dependencies into `~/.m2/repository/` so the cache is fully populated before the job saves it
5. Prune SNAPSHOT artifacts (same as `java.yml`)

#### Python

1. `setup-python` with `cache: pip`
2. Restore explicit pip cache
3. Restore venv cache
4. **`pip install pytest pytest-cov flake8 requests`** + `pip install -r requirements.txt` (if cache miss)

#### JavaScript

1. Detect package manager + E2E tool (same logic as `javascript.yml`)
2. Set up PM extras
3. Restore 4 PM-specific dep caches (npm / yarn / pnpm / bun paths)
4. Restore 2 E2E browser binary caches
5. Frozen install
6. **E2E binary install only when `cache-hit != 'true'`** — avoids re-downloading browser binaries when the E2E cache was hit

#### DevOps

1. Pip cache → install yamllint
2. Detect `has_terraform`, `has_tflint`, `has_helm`
3. Terraform: restore cache → `mkdir plugin-cache` → setup → `terraform init -backend=false`
4. TFLint: restore cache → setup → `tflint --init`
5. Helm: restore cache → `helm dependency update` for each chart (cache miss only)

### Warm-up summary

An `if: always()` step at the end prints `HIT`, `WARMED`, or `SKIP` for each cache, making it easy to diagnose whether warming is working.

---

## 12. `shared/trivy.yml`

**Role:** SARIF upload to the GitHub Security tab. This is *not* the pipeline-failing scan — that runs inside each profile workflow.

### Why two separate Trivy scans?

| Scan | Location | Format | Exit code | Purpose |
|------|----------|--------|-----------|---------|
| Profile scan | `profiles/*.yml` | `table` | `1` (fail on CRITICAL/HIGH) | Block the merge |
| Shared scan | `shared/trivy.yml` | `sarif` | `0` (never fail) | Persistent Security tab alerts |

Combining them would either suppress Security tab alerts on passing builds or double-fail already-blocked pipelines. Keeping them separate means the Security tab is always updated — even when the pipeline-failing scan has already stopped the build.

### Three-block structure

#### Block 1 — Dependency/IaC SARIF

- **Non-devops profiles**: `scan-type: fs`, `scanners: vuln`, `vuln-type: library` → `trivy-results.sarif`
- **devops profile**: `scan-type: config`, scanners: `misconfig,secret` → `trivy-results.sarif`
- Upload → Security tab category `trivy-{profile}` (e.g. `trivy-java`, `trivy-python`)

#### Block 2 — Dockerfile misconfig and secret scan

Runs `if: always()` across all profiles — detects all `Dockerfile*` files in the repo, then runs:

```
scan-type: config
scanners: misconfig,secret
skip-dirs: .git,node_modules,dist,build,.next,.nuxt,.terraform
```

Upload → Security tab category `trivy-dockerfile-misconfig`

This catches hardcoded secrets, `ADD` vs `COPY` best practices, `USER root` without later switching, exposed sensitive ports, and similar Dockerfile anti-patterns across **all profiles** — not just DevOps.

#### Block 3 — Base image OS CVE scan

The most thorough block. For each Dockerfile detected:

1. Extract `FROM` lines, skip `scratch` and `AS <name>` multi-stage aliases
2. For each unique base image:
   - `trivy image` with `format: table` + `exit-code: 1` → **hard gate** (CRITICAL/HIGH block pipeline)
   - `trivy image` with `format: sarif` + `exit-code: 0` → per-image SARIF file in `sarif-images/`
3. Upload entire `sarif-images/` directory → Security tab category `trivy-image-cve`

This means a `ubuntu:20.04` CVE will appear as an alert in the Security tab and also fail the pipeline if its severity is CRITICAL or HIGH.

### GitHub Security tab categories

| Category | Trigger condition |
|----------|------------------|
| `trivy-java` | `profile == java` |
| `trivy-python` | `profile == python` |
| `trivy-javascript` | `profile == javascript` |
| `trivy-devops` | `profile == devops` |
| `trivy-dockerfile-misconfig` | Any profile with Dockerfiles |
| `trivy-image-cve` | Any profile with Dockerfiles |

### Required permissions

```yaml
permissions:
  security-events: write   # upload SARIF to Security tab
  contents: read
```

These are declared on the `trivy-sarif` job rather than at workflow level so callers do not need to grant elevated permissions in their own workflows.

---

## 13. `shared/sonarqube.yml`

**Role:** SonarQube / SonarCloud code quality analysis with quality gate polling.

### Why `fetch-depth: 0`

```yaml
- uses: actions/checkout@v4
  with:
    fetch-depth: 0
```

The default `actions/checkout` performs a shallow clone (depth 1). SonarQube needs the **full git history** to:

- Calculate "new code" correctly on PR analysis (blame data)
- Compute accurate "lines added since reference branch" metrics
- Track issue age and first-introduction commit for each finding

Without `fetch-depth: 0`, every finding appears as "new" and blame metrics are wrong.

### Dynamic project key

```bash
PROJECT_KEY="${{ github.repository_owner }}_${{ github.event.repository.name }}"
```

This means every lab repo **self-registers** in SonarQube on its first run — no manual project creation required. The underscore separator is the SonarQube convention for org-scoped keys. The same key is used consistently across branches and PRs so history accumulates in one place.

Override with `project-key` input if the repo needs a custom key (e.g. for an existing project).

### Artifact download pattern

```yaml
- uses: actions/download-artifact@v4
  with:
    pattern: "*-build"
    merge-multiple: true
    continue-on-error: true
```

The wildcard `*-build` matches whichever artifact was produced by the profile job:

| Profile | Artifact | Contents |
|---------|----------|----------|
| java | `java-build` | `target/` + `target/site/jacoco/jacoco.xml` |
| python | `python-build` | `coverage.xml` |
| javascript | `js-build` | `dist/` / `build/` / `.next/` + `coverage/` |
| devops | `devops-build` | `.tf`, `Dockerfile`, `.yml`, `Jenkinsfile` |

`merge-multiple: true` flattens all matched artifacts into the working directory. `continue-on-error: true` ensures the SonarQube job does not fail if the profile job did not produce an artifact (e.g. on a compile failure).

### Quality gate polling

```yaml
- uses: SonarSource/sonarqube-quality-gate-action@master
  with:
    timeout-minutes: 5
  if: always()
```

`sonarqube-scan-action` submits the analysis and returns immediately — the analysis runs asynchronously on the SonarQube server. `sonarqube-quality-gate-action` polls until the background task completes and the gate is evaluated, then fails the step if the gate is **RED**. `timeout-minutes: 5` prevents the job hanging indefinitely if the server is slow or offline. `if: always()` ensures the gate check runs even if the scan submission step failed.

### Dual SONAR_HOST_URL support

```yaml
env:
  SONAR_HOST_URL: ${{ secrets.SONAR_HOST_URL || inputs.sonar-host-url }}
```

The host URL can be supplied either as an org-level secret (preferred for self-hosted SonarQube) or as a workflow input (useful when calling the workflow directly). The secret takes precedence.

---

## 14. `shared/copilot-review.yml`

**Role:** GitHub Copilot automated PR review.

Currently a placeholder — the `workflow_call` trigger and `review-level` input are defined, but job logic has not yet been implemented.

| Input | Default | Description |
|-------|---------|-------------|
| `review-level` | `summary` | `summary` or `detailed` |

---

## 15. Caching architecture

All caches use a **two-level key strategy**:

- **Primary key**: Exact match on OS + tool + lock file hash. Hits when nothing has changed.
- **Restore key**: Prefix match (no hash). Hits when lock files changed; returns the nearest prior cache so the install step only downloads deltas.

### Cache inventory

| Cache | Tool | Path | Primary key | Used by |
|-------|------|------|-------------|---------|
| Maven wrapper | Maven | `~/.m2/wrapper/` | `{OS}-mvn-wrapper-{hash(.mvn/wrapper/maven-wrapper.properties)}` | java, cache-warmer |
| Maven repository | Maven | `~/.m2/repository/` | `{OS}-maven-{hash(**/pom.xml)}` | java, cache-warmer |
| pip wheel cache | pip | `~/.cache/pip` | `{OS}-pip-{pyver}-{hash(**/requirements*.txt)}` | python, cache-warmer |
| Python venv | pip | `.venv/` | `{OS}-venv-{pyver}-{hash(**/requirements*.txt)}` | python, cache-warmer |
| npm modules | npm | `~/.npm` | `{OS}-node-npm-{hash(**/package-lock.json)}` | javascript, cache-warmer |
| yarn modules | yarn | `~/.yarn/cache` | `{OS}-node-yarn-{hash(**/yarn.lock)}` | javascript, cache-warmer |
| pnpm store | pnpm | `~/.pnpm-store` | `{OS}-node-pnpm-{hash(**/pnpm-lock.yaml)}` | javascript, cache-warmer |
| bun cache | bun | `~/.bun/install/cache` | `{OS}-bun-{hash(**/bun.lockb)}` | javascript, cache-warmer |
| Playwright browsers | Playwright | `~/.cache/ms-playwright` | `{OS}-playwright-{hash(**/package-lock.json)}` | javascript, cache-warmer |
| Cypress binaries | Cypress | `~/.cache/Cypress` | `{OS}-cypress-{hash(**/package-lock.json)}` | javascript, cache-warmer |
| pip (devops) | pip | `~/.cache/pip` | `{OS}-devops-pip` | devops, cache-warmer |
| Terraform providers | Terraform | `~/.terraform.d/plugin-cache` | `{OS}-terraform-{hash(**/*.tf)}` | devops, cache-warmer |
| TFLint plugins | TFLint | `~/.tflint.d/plugins` | `{OS}-tflint-{hash(.tflint.hcl)}` | devops, cache-warmer |
| Helm charts | Helm | `~/.cache/helm` | `{OS}-helm-{hash(**/Chart.lock)}` | devops, cache-warmer |

---

## 16. Security scanning architecture

The pipeline has three independent layers of security scanning:

```
Layer 1 — Pipeline gate (inside profile workflows)
  Tool:      Trivy fs scan
  Format:    table
  exit-code: 1
  Effect:    Fails the profile job on CRITICAL/HIGH CVEs; blocks the merge

Layer 2 — Security tab SARIF (shared/trivy.yml, Block 1)
  Tool:      Trivy fs scan (dependency CVE) or config scan (IaC/devops)
  Format:    sarif
  exit-code: 0
  Effect:    Creates persistent alerts in GitHub Security tab

Layer 3 — Dockerfile scanning (shared/trivy.yml, Blocks 2 and 3)
  Block A — Misconfig + secrets
    Tool:      Trivy config scan on Dockerfile paths
    Format:    sarif
    exit-code: 0
    Effect:    Security tab alerts (category: trivy-dockerfile-misconfig)

  Block B — Base image OS CVEs (per unique base image in FROM lines)
    Tool:      trivy image (pulls image, scans OS packages)
    Format:    table (exit-code 1) AND sarif per image (exit-code 0)
    Effect:    Fails pipeline on CRITICAL/HIGH base image CVEs
               + Security tab alerts (category: trivy-image-cve)
```

Layer 1 and Layer 2 scan the **same files** (the repo source tree) but produce different output formats for different audiences. Layer 3 operates on **container images** and is completely independent of the tech profile — any repo with a Dockerfile gets image CVE scanning regardless of whether it is a Java, Python, JavaScript, or DevOps project.

---

## 17. Inputs reference

### `pipeline.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `java-version` | no | `21` | JDK version (Temurin) |
| `python-version` | no | `3.12` | Python version |
| `node-version` | no | `20` | Node.js version |
| `dockerfile-path` | no | `Dockerfile` | Dockerfile path for hadolint fallback |
| `terraform-version` | no | `latest` | Terraform version |
| `sonar-project-key` | no | `""` | SonarQube project key override |

### `profiles/java.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `java-version` | no | `21` | JDK version |
| `trivy-severity` | no | `CRITICAL,HIGH` | Severity levels that fail the build |

### `profiles/python.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `python-version` | no | `3.12` | Python version |
| `trivy-severity` | no | `CRITICAL,HIGH` | Severity levels that fail the build |

### `profiles/javascript.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `node-version` | no | `20` | Node.js version |
| `package_manager` | no | `auto` | PM override: `npm\|yarn\|pnpm\|bun\|auto` |
| `framework` | no | `auto` | Framework override: `nextjs\|angular\|remix\|nuxt\|vue\|react\|vanilla\|auto` |
| `trivy-severity` | no | `CRITICAL,HIGH` | Severity levels that fail the build |

### `profiles/devops.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `dockerfile-path` | no | `Dockerfile` | hadolint fallback path |
| `terraform-version` | no | `latest` | Terraform version |
| `tflint-version` | no | `latest` | TFLint version |
| `yamllint-strict` | no | `false` | Treat yamllint warnings as errors |

### `shared/trivy.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `profile` | **yes** | — | `java\|python\|javascript\|devops`; controls scan mode |

### `shared/sonarqube.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `sonar-host-url` | no | `https://sonarcloud.io` | SonarQube server URL |
| `project-key` | no | `""` | Override SonarQube project key |

### `shared/cache-warmer.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `profile` | **yes** | — | Profile whose caches to warm |
| `java-version` | no | `21` | Must match `java.yml` default |
| `python-version` | no | `3.12` | Must match `python.yml` default |
| `node-version` | no | `20` | Must match `javascript.yml` default |
| `terraform-version` | no | `latest` | Must match `devops.yml` default |
| `working-directory` | no | `.` | Root directory containing manifests |

### `shared/copilot-review.yml`

| Input | Required | Default | Description |
|-------|----------|---------|-------------|
| `review-level` | no | `summary` | `summary` or `detailed` |

---

## 18. Secrets reference

| Secret | Required by | Description |
|--------|-------------|-------------|
| `SONAR_TOKEN` | `sonarqube.yml` | SonarQube / SonarCloud API token |
| `SONAR_HOST_URL` | `sonarqube.yml` | Optional: self-hosted SonarQube server URL |

### How to set up secrets

1. Go to **Settings → Secrets and variables → Actions** in the lab repository (or at org level for shared secrets)
2. Click **New repository secret** (or **New organization secret**)
3. Add `SONAR_TOKEN` with the token from your SonarQube / SonarCloud account

Because `pipeline.yml` uses `secrets: inherit`, all secrets available in the calling repository are automatically forwarded to every called workflow — you do not need to enumerate them explicitly.

---

## 19. Repository access control setup

### Making workflows accessible to lab repos

This repository must be set to **internal** (for org-owned private repos) or **public** so that lab repos in the same organisation can reference its workflows.

1. **Settings → General → Danger Zone → Change repository visibility** → set to `Internal` or `Public`

### Restricting which repositories can call these workflows

1. **Settings → Actions → General → Access policy**
2. Select **"Accessible from repositories in the `<org>` organization"**

This prevents workflows in repositories outside the org from calling into your shared pipeline.

### Grant workflow token write permissions

For `shared/trivy.yml` to upload SARIF to the Security tab, the `GITHUB_TOKEN` in each lab repo needs `security-events: write`. The `trivy-sarif` job declares this permission explicitly, but the calling repo must not restrict `GITHUB_TOKEN` permissions to read-only.

Check: **Settings → Actions → General → Workflow permissions** → set to **"Read and write permissions"** (or use fine-grained token permissions).

---

## 20. Contributing

### Adding a step to an existing profile

1. Branch off `main`
2. Edit the relevant `profiles/*.yml` or `shared/*.yml`
3. If you add a new cache, add the matching key to `shared/cache-warmer.yml`
4. Open a pull request — Copilot review will post automated feedback
5. A maintainer merges after review

### Adding a new profile

1. Create `profiles/<name>.yml` following the same structure as the existing profiles
2. Add a new job in `pipeline.yml`:
   ```yaml
   <name>:
     needs: [read-profile, cache-warmer]
     if: needs.read-profile.outputs.profile == '<name>'
     uses: ./.github/workflows/profiles/<name>.yml
     secrets: inherit
   ```
3. Update the trivy/sonarqube/copilot-review `needs:` arrays to include `<name>`
4. Add warm-up logic to `shared/cache-warmer.yml` for the new profile
5. Update the profile table in the [ci-profile.yml contract](#3-ci-profileyml-contract) section of this README

### Versioning

Changes to `shared/` workflows take effect **immediately** for all callers on their next run because callers reference `@main`. Breaking changes to inputs should be:

1. Released as a new tag (e.g. `v2`)
2. Announced to apprenticeship mentors
3. Lab repos updated to reference the new tag (e.g. `@v2`)

### Testing workflow changes locally

Use [act](https://github.com/nektos/act) to run workflows locally before pushing:

```bash
act push -W .github/workflows/pipeline.yml \
  --secret-file .env.secrets \
  --input profile=java
```

---

## 21. Lab repository templates

The `templates/` directory contains ready-to-use starter files for each profile. Copy the contents of the relevant profile folder into a new lab repository to get a working CI pipeline with zero configuration.

### Template layout

```
templates/
├── java/
│   ├── ci-profile.yml                          ← tells pipeline.yml to use the java profile
│   ├── .github/workflows/ci.yml                ← calls pipeline.yml on push / pull_request
│   ├── pom.xml                                 ← Maven project with JaCoCo + Checkstyle pre-configured
│   └── src/
│       ├── main/java/com/example/App.java       ← starter application class
│       └── test/java/com/example/AppTest.java   ← starter JUnit 5 tests
├── python/
│   ├── ci-profile.yml
│   ├── .github/workflows/ci.yml
│   ├── requirements.txt                         ← empty starter; add project deps here
│   ├── main.py                                  ← starter module
│   └── test_main.py                             ← starter pytest tests
├── javascript/
│   ├── ci-profile.yml
│   ├── .github/workflows/ci.yml
│   ├── package.json                             ← Jest + ESLint configured
│   ├── .eslintrc.json                           ← ESLint config (eslint:recommended)
│   └── src/
│       ├── index.js                             ← starter module
│       └── index.test.js                        ← starter Jest tests
└── devops/
    ├── ci-profile.yml
    ├── .github/workflows/ci.yml
    ├── .yamllint.yml                            ← yamllint config (120-char lines, strict truthy)
    └── Dockerfile                               ← commented best-practice Dockerfile starter
```

### How to use a template

1. Create a new repository on GitHub (empty).
2. Copy the contents of the matching `templates/<profile>/` folder into the new repository root:

   ```bash
   # Example for a Java lab
   cp -r templates/java/. /path/to/new-lab-repo/
   ```

3. Open `.github/workflows/ci.yml` and replace `<YOUR-ORG>` with the GitHub organisation name:

   ```yaml
   uses: my-org/shared-workflows/.github/workflows/pipeline.yml@main
   ```

4. Push to `main`. The pipeline runs automatically.

### What each template provides

#### Java template

| File | Purpose |
|------|---------|
| `ci-profile.yml` | Sets `profile: java` so `pipeline.yml` routes to `profiles/java.yml` |
| `.github/workflows/ci.yml` | Triggers on push/PR; passes `secrets: inherit` |
| `pom.xml` | Maven project set to Java 21; includes **JaCoCo** (coverage for SonarQube) and **Checkstyle** (Google Java Style, required by the lint step) and **Surefire** (JUnit 5 runner) |
| `src/main/java/com/example/App.java` | Minimal `greet()` implementation to verify the build works end-to-end |
| `src/test/java/com/example/AppTest.java` | Three JUnit 5 tests covering `greet()`; enough to produce a non-zero JaCoCo report |

> **Customise:** Change `groupId`, `artifactId`, and `version` in `pom.xml`. Replace `App.java` and `AppTest.java` with your implementation.

#### Python template

| File | Purpose |
|------|---------|
| `ci-profile.yml` | Sets `profile: python` |
| `.github/workflows/ci.yml` | Triggers on push/PR |
| `requirements.txt` | Empty starter with comments explaining what to add (pytest/flake8 are pre-installed by CI and should NOT be listed here) |
| `main.py` | Minimal `greet()` function with type hints and docstring (satisfies flake8 out of the box) |
| `test_main.py` | Three pytest tests; generates `coverage.xml` for SonarQube |

> **Note:** The CI pipeline pre-installs `pytest`, `pytest-cov`, `flake8`, and `requests`. Do not add these to `requirements.txt` — they will already be available in the CI environment.

#### JavaScript template

| File | Purpose |
|------|---------|
| `ci-profile.yml` | Sets `profile: javascript` |
| `.github/workflows/ci.yml` | Triggers on push/PR; includes commented `with:` block for `package_manager` and `framework` overrides |
| `package.json` | npm project with **Jest** (test runner, auto-detected by the pipeline) and **ESLint** (auto-detected via `.eslintrc.json`) |
| `.eslintrc.json` | `eslint:recommended` ruleset with `node` + `jest` environments enabled |
| `src/index.js` | Minimal `greet()` function |
| `src/index.test.js` | Three Jest tests with coverage; uses `--coverage` flag wired in `package.json` |

> **Framework upgrade:** To use React, Next.js, Vue, etc., install the framework package and add its dependencies to `package.json`. The pipeline's detection step will automatically pick up the framework from `package.json` dependencies.

#### DevOps template

| File | Purpose |
|------|---------|
| `ci-profile.yml` | Sets `profile: devops` |
| `.github/workflows/ci.yml` | Triggers on push/PR; includes commented `terraform-version` and `dockerfile-path` overrides |
| `.yamllint.yml` | yamllint config: 120-char line limit (warning only), strict `truthy` values, 2-space indentation |
| `Dockerfile` | Heavily commented best-practice Dockerfile: pinned base image, single-layer `RUN`, non-root `USER`, `COPY --chown`, exec-form `CMD` — designed to pass hadolint without warnings |

> **Terraform / Helm:** The devops pipeline automatically detects `*.tf` files and `Chart.yaml`. Add them to the repository root and the pipeline will run `terraform validate`, `tflint`, and `helm lint` automatically — no workflow changes needed.
