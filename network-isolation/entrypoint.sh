#!/bin/bash
set -e

if [ -d "/host-claude" ]; then
    mkdir -p "$HOME/.claude"
    if [ -f "/host-claude/.credentials.json" ]; then
        cp "/host-claude/.credentials.json" "$HOME/.claude/.credentials.json" 2>/dev/null || true
    fi
    for f in statsig.json settings.json; do
        if [ -f "/host-claude/$f" ]; then
            cp "/host-claude/$f" "$HOME/.claude/$f" 2>/dev/null || true
        fi
    done
fi

if [ -f "/host-claude.json" ]; then
    cp "/host-claude.json" "$HOME/.claude.json" 2>/dev/null || true
fi

exec claude "$@"
