#!/bin/bash
# Pull shared skills from GitHub and copy to local Hermes skills
# Usage: ./pull-skills.sh [--all | skill-name ...]

set -e

SHARED_DIR="$HOME/shared-skills"
SKILLS_DIR="$HOME/.hermes/skills"

cd "$SHARED_DIR" || exit 1

echo "🔄 Pulling latest shared skills from GitHub..."
git pull origin main

if [ "$1" = "--all" ]; then
    for skill in skills/*/; do
        skill_name=$(basename "$skill")
        echo "  → Updating $skill_name..."
        rm -rf "$SKILLS_DIR/$skill_name"
        cp -r "$skill" "$SKILLS_DIR/"
    done
else
    for skill in "$@"; do
        if [ -d "skills/$skill" ]; then
            echo "  → Updating $skill..."
            rm -rf "$SKILLS_DIR/$skill"
            cp -r "skills/$skill" "$SKILLS_DIR/"
        else
            echo "  ⚠️  Warning: $skill not found in shared repo"
        fi
    done
fi

echo ""
echo "✅ Local skills updated!"
echo ""
echo "Current shared skills on GitHub:"
ls -1 skills/
