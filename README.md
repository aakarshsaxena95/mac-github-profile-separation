# macOS GitHub Profile Separation

A practical guide to configuring a Mac for separate work and personal GitHub accounts using Git conditional configuration and SSH host aliases.

## What this solves

- Separate Git commit name/email for work and personal repositories
- Separate SSH keys for two GitHub accounts on `github.com`
- Preserve existing enterprise/cloud SSH configuration
- Avoid repeatedly changing global Git settings

## Setup

- [Full Markdown setup guide](./setup-guide.md)
- [Reader-friendly HTML setup guide](./setup-guide.html)

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
