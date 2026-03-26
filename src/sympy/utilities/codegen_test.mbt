///|
/// Behavior tests for scalar code generation.

///|
test "codegen c surface" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let result = codegen([("test", (x + y) * z)], "C89", "file")
  inspect(
    result,
    content="[(\"file.c\", \"#include \\\"file.h\\\"\\n#include <math.h>\\ndouble test(double x, double y, double z) {\\n   double test_result;\\n   test_result = z*(x + y);\\n   return test_result;\\n}\\n\"), (\"file.h\", \"#ifndef FILE__H\\n#define FILE__H\\ndouble test(double x, double y, double z);\\n#endif\\n\")]",
  )
}

///|
test "codegen julia and rust surface" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
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
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let routine = make_routine(
    "f",
    [routine_result("f_result", x + y)],
    argument_sequence=Some(["y", "x"]),
  )
  inspect(routine.arguments, content="[\"y\", \"x\"]")
}

///|
test "codegen prints Float literals and rejects complex literals on C targets" {
  let x = @symcore.Expr::Symbol("x")
  let half = @symcore.Expr::Float(
    @symcore.Float::from_str("0.5", prec=80) catch {
      _ => fail("float literal")
    },
  )
  let c_out = codegen([("f", x + half)], "C89", "file")
  assert_true(c_out[0].1.contains("0.5"))

  let nonreal = @symcore.Expr::ComplexFloat(
    @symcore.ComplexFloat::from_real(
      @symcore.Float::from_int(1),
      imag=@symcore.Float::from_int(1),
    ),
  )
  let result : Result[Array[(String, String)], @symutilities.UtilitiesError] = try? codegen(
    [("g", nonreal)],
    "C89",
    "file",
  )
  inspect(
    result,
    content="Err(Unsupported(\"codegen does not support complex floating literals for this target\"))",
  )
}
