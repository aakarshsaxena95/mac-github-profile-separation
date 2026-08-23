# Separate Work & Personal GitHub Profiles on macOS

This guide configures a Mac so work and personal GitHub repositories use separate Git identities and separate GitHub SSH accounts.

> **Use your own directory names and values.** Examples such as `~/Work`, `~/Personal`, `YOUR_USERNAME`, and `YOUR_PERSONAL_GITHUB_EMAIL` are placeholders.

## 1. Check the existing Git identity

```bash
git config --global user.name
git config --global user.email
```

Keep the existing work identity as the global/default identity.

## 2. Choose separate repository directories

Example:

```text
~/Work
~/Personal
```

Your actual directories can have any names.

The important requirement is that personal repositories live below one predictable parent directory.

## 3. Create the personal Git configuration

```bash
nano ~/.gitconfig-personal
```

Paste:

```ini
[user]
    name = YOUR_PERSONAL_NAME
    email = YOUR_PERSONAL_GITHUB_EMAIL
```

Save with `Ctrl + O`, press Enter, then `Ctrl + X`.

## 4. Load the personal config only for personal repositories

Open the global Git config:

```bash
nano ~/.gitconfig
```

Add:

```ini
[includeIf "gitdir:/Users/YOUR_USERNAME/YOUR_PERSONAL_DIRECTORY/"]
    path = ~/.gitconfig-personal
```

Use the absolute path to your personal repository directory. The trailing `/` is important.

## 5. Verify Git identity separation

Inside a personal repository:

```bash
cd /path/to/personal/repository
git config user.name
git config user.email
```

Inside a work repository:

```bash
cd /path/to/work/repository
git config user.name
git config user.email
```

For troubleshooting:

```bash
git config --show-origin --get-regexp 'user\.|include'
```

## 6. Inspect the existing SSH setup

```bash
ls -la ~/.ssh
cat ~/.ssh/config 2>/dev/null
ssh-add -l
```

Identify the existing work SSH key. Do not overwrite it.

If the SSH config contains cloud, enterprise, or server-specific hosts, preserve those entries.

## 7. Back up the SSH configuration

```bash
cp ~/.ssh/config ~/.ssh/config.backup
```

If the config does not exist, this step can be skipped.

## 8. Create a personal SSH key

```bash
ssh-keygen -t ed25519 -C "YOUR_PERSONAL_GITHUB_EMAIL" -f ~/.ssh/id_ed25519_personal
```

Use a passphrase when prompted.

This creates:

```text
~/.ssh/id_ed25519_personal
~/.ssh/id_ed25519_personal.pub
```

Never share the private key.

## 9. Add the personal key to the macOS SSH agent

```bash
ssh-add --apple-use-keychain ~/.ssh/id_ed25519_personal
```

Verify:

```bash
ssh-add -l
```

## 10. Add the personal public key to GitHub

Display it:

```bash
cat ~/.ssh/id_ed25519_personal.pub
```

Copy the entire line and add it to your personal GitHub account under:

**Settings → SSH and GPG keys → New SSH key**

Only the `.pub` key is uploaded.

## 11. Add separate GitHub SSH aliases

Edit the SSH config:

```bash
nano ~/.ssh/config
```

Add these blocks while preserving existing infrastructure-specific configuration:

```sshconfig
# Work GitHub
Host github-work
  HostName github.com
  User git
  IdentityFile ~/.ssh/YOUR_EXISTING_WORK_KEY
  IdentitiesOnly yes

# Personal GitHub
Host github-personal
  HostName github.com
  User git
  IdentityFile ~/.ssh/id_ed25519_personal
  IdentitiesOnly yes
```

Replace `YOUR_EXISTING_WORK_KEY` with the actual work key filename.

Do not blindly replace the entire SSH config if it contains other hosts.

## 12. Test both GitHub accounts

Work:

```bash
ssh -T git@github-work
```

Personal:

```bash
ssh -T git@github-personal
```

Each should identify the expected GitHub account.

GitHub may say that it does not provide shell access. That is normal.

## 13. Clone a personal repository

Use the personal SSH alias for a new clone:

```bash
cd /path/to/personal/directory
git clone git@github-personal:YOUR_GITHUB_USERNAME/YOUR_REPOSITORY.git
```

For example:

```text
git@github-personal:username/repository.git
```

### Why the alias is required during clone

A new repository does not have a `.git` directory yet, so a `gitdir:` conditional include cannot match it during the initial clone.

## 14. Verify the personal repository

```bash
cd /path/to/personal/directory/YOUR_REPOSITORY
git config user.name
git config user.email
git remote -v
```

The email should be the personal email, and the remote should use `github-personal`.

From then on:

```bash
git pull
git push
```

will use the personal SSH key.

## 15. Clone a work repository

```bash
cd /path/to/work/directory
git clone git@github-work:WORK_GITHUB_OWNER/YOUR_REPOSITORY.git
```

Verify:

```bash
cd /path/to/work/directory/YOUR_REPOSITORY
git config user.email
git remote -v
```

## 16. Final validation

After adding the personal public key to GitHub and cloning repositories, run:

```bash
# From a personal repository
git config --show-origin --get user.name
git config --show-origin --get user.email
git remote -v

# Verify both GitHub SSH aliases
ssh -T git@github-work
ssh -T git@github-personal
```

The personal Git values should come from `~/.gitconfig-personal`, the personal
remote should use `github-personal`, and each SSH command should identify the
expected GitHub account. GitHub's "does not provide shell access" message is
expected after successful authentication.

## Troubleshooting

### Personal clone says "Repository not found"

Test:

```bash
ssh -T git@github-personal
```

Confirm the clone URL starts with:

```text
git@github-personal:
```

and that the repository exists in the personal GitHub account.

### Personal repository shows the work email

Run:

```bash
git config --show-origin --get user.email
```

Then:

```bash
git config --show-origin --get-regexp 'user\.|include'
```

Verify that the repository is below the directory specified in `includeIf`.

### Git uses the wrong SSH account

Run:

```bash
GIT_TRACE=1 git ls-remote <remote-url>
```

For a personal repository, the trace should show `git@github-personal`.

For a work repository, it should show `git@github-work`.

### New personal clone does not use the personal Git identity

This is expected until the repository exists. Clone with:

```bash
git clone git@github-personal:USERNAME/REPOSITORY.git
```

Then enter the repository and run:

```bash
git config user.email
```

### Existing enterprise/cloud SSH access breaks

Restore the backup:

```bash
cp ~/.ssh/config.backup ~/.ssh/config
```

Then re-add only the two GitHub host aliases, preserving existing host-specific settings.

## Final architecture

```text
WORK
/path/to/work/repositories/*
    ↓
work Git identity
    ↓
github-work
    ↓
work SSH key
    ↓
work GitHub account


PERSONAL
/path/to/personal/repositories/*
    ↓
personal Git identity
    ↓
github-personal
    ↓
personal SSH key
    ↓
personal GitHub account
```

The key principle:

> **Use Git conditional configuration to separate commit identity, and SSH host aliases to separate GitHub authentication.**
