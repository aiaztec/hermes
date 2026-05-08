#!/bin/bash
# Auto-share new skill to shared repo
# Usage: auto-share-new-skill.sh <skill-name> [commit-message]

SKILL_NAME=$1
COMMIT_MSG=${2:-"Add new skill: $SKILL_NAME"}
REPO_DIR="$HOME/repos/aiaztec-hermes/skills"
SKILLS_DIR="$HOME/.hermes/skills"

if [ -z "$SKILL_NAME" ]; then
    echo "Usage: $0 <skill-name> [commit-message]"
    exit 1
fi

echo "🤖 Auto-sharing skill: $SKILL_NAME"

# 1. Check if skill exists locally but not in shared repo
if [ -d "$SKILLS_DIR/$SKILL_NAME" ] && [ ! -d "$REPO_DIR/$SKILL_NAME" ]; then
    echo "  → Moving skill to shared repo..."
    mv "$SKILLS_DIR/$SKILL_NAME" "$REPO_DIR/$SKILL_NAME"
    
    # Create symlink back
    ln -sf "$REPO_DIR/$SKILL_NAME" "$SKILLS_DIR/$SKILL_NAME"
    echo "  ✅ Symlink created: $SKILLS_DIR/$SKILL_NAME → $REPO_DIR/$SKILL_NAME"
fi

# 2. Commit and push
cd ~/repos/aiaztec-hermes/
git add "skills/$SKILL_NAME/"
git commit -m "$COMMIT_MSG"
git push origin main

echo "✅ Skill '$SKILL_NAME' automatically shared to GitHub!"
echo "   Other agents will get it on next pull."
