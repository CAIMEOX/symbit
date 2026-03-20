///|
using @symcm {
  arch,
  beam,
  cable,
  cm_eval_at,
  cm_expr_is_zero,
  cm_numeric_expr_eq,
  cm_rat_expr,
  cm_simplify,
  cm_singularity,
  column,
  truss,
}

///|
fn continuum_oracle_lines(script : String) -> Array[String] raise {
  Array::from_iter(
    (continuum_exec_stdout(script)).trim().split("\n"),
  )
  .map(line => line.trim().to_string())
  .filter(line => line != "")
}

///|
fn continuum_expr_eq(ours : @symcore.Expr, oracle : String) -> Bool {
  let ours_text = @symprint.to_string(cm_simplify(ours))
  try expr_equal(ours_text, oracle) catch {
    _ => false
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
