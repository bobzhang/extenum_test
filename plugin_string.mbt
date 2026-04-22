///|
/// String plugin — extends `Expr` and `Value` without editing their core
/// declarations. This file could live in a separate package and the rest of
/// the language would keep compiling.
pub(all) extenum Expr += {
  Str(String)
  Concat(Expr, Expr)
}

///|
pub(all) extenum Value += {
  VStr(String)
}

///|
pub fn as_str(v : Value) -> String raise Fail {
  match v {
    VStr(s) => s
    _ => raise Fail(TypeMismatch(expected="VStr", got=v))
  }
}

///|
fn string_eval(e : Expr) -> Value? raise Fail {
  match e {
    Str(s) => Some(VStr(s))
    Concat(a, b) => Some(VStr(as_str(eval(a)) + as_str(eval(b))))
    _ => None
  }
}

///|
fn string_show(v : Value, logger : &Logger) -> Bool {
  match v {
    VStr(s) => {
      logger.write_string("VStr(\{s})")
      true
    }
    _ => false
  }
}

///|
fn init {
  register_eval(string_eval)
  register_value_show(string_show)
}
