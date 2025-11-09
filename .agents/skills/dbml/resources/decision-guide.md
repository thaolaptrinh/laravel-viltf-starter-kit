# Decision Guide — "I want to…" → resource & example

Two indexes: (1) task → resource, (2) example → concept. For the capability inventory and scope boundaries see `capabilities.md`; for activation rules see `SKILL.md`.

---

## Task → resource

| I want to…                                  | Read first                                                                                          | Then                                               |
| ------------------------------------------- | --------------------------------------------------------------------------------------------------- | -------------------------------------------------- |
| write / author DBML from scratch            | `syntax/language.md` (tables/columns/types/defaults/constraints) + `syntax/reference.md` (skeleton) | matching example below                             |
| add a relationship / decide cardinality     | `syntax/relationships.md`                                                                           | `design/normalization.md` (trade-offs)             |
| add defaults / pick types                   | `syntax/language.md` → Defaults & Types                                                             | `design/normalization.md` → Data types             |
| add indexes / a composite PK                | `syntax/language.md` → Indexes                                                                      | `design/review.md`                                 |
| use an enum vs a lookup table               | `syntax/language.md` → Enums                                                                        | `design/normalization.md`                          |
| document the schema                         | `syntax/advanced.md` → Notes                                                                        | `design/best-practices.md`                         |
| reuse columns across tables                 | `syntax/advanced.md` → TablePartial (`~`)                                                           | —                                                  |
| split a big schema across files             | `syntax/advanced.md` → Module system                                                                | `design/naming.md`                                 |
| render docs / an ERD                        | `design/best-practices.md` → Generating documentation                                               | `capabilities.md` (renderers are dbdiagram/dbdocs) |
| review a schema for quality                 | `design/review.md`                                                                                  | `design/best-practices.md`                         |
| fix a parse error / "why won't this parse?" | `troubleshooting/parser-errors.md`                                                                  | `troubleshooting/common-mistakes.md`               |
| import a `.sql` dump into DBML              | `conversion/sql-import.md`                                                                          | —                                                  |
| import a **live** database (incl. BigQuery) | `conversion/sql-import.md` → Path 2                                                                 | —                                                  |
| export DBML to SQL                          | `conversion/sql-export.md`                                                                          | —                                                  |
| round-trip / modernize / losses             | `conversion/fidelity.md`                                                                            | `troubleshooting/common-mistakes.md` → FAQ         |
| know if a feature exists / its status       | `syntax/reference.md` → Status map                                                                  | `capabilities.md` → Scope boundaries               |
| answer "which tool does X?" / scope         | `capabilities.md`                                                                                   | —                                                  |

---

## Example → concept index

Every example under `examples/` is parser-validated. Each teaches a distinct pattern — copy and adapt.

### Domain schemas

| Example                    | Concept(s) it uniquely teaches                                                                                                                                                                                                          |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `basic/notes_app.dbml`     | **The minimal non-toy baseline.** `Project`, `Enum`, inline `[ref: >]`, `[default:]` (literal + expression), single/composite/unique indexes, `[note:]`. Start here.                                                                    |
| `blog/blog.dbml`           | **Junction table** (`post_tags`) for many-to-many, **self-reference** (`comments.parent_id`), an **expression index** (`` `lower(title)` ``), an `Enum`, a `TableGroup`. The recommended explicit-junction pattern (vs `<>`).           |
| `crm/crm.dbml`             | **Multi-schema** (`core.`/`sales.`), cross-schema refs, an `Enum`, a **composite index** `(owner_id, stage)`, **quoting a reserved word** (`"at"`).                                                                                     |
| `ecommerce/ecommerce.dbml` | **Medium-large.** money/precision types (`decimal(10,2)`), `CHECK` constraints (block + inline), an `Enum`, **FK indexes everywhere**, a **self-referencing** category tree, a composite `(customer_id, status)` index, a `TableGroup`. |
| `hospital/hospital.dbml`   | time/date fields, **soft delete** (`deleted_at`), two `Enum`s, a **composite time index** `(doctor_id, "when")`, **quoting a reserved word** (`"when"`), `CHECK` constraints (capacity > 0; discharge ≥ admit), a `TableGroup`.         |

### Enterprise (multi-file) — `enterprise/`, entry = `main.dbml`

| File           | Role                                                                                                                                |
| -------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `common.dbml`  | shared `TablePartial audited` (audit columns), imported by all                                                                      |
| `auth.dbml`    | identity module (`users`, `api_keys`, `role` enum); imports the partial from common, injects with `~audited`                        |
| `billing.dbml` | `subscriptions`, `invoices`, `payments`; `use`s `users` from auth + the partial from common                                         |
| `main.dbml`    | **entry/composition root**: `use`s users + billing, adds ops tables, `Project`, `TableGroup`, `Records`, sticky note, `DiagramView` |

Demonstrates: the **module system** (`use`, cross-file refs), **`TablePartial` import + `~` injection** (`~audited` in every table), **`Records`** (sample data), **`DiagramView`** (a visibility filter), **`TableGroup`** (members must be locally defined — it groups `notifications`/`audit_log`, not the imported tables), and a **sticky note** with a color.

Compile with the multifile API:

```js
const p = new Parser();
['common', 'auth', 'billing', 'main'].forEach((f) =>
    p.setDbmlSource(
        `<abs>/enterprise/${f}.dbml`,
        fs.readFileSync(`…/${f}.dbml`, 'utf8'),
    ),
);
const db = p.parseDbmlProject(`<abs>/enterprise/main.dbml`);
```

### Conversion — `conversion/` (outputs are real importer-generated)

| Input                | Output                              | What it shows                                                                                                                                                    |
| -------------------- | ----------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `postgres_input.sql` | `imported.dbml`                     | clean conversion: `CREATE TYPE … AS ENUM` → `Enum`; `serial` → `[pk, increment]`; FK → `Ref … [delete: cascade]`; `CREATE INDEX` → `indexes`; `COMMENT` → `note` |
| `lossy_postgres.sql` | `lossy_imported.dbml` + `losses.md` | **silent losses**: the `VIEW`, `SEQUENCE`, and `FUNCTION` vanish; the `GENERATED` column keeps its type but loses `lower(email)`                                 |
| `mysql_enum.sql`     | `mysql_enum.dbml`                   | MySQL `ENUM('a','b')` → a synthetic `Enum "orders_status_enum"`; `unsigned` dropped; `auto_increment` → `[increment]`                                            |

### Review — `review/` (broken → fixed pairs)

Each `*_broken.dbml` is **intentionally invalid** (fails to parse, by design); each `*_fixed.dbml` is the corrected version. (Full mistake set: `troubleshooting/common-mistakes.md`, `syntax/relationships.md`.)

| Pair                       | Mistake                                                                             |
| -------------------------- | ----------------------------------------------------------------------------------- |
| `01_relationship_operator` | `><` / `-<` / `>-` are not DBML — use `- < > <>` (here: an explicit junction table) |
| `02_body_layout`           | multiple items on one line — one item per line in every block body                  |
| `03_index_default`         | `[using: …]` → `[type: …]`; `[default_expr: …]` → `[default: \`…\`]`                |
| `04_duplicate_ref`         | two refs between the same column pair — define each relationship once               |
