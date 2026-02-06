///|
fn coeff_strings(coeffs : Array[@symcore.Expr]) -> Array[String] {
  coeffs.map(v => @symprint.to_string(v))
}

///|
fn recurrence_srepr_local(op : RecurrenceOperator) -> String raise {
  let alg = op.algebra()
  @sympy_holo.recurrence_srepr(
    coeff_strings(op.coefficients()),
    var_name=@symprint.to_string(alg.variable()),
    generator=alg.generator(),
  )
}

///|
test "holonomic recurrence: shift commutation parity" {
  let n = @symcore.symbol("n")
  let (r, sn) = recurrence_operators(symbol_var=n)
  let n_op = recurrence_operator([n], r)
  let n2_op = recurrence_operator([@symcore.pow(n, @symcore.int(2))], r)
  let left1 = sn * n_op
  let left2 = sn * n2_op
  let left3 = sn.pow(2) * n2_op
  let o1 = @sympy_holo.recurrence_expr_srepr("Sn*n")
  let o2 = @sympy_holo.recurrence_expr_srepr("Sn*n**2")
  let o3 = @sympy_holo.recurrence_expr_srepr("Sn**2*n**2")
  assert_eq(recurrence_srepr_local(left1), o1)
  assert_eq(recurrence_srepr_local(left2), o2)
  assert_eq(recurrence_srepr_local(left3), o3)
}

///|
test "holonomic recurrence: multiplication and power parity" {
  let n = @symcore.symbol("n")
  let (r, sn) = recurrence_operators(symbol_var=n)
  let n2 = @symcore.pow(n, @symcore.int(2))
  let p = (sn.pow(3) * recurrence_operator([n2], r) + sn * recurrence_operator([n], r)).pow(2)
  let oracle = @sympy_holo.recurrence_expr_srepr("(Sn**3*n**2 + Sn*n)**2")
  assert_eq(recurrence_srepr_local(p), oracle)
}

///|
test "holonomic recurrence: pow parity on scalar operator" {
  let n = @symcore.symbol("n")
  let (r, _) = recurrence_operators(symbol_var=n)
  let rr = recurrence_operator([@symcore.pow(n, @symcore.int(2)), @symcore.int(0), @symcore.int(0)], r)
  for m in 0..<6 {
    let ours = rr.pow(m)
    let oracle = @sympy_holo.recurrence_pow_srepr(["n**2"], m)
    assert_eq(recurrence_srepr_local(ours), oracle)
  }
}
