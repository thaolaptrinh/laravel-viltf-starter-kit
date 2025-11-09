# Fidelity, Round-trip & Lossy Conversions

What survives a round-trip and what doesn't. References the canonical loss lists in `sql-import.md` (SQL→DBML silent drops) and `sql-export.md` (the DBML→SQL enrichment-loss list).

---

## DBML → DBML: near-perfect

Use the **`dbmlv2`** parser, not the legacy `'dbml'` PEG parser:

```js
const { Parser, ModelExporter } = require('@dbml/core');
const db = new Parser().parse(dbmlString, 'dbmlv2'); // ✅ modern
const out = ModelExporter.export(db, 'dbml');
```

DBML→DBML preserves **everything** (tables, refs, enums, indexes, notes, sticky notes, TableGroups, DiagramView, aliases, colors, records, checks, module info within a file).

## DBML → SQL → DBML: lossy (asymmetric)

SQL is a strict subset of DBML's expressiveness. Round-tripping through SQL **permanently loses** the entire **enrichment-loss list** (→ `sql-export.md`) — all DBML enrichment that has no SQL equivalent — **plus the `inactive` ref flag**: the FK still emits on export, but SQL has no "inactive" concept, so the marker doesn't survive the round-trip. And SQL import also drops things the original DBML never had (views, functions, etc. don't round-trip _into_ DBML either — see the SQL→DBML silent-drops list in `sql-import.md`).

---

## The `dbml` vs `dbmlv2` format gotcha (critical)

| Format     | Engine                                 | Behavior                                                                                        |
| ---------- | -------------------------------------- | ----------------------------------------------------------------------------------------------- |
| `'dbmlv2'` | `@dbml/parse` hand-written v2 compiler | **Use this.** Supports all modern features.                                                     |
| `'dbml'`   | deprecated PEG parser                  | Rejects sticky notes, records, table-group notes/colors, module system with cryptic PEG errors. |

For DBML→DBML you have **two equivalent paths**, both using the v2 engine (verified):

```js
importer.import(dbml, 'dbmlv2'); // simplest
// or
ModelExporter.export(new Parser().parse(dbml, 'dbmlv2'), 'dbml');
```

Avoid `importer.import(str, 'dbml')` — it routes to the **deprecated** PEG parser and throws on modern features. (`'dbmlv2'` _is_ accepted by `importer.import`; `'dbml'` is the legacy one.)

---

## "Does X survive conversion?" (quick two-direction lookup)

| Construct                                                  | DBML→SQL                  | SQL→DBML                |
| ---------------------------------------------------------- | ------------------------- | ----------------------- |
| tables/columns/types/pk/fk/indexes/enums/checks            | ✅                        | ✅ (per dialect quirks) |
| notes (table/column)                                       | ✅ as COMMENT             | ✅ from COMMENT         |
| Records / `INSERT`                                         | ✅ INSERT                 | ✅ Records              |
| `<>` many-to-many                                          | ✅ junction table         | n/a                     |
| generated/computed columns                                 | n/a                       | ❌ expression lost      |
| MySQL `UNSIGNED`                                           | n/a                       | ❌ lost                 |
| Views/functions/triggers/sequences                         | n/a                       | ❌ silently dropped     |
| Project/TableGroup/sticky-notes/DiagramView/aliases/colors | ❌ (enrichment-loss list) | n/a                     |

---

## Type fidelity rules

- **No type mapping, no validation, anywhere.** Types are opaque strings carried verbatim in both directions.
- The only automatic type transforms: MySQL/MSSQL `varchar` length defaulting; Postgres increment-type uppercasing; enum/increment special cases per dialect.
- **Implication:** the type you write is the type you get. `int` ≠ `integer` ≠ `INT` for rendering purposes — be deliberate and consistent (`normalization.md`).

## Two SQL paths can disagree

For PostgreSQL, the **DDL-grammar** import (`PostgresASTGen`) and the **live-connector** import (`information_schema` reconstruction) can produce slightly different type strings for the same schema. If you switch import methods, expect minor textual diffs.

---

## Modernize / clean up existing DBML

Use `dbmlv2` (not the legacy `'dbml'`). Two equivalent paths (both round-trip with full fidelity, unlike a SQL detour):

```js
importer.import(dbml, 'dbmlv2'); // simplest
new Parser().parse(dbml, 'dbmlv2'); // then ModelExporter.export(db,'dbml')
```

## Practical advice

- Treat DBML as the **source of truth**; treat generated SQL as a derived artifact.
- Keep enrichment (notes, groups, views) only in `.dbml` — it won't survive a SQL detour.
- When importing legacy SQL, **audit the result** (count tables/enums, check for dropped views/functions) rather than trusting silent success.

## "My conversion looks wrong / produced nothing"

- **Empty output:** unsupported construct silently dropped (view/function), or dialect mismatch, or `'snowflake'` export (returns `""`).
- **Parse error but exit 0:** check `dbml-error.log`; the file produced no SQL.
- **Types look odd:** verbatim, no mapping — you wrote what you got.
- **`dbml` importer failing on modern DBML:** switch to `dbmlv2`.
