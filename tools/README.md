# tools/ — хардгейты и линтеры программы надёжности

Механические проверки, которые нельзя «уговорить». Ставятся один раз, дальше работают сами.
Подробно о роли каждого — `method/08-reliability-program.md`.

```
tools/
├── hooks/pre-commit-guard.sh   ← git-hook: секреты + запретные файлы + порог диффа
├── gates/freshness-check.sh    ← гейт: опоры (граф/аудит/вики) не старше кода
├── gates/CLOSING-GATES.md      ← чек-лист объективных проверок перед закрытием фичи
├── lint/layer-lint.py          ← линтер вики и слоёв без LLM (фронтматтер/ссылки/TTL/сироты)
└── evals/AGENT-EVALS.md        ← эталонные кейсы для ролей после правки промптов
```

## Установка

**pre-commit-guard** — в каждой рабочей копии кода:

```bash
chmod +x tools/hooks/pre-commit-guard.sh
ln -sf ../../tools/hooks/pre-commit-guard.sh .git/hooks/pre-commit
```

Подстрой `MAX_FILES` и список исключений под свой проект.

**layer-lint** — вручную или по расписанию:

```bash
python3 tools/lint/layer-lint.py            # текущее пространство
python3 tools/lint/layer-lint.py project/x  # конкретный подпроект
```

**freshness-check** — перед закрытием крупной фичи (Гейт D):

```bash
bash tools/gates/freshness-check.sh
```

## Ритуал самоочистки (ежедневный отчёт)

Планировщик раз в сутки гоняет линтер и кладёт read-only отчёт в `workspace/lint-report.md`
(см. `method/09-self-cleaning.md`). Пример на systemd:

```ini
# ~/.config/systemd/user/layer-lint.service
[Service]
Type=oneshot
ExecStart=/bin/sh -c 'cd %h/ПРОЕКТ && python3 tools/lint/layer-lint.py > workspace/lint-report.md 2>&1'

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

На cron — эквивалентная строка: `0 6 * * * cd ПРОЕКТ && python3 tools/lint/layer-lint.py > workspace/lint-report.md 2>&1`.
