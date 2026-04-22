///|
fn main {
  // if (1 + 1 == 2) then "yes: " ++ "12" else "no"
  //
  // Constructors cross two packages: `@lib` (core + string plugin) and
  // `@bool` (the boolean plugin in its own package). The evaluator and
  // pretty-printer only see an opaque `Expr`/`Value`; dispatch happens
  // through runtime handler chains registered by each plugin's `init`.
  let e : @lib.Expr = @bool.If(
    @bool.Eq(@lib.Add(@lib.Lit(1), @lib.Lit(1)), @lib.Lit(2)),
    @lib.Concat(@lib.Str("yes: "), @lib.Str("\{3 * 4}")),
    @lib.Str("no"),
  )
  println(@lib.eval(e)) catch {
    err => println("error: \{err}")
  }
}
