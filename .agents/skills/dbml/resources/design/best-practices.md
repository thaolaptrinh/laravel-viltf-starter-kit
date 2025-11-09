# Best Practices — Maintainability, Readability, Consistency

How to keep a DBML schema clean as it grows. Cross-cutting principles; for naming specifics see `naming.md`, for data shape see `normalization.md`, for an audit see `review.md`.

---

## Maintainability

- **Treat DBML as the source of truth; generated SQL as a derived artifact.** Keep enrichment (notes, groups, sticky notes) in `.dbml` — it won't survive a SQL detour (→ `conversion/fidelity.md`).
- **Keep the `.dbml` in sync when a schema layer lives alongside it.** In a repo that also carries framework migrations / Prisma / Drizzle / raw DDL, any schema change (new/renamed/dropped table, column, ref, index, enum) is a trigger to update the `.dbml` too — it is a _maintained_ artifact, not a frozen drawing. Prefer **hand-editing** the `.dbml` over auto-regenerating: a curated file captures _logical_ relationships (polymorphic morphs, soft FKs that aren't physical constraints, business notes) that a `pg_dump` → `sql2dbml` round-trip would lose. (→ SKILL.md “Activation” for the trigger.)
- **Split large schemas by domain** (`auth.dbml`, `billing.dbml`, `main.dbml`) and compose with `use`/`reuse`. Keep a single **entry file** (`main.dbml`) as the composition root (→ `syntax/advanced.md`).
- **Reuse repeated column bundles** (audit columns, soft-delete columns) via `TablePartial` injected with `~name` rather than copy-pasting (→ `syntax/advanced.md`).
- **Order tables top-down by dependency** inside a file: referenced (parent) tables before referencing (child) tables. Not required (refs resolve regardless), but it reads better and matches ERD layout intent.
- **Don't rely on `dbml2sql` exit codes** in CI — it always exits 0 even on error (→ `conversion/sql-export.md`).

## Readability

- **Document the _why_, not the _what_.** `email varchar [unique]` already says what; the note should add "login identity, case-insensitive" (the why).
- **One note per concept.** Don't repeat the same note on column + index + table.
- **Keep notes short.** Multi-line block notes (`'''…'''`) for tables that need it; inline `'…'` otherwise.
- **Use `TableGroup` and sticky notes purposefully** to segment domains and capture cross-table rationale — not as clutter.
- **Colors sparingly:** use `TableGroup color` / sticky-note color to visually segment domains; a rainbow diagram is noise.

## Consistency

- **Consistent type spelling.** DBML does no type mapping — `int` ≠ `integer` ≠ `INT` for rendering purposes; pick one and use it everywhere.
- **Consistent FK naming** (`<target>_id`) and a consistent PK convention (`id`).
- **Consistent operator direction** for the common FK case (`child.parent_id > parent.id`).
- **Match the host project's indentation.** DBML is whitespace-insensitive; follow the project's EditorConfig / Prettier / formatter config, else default to 2 spaces (DBML convention). The skill's own skeletons/examples use 2 spaces.

## Type selection (when authoring for a target SQL dialect)

DBML emits types **verbatim** — it does no dialect mapping on export (→ `conversion/sql-export.md` → "Type fidelity"). So when the `.dbml` will be exported to a specific dialect, write the **dialect-native** type the column actually becomes, not a framework abstraction or a foreign dialect's name. The export auto-fixes only a few things (MySQL `varchar`→`varchar(255)`, MSSQL `varchar`→`nvarchar(255)`, Postgres uppercasing `[increment]` column types); **everything else is your responsibility**.

### Common cross-dialect pitfalls (MySQL-ism → what to write instead)

The names on the left are **valid in MySQL only** and produce invalid DDL on Postgres. They commonly leak in when translating from framework abstractions — e.g. Laravel's `longText()` / `mediumText()` / `tinyInteger()` all collapse to simpler types on Postgres, so carrying the MySQL name into `.dbml` is wrong:

| Don't write (MySQL)                    | Write instead (Postgres)                           | Reason                                            |
| -------------------------------------- | -------------------------------------------------- | ------------------------------------------------- |
| `longtext` · `mediumtext` · `tinytext` | `text`                                             | Postgres has a single variable-length text type   |
| `tinyint` · `tinyint unsigned`         | `smallint`                                         | No 1-byte int in Postgres; smallest is `smallint` |
| `int unsigned` · `bigint unsigned`     | `bigint` / `integer` (+ optional `CHECK (x >= 0)`) | Postgres has no `unsigned`                        |
| `double`                               | `double precision`                                 | Postgres name for the 8-byte float                |
| `blob` · `longblob`                    | `bytea`                                            | Postgres binary type                              |
| `datetime`                             | `timestamp`                                        | Postgres has no `datetime`                        |

MSSQL and Oracle have their own deviations (MSSQL prefers `nvarchar(max)` for large text and `bit` for booleans; Oracle has no native `boolean` and uses `NUMBER(1)`). When unsure, check the target dialect's type list before authoring — DBML will not validate it for you.

---

## Documentation practices

DBML has rich, free-form documentation constructs. Use them to make the schema self-explaining.

| Need                                             | Use                                            |
| ------------------------------------------------ | ---------------------------------------------- |
| What a table represents / business meaning       | `Note: '...'` (block) inside the table         |
| A subtle column (units, format, derivation)      | `[note: 'amount in minor units (cents)']`      |
| A non-obvious enum value                         | `pending [note: 'awaiting payment capture']`   |
| A non-obvious index (esp. expression)            | `(...)[note: 'case-insensitive login lookup']` |
| Cross-table rationale / TODOs / design decisions | **Sticky note** `Note name [color:] { '...' }` |
| Diagram grouping                                 | `TableGroup`                                   |

### What does NOT count as documentation

- `//` and `/* */` comments are **trivia** — not stored as notes, don't travel to exports or the model. Use `note:`/`Note:` for anything that should persist.
- `Project.note` is a one-line project description, not per-entity docs.

### Survives export?

Notes survive **DBML→DBML** round-trips. On **DBML→SQL**, table/column notes become `COMMENT`/extended-property statements (Postgres/MySQL/Oracle) or `sp_addextendedproperty` (MSSQL); **enum-value notes and sticky notes are lost**. Don't put critical info only in places that vanish on export.

### Generating documentation (the DBML-native way)

There is **no DBML "render" command** — DBML produces a model, not a document. To "generate docs" the DBML-native way, **enrich the schema** (`Project.note`, table/column `note:`, `TableGroup`, sticky notes, `Records`) and hand the `.dbml` to a **renderer**: **dbdocs.io** renders DBML into browsable documentation; **dbdiagram.io** renders ERDs. DBML itself is database-agnostic and does not draw or export images/PDFs (those are Tool-only features — → `capabilities.md`).
