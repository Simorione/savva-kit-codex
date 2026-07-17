#!/usr/bin/env bash
# freshness-check — гейт свежести опор (программа надёжности).
# Перед закрытием фичи проверяет: граф кода и аудит-сводка не старше последнего коммита кода
# (STALE = фича не закрыта); вика — мягкий сигнал (WARN, не блокирует).
#
# Запуск откуда угодно — корень пространства находится сам (каталог с wiki/ и workspace/),
# или задаётся явно:  bash freshness-check.sh /путь/к/проекту
# Пути к опорам ниже — под 4-слойку кита; поправь под свою раскладку рабочих копий.

set -u

# --- Определение корня пространства -----------------------------------------
# Аргумент имеет приоритет; иначе поднимаемся от расположения скрипта до каталога,
# где есть и wiki/, и workspace/ (устойчиво к раскладке в корне и в .savva-kit/).
ROOT="${1:-}"
if [ -z "$ROOT" ]; then
  d="$(cd "$(dirname "$0")" && pwd)"
  while [ "$d" != "/" ]; do
    if [ -d "$d/wiki" ] && [ -d "$d/workspace" ]; then ROOT="$d"; break; fi
    d="$(dirname "$d")"
  done
fi
if [ -z "$ROOT" ] || [ ! -d "$ROOT/wiki" ]; then
  echo "freshness-check: не найден корень пространства (каталог с wiki/ и workspace/)." >&2
  echo "Укажи явно: bash freshness-check.sh /путь/к/проекту" >&2
  exit 2
fi
cd "$ROOT" || exit 2
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
