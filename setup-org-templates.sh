#!/usr/bin/env bash
# setup-org-templates.sh
# ──────────────────────────────────────────────────────────────────────────────
# Creates or deletes GitHub template repositories in a target organisation.
#
# CREATE (default): copies local template folders (devops, java, javascript,
# python), substitutes the <YOUR-ORG> placeholder, pushes each as a private
# repo, and marks it as a GitHub template repository.
#
# DELETE (--delete): permanently removes those same four repositories from the
# remote organisation. Local files are never touched.
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail

# ── Constants ─────────────────────────────────────────────────────────────────

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_TEMPLATES_DIR="$SCRIPT_DIR/templates"

# Map: template folder name → repository name in the org
declare -A TEMPLATES=(
  [devops]="template-devops"
  [java]="template-java"
  [javascript]="template-javascript"
  [python]="template-python"
)

# ── Helper functions ───────────────────────────────────────────────────────────

help() {
  cat <<EOF

USAGE
  $(basename "$0") [OPTIONS] <org-name>

DESCRIPTION
  For each of the four CI profile templates (devops, java, javascript, python)
  this script:
    1. Copies the template folder into a temporary working directory.
    2. Replaces every occurrence of the placeholder '<YOUR-ORG>' with the
       the supplied organisation name.
    3. Initialises a git repository (branch: main) and makes an initial commit.
    4. Creates a private repository in the target GitHub organisation and pushes.
    5. Marks the repository as a GitHub template repository via the API so that
       it can be used as a starting point for new repos on GitHub.

ARGUMENTS
  <org-name>           (required) The GitHub organisation where the four
                       template repositories will be created.
                       Example: my-github-org

OPTIONS
  -t, --templates-dir <path>
                       Path to the directory that contains the template
                       sub-folders (devops/, java/, javascript/, python/).
                       Only relevant in create mode.

                       Discovery order:
                         1. The value of this flag, if provided.
                         2. A 'templates/' folder next to this script
                            (auto-detected via BASH_SOURCE), which is the
                            default when the script lives inside the
                            shared-workflows repository.

                       Use this flag when you invoke the script from a
                       different location or have the templates elsewhere:
                         $(basename "$0") -t /path/to/templates my-org

  -d, --delete         Delete mode.  Permanently removes the four template
                       repositories from the remote organisation instead of
                       creating them.  Prompts for confirmation unless --yes
                       is also supplied.  Local files are never modified.

                       Repos that will be deleted:
                         <org>/template-devops
                         <org>/template-java
                         <org>/template-javascript
                         <org>/template-python

  -y, --yes            Skip the interactive confirmation prompt in delete
                       mode.  Intended for non-interactive / CI use.
                       Has no effect in create mode.

  -h, --help           Show this help message and exit.

PREREQUISITES
  The following tools must be installed and available on your PATH:

  git   Standard git CLI.  Used to initialise the repo and make the
        initial commit inside each temp working directory.
        Install: https://git-scm.com/downloads

  gh    GitHub CLI.  Used to:
          • Create each remote repository  (gh repo create)  [create mode]
          • Mark each repo as a template   (gh api PATCH)     [create mode]
          • Delete remote repositories     (gh repo delete)   [delete mode]
          • Confirm the authenticated user (gh api /user)     [both modes]
        Install: https://cli.github.com
        Minimum scope required: 'repo' (full control of private repositories)

  Before running, authenticate with:
    gh auth login
  Verify authentication with:
    gh auth status

  sed, grep  Standard POSIX utilities — present on all Linux/macOS systems.

EXAMPLES
  # Create — auto-discover the templates/ folder next to the script:
  ./setup-org-templates.sh my-github-org

  # Create — provide an explicit path to the templates directory:
  ./setup-org-templates.sh --templates-dir /opt/ci-templates my-github-org

  # Create — short form of the flag:
  ./setup-org-templates.sh -t /opt/ci-templates my-github-org

  # Delete — interactively confirm before removing the four remote repos:
  ./setup-org-templates.sh --delete my-github-org

  # Delete — skip confirmation (non-interactive / CI):
  ./setup-org-templates.sh --delete --yes my-github-org

OUTPUT REPOS
  The following four repositories will be created in <org-name>:
    <org-name>/template-devops
    <org-name>/template-java
    <org-name>/template-javascript
    <org-name>/template-python

  Each repo will have:
    • Visibility  : private
    • Branch      : main
    • Template    : true  (usable as a GitHub repository template)

VERIFICATION
  List the created repos:
    gh repo list <org-name> --limit 10

  Check the template flag on a specific repo:
    gh api /repos/<org-name>/template-devops --jq '.is_template'

EOF
  exit 0
}

info()    { echo "  [•] $*"; }
success() { echo "  [✓] $*"; }
error()   { echo "  [✗] $*" >&2; }
warn()    { echo "  [!] $*"; }

# ── Delete command ────────────────────────────────────────────────────────────

cmd_delete() {
  echo ""
  warn "DELETE MODE — the following remote repositories will be permanently removed:"
  echo ""
  for PROFILE in "${!TEMPLATES[@]}"; do
    echo "      • $ORG_NAME/${TEMPLATES[$PROFILE]}"
  done
  echo ""
  warn "This cannot be undone. Local files will not be affected."
  echo ""

  if [[ "$SKIP_CONFIRM" == false ]]; then
    read -r -p "  Type the organisation name to confirm: " CONFIRM
    if [[ "$CONFIRM" != "$ORG_NAME" ]]; then
      error "Confirmation did not match '$ORG_NAME'. Aborting."
      exit 1
    fi
    echo ""
  fi

  for PROFILE in "${!TEMPLATES[@]}"; do
    REPO_NAME="${TEMPLATES[$PROFILE]}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Deleting : $ORG_NAME/$REPO_NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    if gh api "/repos/$ORG_NAME/$REPO_NAME" &>/dev/null; then
      gh repo delete "$ORG_NAME/$REPO_NAME" --yes
      success "Deleted $ORG_NAME/$REPO_NAME"
    else
      warn "Repo not found, skipping: $ORG_NAME/$REPO_NAME"
    fi
    echo ""
  done

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  All template repos removed from $ORG_NAME."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
}

