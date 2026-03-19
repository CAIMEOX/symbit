///|
/// Behavior tests for scalar code generation.

///|
test "codegen c surface" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let z = @symcore.symbol("z")
  let result = codegen([("test", (x + y) * z)], "C89", "file")
  inspect(
    result,
    content="[(\"file.c\", \"#include \\\"file.h\\\"\\n#include <math.h>\\ndouble test(double x, double y, double z) {\\n   double test_result;\\n   test_result = z*(x + y);\\n   return test_result;\\n}\\n\"), (\"file.h\", \"#ifndef FILE__H\\n#define FILE__H\\ndouble test(double x, double y, double z);\\n#endif\\n\")]",
  )
}

///|
test "codegen julia and rust surface" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let expr = @symcore.function("sin", [x]) + y
  let julia = codegen([("f", expr)], "julia", "file")
  let rust = codegen([("f", expr)], "rust", "file")
  assert_eq(julia[0].0, "file.jl")
  assert_eq(rust[0].0, "file.rs")
  assert_eq(julia[0].1.contains("function f(x, y)"), true)
  assert_eq(rust[0].1.contains("fn f(x: f64, y: f64) -> f64"), true)
}

///|
test "make_routine respects explicit argument order" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let routine = make_routine(
    "f",
    [routine_result("f_result", x + y)],
    argument_sequence=Some(["y", "x"]),
  )
  inspect(routine.arguments, content="[\"y\", \"x\"]")
}
