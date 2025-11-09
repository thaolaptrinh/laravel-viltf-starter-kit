# Relationships (Refs)

Everything about `Ref` — operators, forms, semantics, and the relationship-specific best practices and mistakes. Broader schema design lives in `design/`; the inline `[ref:]` column setting is introduced in `language.md`.

---

## The operators — Official (ONLY these four)

| Operator | Cardinality | Mnemonic                   |
| -------- | ----------- | -------------------------- |
| `-`      | 1:1         | one to one                 |
| `<`      | 1:\*        | one (left) to many (right) |
| `>`      | \*:1        | many (left) to one (right) |
| `<>`     | _:_         | many to many               |

`><`, `-<`, `>-` are **Unsupported** (`INVALID_REF_FIELD`). Reading aid: the left side has the operator as a "prong" pointing at its cardinality. `users.id < posts.user_id` reads "one user → many posts".

---

## Three forms

**Long/block form** (named; can carry referential actions):

```
Ref user_posts {
  posts.user_id > users.id
  [delete: cascade, update: set null]
}
```

**Short form** (`:`, one ref, unnamed; actions allowed):

```
Ref: posts.user_id > users.id [delete: cascade]
```

**Inline column setting** (`ref:`, only the long/short shape; **cannot** carry `delete:`/`update:`):

```
user_id int [ref: > users.id, not null]
```

---

## Referential actions — Official

Allowed on block & short forms (not inline): `delete:` / `update:`, each one of:
`cascade` · `set null` · `set default` · `restrict` · `no action`.

Settings go on the **same line** as the relationship:

```
// ✅
Ref fk { orders.user_id > users.id [delete: cascade] }

// ❌ settings on a separate line
Ref fk { orders.user_id > users.id
         [delete: cascade] }
```

---

## Composite refs — Official

```
Ref: line_items.(order_id, line_no) > orders.(id, line_no)
```

Column order must match on both sides (`UNEQUAL_FIELDS_BINARY_REF` otherwise).

---

## Auto-PK from a ref — Official, enrichment

A ref endpoint over a column can render as a key indicator; the diagram tool auto-detects PKs. This is display behavior — the model stores the ref as written. If a ref targets a table for auto-PK and that table has **no PK**, the build throws _"Can't find primary or composite key in table"_ — give the target a PK.

---

## Duplicate refs — Official (the export-blocker)

Two refs with the **same endpoints** are accepted by the parser but **block SQL export** (the exporter refuses to emit a duplicate foreign key). Dedupe before exporting.

```
Ref: a.x > b.y
Ref: a.x > b.y        // ← duplicate endpoints; export fails
```

---

## `inactive` refs — Official, enrichment

Mark a ref `inactive` to document a relationship visually without it being active:

```
Ref: legacy.fk > users.id [inactive]
```

---

## Relationship best practices

### Pick the operator deliberately

| Situation                                                      | Operator                                    | Notes                                                                        |
| -------------------------------------------------------------- | ------------------------------------------- | ---------------------------------------------------------------------------- |
| Each parent has ≥0 children; each child has exactly one parent | `>` (child.parent_id > parent.id)           | the common FK case                                                           |
| One parent ↔ one child                                         | `-`                                         | rare; usually a 1:1 extension table                                          |
| A junction/mapping table exists                                | model **two `>` refs** through the junction | preferred over a raw `<>`                                                    |
| Logical many-to-many with no junction table                    | `<>`                                        | **synthesizes a junction table on SQL export** — only use if you accept that |

### Prefer explicit junction tables

For many-to-many, define the junction table explicitly with two `>` (or `<`) refs. It's unambiguous, lets you add junction attributes (e.g. `created_at`), and exports cleanly. Reserve `<>` for quick sketches.

```
// ✅ explicit junction (recommended)
Table users { id int [pk] }
Table roles { id int [pk] }
Table user_roles {
  user_id int [ref: > users.id, pk]
  role_id int [ref: > roles.id, pk]
}

// ⚠️ <> synthesizes a junction on export — names it for you
Ref: users.id <> roles.id
```

### FK conventions

- Name FK columns `<target>_id`. Reference the parent PK: `[ref: > users.id]`.
- Put `not null` on FKs unless the relationship is genuinely optional.
- For self-references: `Table employees { manager_id int [ref: > employees.id] }`.

### Referential actions

- Default `delete: no action`. Choose `cascade` only when the child truly cannot exist without the parent (beware of cascading deletes across wide graphs).
- `set null` requires the FK column to be nullable.
- Oracle **drops `on update`** on export — don't rely on it for Oracle targets.

---

## Common relationship mistakes (broken → fixed)

### 1. Many-to-many written with a fake operator

```
// ❌ → "A Ref field must be a binary relationship"
Ref: users.id >< roles.id          // also invalid: -<  >-

// ✅ explicit junction table (recommended, exports cleanly)
Table users { id int [pk] }
Table roles { id int [pk] }
Table user_roles {
  user_id int [ref: > users.id, pk]
  role_id int [ref: > roles.id, pk]
}

// ✅ or, for a quick sketch (synthesizes a junction on export):
Ref: users.id <> roles.id
```

### 2. Inline ref trying to carry an action

```
// ❌ inline refs can't carry delete/update/color/inactive
user_id int [ref: > users.id, delete: cascade]

// ✅ use block/short form
Ref: orders.user_id > users.id [delete: cascade]
```

### 3. Duplicate ref blocking export

```
// ❌ → "References with same endpoints exist"
Ref: orders.user_id > users.id
Ref: users.id < orders.user_id

// ✅ model each logical relationship exactly once
Ref: orders.user_id > users.id
```

### 4. Missing PK on an auto-PK ref target

```
// ❌ → "Can't find primary or composite key in table"
Table users { email varchar }
Table orders { user_id int }
Ref: orders.user_id > users

// ✅ add a primary key to the target
Table users { id int [pk]  email varchar [unique] }
Table orders { user_id int }
Ref: orders.user_id > users
```

### 5. Dangling ref

```
// ❌ → BINDING_ERROR "Can't find table/field …" (aborts the whole build)
org_id int [ref: > ghost_orgs.id]

// ✅ resolve or remove
org_id int [ref: > organizations.id]
```
