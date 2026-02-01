///|
fn expect_gcd_oracle(p : Poly, q : Poly) -> Unit raise {
  let g = try! p.gcd_univar(q)
  let ours = sympy_normalize(g.to_string()).trim().to_string()
  let oracle = @sympy_polys.gcd(p.to_expr(), q.to_expr()).trim().to_string()
  guard ours == oracle else {
    fail("gcd mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expect_div_oracle(p : Poly, q : Poly) -> Unit raise {
  let (quo, rem) = try! p.divmod_univar(q)
  let ours = div_pair_to_string(quo, rem).trim().to_string()
  let oracle = @sympy_polys.div(p.to_expr(), q.to_expr()).trim().to_string()
  guard ours == oracle else {
    fail("divmod mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expect_resultant_oracle(p : Poly, q : Poly) -> Unit raise {
  let res = try! p.resultant(q, 0)
  let ours = sympy_normalize(res.to_string()).trim().to_string()
  let oracle = @sympy_polys.resultant(p.to_expr(), q.to_expr(), x="x")
    .trim()
    .to_string()
  guard ours == oracle else {
    fail("resultant mismatch: ours=\{ours}, oracle=\{oracle}")
  }
}

///|
fn expr_rat(n : Int, d : Int) -> @symcore.Expr {
  try! @symcore.rational_from_ints(n, d)
}

///|
test "euclidtools: gcd_univar oracle parity (x^4-1, x^3-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(4)) - expr_int(1))
  let q = try! b.from_expr((x ^ expr_int(3)) - expr_int(1))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: divmod oracle parity (x^4-1) / (x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(4)) - expr_int(1))
  let d = try! b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ example)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(4)) +
    expr_int(-2) * (x ^ expr_int(3)) +
    expr_int(-6) * (x ^ expr_int(2)) +
    expr_int(12) * x +
    expr_int(15),
  )
  let q = try! b.from_expr(
    (x ^ expr_int(3)) + (x ^ expr_int(2)) + expr_int(-4) * x + expr_int(-4),
  )
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (2*x, x^2-16)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(expr_int(2) * x)
  let q = try! b.from_expr((x ^ expr_int(2)) - expr_int(16))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ rational square)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    expr_rat(1, 2) * ((x ^ expr_int(2)) + expr_int(-2) * x + expr_int(1)),
  )
  let q = try! b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ mixed coeffs)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(3)) +
    expr_rat(1, 3) * (x ^ expr_int(2)) +
    expr_rat(-1, 3) * x +
    expr_rat(-1, 3),
  )
  let q = try! b.from_expr(
    (x ^ expr_int(2)) + expr_rat(-1, 3) * x + expr_rat(-2, 3),
  )
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (x^6-1, x^4-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(6)) - expr_int(1))
  let q = try! b.from_expr((x ^ expr_int(4)) - expr_int(1))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: divmod oracle parity (x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(5)) + expr_int(1))
  let d = try! b.from_expr(x + expr_int(1))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (QQ x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(5)) + expr_int(1))
  let d = try! b.from_expr(x + expr_int(1))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (QQ rational divisor)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    expr_rat(1, 2) * (x ^ expr_int(3)) +
    expr_rat(3, 2) * (x ^ expr_int(2)) +
    x +
    expr_int(1),
  )
  let d = try! b.from_expr(x + expr_rat(1, 2))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (QQ rational coefficients)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(4)) + expr_rat(1, 2) * (x ^ expr_int(2)) - expr_int(1),
  )
  let d = try! b.from_expr((x ^ expr_int(2)) + expr_rat(1, 2))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod dense arrays (x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(5)) + expr_int(1))
  let d = try! b.from_expr(x + expr_int(1))
  let (q, r) = try! p.divmod_univar(d)
  let q_dense = try! to_dense(q)
  let r_dense = try! to_dense(r)
  inspect(q_dense.map(c => c.to_string()).join(","), content="1,-1,1,-1,1")
  inspect(r_dense.map(c => c.to_string()).join(","), content="0")
  let pair = div_pair_to_string(q, r)
  inspect(pair.trim().to_string(), content="x**4 - x**3 + x**2 - x + 1||0")
}

///|
test "euclidtools: resultant oracle parity (x^3-2*x+1, x^2+x+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(3)) + expr_int(-2) * x + expr_int(1))
  let q = try! b.from_expr((x ^ expr_int(2)) + x + expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (QQ rational coefficients)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(1, 3) * x + expr_rat(-2, 3))
  let q = try! b.from_expr(
    (x ^ expr_int(2)) + expr_rat(-2, 3) * x + expr_rat(1, 3),
  )
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ rational root)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(-1, 2) * x + expr_rat(-1, 8))
  let q = try! b.from_expr(x + expr_rat(-1, 4))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: divmod oracle parity (QQ fractional divisor)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(3)) +
    expr_rat(1, 2) * (x ^ expr_int(2)) +
    expr_rat(-3, 2) * x +
    expr_rat(1, 2),
  )
  let d = try! b.from_expr(x + expr_rat(-1, 2))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (x^4+x^3-x-1) / (x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(4)) + (x ^ expr_int(3)) + expr_int(-1) * x - expr_int(1),
  )
  let d = try! b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: resultant oracle parity (x^2+1, x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_int(1))
  let q = try! b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^3-1, x^3+2*x^2+2*x-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(3)) - expr_int(1))
  let q = try! b.from_expr(
    (x ^ expr_int(3)) +
    expr_int(2) * (x ^ expr_int(2)) +
    expr_int(2) * x +
    expr_int(-1),
  )
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^8-2, x-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(8)) - expr_int(2))
  let q = try! b.from_expr(x - expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (3*x^3-x, 5*x^2+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr(expr_int(3) * (x ^ expr_int(3)) + expr_int(-1) * x)
  let q = try! b.from_expr(expr_int(5) * (x ^ expr_int(2)) + expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^2-2*x+1, x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_int(-2) * x + expr_int(1))
  let q = try! b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^2-2*x+7, x^3-x+5)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_int(-2) * x + expr_int(7))
  let q = try! b.from_expr((x ^ expr_int(3)) + expr_int(-1) * x + expr_int(5))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^3-6*x^2+11*x-6, x^3-15*x^2+74*x-120)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(3)) +
    expr_int(-6) * (x ^ expr_int(2)) +
    expr_int(11) * x +
    expr_int(-6),
  )
  let q = try! b.from_expr(
    (x ^ expr_int(3)) +
    expr_int(-15) * (x ^ expr_int(2)) +
    expr_int(74) * x +
    expr_int(-120),
  )
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ rational linear)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(1, 2) * x + expr_rat(1, 4))
  let q = try! b.from_expr(x + expr_rat(1, 2))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: divmod oracle parity (QQ cubic / linear)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(3)) +
    expr_rat(1, 2) * (x ^ expr_int(2)) +
    expr_rat(-1, 2) * x +
    expr_int(1),
  )
  let q = try! b.from_expr(x + expr_rat(1, 2))
  expect_div_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^3-2, x^2-3)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(3)) - expr_int(2))
  let q = try! b.from_expr((x ^ expr_int(2)) - expr_int(3))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (QQ quadratic)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(1, 2) * x + expr_int(1))
  let q = try! b.from_expr(x + expr_rat(-1, 2))
  expect_resultant_oracle(p, q)
}
