///|
/// Boolean plugin — now in its *own package*, extending types declared in
/// the parent package. `extenum @lib.Expr += { ... }` adds variants to a
/// type defined elsewhere. The parent never learns about these variants
/// statically; it picks them up at runtime through the handler registry.
pub(all) extenum @lib.Expr += {
  Bool(Bool)
  Eq(@lib.Expr, @lib.Expr)
  If(@lib.Expr, @lib.Expr, @lib.Expr)
}

///|
pub(all) extenum @lib.Value += {
  VBool(Bool)
}

///|
pub fn as_bool(v : @lib.Value) -> Bool raise @lib.Fail {
  match v {
    VBool(b) => b
    _ => raise @lib.Fail(@lib.TypeMismatch(expected="VBool", got=v))
  }
}

///|
/// Open-world equality: pair up the known value kinds; anything else raises.
fn value_eq(a : @lib.Value, b : @lib.Value) -> Bool raise @lib.Fail {
  match (a, b) {
    (@lib.VInt(x), @lib.VInt(y)) => x == y
    (@lib.VStr(x), @lib.VStr(y)) => x == y
    (VBool(x), VBool(y)) => x == y
    _ => raise @lib.Fail(@lib.Unhandled("no equality for these Value kinds"))
  }
}

///|
fn bool_eval(e : @lib.Expr) -> @lib.Value? raise @lib.Fail {
  match e {
    Bool(b) => Some(VBool(b))
    Eq(a, b) => Some(VBool(value_eq(@lib.eval(a), @lib.eval(b))))
    If(c, t, f) =>
      if as_bool(@lib.eval(c)) {
        Some(@lib.eval(t))
      } else {
        Some(@lib.eval(f))
      }
    _ => None
  }
}

///|
fn bool_show(v : @lib.Value, logger : &Logger) -> Bool {
  match v {
    VBool(b) => {
      logger.write_string("VBool(\{b})")
      true
    }
    _ => false
  }
}

///|
fn init {
  @lib.register_eval(bool_eval)
  @lib.register_value_show(bool_show)
}
