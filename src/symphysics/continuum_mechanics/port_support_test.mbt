///|
fn continuum_oracle_lines(script : String) -> Array[String] {
  Array::from_iter(
    (try! @sympy_physics.continuum_exec_stdout(script)).trim().split("\n"),
  )
  .map(line => line.trim().to_string())
  .filter(line => line != "")
}

///|
fn continuum_expr_eq(ours : @symcore.Expr, oracle : String) -> Bool {
  let ours_text = @symprint.to_string(cm_simplify(ours))
  try @sympy_physics.expr_equal(ours_text, oracle) catch {
    _ => false
  } noraise {
    ok => ok
  }
}

///|
fn continuum_float_close(ours : @symcore.Expr, oracle : String) -> Bool {
  match (cm_expr_eval(ours, {}), try? @strconv.parse_double(oracle)) {
    (Some(ours_value), Ok(oracle_value)) =>
      ours_value.is_close(
        oracle_value,
        relative_tolerance=1.0e-6,
        absolute_tolerance=1.0e-6,
      )
    _ => false
  }
}
