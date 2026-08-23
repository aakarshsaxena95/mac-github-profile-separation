# macOS GitHub Profile Separation

A practical guide to configuring a Mac for separate work and personal GitHub accounts using Git conditional configuration and SSH host aliases.

## What this solves

- Separate Git commit name/email for work and personal repositories
- Separate SSH keys for two GitHub accounts on `github.com`
- Preserve existing enterprise/cloud SSH configuration
- Avoid repeatedly changing global Git settings

## Setup

- [Full Markdown setup guide](./setup-guide.md)
- [Open the reader-friendly HTML setup guide](https://htmlpreview.github.io/?https://raw.githubusercontent.com/aakarshsaxena95/mac-github-profile-separation/main/setup-guide.html)

### One-command setup

Run the non-interactive setup script from the repository root, passing every
required value as an option:

```bash
./scripts/setup-github-profiles.sh \
  --personal-dir "$HOME/Personal" \
  --personal-name "Your Name" \
  --personal-email "you@personal.example" \
  --work-key "$HOME/.ssh/id_ed25519_work" \
  --personal-key "$HOME/.ssh/id_ed25519_personal"
```

It creates the personal Git config, adds the conditional include, backs up and
extends the SSH config, creates the personal key if needed, and adds it to the
macOS keychain-backed SSH agent. If the personal key is new, `ssh-keygen` asks
for its passphrase securely; the passphrase is not an argument to the script.

`--work-key` must point to your existing work **private** key. For
`--personal-key`, provide the path where you want the new personal private key
to live (normally `$HOME/.ssh/id_ed25519_personal`); the script creates it when
it does not exist, including its parent directory when needed. For the manual
key-creation steps and security notes, see [Create a personal SSH
key](./setup-guide.md#8-create-a-personal-ssh-key) in the setup guide.

The script prints the public key at the end; add that key to your personal
GitHub account before testing the `github-personal` alias.

## Prerequisites

- macOS
- Git
- Two GitHub accounts
- An existing work SSH key
- Separate parent directories for work and personal repositories

## Important

Git identity and GitHub authentication are different:

- **Git identity** controls the name/email recorded in commits.
- **SSH authentication** controls which GitHub account is authorized to access repositories.
