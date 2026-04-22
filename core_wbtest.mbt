///|
/// Whitebox test: inside the package, `extenum` constructors don't need a
/// `@pkg.` qualifier. Outside the package (blackbox tests, downstream code),
/// foreign extenum constructors *must* be qualified as `@pkg.C`.
test "whitebox: unqualified constructors work inside the package" {
  let e : Expr = Mul(Add(Lit(1), Lit(2)), Lit(3))
  inspect(eval(e), content="VInt(9)")
}
