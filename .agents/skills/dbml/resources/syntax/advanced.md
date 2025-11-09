# Advanced Language Features

Enrichment and advanced constructs: `Project`, `Note`/sticky notes, `TableGroup`, aliases, `headercolor`, the module system, `TablePartial`, `Records`, `DiagramView`. Most of these have **no SQL equivalent** — they are consumed by diagram/doc tools (dbdiagram.io, dbdocs.io) and dropped on SQL export (kept on DBML→DBML).

---

## Project metadata — Official

```
Project <name> {
  database_type: 'PostgreSQL'
  note: 'A short description of this schema'
}
```

- Top-level, optional, at most one.
- Body is a set of `key: 'value'` fields (lowercase `note:` for the description).
- `name` is optional.

| Field                  | Purpose                                    | Semantics                                                                                                                             |
| ---------------------- | ------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `database_type: '...'` | hints the SQL dialect for rendering/export | **parser stores it generically**; the _meaning_ (which dialect to render) is applied by dbdiagram/dbdocs exporters, not the core spec |
| `note: '...'`          | project description                        | stored structurally                                                                                                                   |

The parser **accepts arbitrary `key: 'value'` pairs** (no closed key set) — unknown keys are stored as strings. Only `note` is structured.

**Spec-vs-tool line:** `Project` is a DBML language construct (parses, appears in the model). But `database_type` rendering and project-level display behavior belong to **dbdiagram/dbdocs**, not DBML — DBML is database-agnostic. The `Project` block (and its `note`) is **dropped on SQL export**; kept on DBML→DBML.

```
// ❌ body fields must be `key: value`, not inline elements
Project p { database_type: 'X' Note { '...' } }   // → INVALID_PROJECT_FIELD
// ✅
Project p { database_type: 'X' note: 'desc' }
```

---

## Notes & Sticky Notes — Official (enrichment)

### Inline note

Attach documentation to a table, column, index, enum value, tablegroup, tablepartial, or project:

```
// inside a table body
Note: 'Stores all application users'

// as a column setting
email varchar [note: 'unique login identity']

// as an enum-value setting
active [note: 'fully provisioned']
```

Multi-line block form (inside a body):

```
Note: '''
  # Users
  - soft-deleted via `deleted_at`
  - email is the login key
'''
```

Leading indentation is normalized (minimum common indent stripped).

### Sticky note (standalone element)

A named, top-level note with an optional **color**:

```
Note reminder [color: #F4D03F] {
  'Remember to index every FK column'
}

Note multiline_note {
  '''
  # Design notes
  Refs use > for FK → parent.
  '''
}
```

### Colors — exact allowed values (verified)

| Value                               | Where valid                                               |
| ----------------------------------- | --------------------------------------------------------- |
| `#rgb` (3 hex, e.g. `#fff`, `#06c`) | sticky note, tablegroup, table `headercolor`, ref `color` |
| `#rrggbb` (6 hex, e.g. `#3498DB`)   | same                                                      |
| `none` (transparent)                | **sticky notes ONLY**                                     |

Named colors (`red`, `blue`) are **rejected**. `none` on a tablegroup or `headercolor` is **rejected**.

```
Note n [color: #fff] { 'ok' }        // ✅
Note n [color: none] { 'ok' }        // ✅ sticky-only
Note n [color: red] { 'x' }          // ❌ named color rejected
TableGroup g [color: none] { t }     // ❌ 'none' not valid on tablegroup
```

### Sticky note vs inline note

Decided by **context**, not syntax: a `Note { }` at top level is a sticky note (needs a name to be useful); a `Note: '...'` inside a Table body is an inline note and **cannot** have `[color:]`.

---

## TableGroup — Official (visualization)

Groups tables for diagram organization (one table per line):

```
TableGroup core [color: #3498DB, note: 'core domain'] {
  users
  organizations
  memberships
}
```

- Members are `<table>` or `<schema>.<table>`, **one per line**.
- A table may belong to **only one** group.
- A group **cannot reference an imported table** (members must be locally defined, or pulled in implicitly by importing the group itself).
- Optional inline `Note:` sub-element or `[note: '...']`/`[color: #hex]` header settings.

---

## Aliases & HeaderColor — Official (enrichment)

### Aliases (`as`)

A display alias on a table — no effect on references; dropped on SQL export.

```
Table order_items as oi {
  id int [pk]
}
```

### HeaderColor

A **header-only** table setting (rejected inside the body). Colors `#rgb` or `#rrggbb` (not `none`).

