///|
/// Oracle helpers for `sympy.integrals` parity tests.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
pub fn integrals_eval_str(expr : String) -> String raise {
  let state = py_gil_ensure()
  let text = symbit_integrals_eval_string(expr)
  py_gil_release(state)
  if text == "__SYMBIT_PY_EVAL_NONE__" {
    fail("py-eval-none")
  }
  text
}

///|
#borrow(expr)
extern "C" fn symbit_integrals_eval_string(expr : String) -> String = "symbit_integrals_eval_string"
