///|
/// Oracle helpers for `sympy.integrals` parity tests.

///|
/// Evaluate one serialized SymPy expression in the shared oracle worker.
pub fn integrals_eval_str(expr : String) -> String raise {
  @runtime.eval_str("integrals.eval_str", expr)
}
