#!/bin/bash
# .claude/hooks/session-start.sh
# guides 项目启动时显示当前状态

echo "=== Guides 项目状态 ==="
echo "时间: $(date '+%Y-%m-%d %H:%M')"
echo ""

# 当前版本号（从 README.md 提取）
VERSION=$(grep -oE 'v[0-9]+\.[0-9]+' README.md 2>/dev/null | head -1)
echo "当前版本: ${VERSION:-未知}"
echo ""

# Git 状态
echo "--- Git 状态 ---"
git status --short 2>/dev/null | head -20

# 未推送 commit 数量
UNPUSHED=$(git log --oneline @{u}.. 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNPUSHED" -gt 0 ]; then
  echo ""
  echo "未推送 commit: $UNPUSHED 个"
fi

# 最近 3 个 commit
echo ""
echo "--- 最近 commit ---"
git log --oneline -3 2>/dev/null

echo ""
echo "就绪。"
