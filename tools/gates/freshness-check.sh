#!/usr/bin/env bash
# freshness-check — гейт свежести опор (программа надёжности).
# Перед закрытием фичи проверяет: аудит-сводка, граф кода и вики не старше последнего коммита кода.
# Если опоры отстали от кода — фича НЕ считается закрытой.
#
# Запуск из корня пространства проекта:  bash tools/gates/freshness-check.sh
# Пути ниже — под 4-слойку кита; поправь под свою раскладку рабочих копий.

set -u
cd "$(dirname "$0")/../.." || exit 2
stale=0

ts() { date -d "@$1" '+%Y-%m-%d %H:%M' 2>/dev/null || echo '?'; }

# Последний коммит кода (адаптируй пути к своим рабочим копиям)
code_commit=$(git log -1 --format=%ct 2>/dev/null || echo 0)

# Опоры: граф кода, свежайшая аудит-сводка, свежайшая страница вики
graph=$(stat -c %Y workspace/graphify-out/graph.json 2>/dev/null || echo 0)
audit=$(ls -t workspace/audits/*.md 2>/dev/null | head -1)
audit_ts=$([ -n "${audit:-}" ] && stat -c %Y "$audit" || echo 0)
wiki_ts=$(find wiki -name '*.md' -printf '%T@\n' 2>/dev/null | sort -rn | head -1 | cut -d. -f1)
wiki_ts=${wiki_ts:-0}

echo "=== Гейт свежести опор ==="
echo "Последний коммит кода:   $(ts "$code_commit")"

if [ "$graph" -lt "$code_commit" ]; then
  echo "STALE  граф кода:        $(ts "$graph")  — ПЕРЕСОБРАТЬ"
  stale=1
else
  echo "OK     граф кода:        $(ts "$graph")"
fi

if [ "$audit_ts" -lt "$code_commit" ]; then
  echo "STALE  аудит-сводка:     $(ts "$audit_ts")  ${audit:-'(нет файлов)'} — контур не подтверждён для текущего кода"
  stale=1
else
  echo "OK     аудит-сводка:     $(ts "$audit_ts")  $audit"
fi

if [ "$wiki_ts" -lt "$code_commit" ]; then
  echo "WARN   вики:             $(ts "$wiki_ts")  — старше кода; проверь, канонизирована ли фича"
else
  echo "OK     вики:             $(ts "$wiki_ts")"
fi

echo ""
if [ "$stale" -ne 0 ]; then
  echo "ИТОГ: STALE — фича НЕ закрыта, опоры отстали от кода."
  exit 1
fi
echo "ИТОГ: OK — опоры не старше кода."
exit 0
