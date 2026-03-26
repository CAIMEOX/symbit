///|
test "core: add/mul/pow parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.Expr::Symbol("x")
  let p = b.from_expr(
    (x ^ @symcore.int(2)) + @symcore.int(2) * x + @symcore.int(1),
  )
  let q = b.from_expr(x + @symcore.int(3))
  let add = p.add(q)
  let mul = p.mul(q)
  let pow = q.pow(2)
  let add_ours = add.to_string()
  assert_true(expr_equal(add_ours, "x**2 + 2*x + 1 + x + 3"))
  let mul_ours = mul.to_string()
  assert_true(expr_equal(mul_ours, "(x**2 + 2*x + 1)*(x + 3)"))
  let pow_ours = pow.to_string()
  assert_true(expr_equal(pow_ours, "(x + 3)**2"))
}

///|
test "core: domain mismatch raises" {
  let x = @symcore.Expr::Symbol("x")
  let p = PolyBuilder::new(["x"], Domain::ZZ).from_expr(x + @symcore.int(1))
  let q = PolyBuilder::new(["x"], Domain::QQ).from_expr(x + @symcore.int(1))
  let res : Result[Poly, PolyError] = try? p.add(q)
  assert_true(res is Err(PolyError::DomainMismatch))
}
