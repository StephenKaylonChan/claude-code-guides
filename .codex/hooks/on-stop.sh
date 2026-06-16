#!/bin/bash
# .claude/hooks/on-stop.sh
# 完成通知（macOS）

INPUT=$(cat)
LAST_MSG=$(echo "$INPUT" | jq -r '.last_assistant_message // ""' | head -c 100)

# macOS 桌面通知
if command -v osascript &>/dev/null; then
  osascript -e "display notification \"$LAST_MSG\" with title \"Claude Code 完成\" sound name \"Glass\""
fi

exit 0
