///|
/// Boolean plugin — adds `Bool` literals, equality, and an `If` conditional.
/// Notice how `If` composes with variants from the core *and* the string
/// plugin for free: `eval` dispatches through the handler registry.
pub(all) extenum Expr += {
  Bool(Bool)
  Eq(Expr, Expr)
  If(Expr, Expr, Expr)
}

///|
pub(all) extenum Value += {
  VBool(Bool)
}

///|
pub fn as_bool(v : Value) -> Bool raise Fail {
  match v {
    VBool(b) => b
    _ => raise Fail(TypeMismatch(expected="VBool", got=v))
  }
}

///|
/// Open-world equality: pair up the known value kinds; anything else raises.
fn value_eq(a : Value, b : Value) -> Bool raise Fail {
  match (a, b) {
    (VInt(x), VInt(y)) => x == y
    (VStr(x), VStr(y)) => x == y
    (VBool(x), VBool(y)) => x == y
    _ => raise Fail(Unhandled("no equality for these Value kinds"))
  }
}

///|
fn bool_eval(e : Expr) -> Value? raise Fail {
  match e {
    Bool(b) => Some(VBool(b))
    Eq(a, b) => Some(VBool(value_eq(eval(a), eval(b))))
    If(c, t, f) => if as_bool(eval(c)) { Some(eval(t)) } else { Some(eval(f)) }
    _ => None
  }
}

///|
fn bool_show(v : Value, logger : &Logger) -> Bool {
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
  register_eval(bool_eval)
  register_value_show(bool_show)
}
