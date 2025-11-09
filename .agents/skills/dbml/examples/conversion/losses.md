# Silent-loss walkthrough (`lossy_postgres.sql` → `lossy_imported.dbml`)

The input defines **4 objects**. The importer produces a DBML file with **1 table** and emits **no errors**. Here is exactly what happened to each.

| Input object                                                 | In output?  | What happened                                                                                                                                    |
| ------------------------------------------------------------ | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------ |
| `CREATE TABLE accounts (…)`                                  | ✅ survived | the table + its plain columns come through                                                                                                       |
| `email_lower text GENERATED ALWAYS AS (lower(email)) STORED` | ⚠️ partial  | the column survives as `email_lower text` — the **`GENERATED` expression `lower(email)` is lost** (no DBML representation for generated columns) |
| `CREATE VIEW active_accounts …`                              | ❌ dropped  | views have no DBML construct → silently absent                                                                                                   |
| `CREATE SEQUENCE accounts_seq …`                             | ❌ dropped  | sequences have no DBML construct → silently absent                                                                                               |
| `CREATE FUNCTION audit() …`                                  | ❌ dropped  | functions have no DBML construct → silently absent                                                                                               |

## Why this matters

The importer **never warns** about dropped objects. If you import a 200-object schema and get a 150-object DBML file, nothing tells you the 50 are missing — you must **diff the object counts** yourself. Common silent drops: views, materialized views, sequences, triggers, stored procedures/functions, most `ALTER TABLE` sub-commands, generated-column expressions, MySQL `UNSIGNED`, Snowflake `CHECK`/secondary indexes.

→ See `resources/conversion/sql-to-dbml.md` for the full mapping + drop list.
