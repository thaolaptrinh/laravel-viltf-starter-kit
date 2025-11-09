# Common Mistakes & FAQ

The highest-frequency **general** mistakes, each shown `❌ cause → ✅ fix` once. (Relationship-specific mistakes — fake operators, inline ref actions, duplicate refs, dangling/missing-PK refs — live in `syntax/relationships.md`.) The same broken→fixed pairs ship as runnable files in `examples/review/`. FAQ at the end.

---

## Common mistakes (broken → fixed)

### 1. Index method keyword

```
// ❌ → "Unknown index setting 'using'"
indexes { (email) [using: btree] }
// ✅
indexes { (email) [type: btree] }
```

### 2. Expression default keyword

```
// ❌ → "Unknown column setting 'default_expr'"
created_at timestamp [default_expr: `now()`]
// ✅
created_at timestamp [default: `now()`]
```

### 3. Multiple items on one line in a block body

```
// ❌ → "These fields must be some inline settings…" / "An Enum must have only a field…"
Table users { id int name varchar }
Enum status { active inactive done }
// ✅ one item per line — always
Table users {
  id int [pk]
  name varchar
}
Enum status {
  active
  inactive
  done
}
```

### 4. `headercolor` in the body

```
// ❌ → "A Custom element can only appear in a Project"
Table users { headercolor: #3498DB  id int [pk] }
// ✅ in the header
Table users [headercolor: #3498DB] {
  id int [pk]
}
```

### 5. Nested schema

```
// ❌ → "Nested schema is not supported" (non-fatal, unreliable)
Table billing.invoice.line { id int }
// ✅ single level (use a separate table for the extra dimension)
Table billing.invoices { id int [pk] }
Table billing.invoice_lines {
  id         int [pk]
  invoice_id int [ref: > billing.invoices.id]
}
```

### 6. Module keywords

```
// ❌ → parse error ('import' is not a keyword); 'namespace' is no construct
import * from './x'
namespace auth { ... }
// ✅ use/reuse (schemas ARE the namespace)
use * from './x'      // or: reuse * from './x'
```

### 7. `TablePartial` injection written as `use`

```
// ❌ parses but treats 'use' as a column name — injects nothing
Table users {
  use audited
  id int [pk]
}
// ✅ inject with ~name
Table users {
  ~audited
  id int [pk]
}
```

### 8. Ref settings on the wrong line (inline / separate line)

→ relationship-specific: see `syntax/relationships.md` (inline refs can't carry actions; block-ref settings go on the same line as the relationship).

### 9. Conversion misconceptions

- **BigQuery DDL import doesn't exist** — connector-only (live DB). (→ `conversion/sql-import.md`)
- **Snowflake export doesn't exist** — `'snowflake'` returns `""`. (→ `conversion/sql-export.md`)
- **`dbml2sql` exit code is always 0** — even on errors; check `dbml-error.log`.
- **`importer.import(str,'dbml')` uses the deprecated PEG parser** — use `Parser.parse(str,'dbmlv2')` (or `importer.import(str,'dbmlv2')`) for modern DBML.

### 10. Expecting type validation/canonicalization

DBML does **NO** type checking — `amount Intdsfsd` is not caught; `int` vs `integer` vs `INT` are all kept as-written. Pick deliberate, consistent types. (→ `syntax/language.md`)

### 11. Expecting comments to become documentation

`//` and `/* */` are **trivia** — they don't become `note:` and don't travel. Use `note:`/`Note:` for persistent docs.

---

## FAQ

**What version of DBML is this?** DBML's npm packages are at `8.x`; the engine self-describes as **"parser v2"** (the 2nd-generation hand-written compiler). The community label **"DBML 3.0"** refers to the modern construct set (module system, TablePartial, Records, DiagramView, sticky notes) — there is no version literal parsed from `.dbml`. Always parse with the **`dbmlv2`** format key; the `'dbml'` key is a deprecated PEG parser.

**`dbml` vs `dbmlv2`?** `'dbmlv2'` = the current `@dbml/parse` engine — use it. `'dbml'` = deprecated PEG parser that throws on modern features. For DBML→DBML: `importer.import(str,'dbmlv2')` or `ModelExporter.export(new Parser().parse(str,'dbmlv2'),'dbml')` — avoid `'dbml'`. (→ `conversion/fidelity.md`)

**Can I import a BigQuery `.sql` file?** No. BigQuery has **no DDL-file import**. Use the live connector: `db2dbml bigquery "<conn>"` or `connector.fetchSchemaJson`. (BigQuery connector returns no FKs/checks/increment.)

**Can I export DBML to Snowflake SQL?** No. Export targets are `{dbml, mysql, postgres, json, mssql, oracle}`. `'snowflake'` returns an empty string.

**Does DBML support `VIEW`s / stored procedures / triggers / sequences?** Not as language constructs. They're silently dropped on SQL import. Document them with `note:`/sticky notes if needed.

**Where's the PDF/PNG/image export?** Not in the npm libs. That's a **dbdiagram.io / dbdocs.io** feature. (→ `capabilities.md`)

**Does `dbml2sql` fail loudly on bad input?** It prints errors and writes `dbml-error.log`, but **always exits 0**. Don't gate CI on the exit code.

**Are table positions / colors / view layout part of DBML?** Only `DiagramView` (a _visibility filter_) and color settings (`headercolor`, group/ref `color`) are DBML. Canvas x/y, per-view geometry, z-order, and "synced" runtime state are **dbdiagram/dbdocs-only** — never serialized to `.dbml`.

**Is `default_expr` / `using:` a thing?** No. Expression defaults are `[default: \`expr\`]`; index method is `[type: btree|hash]`.

**What's a "namespace" in DBML?** There's no `namespace` construct — **schemas are the namespace** (`schema.table`), single level. Cross-file composition uses `use`/`reuse`.

**Does DBML validate types?** No. Types are opaque strings carried verbatim (no mapping, no checking). You write what you get.

**Mermaid relationship operators (`>-`, `-<`, `><`)?** Not valid. Only `- < > <>`. (→ `syntax/relationships.md`)

**Do `//` comments become documentation?** No — they're trivia and don't travel. Use `note:`/`Note:` for persistent docs.

**Modernize old `.dbml`?** Re-parse with `dbmlv2` — it round-trips with full fidelity, unlike a SQL detour. (→ `conversion/fidelity.md`)