```
// ✅ in the header
Table users [headercolor: #3498DB] {
  id int [pk]
}
// ❌ in the body
Table users { id int [headercolor: #3498DB] }   // → "A Custom element can only appear in a Project"
```

---

## TablePartial — Official (reusable column bundles)

Define a bundle of columns; inject it into a table with **`~<partial>`** (a single `~name` line inside the body). **Local overrides partial**: if a table both declares a column and pulls it via a partial, the table's own declaration wins; the partial's copy is dropped (no duplicate).

```
TablePartial timestamped {
  created_at timestamp [default: `now()`]
  updated_at timestamp [default: `now()`]
}

Table posts {
  id         int [pk]
  title      varchar
  ~timestamped
}

Table comments {
  id         int [pk]
  body       text
  ~timestamped
}
```

`~<partial>` (one per line, at the position where the columns should be injected) expands the partial's columns inline. Do **not** write `use <partial>` inside a table body — that parses but silently treats `use` as a column name and injects nothing. (Importing a partial _from another file_ uses the module `use { tablepartial name } from './x'` — a separate file-level operation; see Modules.)

---

## Records — Official (enrichment)

Attach sample data rows to a table (documentation only; no SQL equivalent beyond optional export):

```
Table users {
  id    int [pk]
  name  varchar
  role  varchar
  Records {
    [1, 'Ada', 'admin']
    [2, 'Grace', 'user']
  }
}
```

On SQL export, `Records` become `INSERT` statements by default (`includeRecords: false` suppresses them) — → `conversion/sql-export.md`.

---

## DiagramView — Official (enrichment, tri-state filter)

Filter a named view of the schema. Each dimension is `Tables` / `TableGroups` / `Schemas`; each entry is a table/group/schema name, `*` (all), or `!(name)` (exclude). The **trinity rule**: at least one of the three dimensions must be non-empty for the view to be meaningful.

```
DiagramView sales {
  Tables      { users orders !legacy_users }
  TableGroups { * }
  Schemas     { sales }
}
```

| Token     | Meaning              |
| --------- | -------------------- |
| `name`    | include this element |
| `*`       | include all          |
| `!(name)` | exclude this element |

`DiagramView` stores a **visibility filter** — it stores no geometry. Canvas positions/layout are Tool-only (dbdiagram/dbdocs), not DBML.

---

## Module system — Official (`use` / `reuse`, multi-file)

> There is **no `import` keyword and no `namespace` construct.** Imports use **`use`** / **`reuse`**, and "namespacing" is just **schemas** (`schema.table`).

### Import statements

```
// entire file
use * from './base'

// selective — list kind + name (+ optional alias), ONE PER LINE (no commas)
use {
  table users as u
  enum status
  tablegroup core
  tablepartial timestamped
  note reminder
  schema auth
} from './auth'
```

> **One specifier per line — no commas.** `use { table a, table b } from './x'` is rejected with _"Expect a newline between use specifiers"_.

| Keyword        | Imports                                                         |
| -------------- | --------------------------------------------------------------- |
| `table`        | a Table (its records & inline refs come along)                  |
| `enum`         | an Enum                                                         |
| `tablepartial` | a TablePartial                                                  |
| `note`         | a **Sticky note** (the import kind `note` maps to sticky notes) |
| `tablegroup`   | a TableGroup (auto-expands its member tables)                   |
| `schema`       | all elements under that schema                                  |

`from '<path>'` takes a **single-quoted relative path**; `.dbml` extension is optional (`'./base'` == `'./base.dbml'`). Absolute paths error (`Import path must be relative`). Missing file → `NONEXISTENT_MODULE`.

### `use` vs `reuse` (transitivity)

|                                           | `use` | `reuse` |
| ----------------------------------------- | ----- | ------- |
| Visible in current file                   | ✅    | ✅      |
| Re-exported to files that import this one | ❌    | ✅      |

`use` is **non-transitive**; `reuse` **re-exports**. Circular imports are fine (DBML is declarative; mutual `use` does not loop).

```
reuse * from './users'        // re-export everything from users
```

### Multi-file compilation

- A project is a set of `Filepath → source` entries. Each file parses independently; `use`/`reuse` link them.
- **Entry file:** `DEFAULT_ENTRY = 'main.dbml'`. Pass the entry to the CLI/JS multifile API; imports resolve automatically.
- Aliases: `use { table auth.users as u }` — after aliasing, **only** the alias is visible.

```
// ❌ 'import' is not a keyword — use 'use'   /   'namespace' is no construct — schemas ARE the namespace
import * from './x'
namespace auth { ... }
// ✅
use * from './x'
```
