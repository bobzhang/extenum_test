///|
using @extenum_test {type Expr, type Value}

///|
test "core arithmetic" {
  // (1 + 2) * 3 = 9
  let e : Expr = @extenum_test.Mul(
    @extenum_test.Add(@extenum_test.Lit(1), @extenum_test.Lit(2)),
    @extenum_test.Lit(3),
  )
  inspect(@extenum_test.eval(e), content="VInt(9)")
}

///|
test "string plugin: concat" {
  let e : Expr = @extenum_test.Concat(
    @extenum_test.Str("hello "),
    @extenum_test.Str("world"),
  )
  inspect(@extenum_test.eval(e), content="VStr(hello world)")
}

///|
test "bool plugin: conditional selects a string branch" {
  // if (2 == 2) then "yes" else "no"
  let e : Expr = @extenum_test.If(
    @extenum_test.Eq(@extenum_test.Lit(2), @extenum_test.Lit(2)),
    @extenum_test.Str("yes"),
    @extenum_test.Str("no"),
  )
  inspect(@extenum_test.eval(e), content="VStr(yes)")
}

///|
test "plugins compose: if (1+1 == 2) then 10*10 else 0" {
  let e : Expr = @extenum_test.If(
    @extenum_test.Eq(
      @extenum_test.Add(@extenum_test.Lit(1), @extenum_test.Lit(1)),
      @extenum_test.Lit(2),
    ),
    @extenum_test.Mul(@extenum_test.Lit(10), @extenum_test.Lit(10)),
    @extenum_test.Lit(0),
  )
  inspect(@extenum_test.eval(e), content="VInt(100)")
}

///|
test "type mismatch raises a structured error" {
  // Add(Str("x"), Lit(1)) — Add expects ints on both sides.
  let e : Expr = @extenum_test.Add(@extenum_test.Str("x"), @extenum_test.Lit(1))
  let r : Result[Value, _] = try? @extenum_test.eval(e)
  inspect(r, content="Err(Fail(TypeMismatch(expected=VInt, got=VStr(x))))")
}

///|
/// With the plugin's `Show` handler registered, `VStr` prints correctly —
/// even though `core.mbt` has no static knowledge of `VStr`. The formatting
/// lookup is done at runtime against a registry the plugin wrote into.
test "plugin variants print through the registered handler" {
  let v : Value = @extenum_test.VStr("hi")
  inspect(v, content="VStr(hi)")
  let vb : Value = @extenum_test.VBool(true)
  inspect(vb, content="VBool(true)")
}
