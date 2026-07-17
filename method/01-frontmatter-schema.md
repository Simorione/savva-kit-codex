# Frontmatter Schema для страниц wiki/

Каждая страница в `wiki/` (кроме `index.md`, `log.md`, `README.md`) **обязана** иметь
YAML-фронтматтер. Это то, что позволяет `wiki-maintainer` делать lint: находить устаревшее,
осиротевшее, противоречивое.

## Полная схема

```yaml
---
title: <человекочитаемое название>
domain: <strategy | market | marketing | content | products | identity | meta | moc | architecture | data-model | api | recipes | decisions>
created: YYYY-MM-DD
updated: YYYY-MM-DD
author: <orchestrator | owner | wiki-maintainer | ingest-helper>
status: <draft | active | stale | archived>
sources: [<ссылки на raw/* или внешние URL>]
consumers: [<кто читает: имена страниц/ролей>]
tags: [<свободные тэги>]
confidence: <low | medium | high>
review_cycle: <weekly | monthly | quarterly | never>
last_verified_against: "<против чего сверялась истинность: версия кода/снимок реальности/дата>"
---
```

## Поля

| Поле | Тип | Обяз. | Описание |
|---|---|---|---|
| `title` | string | да | Название страницы (отдельно от slug-имени файла) |
| `domain` | enum | да | Домен страницы (см. ниже) |
| `created` | date | да | Дата создания |
| `updated` | date | да | Дата последнего значимого изменения |
| `author` | string | да | Кто создал/правил последним |
| `status` | enum | да | draft / active / stale / archived |
| `sources` | array | да | Откуда взято: пути к `raw/*` или URL |
| `consumers` | array | нет | Кто использует — страницы или роли |
| `tags` | array | нет | Свободные тэги для поиска |
| `confidence` | enum | да | low / medium / high |
| `review_cycle` | enum | да | Когда пересматривать на актуальность |
| `last_verified_against` | string | нет | Против какой **реальности** сверялась истинность страницы: версия кода (хэш коммита), снимок прода, дата проверки. Отличается от `updated`: `updated` = когда правили **текст**, `last_verified_against` = против какой реальности проверяли, что текст всё ещё правда. Часть программы надёжности (`07-reliability-program.md`) |

## Домены (адаптируй под свой проект)

| Domain | Назначение |
|---|---|
| `architecture` | Как устроена система, карта модулей |
| `data-model` | Сущности, связи, глоссарий |
| `api` | Карта эндпоинтов/контрактов |
| `recipes` | Технические рецепты: баг → решение |
| `decisions` | Лог принятых архитектурных решений |
| `strategy` | Долгосрочные решения, видение, цели |
| `products` | Продукты, фичи, спецификации, roadmap |
| `meta` | Правила самой вики (роли, propagation, schema) |
| `moc` | Map of Content — навигационные хабы |

> Для чисто инженерного проекта хватит `architecture / data-model / api / recipes / decisions`.
> Маркетинговые домены (`market / marketing / content / identity`) — если вика ведёт и их.

## Жизненный цикл status

```
draft  →  active  →  stale  →  archived
                  ↘  →  archived (минуя stale, при отказе от темы)
```

- `draft` — черновик, ещё не утверждён, не цитируется.
- `active` — актуально, можно ссылаться.
- `stale` — подозрение на устаревание (по `review_cycle` или после lint).
- `archived` — устарело окончательно, оставлено для истории.

## Wikilinks

В теле страницы — `[[<slug>]]` (совместимо с Obsidian). `wiki-maintainer` строит граф ссылок
именно по этому синтаксису — так находятся осиротевшие страницы.
