# DevOps Lab Repository

This template gives you the files that power the CI pipeline and your local tooling.
Set up your project **however you like** — the pipeline detects what infrastructure tools
you are using and runs the relevant checks.

---

## Create a public repository

When you create your GitHub repo, choose **Public**.  
The CI pipeline reports scan results as pull-request comments; those only render correctly
on public repos.

---

## What the pipeline does

When you push or open a pull request the pipeline will:

1. Run YAML linting across your repository.
2. Scan Dockerfiles with Hadolint (if any Dockerfiles are present).
3. Scan container images with Trivy (if a `Dockerfile` is present — builds and scans it).
4. Lint Helm charts with `helm lint` (if a `Chart.yaml` is present).
5. Run `terraform validate` (if `.tf` files are present).
6. Detect a `Jenkinsfile` and note it for review.
7. Lint all `.sh` files with ShellCheck (if any shell scripts are present).
8. Lint all `.py` utility scripts with flake8 (if any Python files are present).
9. Scan for secrets and vulnerabilities across all files.

You don't need to configure any of this — it runs based on what files exist in your repo.

---

## What NOT to touch

These files are shared infrastructure. Changing them may break the pipeline for everyone.

| File / folder | Why it must stay |
|---|---|
| `.github/ci.yml` | Calls the central workflow — do not edit or remove it. |
| `ci-profile.yml` | Tells the pipeline which profile to use — do not rename or move it. |
| `.yamllint.yml` | Shared YAML style rules — do not remove rules (you can relax them if needed). |
| `.vscode/extensions.json` | Recommended extensions list — do not remove entries. |
| `.vscode/settings.json` | Workspace defaults — do not remove entries (you can add your own). |

Everything else is yours.

---

## Setting up your project

Add your infrastructure code — Dockerfiles, Terraform, Helm charts, Kubernetes manifests,
pipeline definitions — wherever makes sense for your project.  
The pipeline will detect what is there and run the appropriate checks automatically.

---

## Pre-commit hooks (recommended)

A `.pre-commit-config.yaml` is included — it runs small checks locally before each commit
so obvious issues never reach CI. You are not required to use it, but it is highly
recommended, especially in a team.

```bash
pip install pre-commit
pre-commit install        # one-time setup per clone
```

After that, hooks run automatically on every `git commit`.
Run them manually any time with `pre-commit run --all-files`.

The default hooks cover YAML linting, Dockerfile linting, secret detection, and general
hygiene. Edit `.pre-commit-config.yaml` freely — see the commented examples in the file
for tool-specific hooks (Terraform fmt/validate, etc.) you can opt into.

---

## VS Code extensions

`.vscode/extensions.json` lists recommended extensions.  
When you open the repo VS Code will prompt you to install them — accept the prompt for the
best experience. They are suggestions only; nothing breaks if you skip them.

---

## Questions

Raise an issue in the shared-workflows repository or ask your coach.
