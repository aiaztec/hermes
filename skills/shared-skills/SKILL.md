---
name: shared-skills-symlink
description: "Shared skills management via symlinks for Hermes Agent. Sync skills from aiaztec/hermes repo using symlinks."
version: 1.0.0
author: aiaztec + Hermes-TT
license: MIT
metadata:
  hermes:
    tags: [skills, collaboration, git, symlink, shared]
---

# Shared Skills Management via Symlinks

This skill enables multiple Hermes Agents to share custom skills via a central GitHub repository (`aiaztec/hermes`), using symlinks instead of copying.

## Why Symlinks?

- **No duplication** — files exist only in the git repo
- **Instant sync** — changes in the repo appear immediately via symlinks
- **Simple git workflow** — edit in `~/.hermes/skills/`, commit/push from `~/repos/aiaztec-hermes/`

## Architecture

```
~/repos/aiaztec-hermes/skills/     (git repo - single source of truth)
        ↕ (git pull/push)
Symlinks in ~/.hermes/skills/:
  oracle-sqlcl-dba → ~/repos/aiaztec-hermes/skills/oracle-sqlcl-dba
  system-administration → ~/repos/aiaztec-hermes/skills/system-administration
  system-cleanup → ~/repos/aiaztec-hermes/skills/system-cleanup
  firecrawl → ~/repos/aiaztec-hermes/skills/firecrawl
  shared-skills-symlink → ~/repos/aiaztec-hermes/skills/shared-skills-symlink
```

## Prerequisites

- Git installed
- GitHub repo: `https://github.com/aiaztec/hermes.git`
- Hermes Agent installed

## Setup (First Time)

Run these commands once to set up the shared skills environment:

```bash
# 1. Create repos directory and clone the shared repo
mkdir -p ~/repos
cd ~/repos
git clone https://github.com/aiaztec/hermes.git aiaztec-hermes

# 2. Backup existing local skills (if any)
cd ~/.hermes/skills/
for skill in oracle-sqlcl-dba system-administration system-cleanup firecrawl; do
  if [ -e "$skill" ] && [ ! -L "$skill" ]; then
    mv "$skill" "${skill}.backup"
    echo "Backup: $skill → ${skill}.backup"
  fi
done

# 3. Create symlinks for shared skills
cd ~/.hermes/skills/
for skill in oracle-sqlcl-dba system-administration system-cleanup firecrawl shared-skills-symlink; do
  if [ -e "~/repos/aiaztec-hermes/skills/$skill" ]; then
    ln -sf ~/repos/aiaztec-hermes/skills/$skill $skill
    echo "Symlink: $skill → ~/repos/aiaztec-hermes/skills/$skill"
  fi
done

# 4. Verify Hermes sees the skills
hermes skills list | grep -E "oracle-sqlcl-dba|system-administration|system-cleanup|firecrawl|shared-skills"
```

## Daily Workflow

### 1. Pull updates from other agents (e.g., Hermes-TT pushed changes)

```bash
cd ~/repos/aiaztec-hermes/
git pull origin main
# Symlinks automatically point to updated files
```

### 2. Edit a skill locally and push changes

Since symlinks point to the repo, you can edit directly:

```bash
# Edit a skill (example: update oracle-sqlcl-dba)
nano ~/.hermes/skills/oracle-sqlcl-dba/SKILL.md
# (Actually editing ~/repos/aiaztec-hermes/skills/oracle-sqlcl-dba/SKILL.md)

# Commit and push
cd ~/repos/aiaztec-hermes/
git add skills/oracle-sqlcl-dba/
git commit -m "Update oracle-sqlcl-dba: describe changes"
git push origin main
```

### 3. Add a new skill to the shared repo

```bash
# Create new skill in the repo
cd ~/repos/aiaztec-hermes/skills/
mkdir new-skill-name
# ... create SKILL.md etc. ...

# Symlink it to Hermes
cd ~/.hermes/skills/
ln -s ~/repos/aiaztec-hermes/skills/new-skill-name new-skill-name

# Commit and push
cd ~/repos/aiaztec-hermes/
git add skills/new-skill-name/
git commit -m "Add new skill: new-skill-name"
git push origin main
```

## Automation (Optional)

Set up a cron job to automatically pull updates every 30 minutes:

```bash
hermes cron create "30m" --prompt "Pull shared skills updates: cd ~/repos/aiaztec-hermes && git pull origin main && echo 'Shared skills synced'"
```

Or run manually:

```bash
cd ~/repos/aiaztec-hermes/ && git pull origin main
```

## Current Shared Skills

| Skill | Author | Description |
|-------|--------|-------------|
| `oracle-sqlcl-dba` | aiaztec | Oracle DB administration via SQLcl |
| `system-administration` | aiaztec | Linux system administration tasks |
| `system-cleanup` | aiaztec | System cleanup procedures |
| `firecrawl` | Hermes-TT | Web scraping and search via Firecrawl |
| `shared-skills-symlink` | aiaztec | This skill (shared skills management) |

## Adding New Collaborators

To add a new agent/user to the shared repo:

```bash
# Using gh CLI (requires proper GitHub token)
gh api repos/aiaztec/hermes/collaborators/USERNAME -X PUT -f permission=push
```

The new user should then:
1. Accept the invitation at https://github.com/aiaztec/hermes/invitations
2. Clone the repo: `git clone https://github.com/aiaztec/hermes.git ~/repos/aiaztec-hermes`
3. Create symlinks as described in Setup

## Troubleshooting

### Symlink broken?
```bash
# Check symlinks
ls -la ~/.hermes/skills/ | grep ^l

# Recreate if needed
ln -sf ~/repos/aiaztec-hermes/skills/SKILL-NAME ~/.hermes/skills/SKILL-NAME
```

### Hermes doesn't see the skill?
```bash
hermes skills list
# Skills must have SKILL.md at the root of the skill directory
```

### Git issues?
```bash
cd ~/repos/aiaztec-hermes/
git status
git pull --rebase origin main
```

## Quick Reference

| Action | Command |
|--------|---------|
| Pull updates | `cd ~/repos/aiaztec-hermes/ && git pull origin main` |
| Push changes | `cd ~/repos/aiaztec-hermes/ && git push origin main` |
| Check symlinks | `ls -la ~/.hermes/skills/ \| grep ^l` |
| List shared skills | `hermes skills list \| grep -E "oracle\|system\|firecrawl\|shared"` |
| Add collaborator | `gh api repos/aiaztec/hermes/collaborators/USERNAME -X PUT -f permission=push` |
