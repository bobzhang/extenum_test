///|
fn main {
  // if (1 + 1 == 2) then "yes: " ++ "12" else "no"
  //
  // Every constructor below lives in the library package, but was declared
  // across three separate files (core, string plugin, bool plugin). The
  // evaluator and pretty-printer dispatch through runtime handler chains —
  // that's what makes the enum *open*.
  let e : @lib.Expr = @lib.If(
    @lib.Eq(@lib.Add(@lib.Lit(1), @lib.Lit(1)), @lib.Lit(2)),
    @lib.Concat(@lib.Str("yes: "), @lib.Str("\{3 * 4}")),
    @lib.Str("no"),
  )
  println(@lib.eval(e)) catch {
    err => println("error: \{err}")
  }
}
