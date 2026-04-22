# Design feedback on `extenum`

Notes from building the demo in this repo against `moon 0.1.20260422`. The
demo is deliberately small but exercises cross-package extension: the core
types live in `bobzhang1988/extenum_test` and the boolean plugin extends them
from `bobzhang1988/extenum_test/bool`.

## What feels right

- **`extenum T += { ... }` syntax** is memorable and unambiguous — obviously "append." Better than OCaml's `type t += ...`, which reuses plain `type`.
- **Partial-match is a hard error**, not a warning. Exactly right: openness is load-bearing, so silently routing through a missing arm would be a trap.
- **Error hint on unqualified foreign constructors** (`use @pkg.C`) was helpful the first time I hit it.
- **Cross-package `extenum @lib.T += { ... }`** composes cleanly at runtime. `@bool.If` and `@extenum_test.Lit` both inhabit the same `Expr`, and the handler chain picks the right evaluator without either package knowing about the other.

## What I'd push back on

### 1. `pkg.generated.mbti` hides the `+=` extensions (high severity)

After moving `plugin_bool` to its own subpackage, the generated mbti for
`bobzhang1988/extenum_test/bool` is:

```
package "bobzhang1988/extenum_test/bool"

import {
  "bobzhang1988/extenum_test",
}

// Values
pub fn as_bool(@extenum_test.Value) -> Bool raise @extenum_test.Fail
```

The entire `extenum @lib.Expr += { Bool, Eq, If }` and `extenum @lib.Value += { VBool }` contribution is missing — even though those constructors are
`pub(all)` and callable from blackbox tests and from `cmd/main`. A reviewer
looking at this mbti would have no idea this package extends `@extenum_test`'s
ADTs at all. That's the whole reason the package exists.

Proposed fix: `pkg.generated.mbti` should include a section like

```
// Extensions to foreign extenums
pub(all) extenum @extenum_test.Expr += {
  Bool(Bool)
  Eq(@extenum_test.Expr, @extenum_test.Expr)
  If(@extenum_test.Expr, @extenum_test.Expr, @extenum_test.Expr)
}
```

for every package that opens a foreign enum. Same treatment for in-package
`+=` blocks on the root type.

### 2. `suberror` is not publicly constructible from other packages

The error type `Fail` is declared in the root package as
`pub suberror Fail { Fail(EvalError) }`. From inside the root package I could
write `raise Fail(Unhandled("…"))`. From `bool/bool.mbt` the compiler rejects
this with `Cannot create values of the read-only type: Fail.` — even though
`EvalError` itself is `pub(all) extenum`, and even though `Fail` is `pub`.

I worked around it with a polymorphic helper:

```moonbit
pub fn[T] raise_fail(e : EvalError) -> T raise Fail {
  raise Fail(e)
}
```

This is a serious ergonomic problem specifically for the open-ADT use case:
plugins in other packages will routinely want to raise errors about their own
variants. Two fixes I'd consider:

- **Allow `pub(all) suberror T { ... }`** — the obvious analogue of the enum
  rule, making the constructor externally usable.
- **Or** require every extenum package to expose a `raise_` helper, and make
  the compiler recognize that pattern automatically.

The status quo — "write a polymorphic bottom-return helper by hand" — is a
speed bump that every open-ADT author will hit.

### 3. No `derive(Show)` / `derive(Eq)` / `derive(Hash)`

Understandable in principle (the compiler can't see all variants), but writing
a registry for every derivable trait is a lot of boilerplate for what is the
obvious default use case. A built-in "open-world derive" that generates
`output` / `op_equal` / `hash_combine` with a wildcard arm that falls back to
a user-registerable handler would cover 90% of cases. Or even simpler: let
`derive(Debug)` generate a `<variant?>` fallback string and be done with it,
since Debug is already best-effort.

### 4. Constructor qualification is verbose across packages

In `core_test.mbt` a typical test reads:

```moonbit
let e : Expr = @bool.If(
  @bool.Eq(
    @extenum_test.Add(@extenum_test.Lit(1), @extenum_test.Lit(1)),
    @extenum_test.Lit(2),
  ),
  @extenum_test.Mul(@extenum_test.Lit(10), @extenum_test.Lit(10)),
  @extenum_test.Lit(0),
)
```

Half the characters are package qualifiers. When the *type* of the position is
already an `Expr`, the compiler could pun constructor names from all known
extensions to that type — same treatment closed `enum` already gets when the
context type is known. A `using @pkg.*` constructor import would also be
acceptable. As it stands, writing non-trivial AST literals becomes painful.

### 5. Visibility rules feel duplicated

I had to change `pub extenum` → `pub(all) extenum` to construct variants
externally. That matches closed `enum`, so it's consistent — but for an
extenum the interaction surface is doubled: a downstream package that *extends*
the enum needs `pub(all)` visibility to match existing variants *and* to let
downstream-downstream code construct its new variants. The docs should call
this out explicitly with a worked example.

### 6. `fn init` ordering across packages

Handler registration happens in `fn init`, and order depends on dependency
graph traversal. For this demo it happens to work (root registers `core_eval`
first, then the bool plugin appends `bool_eval`). But a plugin that wanted to
register *before* the core's fallback has no clean way to do so.

The stdlib should provide a canonical `Registry[T]` primitive with
priority/ordering, or the language should offer an `#on_load(priority = 10)`
annotation. Otherwise every open-ADT project will reinvent this poorly.

### 7. Minor: naming

`extenum` reads as "ex-tee-num" (past tense of something?) on first glance.
`openenum` or two-token `open enum` would read better — the latter also
mirrors the Swift terminology people will reach for, and composes with other
modifiers (`pub open enum`).

## Overall

The core feature is sound and the tradeoff (openness ↔ mandatory wildcard + no
derive) is the right one. Cross-package extension works. The rough edges are
all in the *ergonomics around* extensibility:

1. **mbti surfacing of extensions** (#1) — highest priority; without this
   open ADTs aren't reviewable as public API.
2. **`suberror` construction across packages** (#2) — a concrete blocker, not
   just ergonomics.
3. **derive story** (#3) and **constructor qualification** (#4) — both would
   remove substantial boilerplate.

Fixing #1 and #2 would take this feature from "usable" to "pleasant."
