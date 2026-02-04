///|
fn expr_rat_div(n : Int, d : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(n, d)
}

///|
test "division: univariate div parity over ZZ (exact)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let p = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(1))
  let q = b.from_expr(x - @symcore.int(1))
  let (quo, rem) = p.divmod_univar(q)
  let ours = div_pair_to_string(quo, rem).trim().to_string()
  let oracle = @sympy_polys.div(
      p.to_expr(),
      q.to_expr(),
      gens=["x"],
      domain="ZZ",
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("div ZZ exact mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "division: univariate div parity over ZZ (remainder)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let p = b.from_expr((x ^ @symcore.int(2)) + @symcore.int(1))
  let q = b.from_expr(x + @symcore.int(1))
  let (quo, rem) = p.divmod_univar(q)
  let ours = div_pair_to_string(quo, rem).trim().to_string()
  let oracle = @sympy_polys.div(
      p.to_expr(),
      q.to_expr(),
      gens=["x"],
      domain="ZZ",
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("div ZZ remainder mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
test "division: univariate div parity over QQ" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = @symcore.symbol("x")
  let p = b.from_expr(
    expr_rat_div(1, 2) * (x ^ @symcore.int(2)) + x + expr_rat_div(1, 2),
  )
  let q = b.from_expr(x + @symcore.int(1))
  let (quo, rem) = p.divmod_univar(q)
  let ours = div_pair_to_string(quo, rem).trim().to_string()
  let oracle = @sympy_polys.div(
      p.to_expr(),
      q.to_expr(),
      gens=["x"],
      domain="QQ",
    )
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("div QQ mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}
