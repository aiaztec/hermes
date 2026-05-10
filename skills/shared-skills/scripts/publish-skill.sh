#!/bin/bash
# Publish local skills to shared GitHub repo
# Usage: ./publish-skill.sh <skill-name> [skill-name2 ...]
# Or: ./publish-skill.sh --all-local

set -e

SHARED_DIR="$HOME/shared-skills"
SKILLS_DIR="$HOME/.hermes/skills"

cd "$SHARED_DIR" || exit 1

# Pull latest changes first
echo "🔄 Pulling latest changes from GitHub..."
git pull origin main

if [ "$1" = "--all-local" ]; then
    SKILLS=("oracle-sqlcl-dba" "system-administration" "system-cleanup" "firecrawl")
else
    SKILLS=("$@")
fi

if [ ${#SKILLS[@]} -eq 0 ]; then
    echo "❌ No skills specified. Usage: $0 <skill-name> [skill-name2 ...]"
    echo "   Or: $0 --all-local"
    exit 1
fi

echo "📤 Publishing skills to shared repo..."

for skill in "${SKILLS[@]}"; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
        echo "  → Copying $skill..."
        cp -r "$SKILLS_DIR/$skill" "$SHARED_DIR/skills/"
    else
        echo "  ⚠️  Warning: $skill not found in $SKILLS_DIR"
    fi
done

echo ""
echo "📋 Changes to be committed:"
git status --short skills/

if ! git diff --quiet skills/ || ! git diff --cached --quiet skills/; then
    git add skills/
    COMMIT_MSG="Update skills: $(date '+%Y-%m-%d %H:%M:%S') - $(echo ${SKILLS[*]})"
    git commit -m "$COMMIT_MSG"
    git push origin main
    echo "✅ Skills published to GitHub!"
else
    echo "ℹ️  No changes to publish."
fi
