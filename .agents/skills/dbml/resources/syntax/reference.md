# Quick Reference

The fast path: grammar model, a skeleton, the status map, reserved keywords, and settings-by-context. **All syntax below is parser-verified.** For depth on any construct, follow the cross-links to `language.md`, `relationships.md`, `advanced.md`.

> **Status tags** (`Official`, `Experimental`, `Unsupported`, `Tool-only`, `Unknown`) are defined once in `SKILL.md`.

---

## Grammar model (the spine)

DBML is **declarative**: a sequence of top-level elements, each **block-shaped** (`<type> … { body }`) or **simple-shaped** (`<type> … : value`). No statement terminators, no flow control.

```
<type> [schema.]name [as alias] [[settings]] {        // block-shaped
  <body: one item per line>
}

<type> [: simple-value] [[settings]]                   // simple-shaped
```

### Element kinds

| Element         | Shape                     | Detail                                                  |
| --------------- | ------------------------- | ------------------------------------------------------- |
| `Project`       | block, ≤1, top-level      | → advanced.md                                           |
| `Table`         | block                     | columns + `indexes`/`Ref`/`checks`/`Note` → language.md |
| `Enum`          | block                     | one value per line → language.md                        |
| `TableGroup`    | block                     | visualization grouping → advanced.md                    |
| `TablePartial`  | block                     | reusable column bundle → advanced.md                    |
| `Ref`           | block **or** simple (`:`) | → relationships.md                                      |
| `Note`          | block                     | sticky note → advanced.md                               |
| `DiagramView`   | block                     | visibility filter → advanced.md                         |
| `Record`        | block                     | sample data → advanced.md                               |
| `use` / `reuse` | simple                    | module imports → advanced.md                            |

### Settings grammar — Official

```
[ name: value, name2: value2, flag ]
```

- **Names are case-insensitive:** `primary key` == `primary_key` == `pk`; `not null` == `not_null`.
- **Flags** (bare keywords like `pk`, `unique`) == `[flag: true]`.
- **Values:** bareword, single-quoted string, backtick expression, hex color, number, boolean.

### One item per line — the #1 syntax error

Every block body puts **one item per line**: columns, enum values, `TableGroup` members, `use` specifiers, index entries, `checks` entries.

```
// ❌ rejected
Table t { a int  b int }            // "must have only one field/column"
Enum e { a b c }                    // "must have only a field"
use { table x, table y } from './f' // "Expect a newline between use specifiers"
// ✅
Table t { a int
         b int }
```

### Schema qualification — single-level only

`schema.table` / `schema.enum` only. Nested `a.b.c` is **Unsupported** (non-fatal `UNSUPPORTED` diagnostic; unreliable).

```
Table core.users { ... }            // ✅
Table a.b.c { ... }                 // ⚠️ non-fatal UNSUPPORTED; avoid
```

---

## Status map (the most important construct statuses)

| Construct                                                            | Status                                                     |
| -------------------------------------------------------------------- | ---------------------------------------------------------- |
| relationship ops `- < > <>`                                          | Official                                                   |
| `><` `-<` `>-`                                                       | **Unsupported** → junction table                           |
| index method `type:`                                                 | Official                                                   |
| index method `using:`                                                | **Unsupported** → `type:`                                  |
| expression default `[default: \`expr\`]`                             | Official                                                   |
| `default_expr:`                                                      | **Unsupported** → backtick `default:`                      |
| `use` / `reuse`                                                      | Official                                                   |
| `import` / `namespace`                                               | **Unsupported** → `use`/`reuse`; schemas are the namespace |
| `Note`/sticky + `TableGroup` + `DiagramView` + `Records` + `Project` | Official, **enrichment** (no SQL equivalent)               |
| `TablePartial` + `~` injection                                       | Official                                                   |
| colors `#rgb`/`#rrggbb`/`none`(sticky-only)                          | Official                                                   |
| canvas positions / image-PDF export / view runtime state             | **Tool-only** (dbdiagram/dbdocs)                           |

---

## Skeleton (copy-adapt)

