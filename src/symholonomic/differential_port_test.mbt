///|
fn dcoeff_strings(coeffs : Array[@symcore.Expr]) -> Array[String] {
  coeffs.map(v => @symprint.to_string(v))
}

///|
fn differential_srepr_local(op : DifferentialOperator) -> String raise {
  let alg = op.algebra()
  @sympy_holo.differential_srepr(
    dcoeff_strings(op.coefficients()),
    var_name=@symprint.to_string(alg.variable()),
    generator=alg.generator(),
  )
}

///|
test "holonomic differential: weyl commutation parity" {
  let x = @symcore.symbol("x")
  let (r, dx) = differential_operators(symbol_var=x)
  let x_op = differential_operator([x], r)
  let left1 = dx * x_op
  let left2 = dx * differential_operator([@symcore.pow(x, @symcore.int(2))], r)
  let left3 = dx.pow(2) * differential_operator([@symcore.pow(x, @symcore.int(2))], r)
  assert_eq(differential_srepr_local(left1), @sympy_holo.differential_expr_srepr("Dx*x"))
  assert_eq(differential_srepr_local(left2), @sympy_holo.differential_expr_srepr("Dx*x**2"))
  assert_eq(differential_srepr_local(left3), @sympy_holo.differential_expr_srepr("Dx**2*x**2"))
}

///|
test "holonomic differential: polynomial operator multiplication parity" {
  let x = @symcore.symbol("x")
  let (r, dx) = differential_operators(symbol_var=x)
  let x_op = differential_operator([x], r)
  let one = differential_operator([@symcore.int(1)], r)
  let minus_dx2 = differential_operator([@symcore.int(0), @symcore.int(0), @symcore.int(-1)], r)
  let base = x_op * dx * x_op + one + minus_dx2
  let ours = base.pow(2)
  let oracle = @sympy_holo.differential_expr_srepr("(x*Dx*x + 1 - Dx**2)**2")
  assert_eq(differential_srepr_local(ours), oracle)
}

///|
test "holonomic differential: pow parity on first-order op" {
  let x = @symcore.symbol("x")
  let (r, _) = differential_operators(symbol_var=x)
  let op = differential_operator([@symcore.int(1), x], r)
  for m in 0..<6 {
    let ours = op.pow(m)
    let oracle = @sympy_holo.differential_pow_srepr(["1", "x"], m)
    assert_eq(differential_srepr_local(ours), oracle)
  }
}
