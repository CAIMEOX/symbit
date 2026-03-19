///|
/// Oracle parity tests for scalar `codegen` output.

///|
fn codegen_source_from_oracle(
  name : String,
  expr : String,
  language : String,
) -> String raise {
  @sympy_utilities.utilities_eval_str(
    "__import__('sympy.utilities.codegen', fromlist=['codegen']).codegen((\"" +
    name +
    "\", " +
    expr +
    "), \"" +
    language +
    "\", \"file\", header=False, empty=False)[0][1]",
  )
}

///|
test "codegen c parity on scalar routine" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let ours = codegen([("test", (x + y) * z)], "C89", "file")[0].1
  let oracle = codegen_source_from_oracle(
    "test", "sympy.Symbol('z')*(sympy.Symbol('x') + sympy.Symbol('y'))", "C89",
  )
  assert_eq(ours, oracle)
}
