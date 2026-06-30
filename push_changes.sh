#!/bin/bash

# 1. Check if there are actual changes to commit
if [ -z "$(git status --porcelain)" ]; then
    echo "⚠️ No changes detected to push. Codebase is already clean."
    exit 0
fi

echo "📦 Staging fixed files..."
git add .

echo "💾 Committing the conflict resolution..."
git commit -m "chore: resolve git merge conflicts and fix syntax errors"

CURRENT_BRANCH=$(git branch --show-current)
echo "🚀 Pushing fixes to origin/$CURRENT_BRANCH..."
git push origin "$CURRENT_BRANCH"

echo "✅ Successfully pushed! Check your build runner pipeline now."
