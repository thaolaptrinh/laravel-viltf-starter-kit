---
name: dbml
description: Use when authoring, reviewing, converting, or explaining DBML (Database Markup Language) — writing or validating .dbml schemas, designing tables/relationships/indexes/enums, converting SQL to/from DBML (PostgreSQL, MySQL, MSSQL, Oracle, Snowflake, BigQuery), debugging DBML parser errors, or working with @dbml/core, @dbml/cli, @dbml/connector, dbdiagram.io, or dbdocs.io.
license: Apache-2.0
metadata:
    category: databases
    domain: data-modeling
    source: https://github.com/holistics/dbml
---

# DBML

Expert reference for the **DBML** language and its ecosystem. Grounded in the `holistics/dbml` source + empirically verified against the installed `@dbml/*` packages. Every `examples/*.dbml` is parser-validated.

## Activation

Activate for any DBML task: **author** / **explain** / **review** / **fix** / **convert (SQL ↔ DBML)** / **diagnose parser errors** / **improve schema design**. Do not activate for rendering-only tasks (ERD drawing, image/PDF export) — those are dbdiagram.io/dbdocs.io, not DBML.

**Also re-invoke whenever the project's database schema changes** — new or edited migrations/schema files, added/renamed/dropped tables, columns, relationships, indexes, or enums — so the project's `.dbml` (when one exists) stays in sync. This trigger is **framework-agnostic**: any stack that carries a schema layer (Laravel/Rails/Django migrations, Prisma schema, Drizzle, raw DDL, …) counts. Treat a `.dbml` in a repo as a maintained artifact that must follow schema changes, not a one-time drawing.

## Supported tasks → route to a resource

Load only what you need. **Full routing is in `resources/decision-guide.md`**; the one-line map:

| Task family                                | Read                                                  |
| ------------------------------------------ | ----------------------------------------------------- |
| Language syntax                            | `resources/syntax/` (`reference.md` is the fast path) |
| Relationships / refs                       | `resources/syntax/relationships.md`                   |
| Design / naming / normalization / review   | `resources/design/`                                   |
| SQL → DBML / DBML → SQL / fidelity         | `resources/conversion/`                               |
| Parser errors / common mistakes / FAQ      | `resources/troubleshooting/`                          |
| "Can the skill do X?" / scope / boundaries | `resources/capabilities.md`                           |

**Examples (validated, copy-adapt freely):** `examples/{basic,blog,crm,ecommerce,hospital}/` · `examples/enterprise/` (multi-file module system, entry `main.dbml`) · `examples/conversion/` · `examples/review/` (broken→fixed).

## Workflow

1. Identify the task family (above) and load that one resource (start at `syntax/reference.md` for syntax asks).
2. Apply the quality rules below; copy-adapt from `examples/` rather than writing from memory.
3. Label every construct's status; state boundaries honestly.
4. Verify with a parse when correctness matters (`new Parser().parse(src, 'dbmlv2')`).

## Tooling prerequisites

Conversions run through the **`@dbml/cli`** CLI (Node.js ≥ 18): `npm install -g @dbml/cli` → bins `dbml2sql`, `sql2dbml`, `db2dbml`. **If a bin is missing, stop and ask the user to install it first** — never assume it is available or invent workarounds. Full commands + dialect flags: `resources/conversion/sql-export.md` and `sql-import.md`.

**Conversions are CLI-only:** when the user asks to convert/export/import, run `dbml2sql` / `sql2dbml` / `db2dbml`. **Do not write `.js` scripts or call the `@dbml/core` API for conversions** — the CLI is the path. (`@dbml/core` is used only for parse-validation — workflow step 4 — and DBML→DBML round-trip — `fidelity.md`.)

## Quality rules (apply to every answer)

1. **Never invent syntax.** Only `- < > <>` are relationship operators; index method is `type:` (no `using:`); expression default is `[default: \`expr\`]`(no`default_expr`); modules use `use`/`reuse`(no`import`/`namespace`); `TablePartial`injection is`~name`(not`use name`); schemas are single-level.
2. **Never conflate.** DBML-the-language ≠ SQL-import (ANTLR) ≠ dbdiagram/dbdocs (rendering). Positions/image-export/view-runtime are Tool-only, not DBML.
3. **Prefer `dbmlv2`.** The `'dbml'` key is a deprecated PEG parser. `dbml2sql` **always exits 0** even on error — check `dbml-error.log`.
4. **One item per line** inside every block body (the #1 syntax error).
5. **Match the host project's indentation.** DBML is whitespace-insensitive, so follow the convention of the project you are editing — read existing `.dbml` files, or the EditorConfig / Prettier / formatter config. Default to **2 spaces** (the DBML community convention) when the project has no preference. Keep column name, type, and `[settings]` visually aligned within each table.
6. **Always label status** with these canonical tags:
    - **Official** — in the DBML spec, parsed by `@dbml/parse`, stable (annotate _enrichment_ = parsed but no SQL equivalent; _newer_ = recent "3.0-era" addition).
    - **Experimental** — newest/least battle-tested (currently: none — all constructs are stable; reserve this if one appears).
    - **Unsupported** — rejected by the parser / does not exist in DBML (e.g. `><`, `using:`, `default_expr`).
    - **Tool-only** — dbdiagram.io/dbdocs.io rendering features that are **not** DBML (canvas positions, image/PDF export, view runtime state).
    - **Unknown** — not verifiable at runtime (state it honestly; don't guess).

This file orchestrates; it does not teach DBML. For a quick syntax refresher read `resources/syntax/reference.md`.
