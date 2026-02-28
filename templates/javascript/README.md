# JavaScript / TypeScript Lab Repository

This template gives you the files that power the CI pipeline and your local tooling.
Set up your project **however you like** — the pipeline will detect your package manager
and test framework automatically.

---

## Create a public repository

When you create your GitHub repo, choose **Public**.  
The CI pipeline reports coverage and quality metrics as pull-request comments; those only
render correctly on public repos.

---

## What the pipeline does

When you push or open a pull request the pipeline will:

1. Detect your package manager — npm, yarn, pnpm, or bun — from your lockfile.
2. Restore the dependency cache and install packages.
3. Detect your test runner — Jest, Vitest, Mocha, Jasmine, or Playwright — and run it.
4. Report code coverage as a PR comment (only if tests produce a coverage report — skipped otherwise).
5. Scan for secrets and security issues.
6. Run static analysis (SonarQube runs automatically if the org secret is present — you do not need to configure it).

You don't need to tell the pipeline anything; just build your app normally and push.

---

## What NOT to touch

These files are shared infrastructure. Changing them may break the pipeline for everyone.

| File / folder | Why it must stay |
|---|---|
| `.github/ci.yml` | Calls the central workflow — do not edit or remove it. |
| `ci-profile.yml` | Tells the pipeline which profile to use — do not rename or move it. |
| `.vscode/extensions.json` | Recommended extensions list — do not remove entries. |
| `.vscode/settings.json` | Workspace defaults — do not remove entries (you can add your own). |

Everything else is yours.

---

## Setting up your project

Create your `package.json` with whatever dependencies, scripts, and frameworks your team
chooses. The pipeline reads your `test` and `coverage` scripts — name them as you normally
would.

There is no required folder structure beyond what your framework expects.

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

The default hooks cover whitespace, line endings, secret detection, and merge conflict
markers. Edit `.pre-commit-config.yaml` freely — add, remove, or swap hooks to suit
your project. See the commented examples in the file for linting/formatting options
(ESLint, Prettier, etc.) tied to your local install.

---

## VS Code extensions

`.vscode/extensions.json` lists recommended extensions.  
When you open the repo VS Code will prompt you to install them — accept the prompt for the
best experience. They are suggestions only; nothing breaks if you skip them.

---

## Questions

Raise an issue in the shared-workflows repository or ask your coach.
