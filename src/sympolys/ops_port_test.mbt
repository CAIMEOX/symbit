///|
test "ops: gcd_list/lcm_list parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let f = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(1))
  let g = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(4))
  let h = b.from_expr((x ^ @symcore.int(2)) - @symcore.int(9))
  let ours_g = sympy_normalize(gcd_list([f, g, h]).to_string()).trim().to_string()
  let oracle_g = @sympy_polys.gcd_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_string()
  guard ours_g == oracle_g else { fail("gcd_list mismatch: ours=\{ours_g}, oracle=\{oracle_g}") }
  let ours_l = sympy_normalize(lcm_list([f, g, h]).to_string()).trim().to_string()
  let oracle_l = @sympy_polys.lcm_list([f.to_expr(), g.to_expr(), h.to_expr()])
    .trim()
    .to_string()
  guard ours_l == oracle_l else { fail("lcm_list mismatch: ours=\{ours_l}, oracle=\{oracle_l}") }
}

///|
test "ops: discriminant parity over ZZ" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = @symcore.symbol("x")
  let f = b.from_expr((x ^ @symcore.int(3)) - @symcore.int(2) * x + @symcore.int(1))
  let disc = discriminant(f)
  let ours = disc.to_string()
  let oracle = @sympy_polys.discriminant(f.to_expr()).trim().to_string()
  guard ours == oracle else { fail("discriminant mismatch: ours=\{ours}, oracle=\{oracle}") }
}

///|
test "ops: resultant_expr parity with gens/domain (univariate)" {
  let x = @symcore.symbol("x")
  let f = (x ^ @symcore.int(3)) + @symcore.int(2) * x + @symcore.int(1)
  let g = (x ^ @symcore.int(2)) + @symcore.int(1)
  let res = resultant_expr(
    f,
    g,
    "x",
    gens=["x"],
    domain=Domain::ZZ,
  )
  let ours = sympy_normalize(res.to_string()).trim().to_string()
  let oracle = @sympy_polys.resultant(
    f,
    g,
    x="x",
    gens=["x"],
    domain="ZZ",
  ).trim().to_string()
  guard ours == oracle else { fail("resultant_expr mismatch: ours=\{ours}, oracle=\{oracle}") }
}
