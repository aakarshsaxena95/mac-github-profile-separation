#!/usr/bin/env bash
# Configure separate personal and work GitHub identities on macOS.

set -euo pipefail

readonly PERSONAL_ALIAS="github-personal"
readonly WORK_ALIAS="github-work"

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

require_command() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

ensure_single_line() {
  case "$2" in
    *$'\n'*|*$'\r'*) die "$1 cannot contain a newline." ;;
  esac
}

absolute_path() {
  case "$1" in
    /*) printf '%s\n' "${1%/}" ;;
    *) die "$2 must be an absolute path." ;;
  esac
}

usage() {
  cat <<'EOF'
Usage:
  setup-github-profiles.sh \
    --personal-dir /absolute/path/to/Personal \
    --personal-name "Your Name" \
    --personal-email you@example.com \
    --work-key /absolute/path/to/work-private-key \
    --personal-key /absolute/path/to/personal-private-key

All options are required. The personal key is created when it does not already
exist. Its passphrase is collected directly by ssh-keygen and is never passed
as a command-line argument.
EOF
}

host_alias_conflicts() {
  # A literal alias must remain user-managed. A matching wildcard is only a
  # conflict when it sets a value that our aliases require.
  local alias="$1"
  local key rest pattern matching=0

  while IFS=$' \t' read -r key rest; do
    case "$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')" in
      host)
        matching=0
        for pattern in $rest; do
          case "$pattern" in
            "$alias") return 0 ;;
            !*) ;;
            *) case "$alias" in $pattern) matching=1 ;; esac ;;
          esac
        done
        ;;
      hostname|user|identityfile|identitiesonly)
        [ "$matching" -eq 1 ] && return 0
        ;;
    esac
  done < "$SSH_CONFIG"

  return 1
}

append_host_block() {
  local alias="$1"
  local key_path="$2"
  {
    printf '\n# %s GitHub\n' "$3"
    printf 'Host %s\n' "$alias"
    printf '  HostName github.com\n'
    printf '  User git\n'
    printf '  IdentityFile %s\n' "$key_path"
    printf '  IdentitiesOnly yes\n'
  } >> "$SSH_CONFIG"
}

validate_local_configuration() {
  [ "$(git config --file "$PERSONAL_GIT_CONFIG" --get user.name)" = "$PERSONAL_NAME" ] || die 'Personal Git name validation failed.'
  [ "$(git config --file "$PERSONAL_GIT_CONFIG" --get user.email)" = "$PERSONAL_EMAIL" ] || die 'Personal Git email validation failed.'
  [ "$(git config --global --get "includeIf.gitdir:${PERSONAL_DIR}/.path")" = "$PERSONAL_GIT_CONFIG" ] || die 'Conditional Git include validation failed.'

  ssh -G "$WORK_ALIAS" 2>/dev/null | grep -Fqx 'hostname github.com'
  ssh -G "$WORK_ALIAS" 2>/dev/null | grep -Fqx "identityfile $WORK_KEY"
  ssh -G "$PERSONAL_ALIAS" 2>/dev/null | grep -Fqx 'hostname github.com'
  ssh -G "$PERSONAL_ALIAS" 2>/dev/null | grep -Fqx "identityfile $PERSONAL_KEY"
  printf 'Local Git and SSH configuration validated.\n'
}

main() {
  PERSONAL_DIR=''
  PERSONAL_NAME=''
  PERSONAL_EMAIL=''
  WORK_KEY=''
  PERSONAL_KEY=''

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --personal-dir|--personal-name|--personal-email|--work-key|--personal-key)
        [ "$#" -ge 2 ] || die "Missing value for $1."
        case "$1" in
          --personal-dir) PERSONAL_DIR="$2" ;;
          --personal-name) PERSONAL_NAME="$2" ;;
          --personal-email) PERSONAL_EMAIL="$2" ;;
          --work-key) WORK_KEY="$2" ;;
          --personal-key) PERSONAL_KEY="$2" ;;
        esac
        shift 2
        ;;
      --help|-h)
        usage
        exit 0
        ;;
      *) die "Unknown option: $1. Run with --help for usage." ;;
    esac
  done

  require_command git
  require_command ssh-keygen
  require_command ssh-add
  require_command awk
  require_command dirname
  require_command grep
  require_command tr

  if [ "$(uname)" != "Darwin" ]; then
    die "This script is designed for macOS."
  fi

  [ -n "$PERSONAL_DIR" ] || die 'Missing required option: --personal-dir.'
  PERSONAL_DIR="$(absolute_path "$PERSONAL_DIR" 'the personal repositories directory')"
  ensure_single_line 'Personal repositories directory' "$PERSONAL_DIR"

  [ -n "$PERSONAL_NAME" ] || die 'Missing required option: --personal-name.'
  ensure_single_line 'Personal Git display name' "$PERSONAL_NAME"

  [ -n "$PERSONAL_EMAIL" ] || die 'Missing required option: --personal-email.'
  ensure_single_line 'Personal GitHub email' "$PERSONAL_EMAIL"

  [ -n "$WORK_KEY" ] || die 'Missing required option: --work-key.'
  WORK_KEY="$(absolute_path "$WORK_KEY" 'the work SSH key')"
  ensure_single_line 'Work SSH key path' "$WORK_KEY"
  [ -f "$WORK_KEY" ] || die "Work SSH private key was not found: $WORK_KEY"

  [ -n "$PERSONAL_KEY" ] || die 'Missing required option: --personal-key.'
  PERSONAL_KEY="$(absolute_path "$PERSONAL_KEY" 'the personal SSH key')"
  ensure_single_line 'Personal SSH key path' "$PERSONAL_KEY"
  PERSONAL_KEY_DIR="$(dirname "$PERSONAL_KEY")"

  PERSONAL_GIT_CONFIG="$HOME/.gitconfig-personal"
  SSH_DIR="$HOME/.ssh"
  SSH_CONFIG="$SSH_DIR/config"

  if [ -e "$PERSONAL_KEY" ] && [ ! -f "$PERSONAL_KEY" ]; then
    die "Personal SSH key path exists but is not a regular file: $PERSONAL_KEY"
  fi

  if [ -f "$SSH_CONFIG" ] && { host_alias_conflicts "$PERSONAL_ALIAS" || host_alias_conflicts "$WORK_ALIAS"; }; then
    die "~/.ssh/config has an alias or wildcard that can override github-work or github-personal. Review it manually to preserve the existing SSH setup."
  fi

  mkdir -p "$PERSONAL_DIR" "$SSH_DIR" "$PERSONAL_KEY_DIR"
  chmod 700 "$SSH_DIR"

  if [ -f "$SSH_CONFIG" ]; then
    SSH_BACKUP="$SSH_CONFIG.backup.$(date +%Y%m%d%H%M%S)"
    cp -p "$SSH_CONFIG" "$SSH_BACKUP"
    printf 'Backed up SSH config to %s\n' "$SSH_BACKUP"
  fi
  touch "$SSH_CONFIG"
  chmod 600 "$SSH_CONFIG"

  git config --file "$PERSONAL_GIT_CONFIG" user.name "$PERSONAL_NAME"
  git config --file "$PERSONAL_GIT_CONFIG" user.email "$PERSONAL_EMAIL"
  git config --global --replace-all "includeIf.gitdir:${PERSONAL_DIR}/.path" "$PERSONAL_GIT_CONFIG"

  if [ ! -f "$PERSONAL_KEY" ]; then
    printf '\nCreating the personal SSH key. ssh-keygen will ask you for its passphrase.\n'
    ssh-keygen -t ed25519 -C "$PERSONAL_EMAIL" -f "$PERSONAL_KEY"
  else
    printf '\nUsing the existing personal SSH key: %s\n' "$PERSONAL_KEY"
  fi

  if [ ! -f "${PERSONAL_KEY}.pub" ]; then
    printf 'Creating the missing public key file: %s.pub\n' "$PERSONAL_KEY"
    ssh-keygen -y -f "$PERSONAL_KEY" > "${PERSONAL_KEY}.pub"
    chmod 644 "${PERSONAL_KEY}.pub"
  fi

  append_host_block "$WORK_ALIAS" "$WORK_KEY" 'Work'
  append_host_block "$PERSONAL_ALIAS" "$PERSONAL_KEY" 'Personal'

  validate_local_configuration

  printf '\nAdding the personal key to the macOS SSH agent (you may be asked for its passphrase).\n'
  ssh-add --apple-use-keychain "$PERSONAL_KEY"

  printf '\nSetup complete. Add this public key to your personal GitHub account:\n\n'
  cat "${PERSONAL_KEY}.pub"
  printf '\nThen test the aliases:\n  ssh -T git@%s\n  ssh -T git@%s\n' "$WORK_ALIAS" "$PERSONAL_ALIAS"
  printf '\nClone personal repositories with: git@%s:OWNER/REPOSITORY.git\n' "$PERSONAL_ALIAS"
}

main "$@"
