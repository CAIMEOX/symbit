///|
pub fn dimacs_load_str(s : String) -> String raise {
  let obj = sympy_call_must(
    "sympy.logic.utilities.dimacs.load",
    [OracleArg::Str(s)],
  )
  py_str_enum(obj)
}
