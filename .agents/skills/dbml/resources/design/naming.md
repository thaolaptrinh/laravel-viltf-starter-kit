# Naming & Schema Organization

How to name things and organize a schema for clarity. DBML **enforces none** of these — they are conventions; the parser is case/format-agnostic. For design-quality auditing see `review.md`.

---

## Naming conventions (recommendations; DBML enforces none)

- **Tables:** `snake_case`, **singular** (`user`, `order_item`) — or pick plural and be 100% consistent. The parser doesn't care; your readers do.
- **Columns:** `snake_case`. Booleans prefixed `is_`/`has_` (`is_active`). Timestamps as `_at` (`created_at`, `deleted_at`).
- **Primary keys:** a consistent `id` (or `<table>_id` for FKs). Consistency here pays off across every relationship.
- **Foreign keys:** `<target_singular>_id` (`user_id`, `order_id`) — makes inline `[ref: > users.id]` read naturally.
- **Enums:** singular noun (`role`, `order_status`); values lowercase.
- **Quoting:** avoid unless required. Quote only names with spaces/special chars (`"Order Details"`). Over-quoting adds noise.

## Schema organization

- DBML supports a **single schema level**: `schema.table`. Use schemas to group by bounded context (`auth.users`, `billing.invoices`), not as a deep hierarchy.
- Default schema is `public`; unqualified tables land there.
- **Never** use nested schemas (`a.b.c`) — it's unsupported (emits `UNSUPPORTED`) and unreliable.

## Large-schema modularity (→ `syntax/advanced.md`)

- Split a monolithic file per domain (`auth.dbml`, `billing.dbml`, `main.dbml`) and compose with `use`/`reuse`.
- `use` for private imports; `reuse` to re-export shared building blocks (e.g. a `common.dbml` with `TablePartial audited`).
- Keep the **entry file** (`main.dbml`) as the composition root.

## Table ordering inside a file

- Order tables top-down by dependency: referenced (parent) tables before referencing (child) tables. Not required, but reads better and matches ERD layout intent.
- Group related tables visually with `TableGroup` and `Note`/sticky notes (→ `best-practices.md`).
