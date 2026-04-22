# `extenum` — open ADTs in MoonBit

**Status:** MoonBit nightly feature (as of `moon 0.1.20260422`).

A demo/smoke-test of the new `extenum` declaration and its extension form
`extenum T += { ... }`. Think of it as MoonBit's answer to **OCaml's extensible
variants** or **Swift's open enums**: an enum whose list of constructors is
*not* sealed at the declaration site — downstream code (in the same package, a
different file, or a different package) can add new variants.

## The feature in 20 lines

```mbt nocheck
// Declare an open enum: "extenum" instead of "enum".

///|
pub(all) extenum Expr {
  Lit(Int)
  Add(Expr, Expr)
}

// Later — in another file or another package — extend it:

///|
pub(all) extenum Expr += {
  Mul(Expr, Expr)
  Neg(Expr)
}

// Pattern matching on an open enum *must* have a wildcard arm, because
// the compiler cannot prove the list is closed. Non-exhaustive match
// without `_` is a hard error.

///|
fn describe(e : Expr) -> String {
  match e {
    Lit(_) => "lit"
    Add(..) => "add"
    _ => "unknown" // required
  }
}
```

Foreign constructors (defined in another package) must be qualified: `@pkg.C`.
Inside the defining package, unqualified names work as usual.

## Why open ADTs?

The classical closed `enum` forces the "expression problem" on you: once a type
is declared, you can add new *functions* over it freely but adding new
*variants* requires editing the original declaration. `extenum` flips that
tradeoff — variants become open, at the cost of matches needing a default arm
(and runtime dispatch for traits the compiler can't derive).

Typical use cases:

- **Extensible ASTs / IRs** — core language plus optional passes/plugins that
  add new node kinds (macros, desugared forms, backend-specific ops).
- **Error hierarchies** — a common `Error` type where downstream libraries
  add their own variants without coordinating with the root.
- **Event / message types** in plugin architectures (editors, game engines,
  build systems).
- **Effect labels** — open sets of effects that handlers can grow.

## What this demo shows

A tiny expression evaluator split into **two packages** — the string plugin
lives next to the core in the root package, while the boolean plugin lives in
a sibling subpackage (`bool/`) to exercise cross-package extension.

| Location | Adds to `Expr` | Adds to `Value` |
| --- | --- | --- |
| `core.mbt` (root) | `Lit`, `Add`, `Mul` | `VInt` |
| `plugin_string.mbt` (root) | `Str`, `Concat` | `VStr` |
| `bool/bool.mbt` (**separate package**) | `Bool`, `Eq`, `If` | `VBool` |

Note that `bool/bool.mbt` writes `extenum @lib.Expr += { ... }` — it names the
foreign type it's extending. Its own `fn init` registers handlers into the
root package's registry at load time.

The core defines **two runtime registries**:

- `eval_handlers` — each plugin registers a partial evaluator that returns
  `None` for expressions it doesn't recognize, so the next handler gets a try.
- `value_show_handlers` — same pattern for pretty-printing.

Both are populated from `fn init` blocks, which MoonBit runs at package load.
The master `eval` function and `Show` impl just walk the registry.

This is the honest shape of open-ADT programming: the compiler gives you
openness, and you pay for it with a bit of runtime dispatch plus a wildcard
arm in every match.

## Running it

```bash
moon test                 # 9 tests pass (blackbox + whitebox + README doctests)
moon run cmd/main         # prints: VStr(yes: 12)
```

## A worked example

The example below composes all three plugins: an `If` (bool plugin) whose
condition is `Eq` of two ints (core + bool), and whose branches are `Str`s
(string plugin). None of the plugins know about each other; `eval` stitches
them together via the handler chain.

```mbt check
///|
test "compose across three open-enum extensions (two packages)" {
  // `If`, `Eq` live in @bool (a subpackage).
  // `Add`, `Lit`, `Concat`, `Str` live in @extenum_test (the root package).
  // Both contribute variants to the same open `Expr`.
  let e : @extenum_test.Expr = @bool.If(
    @bool.Eq(
      @extenum_test.Add(@extenum_test.Lit(1), @extenum_test.Lit(1)),
      @extenum_test.Lit(2),
    ),
    @extenum_test.Concat(@extenum_test.Str("yes: "), @extenum_test.Str("12")),
    @extenum_test.Str("no"),
  )
  inspect(@extenum_test.eval(e), content="VStr(yes: 12)")
}
```

And the honest failure mode — open `Value` means type mismatches print the
offending value via the same extensible `Show` chain:

```mbt check
///|
test "type mismatches carry the offending Value" {
  // Add on a string literal — Add expects VInts on both sides.
  let bad : @extenum_test.Expr = @extenum_test.Add(
    @extenum_test.Str("oops"),
    @extenum_test.Lit(1),
  )
  let r : Result[@extenum_test.Value, _] = try? @extenum_test.eval(bad)
  inspect(r, content="Err(Fail(TypeMismatch(expected=VInt, got=VStr(oops))))")
}
```

## Constraints worth knowing

- `derive(Show)` (and friends) won't work on an `extenum` — the compiler can't
  see the full variant set. Implement the trait manually with a wildcard arm,
  or use a registry as shown here.
- Constructors used across package boundaries must be written `@pkg.Ctor`.
  The compiler's error message includes this hint when you forget.
- Every match on the enum must end in `_`. Leaving it out is a *hard* error
  (`partial_match`), not a warning — that's the whole point of openness.
- Declaration visibility matters: `pub extenum T { ... }` lets downstream
  code *use* the type but not construct its variants; `pub(all)` is needed
  for external constructor access, same as regular `enum`. The same rule
  applies to `suberror` — use `pub(all) suberror` if cross-package code
  needs to raise it.

## Comparison notes

- **vs. closed `enum`** — `enum` gives exhaustiveness + auto-derive, at the
  cost of no extension after declaration.
- **vs. trait + `&TraitObject`** — traits give open-world *behavior* without
  enumerating cases, but lose pattern matching. Pick `extenum` when some core
  cases benefit from match, and the rest are plugin-like.
- **vs. OCaml polymorphic variants** — polymorphic variants are structurally
  typed and flow through inference; `extenum`s here are nominal, which makes
  error messages easier to read and constructor names unambiguous once
  qualified.
