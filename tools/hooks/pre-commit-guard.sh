#!/usr/bin/env bash
# pre-commit-guard — хардгейт рабочих копий (программа надёжности).
# Проверяет ТОЛЬКО staged-изменения: секреты, запретные файлы, порог размера диффа.
# Обход: git commit --no-verify — ТОЛЬКО по явному слову владельца.
#
# Установка (в каждой рабочей копии):
#   ln -sf ../../tools/hooks/pre-commit-guard.sh .git/hooks/pre-commit
#   chmod +x tools/hooks/pre-commit-guard.sh
# Настрой MAX_FILES и список исключений под свой проект.

set -u
MAX_FILES=50           # порог размера диффа: больше — дробим фичу
fail=0

files=$(git diff --cached --name-only --diff-filter=ACMR)
count=$(printf '%s\n' "$files" | sed '/^$/d' | wc -l)

# --- 1. Порог размера диффа -------------------------------------------------
if [ "$count" -gt "$MAX_FILES" ]; then
  echo "BLOCK: в коммите $count файлов (> $MAX_FILES). Дроби фичу на части (лимит диффа)." >&2
  fail=1
fi

# --- 2. Запретные файлы -----------------------------------------------------
# Добавь сюда легитимные исключения через `grep -v` (напр. публичные CA-сертификаты).
banned=$(printf '%s\n' "$files" | grep -Ei '(^|/)\.env($|\.)|\.pem$|\.p12$|\.jks$|(^|/)\.secrets|(^|/)id_rsa|config\.secret\.' || true)
if [ -n "$banned" ]; then
  echo "BLOCK: запретные файлы в staged:" >&2
  printf '%s\n' "$banned" >&2
  fail=1
fi

# --- 3. Секреты в добавленных строках ---------------------------------------
# Смотрим только НОВЫЕ строки (+), чтобы не ругаться на легаси-код.
added=$(git diff --cached -U0 --diff-filter=ACMR | grep '^+' | grep -v '^+++' || true)
patterns=(
  'BEGIN[[:space:]].*PRIVATE KEY'
  'AKIA[0-9A-Z]{16}'
  'ghp_[A-Za-z0-9]{20,}'
  'glpat-[A-Za-z0-9_-]{15,}'
  'xox[baprs]-[A-Za-z0-9-]{10,}'
  'Bearer[[:space:]]+[A-Za-z0-9_\.\-]{25,}'
  '(password|passwd|secret|api[_-]?key|token)[[:space:]]*[=:][[:space:]]*["'"'"'][A-Za-z0-9_@#\$%\^&\*\.\-]{12,}["'"'"']'
)
for p in "${patterns[@]}"; do
  case "$p" in
    # для парольных присваиваний отсеиваем очевидные плейсхолдеры
    *password*) hits=$(printf '%s\n' "$added" | grep -En "$p" | grep -Ev 'test|example|placeholder|changeme|dummy' || true) ;;
    *)          hits=$(printf '%s\n' "$added" | grep -En "$p" || true) ;;
  esac
  if [ -n "$hits" ]; then
    echo "BLOCK: похоже на секрет (паттерн: $p):" >&2
    printf '%s\n' "$hits" | head -5 >&2
    fail=1
  fi
done

if [ "$fail" -ne 0 ]; then
  echo "" >&2
  echo "Коммит остановлен pre-commit-guard. Ложное срабатывание — обход --no-verify только по явному слову владельца." >&2
  exit 1
fi
exit 0
