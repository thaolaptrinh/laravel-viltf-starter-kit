# Schema Review — Checklist & Common Design Problems

An actionable audit. Each item points to the resource that explains the cause/fix. Pair with `troubleshooting/common-mistakes.md` for syntax errors.

---

## Structure & validity (parser-level)

- [ ] Every `Table` has ≥1 column.
- [ ] No nested schemas (`a.b.c`) — single-level `schema.table` only. (`syntax/language.md`)
- [ ] No duplicate refs between the same endpoint pair (throws + blocks export). (`syntax/relationships.md`)
- [ ] No dangling refs (`ref: > missing.id`) — aborts the whole build. (`syntax/relationships.md`)
- [ ] No invented settings: `using:`, `default_expr`, `headercolor:` in body. (`syntax/language.md`, `syntax/reference.md`)
- [ ] Block bodies are one-item-per-line. (`syntax/reference.md`)
- [ ] Relationship operators are only `- < > <>` (no Mermaid ops). (`syntax/relationships.md`)
- [ ] `TablePartial` injection uses `~name`, not `use name` (inside a table). (`syntax/advanced.md`)

## Keys & relationships

- [ ] Every table has a **primary key** (single `[pk]` or composite `indexes { (...) [pk] }`).
- [ ] Every FK column has a matching `ref:`. (`syntax/relationships.md`)
- [ ] Every FK column is **indexed** (common perf bug). (`syntax/language.md`)
- [ ] Many-to-many uses an explicit junction table (or `<>` is intentional). (`syntax/relationships.md`)
- [ ] `not null` on FKs unless genuinely optional.
- [ ] Referential actions (`delete:`/`update:`) are deliberate; Oracle drops `on update`. (`syntax/relationships.md`)

## Naming & consistency

- [ ] Consistent table naming (singular `snake_case` recommended). (`naming.md`)
- [ ] FK columns named `<target>_id`.
- [ ] Consistent type spelling (don't mix `int`/`integer`/`INT` — emitted verbatim). (`normalization.md`)
- [ ] Indentation matches the host project (EditorConfig / Prettier / formatter config); default to 2 spaces when none. (`best-practices.md`)
- [ ] Enum values one-per-line, lowercase. (`syntax/language.md`)

## Indexes

- [ ] No redundant indexes (prefix of composite PK, duplicate of a `[unique]` column).
- [ ] Expression indexes documented with `[note:]`.
- [ ] `type:` (not `using:`); `hash` only where the target DB supports it.

## Normalization & enums

- [ ] No repeated column groups; no list-in-a-column; no transitive dependencies. (`normalization.md`)
- [ ] Enums for closed small sets; lookup tables for extensible/metadata-bearing sets. (`normalization.md`)

## Documentation & organization

- [ ] Important tables/columns have `note:` explaining _why_. (`best-practices.md`)
- [ ] `TableGroup`s and sticky notes used purposefully, not as clutter. (`best-practices.md`)
- [ ] Large schemas split via `use`/`reuse` with a clear entry file. (`naming.md`, `syntax/advanced.md`)

## Conversion readiness (if exporting)

- [ ] Types are target-dialect-correct — no MySQL-isms on Postgres (`longtext`/`mediumtext`→`text`, `tinyint`→`smallint`, no `unsigned`). No validation is done for you. (`design/best-practices.md`, `conversion/sql-export.md`)
- [ ] You've decided on `includeRecords` (Records → `INSERT` by default). (`conversion/sql-export.md`)
- [ ] Not relying on Snowflake export (unsupported) or BigQuery DDL import. (`conversion/sql-import.md`)
- [ ] CI does **not** gate on `dbml2sql` exit code (always 0). (`conversion/sql-export.md`)

---

## Common design problems & recommendations

| Problem                                     | Recommendation                                                                |
| ------------------------------------------- | ----------------------------------------------------------------------------- |
| Wide tables with many nullable columns      | split by concern; consider sub-typing or a separate table                     |
| Missing FK indexes                          | index every `[ref: >]` column — the #1 real-world perf bug                    |
| Over-indexing                               | index for actual query patterns, not "just in case"; every index slows writes |
| Many-to-many via `<>` in a published schema | replace with an explicit junction table (carries attributes, exports cleanly) |
| Duplicate data kept "in sync" by app logic  | single source of truth + ref; let a ref enforce it                            |
| Notes duplicated on column + index + table  | one note per concept (`best-practices.md`)                                    |
| Monolithic file that's hard to navigate     | split per domain; compose with `use`/`reuse` (`naming.md`)                    |
| Enums that keep growing                     | promote to a lookup table (`normalization.md`)                                |
