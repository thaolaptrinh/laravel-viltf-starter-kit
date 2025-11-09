# Normalization, Enums & Modeling Trade-offs

Data-shape design: normalization discipline, enum-vs-lookup decisions, and type choices. For relationship shape see `syntax/relationships.md`; for an audit see `review.md`.

---

## Normalization in DBML

DBML is structure-only; normalization is a design discipline you apply, then express. Target **3NF** by default; denormalize deliberately with a `note:` explaining why.

| Smell                                                   | Fix                                          |
| ------------------------------------------------------- | -------------------------------------------- |
| Repeated column groups across tables                    | extract to a referenced table                |
| A column that depends on another non-key column         | move it to its own table                     |
| Comma-separated lists in a column                       | junction table (→ `syntax/relationships.md`) |
| A "type" column driving many nullable specialty columns | consider sub-typing or a separate table      |
| Duplicate data that must stay in sync                   | single source of truth + ref                 |

---

## Enums vs lookup tables (→ `syntax/language.md`)

|                                                    | Enum                       | Lookup table |
| -------------------------------------------------- | -------------------------- | ------------ |
| Stable, small, closed set (status, role)           | ✅ best                    | ok           |
| Set may grow / needs metadata / translated         | ❌                         | ✅           |
| Needs to be referenced by FK with extra attributes | ❌                         | ✅           |
| Cross-dialect portability                          | ⚠️ maps differently per DB | ✅ universal |

- Use **`Enum`** for small closed sets (`order_status`: pending/paid/shipped).
- Use a **lookup table** when values carry their own attributes (`priority` with `sla_hours`, `label`), may change frequently, or need referential metadata.
- **Enum portability:** Postgres `CREATE TYPE`; MySQL inline `ENUM`; MSSQL/Oracle → `CHECK IN`. If you target MSSQL/Oracle, enums become CHECK constraints — fine, but know the trade-off.

---

## Data types

DBML does **no type validation** (`syntax/language.md`). Pick concrete, portable types for your target dialect; avoid ambiguous aliases (`int` vs `integer` vs `INT` are all kept verbatim and may render differently). For multi-dialect schemas, prefer the most common denominator and verify with a test export.

### Type fidelity rules (→ `conversion/`)

- **No type mapping, no validation, anywhere.** Types are opaque strings carried verbatim in both directions.
- The only automatic type transforms: MySQL/MSSQL `varchar` length defaulting; Postgres increment-type uppercasing; enum/increment special cases per dialect.
- **Implication:** the type you write is the type you get — be deliberate and consistent.

---

## Modeling trade-offs (quick reference)

| Decision       | Default                                           | When to deviate                                                |
| -------------- | ------------------------------------------------- | -------------------------------------------------------------- |
| Normalize      | 3NF                                               | denormalize for read-heavy/reporting workloads, with a `note:` |
| Enum vs lookup | Enum for closed small sets                        | lookup table when extensible/metadata-bearing                  |
| Soft delete    | `deleted_at timestamp` column + filter convention | only if the domain needs history without row removal           |
| Composite PK   | explicit `indexes { (…) [pk] }`                   | natural keys only when genuinely stable & unique               |
| Self-reference | `parent_id int [ref: > self.id]`                  | trees/graphs (categories, comment threads, org charts)         |
