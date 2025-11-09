# SQL → DBML Import

Get SQL _into_ DBML. **Two completely separate import paths — never conflate them.** For the lossy/round-trip picture see `fidelity.md`; for the export direction see `sql-export.md`. Tooling boundaries live in `capabilities.md`.

> **Prerequisites:** the CLI bins `sql2dbml` / `db2dbml` come from **`@dbml/cli`** — install once with `npm install -g @dbml/cli` (Node.js ≥ 18; same package also provides `dbml2sql`, see `sql-export.md`). **If a bin is missing, ask the user to install it before running — never assume availability.**

---

## Path 1: DDL/file import — `sql2dbml`

Parses a `.sql` text blob via **ANTLR grammars**. Match the source dialect:

```bash
sql2dbml dump.sql --postgres            # PostgreSQL
sql2dbml dump.sql --mysql               # MySQL
sql2dbml dump.sql --mssql               # SQL Server
sql2dbml dump.sql --snowflake           # Snowflake (DDL import IS supported — unlike export)
sql2dbml dump.sql --oracle              # Oracle
sql2dbml dump.sql --postgres -o out.dbml   # write to file  (--out-file / -o)
# legacy parsers (quicker, less accurate): --postgres-legacy / --mysql-legacy / --mssql-legacy
```

## Path 2: Live-DB import — `db2dbml`

Connects to a **running database** via native drivers and introspects `INFORMATION_SCHEMA`. **6 dialects, including BigQuery.**

```bash
db2dbml <dialect> "<connection-string>" -o out.dbml
# dialects: postgres | mysql | mssql | snowflake | bigquery | oracle
```

Connection string per dialect (drivers e.g. `oracledb`/`mysql2`/`pg` must be installed separately):

| Dialect   | Connection string                                                                                                                     |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| postgres  | `'postgresql://user:password@localhost:5432/dbname?schemas=schema1,schema2'`                                                          |
| mysql     | `'mysql://user:password@localhost:3306/dbname'`                                                                                       |
| mssql     | `'Server=localhost,1433;Database=master;User Id=sa;Password=...;Encrypt=true;TrustServerCertificate=true;Schemas=schema1,schema2;'`   |
| snowflake | `'SERVER=<account>.<region>;UID=<user>;PWD=<pass>;DATABASE=<db>;WAREHOUSE=<wh>;ROLE=<role>;SCHEMAS=schema1,schema2;'`                 |
| bigquery  | `/path/to/credential.json` (ADC `{}` for env auth, or service-account JSON with `project_id`/`client_email`/`private_key`/`datasets`) |
| oracle    | `'username/password@[//]host[:port][/service_name]'`                                                                                  |

## ❗ BigQuery is connector-only

There is **no DDL-file import** for BigQuery (no grammar; `ImportFormat` has no `bigquery`). The repo's `ddl_samples/bigquery.sql` is an orphan red herring. To get BigQuery into DBML you must connect live. BigQuery connector returns **no FKs, no checks, no increment** (BigQuery doesn't support them natively).

---

## What converts (DDL path) — per construct

| SQL                                                  | → DBML                                      | Notes                                                                               |
| ---------------------------------------------------- | ------------------------------------------- | ----------------------------------------------------------------------------------- |
| `CREATE TABLE` + columns                             | `Table` + columns                           | types largely **verbatim**                                                          |
| `PRIMARY KEY` (single)                               | `[pk]`                                      |                                                                                     |
| `PRIMARY KEY` (multi)                                | `indexes { (...) [pk] }`                    |                                                                                     |
| `FOREIGN KEY` / `REFERENCES`                         | `Ref … [delete: …]`                         | inline + table-level; `MATCH` clauses lost                                          |
| `UNIQUE` (single)                                    | `[unique]`                                  |                                                                                     |
| `UNIQUE` (multi)                                     | `indexes { (...) [unique] }`                |                                                                                     |
| `CREATE INDEX` / `KEY`                               | `indexes`                                   | **errors on Snowflake** (grammar has no rule → `no viable alternative`; not silent) |
| `AUTO_INCREMENT`/`IDENTITY`/`SERIAL`/`AUTOINCREMENT` | `[increment]`                               | dialect-specific detection                                                          |
| `NOT NULL`                                           | `[not null]`                                |                                                                                     |
| `DEFAULT`                                            | `[default: …]` (typed)                      |                                                                                     |
| `CHECK`                                              | table/field `checks`                        | **errors on Snowflake** (not supported; not silent)                                 |
| table/column comments                                | `note:`                                     | Postgres/MySQL/Oracle `COMMENT`; MSSQL `sp_addextendedproperty`                     |
| `CREATE TYPE … AS ENUM` (Postgres)                   | `Enum`                                      |                                                                                     |
| MySQL `ENUM('a','b')`                                | synthetic `Enum "<table>_<col>_enum"`       | column type renamed to it                                                           |
| MySQL `SET('a','b')`                                 | kept as the **literal type** `SET('a','b')` | only `ENUM` becomes a DBML `Enum`; `SET` is not converted                           |
| `INSERT INTO … VALUES`                               | `Records`                                   | only when `includeRecords` (default on)                                             |
| `ALTER TABLE ADD CONSTRAINT`                         | applied to existing table                   | only `ADD CONSTRAINT` (FK/CHECK/PK/UNIQUE); most ALTERs dropped                     |

---

## ⚠️ Silently dropped — NO error, NO output (DDL path)

These have no DBML representation and vanish without warning:

- **Views, materialized views, sequences, triggers, stored procedures/functions** (a `CREATE FUNCTION` produces nothing).
- **Most `ALTER TABLE`** sub-commands (RENAME, ADD/DROP COLUMN, type changes, owner, tablespace…).
- **Generated/computed columns** — the column survives but the **generation expression is lost** (MSSQL stuffs it into the type string as `AS (expr) PERSISTED`).
- **MySQL `UNSIGNED`/`ZEROFILL`**, charsets/collations.
- Schema/tablespace/role/policy/extension DDL.

Because drops are silent, **diff table/enum counts against the source** to catch what's missing.

---

## ⚠️ Parse errors (NOT silent) — Snowflake

Unlike the silent drops above, these **throw a `no viable alternative` error** and abort the import on Snowflake:

- **`CREATE INDEX`** (secondary indexes) — the Snowflake grammar has no rule for it.
- **`CHECK` constraints** (inline or `CONSTRAINT … CHECK`).

If your Snowflake DDL contains these, **strip them before importing** (Snowflake import supports tables, PK, UNIQUE, FK, defaults, comments — but not secondary indexes or CHECK).

---

## No type validation

A bogus type (`Intdsfsd`) passes through verbatim. Good for fidelity, bad if you expected canonicalization.

---

## After-import audit

- Match the dialect flag (`--postgres`/`--mysql`/`--mssql`/`--snowflake`/`--oracle`, plus `--postgres-legacy`/`--mysql-legacy`/`--mssql-legacy` for the quicker/less-accurate old parsers). Wrong dialect = wrong/missing output.
- **BigQuery:** use the live connector (`db2dbml bigquery "<conn>"`).
- Count tables/enums vs source; re-add views/functions/triggers as notes (silently dropped).
- Check generated-column expressions and MySQL `UNSIGNED` — both lost.
- Snowflake: strip `CREATE INDEX` and `CHECK` first (they error, not drop).
- Pass `includeRecords: false` if you don't want sample `INSERT` rows as Records.
