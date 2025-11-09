# Tables, Columns, Types, Defaults, Constraints

The core data-modeling constructs of DBML. **Status tags** (`Official`, `Experimental`, `Unsupported`, `Tool-only`, `Unknown`) are defined in `SKILL.md`. Relationships live in `relationships.md`; the quick grammar/skeleton is in `reference.md`.

---

## Table — Official

```
Table [schema.]table_name [as alias] [headercolor: #hex] {
  column_name type [[settings]]
  ...
  Note: '...'                  // inline table note (→ advanced.md)
  Ref { ... }                  // in-table relationship (→ relationships.md)
  indexes { ... }              // index block
  checks { ... }               // check block
}
```

- `as alias` is a display alias (no effect on references). → `advanced.md`
- `headercolor: #hex` is a **header-only** setting (rejected inside the body); colors `#rgb` or `#rrggbb`. → `advanced.md`

### Column settings — Official

| Setting            | Meaning                          | Example                                  |
| ------------------ | -------------------------------- | ---------------------------------------- |
| `pk`               | primary key (flag)               | `id int [pk]`                            |
| `unique`           | unique constraint                | `email varchar [unique]`                 |
| `not null`         | NOT NULL                         | `name varchar [not null]`                |
| `increment`        | auto-increment (serial/identity) | `id int [pk, increment]`                 |
| `default: <value>` | default (see Defaults)           | `[default: 5]`                           |
| `note: '...'`      | inline documentation             | `[note: 'login key']`                    |
| `ref: > table.col` | inline relationship              | `[ref: > users.id]` (→ relationships.md) |
| `check: \`expr\``  | inline single-column check       | `[check: \`amount > 0\`]`                |

```
Table users {
  id         int          [pk, increment]
  email      varchar(255) [unique, not null, note: 'unique login identity']
  created_at timestamp    [default: `now()`]
  org_id     int          [ref: > organizations.id, not null]
}
```

### Nullability

Default is nullable. Add `not null` for required columns; combine with `unique`, `pk`, etc. in one settings list: `[pk, not null]`.

---

## Data types — Official

### Type forms

Types are **opaque strings** — DBML does no validation or mapping. Any of these parse:

```
int
varchar(255)
decimal(10,2)
int[]                       // array
auth.role_enum              // schema-qualified enum reference (→ Enums below)
"order"                     // quoted (reserved word / special char)
```

### Type representation in the model

A column type is stored as `{ schemaName, type_name, args }`:

| You write        | `type_name`     | `args`                     |
| ---------------- | --------------- | -------------------------- |
| `int`            | `int`           | `null`                     |
| `varchar(255)`   | `varchar(255)`  | `'255'`                    |
| `decimal(10,2)`  | `decimal(10,2)` | `'10,2'`                   |
| `int[]`          | `int[]`         | `null`                     |
| `auth.role_enum` | `role_enum`     | `null` (schemaName=`auth`) |

`args` captures only the **first** parenthesized group. The full text (incl. precision) lives in `type_name`.

### Type fidelity (carries into conversion)

- DBML performs **no type validation or mapping**. Types are opaque strings.
- On **SQL export**, types emit **verbatim** (only `varchar`→`varchar(255)` in MySQL, `varchar`→`nvarchar(255)` in MSSQL, and the increment/enum special cases). So `integer` vs `int` vs `INT` matters — write what you want emitted.
- On **SQL import**, types are largely preserved verbatim per dialect (→ `conversion/`).

### Quoting & comments

- **Single quotes** `'...'` for string values/notes/paths.
- **Double quotes** `"..."` for identifiers that collide with keywords or need special chars (e.g. `"at"`, `"when"`, `"order"`).
- **Comments:** line `// ...` and block `/* ... */`, both dropped on parse (trivia — do **not** use them for persistent docs).

---

## Defaults — Official

A column `default:` accepts several literal forms. Each maps to a typed value (`dbdefault = { type, value }`):

| Form                             | `type`           | Example                                               | Resulting value                      |
| -------------------------------- | ---------------- | ----------------------------------------------------- | ------------------------------------ |
| number (incl. sign / scientific) | `number`         | `[default: 5]` `[default: -3.14]` `[default: 1.5e10]` | `{type:'number', value:5}`           |
| string                           | `string`         | `[default: 'active']`                                 | `{type:'string', value:'active'}`    |
| boolean                          | `boolean`        | `[default: true]` `[default: false]`                  | `{type:'boolean', value:'true'}`     |
| **`null`**                       | **`boolean`** ⚠️ | `[default: null]`                                     | `{type:'boolean', value:'null'}`     |
| expression (backtick)            | `expression`     | ``[default: `now()`]``                                | `{type:'expression', value:'now()'}` |
| enum member (dot form)           | string           | `[default: status.active]`                            | the member value                     |

### ⚠️ The `default: null` quirk (verified)

`default: null` is classified as `type:'boolean'` with `value:'null'` — **not** a dedicated null type. It works, but if you introspect the model, expect `{type:'boolean', value:'null'}`.

### Expression defaults — use backticks, NOT `default_expr`

```
created_at timestamp [default: `now()`]
expires_at timestamp [default: `now() + interval '30 days'`]
```

