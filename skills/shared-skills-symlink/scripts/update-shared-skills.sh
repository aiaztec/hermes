#!/bin/bash
# Update shared skills - pull from GitHub and verify symlinks
# Run this periodically or when you know there are updates

set -e

REPO_DIR="$HOME/repos/aiaztec-hermes"

echo "🔄 Updating shared skills from GitHub..."

# Pull latest changes
cd "$REPO_DIR"
git pull origin main

echo "✅ Repository updated."

# Verify symlinks in ~/.hermes/skills/
echo ""
echo "🔗 Verifying symlinks..."
cd ~/.hermes/skills/

for skill in oracle-sqlcl-dba system-administration system-cleanup firecrawl shared-skills-symlink; do
    if [ -L "$skill" ]; then
        target=$(readlink "$skill")
        if [ -e "$skill" ]; then
            echo "  ✅ $skill → $target"
        else
            echo "  ❌ $skill → BROKEN LINK ($target)"
        fi
    else
        if [ -e "$skill" ]; then
            echo "  ⚠️  $skill exists but is NOT a symlink"
        else
            echo "  ❌ $skill missing"
        fi
    fi
done

echo ""
echo "Current shared skills on GitHub:"
ls -1 "$REPO_DIR/skills/"
