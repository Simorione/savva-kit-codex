#!/usr/bin/env python3
"""layer-lint — механический линтер слоёв (программа надёжности).

Проверяет здоровье вики и слоёв без LLM: фронтматтер по схеме, источники, битые ссылки,
протухание по review_cycle, сироты, TTL слоёв inbox/ и workspace/.

Использование:
  python3 tools/lint/layer-lint.py            # текущее пространство (корень = .)
  python3 tools/lint/layer-lint.py <корень>   # конкретное пространство/подпроект
"""
import re
import sys
import time
from datetime import date, datetime
from pathlib import Path

REQUIRED_KEYS = ["title", "created", "updated", "status", "sources", "review_cycle"]
STALE_WINDOW_DAYS = {"weekly": 14, "monthly": 45, "quarterly": 120, "never": 10**6}
SKIP_NAMES = {"index.md", "log.md", "README.md"}
INBOX_TTL_DAYS = 7
WORKSPACE_TTL_DAYS = 14


def parse_frontmatter(text: str) -> dict | None:
    if not text.startswith("---"):
        return None
    end = text.find("\n---", 3)
    if end == -1:
        return None
    fm = {}
    for line in text[3:end].splitlines():
        m = re.match(r"^(\w[\w_-]*):\s*(.*)$", line)
        if m:
            fm[m.group(1)] = m.group(2).strip()
    return fm


def check_wiki(wiki: Path, problems: list[str]) -> None:
    pages = [p for p in wiki.rglob("*.md") if p.name not in SKIP_NAMES]
    all_names = {p.stem for p in wiki.rglob("*.md")}
    linked: set[str] = set()

    # исходящие ссылки служебных страниц (index/log/README) тоже считаются входящими
    for svc in (p for p in wiki.rglob("*.md") if p.name in SKIP_NAMES):
        text = svc.read_text(encoding="utf-8", errors="replace")
        for ml in re.findall(r"\]\(([^)#]+\.md)", text):
            if not ml.startswith("http"):
                linked.add(Path(ml).stem)
        for wl in re.findall(r"\[\[([^\[\]|#]+)\]\](?!\()", text):
            linked.add(wl.strip())

    for page in pages:
        rel = page.relative_to(wiki.parent)
        text = page.read_text(encoding="utf-8", errors="replace")
        fm = parse_frontmatter(text)

        if fm is None:
            problems.append(f"[frontmatter] {rel}: нет YAML-фронтматтера")
        else:
            for key in REQUIRED_KEYS:
                if key not in fm:
                    problems.append(f"[frontmatter] {rel}: нет поля '{key}'")
            src = fm.get("sources", "")
            if src in ("", "[]", "[ ]"):
                problems.append(f"[sources] {rel}: пустые sources — знание без источника")
            cycle = fm.get("review_cycle", "")
            updated = fm.get("updated", "")
            if cycle in STALE_WINDOW_DAYS and updated:
                try:
                    upd = datetime.strptime(updated[:10], "%Y-%m-%d").date()
                    age = (date.today() - upd).days
                    if age > STALE_WINDOW_DAYS[cycle]:
                        problems.append(
                            f"[stale] {rel}: updated {updated[:10]} ({age} дн.) при review_cycle={cycle}"
                        )
                except ValueError:
                    problems.append(f"[frontmatter] {rel}: не разобрать updated='{updated}'")

        # ссылки: [[wiki]] и markdown [текст](путь.md); формат [[имя]](путь.md) считается markdown
        md_targets = re.findall(r"\]\(([^)#]+\.md)", text)
        for wl in re.findall(r"\[\[([^\[\]|#]+)\]\](?!\()", text):
            name = wl.strip()
            linked.add(name)
            if name not in all_names:
                problems.append(f"[link] {rel}: [[{name}]] не существует")
        for ml in md_targets:
            if ml.startswith("http"):
                continue
            linked.add(Path(ml).stem)
            target = (page.parent / ml).resolve()
            if not target.exists():
                problems.append(f"[link] {rel}: битая ссылка {ml}")

    # сироты (никто не ссылается)
    for page in pages:
        if ".backup-" in page.name:
            continue  # архивные копии — не сироты
        if page.stem not in linked and page.parent.name != "meta":
            problems.append(f"[orphan] {page.relative_to(wiki.parent)}: нет входящих [[ссылок]]")


def check_ttl(root: Path, problems: list[str]) -> None:
    now = time.time()
    for layer, ttl in (("inbox", INBOX_TTL_DAYS), ("workspace", WORKSPACE_TTL_DAYS)):
        d = root / layer
        if not d.is_dir():
            continue
        # .ttl-keep — осознанные исключения: «имя — причина», по строке на запись
        keep: set[str] = set()
        keep_file = d / ".ttl-keep"
        if keep_file.is_file():
            for line in keep_file.read_text(encoding="utf-8").splitlines():
                line = line.strip()
                if line and not line.startswith("#"):
                    keep.add(line.split(" — ")[0].split(" - ")[0].strip())
        for f in d.iterdir():
            if f.name.startswith("."):
                continue
            if f.name in keep:
                continue
            age = (now - f.stat().st_mtime) / 86400
            if age > ttl:
                problems.append(f"[ttl] {layer}/{f.name}: {age:.0f} дн. (TTL {ttl})")


def main() -> int:
    root = Path(sys.argv[1]).resolve() if len(sys.argv) > 1 else Path(".").resolve()
    problems: list[str] = []
    wiki = root / "wiki"
    if wiki.is_dir():
        check_wiki(wiki, problems)
    else:
        problems.append(f"[error] {root}: нет каталога wiki/")
    check_ttl(root, problems)

    print(f"layer-lint: {root}")
    if not problems:
        print("OK: проблем не найдено")
        return 0
    by_kind: dict[str, int] = {}
    for p in problems:
        kind = p.split("]")[0].lstrip("[")
        by_kind[kind] = by_kind.get(kind, 0) + 1
    print(f"Найдено проблем: {len(problems)} " + str(by_kind))
    for p in sorted(problems):
        print("  " + p)
    return 1


if __name__ == "__main__":
    sys.exit(main())
