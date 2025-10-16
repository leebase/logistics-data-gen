#!/usr/bin/env bash
set -euo pipefail

# Install local git hooks from .githooks

git config core.hooksPath .githooks
chmod +x .githooks/pre-commit || true
echo "Git hooks path set to .githooks. Pre-commit hook installed."

