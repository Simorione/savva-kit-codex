#!/usr/bin/env bash
# savva-kit bootstrap (Codex/tool-agnostic edition) — раскладывает 4-слойку и подключает
# контракт/роли/хардгейты в целевой проект.
#
# Режимы:
#   ./bootstrap.sh /path/to/project           установка (не трогает уже существующее)
#   ./bootstrap.sh /path/to/project --force    переустановка kit-части с бэкапом (.bak-<время>)
#
# Требования: bash + GNU coreutils (Linux/macOS; Windows — через WSL/Git Bash).
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"
FORCE=0
[[ "${2:-}" == "--force" ]] && FORCE=1

if [[ -z "$TARGET" ]]; then
  echo "Usage: ./bootstrap.sh /path/to/your/project [--force]"
  echo "Разложит raw/ inbox/ workspace/ wiki/ + .savva-kit/ (метод, роли, tools) + контракт."
  exit 1
fi

mkdir -p "$TARGET"; TARGET="$(cd "$TARGET" && pwd)"
KIT_SUBDIR=".savva-kit"          # куда кладём метод/роли/тулы в целевом проекте
KIT_ROOT_VALUE="${KIT_SUBDIR}/"  # подстановка для {{KIT_ROOT}} в документах
echo "==> Целевой проект: $TARGET  (режим: $([[ $FORCE == 1 ]] && echo force || echo install))"

# --- helper: скопировать каталог/файл идемпотентно ---------------------------
STAMP="$(date +%Y%m%d-%H%M%S)"
copy_item() { # src dst
  local src="$1" dst="$2"
  if [[ -e "$dst" ]]; then
    if [[ $FORCE == 1 ]]; then
      mv "$dst" "${dst}.bak-${STAMP}"
      echo "   (бэкап: ${dst}.bak-${STAMP})"
    else
      echo "==> $dst уже существует — пропускаю (--force для перезаписи с бэкапом)"
      return 0
    fi
  fi
  cp -R "$src" "$dst"
}

# 1. 4-слойка (mkdir идемпотентен, содержимое не трогаем)
for layer in raw inbox workspace wiki wiki/meta; do mkdir -p "$TARGET/$layer"; done
echo "==> Слои raw/ inbox/ workspace/ wiki/ готовы"

# 2. Метод, роли, хардгейты, референсы → .savva-kit/
mkdir -p "$TARGET/$KIT_SUBDIR"
for item in method agents skills tools example-izolation; do
  copy_item "$KIT_DIR/$item" "$TARGET/$KIT_SUBDIR/$item"
done
copy_item "$KIT_DIR/INSTALL.md" "$TARGET/$KIT_SUBDIR/INSTALL.md"
copy_item "$KIT_DIR/method/01-frontmatter-schema.md" "$TARGET/wiki/meta/frontmatter-schema.md"
copy_item "$KIT_DIR/method/02-propagation-rules.md"  "$TARGET/wiki/meta/propagation-rules.md"
echo "==> Метод, роли, хардгейты и референсы → $TARGET/$KIT_SUBDIR/"

# 3. Стартовые index.md / log.md вики (только если их ещё нет)
if [[ ! -f "$TARGET/wiki/index.md" ]]; then
  cat > "$TARGET/wiki/index.md" <<'EOF'
# Wiki Index

SSOT проекта. Пишет сюда только роль `wiki-maintainer`.

## Домены
- architecture/ · data-model/ · api/ · recipes/ · decisions/

## Правила
- Каждая страница — с YAML-фронтматтером (wiki/meta/frontmatter-schema.md).
- Журнал операций — wiki/log.md.
EOF
  : > "$TARGET/wiki/log.md"
  echo "==> Создан стартовый wiki/index.md + log.md"
fi

# 4. Контракт в корень (каждый файл — раздельно, чтобы не затирать чужой)
copy_item "$KIT_DIR/AGENTS.md" "$TARGET/AGENTS.md"
copy_item "$KIT_DIR/AGENTS.md" "$TARGET/CLAUDE.md"

# 5. Подстановка {{KIT_ROOT}} во всех разложенных документах (метод/роли/тулы/контракт)
#    В целевом проекте эти файлы лежат в .savva-kit/, слои — в корне.
while IFS= read -r -d '' f; do
  sed -i "s#{{KIT_ROOT}}#${KIT_ROOT_VALUE}#g" "$f"
done < <(find "$TARGET/$KIT_SUBDIR" "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md" \
              "$TARGET/wiki/meta" -type f -name '*.md' -print0 2>/dev/null)
echo "==> Пути {{KIT_ROOT}} → ${KIT_ROOT_VALUE}"

# 6. Интерактивная подстановка плейсхолдеров проекта (по желанию)
echo
read -r -p "Проставить плейсхолдеры проекта сейчас? [y/N] " ans
if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
  read -r -p "  {{PROJECT}} (название системы): " V_PROJECT
  read -r -p "  {{OWNER}} (владелец проекта):   " V_OWNER
  read -r -p "  {{ORCHESTRATOR}} (главный агент): " V_ORCH
  read -r -p "  {{STACK}} (техстек):             " V_STACK
  read -r -p "  {{WORKSPACE}} (корень проекта):  " V_WS
  V_WS="${V_WS:-$TARGET}"
  while IFS= read -r -d '' f; do
    sed -i \
      -e "s|{{PROJECT}}|${V_PROJECT}|g" \
      -e "s|{{OWNER}}|${V_OWNER}|g" \
      -e "s|{{ORCHESTRATOR}}|${V_ORCH}|g" \
      -e "s|{{STACK}}|${V_STACK}|g" \
      -e "s|{{WORKSPACE}}|${V_WS}|g" \
      "$f"
  done < <(find "$TARGET/$KIT_SUBDIR" "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md" \
                -type f -name '*.md' ! -path '*/example-*' -print0)
  echo "==> Плейсхолдеры проставлены"
else
  echo "==> Плейсхолдеры оставлены как есть — заменишь вручную позже"
fi

echo
echo "Готово. Дальше:"
echo "  1. Открой $TARGET в своём ИИ-ассистенте."
echo "  2. Скажи: «прочитай AGENTS.md и ${KIT_SUBDIR}/method/, представься по роли оркестратора»."
echo "  3. Для ChatGPT без git — см. ${KIT_SUBDIR}/INSTALL.md, путь 2."
echo
echo "Хардгейты (опционально; bash + GNU coreutils, на Windows — WSL/Git Bash):"
echo "  • pre-commit-hook в рабочей копии кода (симлинк или копия файла на Windows):"
echo "      ln -sf \"$TARGET/${KIT_SUBDIR}/tools/hooks/pre-commit-guard.sh\" .git/hooks/pre-commit"
echo "  • ежедневный отчёт линтера — см. ${KIT_SUBDIR}/tools/README.md (systemd-таймер или cron)."
echo "  • перед закрытием крупной фичи (корень найдётся сам):"
echo "      bash \"$TARGET/${KIT_SUBDIR}/tools/gates/freshness-check.sh\""
