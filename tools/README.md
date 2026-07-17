# tools/ — хардгейты и линтеры программы надёжности

Механические проверки, которые нельзя «уговорить». Ставятся один раз, дальше работают сами.
Подробно о роли каждого — `{{KIT_ROOT}}method/07-reliability-program.md`.

> **Требования к окружению.** Скрипты рассчитаны на **bash + GNU coreutils** (`sed -i`,
> `date -d`, `stat -c`, `find -printf`) и Python 3.10+. Это Linux и macOS с GNU-утилитами.
> На **Windows** — через **WSL** или **Git Bash** (нативный PowerShell не подойдёт: другой
> синтаксис и утилиты). Хуки подключаются симлинком в `.git/hooks` — на Windows используй
> копию файла вместо симлинка.
>
> Команды ниже запускаются **из корня проекта**. `{{KIT_ROOT}}` — префикс до каталога набора
> (после `bootstrap.sh` он уже подставлен: пусто для Claude-раскладки, `.savva-kit/` для Codex).

```
tools/
├── hooks/pre-commit-guard.sh   ← git-hook: секреты + запретные файлы + порог диффа
├── gates/freshness-check.sh    ← гейт: граф/аудит не старше кода (вика — мягкий WARN)
├── gates/CLOSING-GATES.md      ← чек-лист объективных проверок перед закрытием фичи
├── lint/layer-lint.py          ← линтер вики и слоёв без LLM (фронтматтер/ссылки/TTL/сироты)
└── evals/AGENT-EVALS.md        ← эталонные кейсы для ролей после правки промптов
```

## Установка

**pre-commit-guard** — в каждой рабочей копии кода (замени `<PROJECT>` на путь к своему проекту):

```bash
chmod +x <PROJECT>/{{KIT_ROOT}}tools/hooks/pre-commit-guard.sh
# симлинк (Linux/macOS) — или просто скопируй файл в .git/hooks/pre-commit на Windows:
ln -sf <PROJECT>/{{KIT_ROOT}}tools/hooks/pre-commit-guard.sh .git/hooks/pre-commit
```

Подстрой `MAX_FILES` и список исключений под свой проект.

**layer-lint** — вручную или по расписанию (из корня проекта):

```bash
python3 {{KIT_ROOT}}tools/lint/layer-lint.py            # текущее пространство
python3 {{KIT_ROOT}}tools/lint/layer-lint.py project/x  # конкретный подпроект
```

**freshness-check** — перед закрытием крупной фичи (Гейт D). Корень пространства находит сам:

```bash
bash {{KIT_ROOT}}tools/gates/freshness-check.sh
```

## Ритуал самоочистки (ежедневный отчёт)

Планировщик раз в сутки гоняет линтер и кладёт read-only отчёт в `workspace/lint-report.md`
(см. `{{KIT_ROOT}}method/08-self-cleaning.md`). Пример на systemd (замени `ПРОЕКТ` на корень проекта):

```ini
# ~/.config/systemd/user/layer-lint.service
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'cd ПРОЕКТ && python3 {{KIT_ROOT}}tools/lint/layer-lint.py > workspace/lint-report.md 2>&1'

# ~/.config/systemd/user/layer-lint.timer
[Timer]
OnCalendar=*-*-* 06:00:00
Persistent=true
[Install]
WantedBy=timers.target
```

```bash
systemctl --user enable --now layer-lint.timer
```

На cron — эквивалент: `0 6 * * * cd ПРОЕКТ && python3 {{KIT_ROOT}}tools/lint/layer-lint.py > workspace/lint-report.md 2>&1`.
