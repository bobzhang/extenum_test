///|
/// Core of an extensible expression language.
///
/// `extenum` means **open** ADT: variants can be added later, in other files
/// (and, in principle, other packages) without editing this declaration.
///
/// Because the set of variants is open, every `match` on an extenum must
/// include a wildcard arm — the compiler cannot prove a fixed list is
/// exhaustive. That wildcard is also where plugin dispatch lives.
pub(all) extenum Expr {
  Lit(Int)
  Add(Expr, Expr)
  Mul(Expr, Expr)
}

///|
/// A `Value` is also open: plugins can add new value kinds (strings, bools,
/// closures, ...) without touching this file.
pub(all) extenum Value {
  VInt(Int)
}

///|
/// A runtime error for the evaluator. Kept open so plugins can introduce
/// their own error variants without editing this file.
pub(all) extenum EvalError {
  Unhandled(String)
  TypeMismatch(expected~ : String, got~ : Value)
}

///|
pub(all) suberror Fail {
  Fail(EvalError)
}

// ─── eval handler chain ────────────────────────────────────────────────────

///|
/// Each plugin registers a partial handler. The core runs them in order and
/// falls back to `Unhandled` if none matches. `None` means "I don't recognize
/// this expression — let the next handler try." This is the open-world
/// analogue of a `match` arm.
let eval_handlers : Array[(Expr) -> Value? raise Fail] = []

///|
pub fn register_eval(h : (Expr) -> Value? raise Fail) -> Unit {
  eval_handlers.push(h)
}

///|
fn core_eval(e : Expr) -> Value? raise Fail {
  match e {
    Lit(n) => Some(VInt(n))
    Add(a, b) => Some(VInt(as_int(eval(a)) + as_int(eval(b))))
    Mul(a, b) => Some(VInt(as_int(eval(a)) * as_int(eval(b))))
    _ => None
  }
}

///|
/// The public evaluator. Tries each registered handler, in order.
pub fn eval(e : Expr) -> Value raise Fail {
  for h in eval_handlers {
    match h(e) {
      Some(v) => return v
      None => continue
    }
  }
  raise Fail(Unhandled("no handler for expression"))
}

// ─── show handler chain ────────────────────────────────────────────────────
// Same pattern as eval — plugins register a formatter for their variants, and
// the master `Show` impl walks the registry.

///|
let value_show_handlers : Array[(Value, &Logger) -> Bool] = []

///|
pub fn register_value_show(h : (Value, &Logger) -> Bool) -> Unit {
  value_show_handlers.push(h)
}

///|
fn core_value_show(v : Value, logger : &Logger) -> Bool {
  match v {
    VInt(n) => {
      logger.write_string("VInt(\{n})")
      true
    }
    _ => false
  }
}

///|
pub impl Show for Value with output(self, logger) {
  for h in value_show_handlers {
    if h(self, logger) {
      return
    }
  }
  logger.write_string("<opaque Value>")
}

// ─── misc helpers ──────────────────────────────────────────────────────────

///|
/// Project a `Value` to an `Int`, raising on mismatch. Because `Value` is
/// open, the wildcard is required — and the resulting error is informative.
pub fn as_int(v : Value) -> Int raise Fail {
  match v {
    VInt(n) => n
    _ => raise Fail(TypeMismatch(expected="VInt", got=v))
  }
}

///|
pub impl Show for EvalError with output(self, logger) {
  match self {
    Unhandled(msg) => logger.write_string("Unhandled(\{msg})")
    TypeMismatch(expected~, got~) =>
      logger.write_string("TypeMismatch(expected=\{expected}, got=\{got})")
    _ => logger.write_string("<opaque EvalError>")
  }
}

///|
pub impl Show for Fail with output(self, logger) {
  let Fail(e) = self
  logger.write_string("Fail(\{e})")
}

///|
fn init {
  register_eval(core_eval)
  register_value_show(core_value_show)
}
