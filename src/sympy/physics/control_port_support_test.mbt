///|
using @symcontrol {
  type ControlComplex,
  type DiscreteTransferFunction,
  type SISOLinearTimeInvariant,
  type TransferFunction,
  bode_magnitude_numerical_data,
  bode_phase_numerical_data,
  bode_plot,
  create_transfer_function,
  discrete_transfer_function,
  feedback,
  impulse_response_numerical_data,
  nichols_plot,
  nichols_plot_expr,
  nyquist_plot,
  nyquist_plot_expr,
  parallel,
  pid_controller,
  pole_zero_numerical_data,
  pole_zero_plot,
  ramp_response_numerical_data,
  routh_hurwitz,
  series,
  step_response_numerical_data,
  transfer_function,
}

///|
fn control_oracle_lines(script : String) -> Array[String] raise {
  Array::from_iter(control_exec_stdout(script).trim().split("\n"))
  .map(line => line.trim().to_owned())
  .filter(line => line != "")
}

///|
fn control_expr_eq(ours : @symcore.Expr, oracle : String) -> Bool {
  control_expr_equivalent(ours, oracle) catch {
    _ => false
  }
}

///|
fn control_parse_double(text : String) -> Double raise {
  @string.parse_double(text.trim().to_owned())
}

///|
fn control_parse_complex(text : String) -> ControlComplex raise {
  let parts = Array::from_iter(text.trim().split(","))
  guard parts.length() == 2 else {
    fail("expected oracle complex line as 're,im'")
  }
  (
    control_parse_double(parts[0].to_owned()),
    control_parse_double(parts[1].to_owned()),
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
fn control_parse_double_lines(lines : Array[String]) -> Array[Double] raise {
  let out : Array[Double] = []
  for line in lines {
    out.push(control_parse_double(line))
  }
  out
}

///|
fn control_parse_complex_lines(
  lines : Array[String],
) -> Array[ControlComplex] raise {
  let out : Array[ControlComplex] = []
  for line in lines {
    out.push(control_parse_complex(line))
  }
  out
}
