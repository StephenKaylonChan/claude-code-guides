#!/bin/bash
# .claude/hooks/pre-commit-check.sh
# 提交前检查所有文档版本号一致性

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

# 只拦截 git commit 命令
if [[ "$COMMAND" != *"git commit"* ]]; then
  exit 0
fi

echo "检查文档版本号一致性..." >&2

# 从 README.md 提取基准版本号
BASE_VERSION=$(grep -m1 '\*\*版本\*\*:' README.md 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+')

if [ -z "$BASE_VERSION" ]; then
  echo "无法从 README.md 提取版本号，跳过检查" >&2
  exit 0
fi

ERRORS=""

# 检查 00-04 文档中所有 **版本**: 行是否与基准一致
for f in 00-*.md 01-*.md 02-*.md 03-*.md 04-*.md; do
  if [ -f "$f" ]; then
    # 提取该文件中所有版本号
    VERSIONS=$(grep '\*\*版本\*\*:' "$f" 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+')
    LINE_NUM=0
    for v in $VERSIONS; do
      LINE_NUM=$((LINE_NUM + 1))
      if [ "$v" != "$BASE_VERSION" ]; then
        LABEL="头部"
        [ "$LINE_NUM" -gt 1 ] && LABEL="尾部"
        ERRORS="${ERRORS}\n  $f ($LABEL): $v (应为 $BASE_VERSION)"
      fi
    done
  fi
done

if [ -n "$ERRORS" ]; then
  echo -e "版本号不一致！基准版本: $BASE_VERSION$ERRORS" >&2
  echo "" >&2
  echo "请修复版本号后重新提交。" >&2
  exit 2
fi

echo "版本号一致性检查通过 ($BASE_VERSION)" >&2
exit 0
