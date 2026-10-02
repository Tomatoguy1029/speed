#!/bin/bash
# Stop hook: when the game changed, build + test, then commit and push main.
# Vercel deploys main on every push. Set AUTO_DEPLOY_DRY_RUN=1 to only report.
cd "$(dirname "$0")/../.." || exit 0
[ -d .git ] || exit 0

say() { node -e 'console.log(JSON.stringify({ systemMessage: process.argv[1] }))' "$1"; }

changes=$(git status --porcelain)
ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo 0)
[ -z "$changes" ] && [ "$ahead" = "0" ] && exit 0

if [ -n "$changes" ]; then
  if ! out=$(node build.js 2>&1); then
    say "自動デプロイ中止: ビルド失敗（コミットしていません） $(echo "$out" | tail -1)"
    exit 0
  fi
  if ! out=$(node --test 2>&1); then
    say "自動デプロイ中止: テスト失敗 $(echo "$out" | grep -E '^ℹ fail' | head -1)（コミットしていません）"
    exit 0
  fi
  files=$(git status --porcelain | awk '{print $2}' | grep -v '^dist/' | head -4 | tr '\n' ' ')
  if [ -n "$AUTO_DEPLOY_DRY_RUN" ]; then
    say "[dry run] ビルド・テスト OK。コミット対象: ${files:-dist のみ}"
    exit 0
  fi
  git add -A
  git commit -q -m "Auto: update ${files:-build output}" -m "Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>" || exit 0
elif [ -n "$AUTO_DEPLOY_DRY_RUN" ]; then
  say "[dry run] 未 push のコミット ${ahead} 件を push します"
  exit 0
fi

if err=$(git push -q origin HEAD:main 2>&1); then
  say "自動コミット＆push 完了 → Vercel がデプロイします: https://speed-nine-kappa.vercel.app"
else
  say "自動 push 失敗: $(echo "$err" | tail -1)"
fi
exit 0
