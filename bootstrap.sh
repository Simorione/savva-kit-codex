#!/usr/bin/env bash
# savva-kit bootstrap — раскладывает скелет 4-слойной вики в целевой проект
# и подключает контракт/роли. Идемпотентен: не перезаписывает существующее без спроса.
set -euo pipefail

KIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-}"

if [[ -z "$TARGET" ]]; then
  echo "Usage: ./bootstrap.sh /path/to/your/project"
  echo "Разложит raw/ inbox/ workspace/ wiki/, положит метод и контракт."
  exit 1
fi

mkdir -p "$TARGET"
TARGET="$(cd "$TARGET" && pwd)"
echo "==> Целевой проект: $TARGET"

# 1. 4-слойка
for layer in raw inbox workspace wiki wiki/meta; do
  mkdir -p "$TARGET/$layer"
done
echo "==> Слои raw/ inbox/ workspace/ wiki/ готовы"

# 2. Метод и мета-правила
mkdir -p "$TARGET/.savva-kit"
cp -R "$KIT_DIR/method"           "$TARGET/.savva-kit/"
cp -R "$KIT_DIR/agents"           "$TARGET/.savva-kit/"
cp -R "$KIT_DIR/skills"           "$TARGET/.savva-kit/"
cp    "$KIT_DIR/method/01-frontmatter-schema.md" "$TARGET/wiki/meta/frontmatter-schema.md"
cp    "$KIT_DIR/method/02-propagation-rules.md"  "$TARGET/wiki/meta/propagation-rules.md"
echo "==> Метод и роли скопированы в $TARGET/.savva-kit/"

# 3. Стартовый index.md вики (если ещё нет)
if [[ ! -f "$TARGET/wiki/index.md" ]]; then
  cat > "$TARGET/wiki/index.md" <<'EOF'
# Wiki Index

SSOT проекта. Пишет сюда только роль `wiki-maintainer`.

## Домены
- architecture/ — как устроена система
- data-model/   — сущности и связи
- api/          — карта эндпоинтов
- recipes/      — рецепты (баг → решение)
- decisions/    — лог технических решений

## Журнал
См. `wiki/log.md`.
EOF
  : > "$TARGET/wiki/log.md"
  echo "==> Создан стартовый wiki/index.md + log.md"
fi

# 4. Контракт в корень (AGENTS.md для Codex + копия как CLAUDE.md)
if [[ ! -f "$TARGET/AGENTS.md" ]]; then
  cp "$KIT_DIR/AGENTS.md" "$TARGET/AGENTS.md"
  cp "$KIT_DIR/AGENTS.md" "$TARGET/CLAUDE.md"
  echo "==> Контракт положен: $TARGET/AGENTS.md (+ CLAUDE.md)"
else
  echo "==> AGENTS.md уже существует — пропускаю (не перезаписываю)"
fi

# 5. Интерактивная подстановка плейсхолдеров (по желанию)
echo
read -r -p "Проставить плейсхолдеры сейчас? [y/N] " ans
if [[ "${ans:-N}" =~ ^[Yy]$ ]]; then
  read -r -p "  {{PROJECT}} (название системы): " V_PROJECT
  read -r -p "  {{OWNER}} (владелец проекта):   " V_OWNER
  read -r -p "  {{ORCHESTRATOR}} (главный агент): " V_ORCH
  read -r -p "  {{STACK}} (техстек):             " V_STACK
  read -r -p "  {{WORKSPACE}} (корень проекта):  " V_WS
  V_WS="${V_WS:-$TARGET}"
  # заменяем во всех markdown целевого проекта, кроме example-*
  find "$TARGET/.savva-kit" "$TARGET/AGENTS.md" "$TARGET/CLAUDE.md" -type f -name '*.md' \
    ! -path '*/example-*' -print0 | while IFS= read -r -d '' f; do
    sed -i \
      -e "s|{{PROJECT}}|${V_PROJECT}|g" \
      -e "s|{{OWNER}}|${V_OWNER}|g" \
      -e "s|{{ORCHESTRATOR}}|${V_ORCH}|g" \
      -e "s|{{STACK}}|${V_STACK}|g" \
      -e "s|{{WORKSPACE}}|${V_WS}|g" \
      "$f"
  done
  echo "==> Плейсхолдеры проставлены"
else
  echo "==> Плейсхолдеры оставлены как есть — заменишь вручную позже"
fi

echo
echo "Готово. Дальше:"
echo "  1. Открой $TARGET в своём ИИ-ассистенте."
echo "  2. Скажи ему: «прочитай AGENTS.md и .savva-kit/method/, представься по роли оркестратора»."
echo "  3. Для ChatGPT без git — см. INSTALL.md, путь 2."
