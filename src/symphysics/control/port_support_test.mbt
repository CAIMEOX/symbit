///|
fn control_oracle_lines(script : String) -> Array[String] {
  Array::from_iter(
    (try! @sympy_physics.control_exec_stdout(script)).trim().split("\n"),
  )
  .map(line => line.trim().to_string())
  .filter(line => line != "")
}

///|
fn control_expr_eq(ours : @symcore.Expr, oracle : String) -> Bool {
  try @sympy_physics.control_expr_equivalent(ours, oracle) catch {
    _ => false
  }
}

///|
fn control_parse_double(text : String) -> Double {
  try! @strconv.parse_double(text.trim().to_string())
}

///|
fn control_parse_complex(text : String) -> ControlComplex {
  let parts = Array::from_iter(text.trim().split(","))
  guard parts.length() == 2 else { panic() }
  (
    control_parse_double(parts[0].to_string()),
    control_parse_double(parts[1].to_string()),
  )
}

///|
fn control_test_complex_close(
  lhs : ControlComplex,
  rhs : ControlComplex,
  tol? : Double = 1.0e-6,
) -> Bool {
  (lhs.0 - rhs.0).abs() <= tol && (lhs.1 - rhs.1).abs() <= tol
}

///|
fn control_test_double_close(
  lhs : Double,
  rhs : Double,
  tol? : Double = 1.0e-6,
) -> Bool {
  lhs.is_close(rhs, relative_tolerance=tol, absolute_tolerance=tol)
}

///|
fn control_double_array_close(
  lhs : Array[Double],
  rhs : Array[Double],
  tol? : Double = 1.0e-6,
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if !control_test_double_close(lhs[i], rhs[i], tol~) {
      return false
    }
  }
  true
}

///|
fn control_complex_array_close(
  lhs : Array[ControlComplex],
  rhs : Array[ControlComplex],
  tol? : Double = 1.0e-6,
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if !control_test_complex_close(lhs[i], rhs[i], tol~) {
      return false
    }
  }
  true
}

///|
fn control_parse_double_lines(lines : Array[String]) -> Array[Double] {
  lines.map(control_parse_double)
}

///|
fn control_parse_complex_lines(lines : Array[String]) -> Array[ControlComplex] {
  lines.map(control_parse_complex)
}