`default_expr` **does not exist** in DBML (it's a deprecated SQL-importer term). The backtick form is the only way.

---

## Constraints — Official

### Primary key

Single column: `id int [pk]`. Composite PK: an `indexes` entry `(c1, c2) [pk]` (see Indexes). Two columns each marked `[pk]` is accepted but auto-collapses into a synthetic PK index — prefer the explicit composite form.

### Unique

Single column `[unique]`; multi-column `indexes { (a, b) [unique] }`.

### NOT NULL

`[not null]` (see Column settings).

### Check constraints — inline and block

Inline (single column) or block (`checks {}`, multi-line, one per line):

```
// inline
amount int [check: `amount > 0`]

// block — supports multi-column expressions
Table orders {
  id          int [pk]
  total       decimal(10,2)
  discount    decimal(10,2)
  checks {
    `total >= 0`                [name: 'chk_total_nonneg']
    `discount <= total`         [name: 'chk_discount_valid']
  }
}
```

Each check entry is a backtick expression, optionally `[name: '...']` / `[note: '...']`. Checks **do** round-trip to SQL export (unlike notes/colors — → `advanced.md`, `conversion/`).

---

## Indexes — Official

Indexes live in an **`indexes {}` block** inside a table (one index per line):

```
Table users {
  id         int [pk]
  email      varchar(255)
  org_id     int
  lower_email text

  indexes {
    email                                  // single column
    (org_id, id)      [pk]                 // composite tuple → primary key
    (`lower(email)`)  [type: hash, name: 'idx_lower']   // expression index
    (`f(x)`, org_id)  [unique, name: 'idx_fx']          // mixed expression + column
  }
}
```

### Index entry forms

| Form              | Meaning                     |
| ----------------- | --------------------------- |
| `col`             | single column               |
| `(c1, c2, ...)`   | composite (tuple)           |
| `` `expr` ``      | functional/expression index |
| ``(`expr`, col)`` | expression + column mix     |

### Index settings — Official

| Setting               | Meaning             | Example                          |
| --------------------- | ------------------- | -------------------------------- |
| `pk`                  | mark as primary key | `(id, tenant) [pk]`              |
| `unique`              | unique index        | `(email) [unique]`               |
| `type: btree \| hash` | index method        | `[type: hash]`                   |
| `name: '...'`         | index name          | `[name: 'idx_email']`            |
| `note: '...'`         | inline doc          | `[note: 'covers login lookups']` |

### ⚠️ No `using:` — the method is `type:`

```
// ❌ — 'using' is not a DBML setting
indexes { (email) [using: btree] }      // → "Unknown index setting 'using'"

// ✅
indexes { (email) [type: btree] }
```

### Composite primary keys — verified behavior

Two ways to mark a PK; both produce a `pk` index:

```
// (A) explicit composite PK index (preferred)
indexes {
  (tenant_id, id) [pk]
}

// (B) two columns each marked [pk]
Table t {
  a int [pk]
  b int [pk]
}
```

For (B): when ≥2 columns carry `[pk]`, both flags are reset to `false` and a **synthetic `{pk:true}` index** over them is created automatically. Prefer (A) for clarity.

### Indexed column kinds (model)

Each index column is either `column` (a field reference) or `expression` (a backtick/paren expression). The parser flattens call-chains like `(a,b)(c,d)` into multiple columns.

---

## Enums — Official

### Syntax

```
Enum [schema.]name {
  value1
  value2 [[note: '...']]
  ...
}
```

- Enum **values are one per line** (the universal block-body rule).
- Values may be bare identifiers or **double-quoted strings** (for spaces/special chars).
- Each value may carry a `[note: '...']`.

```
Enum job_status {
  created
  running   [note: 'in progress']
  done
  "on hold"                 // quoted value with a space
  "A+"                      // quoted value with special char
}

// schema-qualified
Enum auth.role {
  admin
  user
  guest
}
```

### Using an enum as a column type

Reference the enum by name (optionally schema-qualified). If an enum of that name exists in scope, the column binds to it.

```
Table users {
  id      int        [pk]
  role    role       [default: 'user']          // or dot form: default: role.user
  status  job_status [default: status.running]
}
```

### Conversion behavior (→ `conversion/`)

- **Postgres** import: `CREATE TYPE … AS ENUM (...)` → `Enum`; export: `Enum` → `CREATE TYPE`.
- **MySQL**: `ENUM('a','b')` import → a synthetic `Enum "<table>_<col>_enum"` (column type renamed to it); export: inline `ENUM (...)`.
- **MSSQL / Oracle**: no native enum — export as `CHECK (col IN (...))`.
- **Enum-value notes are lost** on SQL export (kept only in DBML→DBML).

### ❌ Common mistakes

```
// values on one line
Enum s { active inactive }              // → "An Enum must have only a field..." — one per line

// empty enum
Enum empty { }                          // → EMPTY_ENUM
```

---

## ❌ Common table/column mistakes

```
headercolor inside body:
Table t { id int [headercolor: #fff] }   // ❌ header-only (→ advanced.md)

multiple columns per line:
Table t { a int b int }                  // ❌ one per line (→ reference.md)

quoted string where identifier expected:
Table 't' { ... }                        // ❌ use bareword/identifier
```