```
Project shop {
  database_type: 'PostgreSQL'
  note: 'orders + users'
}

Table users {
  id         int          [pk, increment]
  email      varchar(255) [unique, not null]
  role       role_enum    [default: 'user']
  created_at timestamp    [default: `now()`]

  indexes {
    (email) [unique, name: 'idx_email']
    (`lower(email)`) [type: hash, name: 'idx_lower']
  }
}

Table orders {
  id        int [pk]
  user_id   int [ref: > users.id, not null]
  total     decimal(10,2)
  indexes {
    (user_id, id) [pk]
  }
  checks {
    `total >= 0` [name: 'chk_total_nonneg']
  }
}

Enum role_enum {
  admin [note: 'all access']
  user
  guest
}

Ref: orders.user_id > users.id [delete: cascade, update: set null]

TableGroup core [color: #3498DB, note: 'core domain'] {
  users
  orders
}

Note reminder [color: #F4D03F] { 'index every FK' }

DiagramView sales {
  Tables      { users orders }
  TableGroups { * }
  Schemas     { * }
}
```

---

## Indentation & style

DBML is **whitespace-insensitive** — indent to match the host project. Read existing `.dbml` files or the project's EditorConfig / Prettier / formatter config, and follow that. Default to **2 spaces** (the DBML community convention) when the project has no preference. The skeletons and examples in this skill use **2 spaces**. Within each table, align the column name, type, and `[settings]` columns for readability.

## Type names — use the target dialect's native type

DBML emits types **verbatim** (no dialect mapping). When the `.dbml` targets a specific SQL dialect, write that dialect's native type — `text`, not `longtext`, on Postgres — because DBML will neither map nor validate it for you. See `design/best-practices.md` → "Type selection" for the common MySQL→Postgres pitfalls.

---

## Settings by context

| Where             | Valid settings                                                          |
| ----------------- | ----------------------------------------------------------------------- |
| Column            | `pk` `unique` `not null` `increment` `default:` `note:` `ref:` `check:` |
| Index             | `pk` `unique` `type: btree\|hash` `name:` `note:`                       |
| Ref (block/short) | `delete:` `update:` `color:` `inactive`                                 |
| Table header      | `headercolor:`                                                          |
| TableGroup header | `color:` `note:`                                                        |
| Sticky note       | `color: #hex\|none`                                                     |

## Defaults — one-liners

`default: 5` · `'str'` · `true`/`false`/`null` · `` `expr` `` · `enum.member`
(`default: null` → stored as `{type:'boolean', value:'null'}`.)

## Operators — the only four

`-` 1:1 · `<` 1:_ · `>` _:1 · `<>` _:_ — **no** `><`/`-<`/`>-`.

---

## Reserved / significant keywords

These are the keywords with parser-defined meaning (case-insensitive in settings):

| Category            | Keywords                                                                                                                             |
| ------------------- | ------------------------------------------------------------------------------------------------------------------------------------ |
| Top-level elements  | `Project` `Table` `Enum` `TableGroup` `TablePartial` `Ref` `Note` `DiagramView` `Record`                                             |
| Module              | `use` `reuse` `from` `as`                                                                                                            |
| Settings/flags      | `pk` `unique` `not null` `increment` `default` `note` `ref` `check` `type` `name` `delete` `update` `color` `headercolor` `inactive` |
| Index methods       | `btree` `hash`                                                                                                                       |
| Referential actions | `cascade` `set null` `set default` `restrict` `no action`                                                                            |
| DiagramView         | `Tables` `TableGroups` `Schemas` `*` (and `!` exclude)                                                                               |
| Color literals      | `#rgb` `#rrggbb` `none`                                                                                                              |

**Not keywords (commonly assumed, but rejected):** `import`, `namespace`, `using`, `default_expr`, `><`/`-<`/`>-`, named colors (`red`/`blue`), `varchar(…)` is _not_ a keyword (types are opaque strings).

---

## Top errors to avoid (fast list)

- Multiple items on one line in a body → one per line.
- `[using: btree]` → `[type: btree]`.
- `[default_expr: ...]` → ``[default: `...`]``.
- `import`/`namespace` → `use`/`reuse`; schemas are the namespace.
- `headercolor:` inside a table body → header only.
- Nested schema `a.b.c` → single-level `schema.table` only.
- `><`/`-<`/`>-` → use `- < > <>`.
- `use <partial>` inside a table → `~<partial>`.

(Full error→fix tables: `troubleshooting/parser-errors.md`, `troubleshooting/common-mistakes.md`.)
