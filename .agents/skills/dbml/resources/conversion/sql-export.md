# DBML → SQL Export

Get DBML _out to_ SQL via the `dbml2sql` CLI. SQL dialects: **PostgreSQL (default), MySQL, MSSQL, Oracle** — **there is no Snowflake exporter**. (DBML→DBML round-trip and JSON export are API-only — see `fidelity.md`.) For the import direction see `sql-import.md`; for round-trip/loss see `fidelity.md`.

---

## Prerequisites & Installation

The conversion CLI ships in the **`@dbml/cli`** package (requires **Node.js ≥ 18**).

```bash
npm install -g @dbml/cli      # or: yarn global add @dbml/cli  /  pnpm add -g @dbml/cli
```

This installs three global bins: **`dbml2sql`**, `sql2dbml`, `db2dbml`. **If a bin is missing when you try to run, stop and ask the user to install `@dbml/cli` first** — never assume it is available, and never invent alternative commands.

One-off without a global install (same bins, scoped invocation):

```bash
npx -p @dbml/cli dbml2sql schema.dbml --mysql -o out.sql
```

> ⚠️ `npx @dbml/cli …` does **not** work — the package name differs from the bin name. Always use `npx -p @dbml/cli <bin>`.

## Convert DBML → SQL

```bash
dbml2sql schema.dbml                 # default dialect = PostgreSQL
dbml2sql schema.dbml --mysql         # MySQL
dbml2sql schema.dbml --mssql         # SQL Server
dbml2sql schema.dbml --oracle        # Oracle
dbml2sql schema.dbml -o schema.sql   # write to file  (--out-file / -o)
```

Dialect flags: `--postgres` (default) · `--mysql` · `--mssql` · `--oracle`. **There is no `--snowflake`** (no exporter exists). Multi-file DBML: pass the **entry** file; `use`/`reuse` resolve automatically.

---

## Behavior, gotchas & limits

### ⚠️ Exit code gotcha (critical)

**`dbml2sql` always exits 0, even on hard parse errors.** Errors print to stdout as `ERROR: <file>(line,col): <msg>` and are written to `./dbml-error.log`. **Do not gate CI/scripts on the exit code** — parse the output or check the log.

### ⚠️ Duplicate/overlapping refs block output

"References with same endpoints exist" is emitted as an error and the file produces **no SQL**. Two refs between the same column pair (even opposite direction) trip it.

### Flags that DO NOT exist

`--config`, `--include`, `--out-dir`, `--snowflake` (on `dbml2sql`). `-o/--out-file` is single-file only (`--out-dir` does not exist).

---

## What survives export (all SQL dialects)

| DBML                                  | → SQL                                                                                             |
| ------------------------------------- | ------------------------------------------------------------------------------------------------- |
| tables, columns, types                | `CREATE TABLE` (types **verbatim**)                                                               |
| `[pk]` / composite PK index           | `PRIMARY KEY`                                                                                     |
| `[unique]`, `not null`                | column constraints                                                                                |
| `default:` (number/string/expression) | `DEFAULT` (`DEFAULT NULL` skipped as redundant)                                                   |
| `[increment]`                         | dialect-specific identity                                                                         |
| `ref: > / < / -`                      | `ALTER TABLE … ADD FOREIGN KEY`                                                                   |
| `delete:` / `update:`                 | `ON DELETE` / `ON UPDATE` (**`ON UPDATE` dropped on Oracle**)                                     |
| Ref names                             | `CONSTRAINT "name"`                                                                               |
| indexes                               | `CREATE INDEX` (composite-PK indexes excluded; MySQL/MSSQL auto-name unnamed `<table>_index_<n>`) |
| `Enum`                                | dialect-mapped (see below)                                                                        |
| `Checks`                              | `CHECK (…)`                                                                                       |
| table/column `note:`                  | `COMMENT` / `sp_addextendedproperty`                                                              |
| `Records`                             | `INSERT` (wrapped in constraint-deferral scaffolding)                                             |

### Enum export per dialect

| Dialect  | Enum →                            |
| -------- | --------------------------------- |
| Postgres | `CREATE TYPE "x" AS ENUM (...)`   |
| MySQL    | inline `ENUM (...)` on the column |
| MSSQL    | `CHECK (col IN (...))`            |
| Oracle   | `CHECK (col IN (...))`            |

### `increment` export per dialect

Postgres `GENERATED … AS IDENTITY` · MySQL `AUTO_INCREMENT` · MSSQL `IDENTITY(1,1)` · Oracle `GENERATED AS IDENTITY` (suppresses `NOT NULL`/`DEFAULT`).

### Type fidelity (verbatim — NO type mapping)

`integer`→`integer`, `decimal(10,2)`→`decimal(10,2)`, custom `job_status`→`job_status`. **Exceptions:** MySQL `varchar`→`varchar(255)`, MSSQL `varchar`→`nvarchar(255)`; Postgres uppercases increment-column type names to match `SERIAL`/`IDENTITY` built-ins. Non-builtin types with spaces/uppercase get double-quoted (Postgres).

---

## ❌ Lost on DBML→SQL (canonical enrichment-loss list — all dialectes)

DBML enrichment with **no SQL equivalent** is dropped on SQL export (kept on DBML→DBML). This is the canonical list; `fidelity.md` references it rather than restating it:

`Project` block · `TableGroup` · sticky notes · `DiagramView` · aliases (`as`) · enum-value notes · colors (`headercolor`, group `color`, ref `color`) · `//` comments.

---

## `<>` many-to-many synthesizes a junction table

`Ref: a.id <> b.id` → a generated `a_b` junction table with two FKs (all dialects). Oracle also emits `GRANT REFERENCES … TO PUBLIC` for cross-schema refs.

## Records surprise

By default `Records` become real `INSERT` statements wrapped in deferral scaffolding (Postgres `BEGIN; SET CONSTRAINTS ALL DEFERRED; … COMMIT;`; MySQL `SET FOREIGN_KEY_CHECKS=0/1`; MSSQL `NOCHECK CONSTRAINT ALL`/`WITH CHECK CHECK`; Oracle `SET CONSTRAINTS ALL DEFERRED` + `INSERT ALL … SELECT FROM dual`). The CLI has **no flag to suppress this** — a CLI export always emits Records as INSERTs. (Removing `Records` blocks from the `.dbml` first is the CLI way to get pure DDL.)

## Decisions before exporting

- Dialects: `--mysql --postgres --mssql --oracle`. **No Snowflake.**
- Records: a CLI export always includes them as `INSERT` (with deferral scaffolding). Want pure DDL? Strip `Records` from the source `.dbml` first.
- **Don't gate on exit code** — check `dbml-error.log`.
- Review losses: the enrichment-loss list applies (Project/TableGroup/sticky-notes/aliases/colors/enum-value notes gone).
