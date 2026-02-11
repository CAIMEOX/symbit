///|
test "holonomic function: expr_to_holonomic parity for elementary forms" {
  let x = @symcore.symbol("x")
  let hf_exp = expr_to_holonomic(@symcore.function("exp", [x]), x~)
  let hf_sin = expr_to_holonomic(@symcore.function("sin", [x]), x~)
  let hf_cos = expr_to_holonomic(@symcore.function("cos", [x]), x~)
  assert_eq(hf_exp.to_sympy_str(), @sympy_holo.expr_to_holonomic_str("exp(x)"))
  assert_eq(hf_sin.to_sympy_str(), @sympy_holo.expr_to_holonomic_str("sin(x)"))
  assert_eq(hf_cos.to_sympy_str(), @sympy_holo.expr_to_holonomic_str("cos(x)"))
}

///|
test "holonomic function: closure ops and calculus on expr hints" {
  let x = @symcore.symbol("x")
  let hf_exp = expr_to_holonomic(@symcore.function("exp", [x]), x~)
  let hf_sin = expr_to_holonomic(@symcore.function("sin", [x]), x~)
  let add_expr = @symprint.to_string((hf_exp + hf_sin).to_expr())
  let mul_expr = @symprint.to_string((hf_exp * hf_sin).to_expr())
  let diff_expr = @symprint.to_string(hf_sin.diff().to_expr())
  let int_expr = @symprint.to_string(
    expr_to_holonomic(@symcore.function("cos", [x]), x~).integrate().to_expr(),
  )
  let comp_expr = @symprint.to_string(
    hf_exp.composition(@symcore.pow(x, @symcore.int(2))).to_expr(),
  )
  assert_true(@sympy_holo.sympy_equiv_str(add_expr, "exp(x) + sin(x)"))
  assert_true(@sympy_holo.sympy_equiv_str(mul_expr, "exp(x)*sin(x)"))
  assert_true(@sympy_holo.sympy_equiv_str(diff_expr, "cos(x)"))
  assert_true(@sympy_holo.sympy_equiv_str(int_expr, "sin(x)"))
  assert_true(@sympy_holo.sympy_equiv_str(comp_expr, "exp(x**2)"))
}

///|
test "holonomic function: sequence conversion for constant-coefficient ode" {
  let x = @symcore.symbol("x")
  let seq_exp = expr_to_holonomic(@symcore.function("exp", [x]), x~).to_sequence()
  guard seq_exp.length() == 1 else { fail("expected one sequence") }
  let oracle_exp = @sympy_holo.sequence_str(["-1", "n + 1"], u0=["1"])
  assert_eq(seq_exp[0].to_sympy_str(), oracle_exp)

  let seq_sin = expr_to_holonomic(@symcore.function("sin", [x]), x~).to_sequence()
  guard seq_sin.length() == 1 else { fail("expected one sequence") }
  let sin_coeffs = seq_sin[0].recurrence().coefficients()
  assert_eq(sin_coeffs.length(), 3)
  assert_true(
    @sympy_holo.sympy_equiv_str(@symprint.to_string(sin_coeffs[0]), "1"),
  )
  assert_true(
    @sympy_holo.sympy_equiv_str(@symprint.to_string(sin_coeffs[1]), "0"),
  )
  assert_true(
    @sympy_holo.sympy_equiv_str(
      @symprint.to_string(sin_coeffs[2]),
      "n**2 + 3*n + 2",
    ),
  )
  let sin_u0 = seq_sin[0].initial_values()
  assert_eq(sin_u0.length(), 2)
  assert_true(@sympy_holo.sympy_equiv_str(@symprint.to_string(sin_u0[0]), "0"))
  assert_true(@sympy_holo.sympy_equiv_str(@symprint.to_string(sin_u0[1]), "1"))
}

///|
test "holonomic function: series and evalf pipeline" {
  let x = @symcore.symbol("x")
  let hf_exp = expr_to_holonomic(@symcore.function("exp", [x]), x~)
  let series_expr = @symprint.to_string(hf_exp.series(n=6))
  assert_true(
    @sympy_holo.sympy_equiv_str(
      series_expr, "1 + x + x**2/2 + x**3/6 + x**4/24 + x**5/120",
    ),
  )
  let eval = @symprint.to_string(
    hf_exp.evalf(@symnum.BigRational::from_int(1), terms=6),
  )
  assert_true(@sympy_holo.sympy_equiv_str(eval, "163/60"))
}
