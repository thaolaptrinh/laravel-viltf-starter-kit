# Capabilities, Limitations & Scope

What this skill can and cannot do, and where the boundary between **DBML-the-language** and the surrounding packages/tools lies. No syntax here — this is the inventory and the scope line.

---

## Supported tasks

| Task                                                          | Handled by | Where to look                                                         |
| ------------------------------------------------------------- | ---------- | --------------------------------------------------------------------- |
| Generate DBML (write valid `.dbml`)                           | ✅         | `syntax/language.md`, `syntax/relationships.md`, `syntax/advanced.md` |
| Explain DBML (read/interpret a schema, status of a construct) | ✅         | `syntax/reference.md`, this file (scope)                              |
| Review a schema for quality/validity                          | ✅         | `design/review.md`                                                    |
| Fix DBML (parse errors, modeling mistakes)                    | ✅         | `troubleshooting/`, `design/review.md`                                |
| Convert SQL → DBML (DDL file or live DB)                      | ✅         | `conversion/sql-import.md`                                            |
| Convert DBML → SQL (export)                                   | ✅         | `conversion/sql-export.md`                                            |
| Assess round-trip / fidelity / losses                         | ✅         | `conversion/fidelity.md`                                              |
| Improve schema design (naming, indexes, normalization)        | ✅         | `design/`                                                             |
| Explain relationships & cardinality                           | ✅         | `syntax/relationships.md`, `design/normalization.md`                  |
| Explain limitations & best practices                          | ✅         | this file, `design/best-practices.md`                                 |

## Unsupported tasks / out of scope

| Task                                                       | Why                                                      | Where it actually lives         |
| ---------------------------------------------------------- | -------------------------------------------------------- | ------------------------------- |
| Render an ERD / export PDF/PNG/SVG                         | DBML has no renderer — it produces a model, not an image | **dbdiagram.io / dbdocs.io**    |
| Canvas layout / table x-y positions / z-order              | No `.dbml` text representation                           | dbdiagram/dbdocs (Tool-only)    |
| Install drivers / manage DB credentials / tune connections | Operational, not schema-authoring                        | `@dbml/connector` operator docs |
| Parse/parser internals (lexer, ANTLR `.g4`, binding-power) | Implementation detail, not behavior                      | `@dbml/parse` source            |

When a request falls out of scope, **state the boundary** (below) rather than guessing.

---

## Scope boundaries — what belongs to what

> The #1 rule: **never conflate DBML-the-language with the packages or the rendering tools.** Each capability has exactly one owner.

| Component               | Is                           | Owns                                                                                                                                          |
| ----------------------- | ---------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| **DBML** (the language) | a database-agnostic DSL spec | the syntax — exactly what `@dbml/parse` accepts (tables, refs, enums, indexes, notes, records, project, checks, diagram views, module system) |
| **`@dbml/parse`**       | low-level parser engine      | the `Compiler`; ANTLR grammars (dbmlv2 + 5 SQL dialects); `CompileError`/`CompileErrorCode`; multifile/`Filepath`; schemaJson types           |
| **`@dbml/core`**        | user-facing library          | the `Database` model; `Parser`, `importer`, `exporter`/`ModelExporter`; transforms                                                            |
| **`@dbml/cli`**         | command-line tool            | `dbml2sql`, `sql2dbml`, `db2dbml` (→ `conversion/`)                                                                                           |
| **`@dbml/connector`**   | live-DB introspection        | `connector.fetchSchemaJson` for **6 dialects** incl. BigQuery                                                                                 |
| **dbdiagram.io**        | online renderer              | interactive ERD, sharing, **PDF/PNG/SVG export**, canvas layout                                                                               |
| **dbdocs.io**           | docs app                     | documentation generation/publishing/sharing                                                                                                   |

### Renderer-only vs DBML-language

Anything with **no `.dbml` text representation** is **Tool-only** (dbdiagram/dbdocs), NOT DBML:

| Capability                                                               | Owner                                                         |
| ------------------------------------------------------------------------ | ------------------------------------------------------------- |
| Canvas x/y positions, per-view geometry, z-order, "synced" runtime state | dbdiagram/dbdocs (Tool-only)                                  |
| Image/PDF/PNG export                                                     | dbdiagram/dbdocs (Tool-only)                                  |
| `DiagramView` _filter_ (which entities are visible)                      | **DBML** — but stores no geometry                             |
| `headercolor` / group `color` / ref `color`                              | **DBML** syntax (parses) — visual meaning is renderer-applied |

`Project.database_type` is stored by the parser generically; its **rendering dialect semantics** are applied by dbdiagram/dbdocs exporters.

---

## Limitations (DBML itself)

- **Single schema level only** — `schema.table`; nested `a.b.c` is unsupported (non-fatal `UNSUPPORTED`).
- **No type validation or mapping** — types are opaque strings carried verbatim.
- **No language-level `VIEW`s / procedures / triggers / sequences** — they're silently dropped on SQL import; document them with notes.
- **`<>` many-to-many synthesizes a junction table on SQL export** — only use it if you accept the auto-generated table.
- **Comments (`//`, `/* */`) are trivia** — not stored, not exported; use `note:`/`Note:` for persistent docs.
- **SQL is a strict subset of DBML** — round-tripping through SQL loses all enrichment (→ `conversion/fidelity.md`).

## Conversion support matrix

| Direction                          | Support                                                           |
| ---------------------------------- | ----------------------------------------------------------------- |
| DDL-file import (SQL→DBML)         | PostgreSQL, MySQL, MSSQL, Snowflake, Oracle (**no BigQuery**)     |
| Live-DB import (`@dbml/connector`) | + **BigQuery** (6 total)                                          |
| DBML→SQL export                    | `{dbml, mysql, postgres, json, mssql, oracle}` (**no Snowflake**) |

## Assumptions

- **Format:** always use the **`dbmlv2`** format key; `'dbml'` is the deprecated PEG parser.
- **Versions:** npm packages at `8.x`, engine self-described as "parser v2"; "DBML 3.0" is a community label for the modern construct set, not a parsed literal.
- **Exit codes:** `dbml2sql` **always exits 0** — never gate CI on it.
- **Verification:** every `.dbml` example is parser-validated; `examples/conversion/*.dbml` are real importer outputs.
