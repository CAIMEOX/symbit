///|\
/// Oracle helpers for `sympy.utilities` parity tests.

///|
pub fn utilities_eval_str(expr : String) -> String raise {
  @runtime.eval_str("utilities.eval_str", expr)
}

///|
pub fn utilities_eval_repr(expr : String) -> String raise {
  utilities_eval_str("repr(" + expr + ")")
}
