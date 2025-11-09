# Parser Errors — code → meaning → fix

`@dbml/parse` emits `CompileError`s with a numeric `CompileErrorCode`. `@dbml/core` surfaces them via `CompilerError.diags[]` with `{ message, location:{start:{line,column}}, code }`. Legacy/SQL PEG errors instead carry `expected`/`found` text. For worked broken→fixed examples see `common-mistakes.md`.

---

## Top errors you will actually hit

| Code group / message                                                               | Meaning                          | Cause                                                          | Fix                                                  |
| ---------------------------------------------------------------------------------- | -------------------------------- | -------------------------------------------------------------- | ---------------------------------------------------- |
| `INVALID_REF_FIELD` — _"A Ref field must be a binary relationship"_                | invalid relationship operator    | `><`, `-<`, `>-`, or a malformed endpoint                      | use only `- < > <>` (→ `relationships.md`)           |
| `UNEQUAL_FIELDS_BINARY_REF` — _"Unequal fields in ref endpoints"_                  | composite tuple size mismatch    | `a.(x,y) > b.(p)`                                              | make both tuples equal length                        |
| `REF_REDEFINED` / `SAME_ENDPOINT` — _"References with same endpoints exist"_       | duplicate ref                    | two refs between the same column pair                          | define each relationship once (→ `relationships.md`) |
| `UNKNOWN_COLUMN_SETTING` — _"Unknown column setting 'X'"_                          | invented column setting          | `default_expr`, `using`, etc.                                  | use the real settings (→ `common-mistakes.md`)       |
| `UNKNOWN_INDEX_SETTING` — _"Unknown index setting 'using'"_                        | wrong index-method keyword       | `[using: btree]`                                               | `[type: btree]`                                      |
| `UNSUPPORTED` — _"Nested schema is not supported"_                                 | schema has >1 segment            | `Table a.b.c`                                                  | single-level `schema.table` only                     |
| `INVALID_CUSTOM_*` — _"A Custom element can only appear in a Project"_             | enrichment in wrong place        | `headercolor:` inside a Table body                             | put `headercolor` in the header `[...]`              |
| `EMPTY_TABLE` — _"Table must have at least one field"_                             | table with no columns            | `Table t { }`                                                  | add ≥1 column                                        |
| `DUPLICATE_COLUMN_NAME` — _"Field X existed in table"_                             | repeated column                  | two `id int`                                                   | unique column names                                  |
| `INVALID_PROJECT_FIELD`                                                            | non `key: value` in Project      | `Project p { Note {} }`                                        | use `key: 'value'` + lowercase `note:`               |
| `NONEXISTENT_MODULE` — _"Failed to resolve the non-existent file"_                 | missing import target            | `use * from './missing'`                                       | fix the relative path                                |
| _"These fields must be some inline settings optionally ended with a setting list"_ | malformed column/index line      | multiple columns on one line, or `index {…}` glued to a column | one item per line                                    |
| `EMPTY_ENUM` — _"An Enum must have only a field"_                                  | enum values on one line          | `Enum s { a b }`                                               | one value per line                                   |
| `BINDING_ERROR` — _"Can't find table …"_ / _"Can't find field …"_                  | dangling ref                     | `ref: > ghost.id`                                              | fix/remove the ref (→ `relationships.md`)            |
| _"Can't find primary or composite key in table"_                                   | ref auto-PK target lacks a PK    | `Ref: child.parent_id > parent` with no PK on `parent`         | add a PK to the target                               |
| _"Expect a newline between use specifiers"_                                        | comma-separated `use` specifiers | `use { table a, table b } from './x'`                          | one specifier per line                               |

---

## Error-code ranges (full enum in `@dbml/parse` `core/types/errors.ts`)

| Range     | Category                 | Examples                                                                                                                                               |
| --------- | ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 1000–1999 | lexer / tokens / symbols | `UNKNOWN_SYMBOL`, `UNEXPECTED_TOKEN`, `INVALID_OPERAND`, `MISSING_SPACES`                                                                              |
| 3000–3999 | per-construct validation | table/column/enum/ref/note/indexes/project/tablepartial/checks/records/use/diagramview + their `*_CONTEXT`/`UNKNOWN_*`/`DUPLICATE_*`/`INVALID_*` codes |
| 4000      | binding                  | `BINDING_ERROR`, `NONEXISTENT_MODULE`                                                                                                                  |
| 5000      | structural               | `UNSUPPORTED`, `CIRCULAR_REF`, `SAME_ENDPOINT`, `UNEQUAL_FIELDS_BINARY_REF`, `CONFLICTING_SETTING`, `TABLE_REAPPEAR_IN_TABLEGROUP`                     |

---

## Throw vs collected (nuance)

`@dbml/core` (`Parser.parse('dbmlv2')`) **throws** `CompilerError` for many errors (invalid ref ops, duplicate refs, dangling refs, unknown settings). A few diagnostics are **collected but non-fatal** — e.g. nested schema emits `UNSUPPORTED` yet still returns a model. When programmatically checking validity, **inspect `.diags`, don't rely solely on "did it throw."** The CLI prints errors to stdout + `dbml-error.log` but **always exits 0** (→ `conversion/sql-export.md`).

`@dbml/core` is **all-or-nothing per model**: the first dangling ref / missing field / duplicate **throws** and aborts the build. (The `@dbml/parse` layer is more forgiving — it collects diagnostics.)

---

## Repair patterns (by symptom)

| Symptom in the error                                   | Likely cause                                    | Repair                                        |
| ------------------------------------------------------ | ----------------------------------------------- | --------------------------------------------- |
| _"binary relationship"_ / _"invalid operator"_         | Mermaid op `><`/`-<`/`>-`                       | use `- < > <>`; many-to-many → junction table |
| _"Unknown column setting"_ / _"Unknown index setting"_ | `default_expr`, `using`, or other invented name | use the real setting name                     |
| _"must have only one field"_ / _"only a field"_        | multiple items on one line                      | one item per line                             |
| _"A Custom element can only appear in a Project"_      | `headercolor:` (or color) inside a body         | move it to the header `[...]`                 |
| _"Nested schema is not supported"_                     | `a.b.c`                                         | collapse to single-level `schema.table`       |
| _"same endpoints exist"_                               | duplicate ref (possibly reversed)               | keep one ref per column pair                  |
| _"Can't find table/field"_                             | dangling ref                                    | fix or remove the ref                         |
| _"Can't find primary or composite key"_                | ref target has no PK                            | add a PK to the target                        |
| _"Failed to resolve the non-existent file"_            | bad `use` path                                  | fix the relative path                         |
| PEG-style _"expected … found …"_                       | legacy `'dbml'` format or SQL import            | use `'dbmlv2'`; match the SQL dialect         |
