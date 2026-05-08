#!/bin/bash
# Setup shared skills via symlinks - run once per new agent
# This script creates the ~/repos/ directory, clones the shared repo,
# and creates symlinks in ~/.hermes/skills/

set -e

REPO_DIR="$HOME/repos/aiaztec-hermes"
SKILLS_DIR="$HOME/.hermes/skills"

echo "🚀 Setting up shared skills environment..."

# 1. Create repos directory and clone shared repo
if [ ! -d "$REPO_DIR" ]; then
    mkdir -p ~/repos
    cd ~/repos
    git clone https://github.com/aiaztec/hermes.git aiaztec-hermes
    echo "✅ Cloned aiaztec/hermes to $REPO_DIR"
else
    echo "ℹ️  Repo already exists at $REPO_DIR"
    cd "$REPO_DIR"
    git pull origin main
fi

# 2. Backup existing local skills (if any)
cd "$SKILLS_DIR"
SHARED_SKILLS="oracle-sqlcl-dba system-administration system-cleanup firecrawl shared-skills"

for skill in $SHARED_SKILLS; do
    if [ -e "$skill" ] && [ ! -L "$skill" ]; then
        mv "$skill" "${skill}.backup.$(date +%Y%m%d)"
        echo "📦 Backup: $skill → ${skill}.backup.$(date +%Y%m%d)"
    fi
done

# 3. Create symlinks for shared skills
cd "$SKILLS_DIR"
for skill in $SHARED_SKILLS; do
    if [ -e "$REPO_DIR/skills/$skill" ]; then
        if [ -L "$skill" ]; then
            echo "✓ Symlink already exists: $skill"
        else
            ln -sf "$REPO_DIR/skills/$skill" "$skill"
            echo "🔗 Created symlink: $skill → $REPO_DIR/skills/$skill"
        fi
    else
        echo "⚠️  Warning: $skill not found in repo"
    fi
done

# 4. Verify Hermes sees the skills
echo ""
echo "🔍 Verifying skills in Hermes..."
hermes skills list 2>/dev/null | grep -E "oracle|system|firecrawl|shared-skills" || echo "Run 'hermes skills list' to verify"

echo ""
echo "✅ Setup complete! Symlinked skills:"
ls -la "$SKILLS_DIR" | grep "^l" | awk '{print $9, "→", $11}'