# ── Argument parsing ──────────────────────────────────────────────────────────

ORG_NAME=""
TEMPLATES_DIR="$DEFAULT_TEMPLATES_DIR"
DELETE_MODE=false
SKIP_CONFIRM=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      help
      ;;
    -t|--templates-dir)
      [[ -z "${2:-}" ]] && { error "--templates-dir requires a path argument."; exit 1; }
      TEMPLATES_DIR="$(cd "$2" && pwd)"
      shift 2
      ;;
    -d|--delete)
      DELETE_MODE=true
      shift
      ;;
    -y|--yes)
      SKIP_CONFIRM=true
      shift
      ;;
    -*)
      error "Unknown option: $1  (run with --help for usage)"
      exit 1
      ;;
    *)
      [[ -n "$ORG_NAME" ]] && { error "Unexpected argument: $1  (org-name already set to '$ORG_NAME')"; exit 1; }
      ORG_NAME="$1"
      shift
      ;;
  esac
done

# ── Prerequisite checks ────────────────────────────────────────────────────────

[[ -z "$ORG_NAME" ]] && {
  error "Organisation name is required."
  echo "       Run '$(basename "$0") --help' for usage."
  exit 1
}

if [[ "$DELETE_MODE" == false ]]; then
  [[ -d "$TEMPLATES_DIR" ]] || {
    error "Templates directory not found: $TEMPLATES_DIR"
    echo "       Use -t / --templates-dir to specify its location."
    exit 1
  }
fi

if [[ "$DELETE_MODE" == false ]]; then
  REQUIRED_CMDS=(git gh sed grep)
else
  REQUIRED_CMDS=(gh)
fi

for cmd in "${REQUIRED_CMDS[@]}"; do
  command -v "$cmd" &>/dev/null || {
    error "'$cmd' is not installed or not in PATH."
    exit 1
  }
done

if ! gh auth status &>/dev/null; then
  error "Not authenticated with the GitHub CLI."
  echo "       Run 'gh auth login' first."
  exit 1
fi

info "Authenticated GitHub user: $(gh api /user --jq '.login')"
echo ""

# Dispatch to delete mode if requested
[[ "$DELETE_MODE" == true ]] && cmd_delete

# ── Main loop (create mode) ───────────────────────────────────────────────────

for PROFILE in "${!TEMPLATES[@]}"; do
  REPO_NAME="${TEMPLATES[$PROFILE]}"
  SRC_DIR="$TEMPLATES_DIR/$PROFILE"
  WORK_DIR="$(mktemp -d)"

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "  Profile : $PROFILE"
  echo "  Repo    : $ORG_NAME/$REPO_NAME"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  # Guarantee cleanup of the temp directory if the script exits or errors
  # mid-iteration. The trap is reset at the end of each iteration.
  trap 'rm -rf "$WORK_DIR"' EXIT

  # 1. Copy the full template (including hidden files/dirs) into the temp dir
  info "Copying template files..."
  cp -r "$SRC_DIR/." "$WORK_DIR/"

  # 2. Replace <YOUR-ORG> placeholder in every file that contains it
  info "Substituting <YOUR-ORG> → $ORG_NAME..."
  while IFS= read -r file; do
    sed -i "s|<YOUR-ORG>|$ORG_NAME|g" "$file"
    info "  Patched: ${file#"$WORK_DIR/"}"
  done < <(grep -rl '<YOUR-ORG>' "$WORK_DIR" 2>/dev/null || true)

  # 3. Initialise a git repository on the main branch and make the first commit
  info "Initialising git repository..."
  git -C "$WORK_DIR" init -b main          -q
  git -C "$WORK_DIR" add .
  git -C "$WORK_DIR" commit -m "chore: initial template for $PROFILE profile" -q
  success "Git repository initialised."

  # 4. Create the private remote repo and push (gh wraps POST /orgs/{org}/repos)
  info "Creating remote repo $ORG_NAME/$REPO_NAME and pushing..."
  gh repo create "$ORG_NAME/$REPO_NAME" \
    --private                            \
    --source="$WORK_DIR"                 \
    --remote=origin                      \
    --push
  success "Pushed to https://github.com/$ORG_NAME/$REPO_NAME"

  # 5. Mark the repo as a GitHub template repository
  #    (gh repo create has no flag for this — requires a PATCH via gh api)
  info "Marking repo as a template..."
  gh api                               \
    --method PATCH                     \
    "/repos/$ORG_NAME/$REPO_NAME"      \
    --field is_template=true           \
    --jq '"    → is_template: \(.is_template)"'
  success "Template flag set."

  # Cleanup — reset trap and remove temp dir before next iteration
  trap - EXIT
  rm -rf "$WORK_DIR"

  echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  All done! Verify with:"
echo ""
echo "    gh repo list $ORG_NAME --limit 10"
echo ""
echo "  Or check the template flag for one repo:"
echo "    gh api /repos/$ORG_NAME/template-devops --jq '.is_template'"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
