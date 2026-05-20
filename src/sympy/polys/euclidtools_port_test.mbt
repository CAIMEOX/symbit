///|
fn expect_gcd_oracle(p : Poly, q : Poly) -> Unit raise {
  let g = p.gcd_univar(q)
  let ours = sympy_normalize(g.to_string()).trim().to_string()
  let oracle = gcd(p.to_expr(), q.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
fn expect_div_oracle(p : Poly, q : Poly) -> Unit raise {
  let (quo, rem) = p.divmod_univar(q)
  let ours = div_pair_to_string(quo, rem).trim().to_string()
  let oracle = div(p.to_expr(), q.to_expr()).trim().to_string()
  assert_eq(ours, oracle)
}

///|
fn expect_resultant_oracle(p : Poly, q : Poly) -> Unit raise {
  let res = p.resultant(q, 0)
  let ours = sympy_normalize(res.to_string()).trim().to_string()
  let oracle = resultant(p.to_expr(), q.to_expr(), x="x").trim().to_string()
  assert_eq(ours, oracle)
}

///|
test "euclidtools: gcd_univar oracle parity (x^4-1, x^3-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(4)) - expr_int(1))
  let q = b.from_expr((x ^ expr_int(3)) - expr_int(1))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: divmod oracle parity (x^4-1) / (x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(4)) - expr_int(1))
  let d = b.from_expr((x ^ expr_int(2)) - expr_int(1))
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
  let q = b.from_expr(
    (x ^ expr_int(3)) + (x ^ expr_int(2)) + expr_int(-4) * x + expr_int(-4),
  )
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (2*x, x^2-16)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(expr_int(2) * x)
  let q = b.from_expr((x ^ expr_int(2)) - expr_int(16))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ rational square)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    expr_rat(1, 2) * ((x ^ expr_int(2)) + expr_int(-2) * x + expr_int(1)),
  )
  let q = b.from_expr((x ^ expr_int(2)) - expr_int(1))
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
  let q = b.from_expr((x ^ expr_int(2)) + expr_rat(-1, 3) * x + expr_rat(-2, 3))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (x^6-1, x^4-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(6)) - expr_int(1))
  let q = b.from_expr((x ^ expr_int(4)) - expr_int(1))
  expect_gcd_oracle(p, q)
}

///|
test "euclidtools: divmod oracle parity (x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(5)) + expr_int(1))
  let d = b.from_expr(x + expr_int(1))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (QQ x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(5)) + expr_int(1))
  let d = b.from_expr(x + expr_int(1))
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
  let d = b.from_expr(x + expr_rat(1, 2))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (QQ rational coefficients)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(4)) + expr_rat(1, 2) * (x ^ expr_int(2)) - expr_int(1),
  )
  let d = b.from_expr((x ^ expr_int(2)) + expr_rat(1, 2))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod dense arrays (x^5+1) / (x+1)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(5)) + expr_int(1))
  let d = b.from_expr(x + expr_int(1))
  let (q, r) = p.divmod_univar(d)
  let q_dense = @sympolys.to_dense(q)
  let r_dense = @sympolys.to_dense(r)
  inspect(q_dense.map(c => c.to_string()).join(","), content="1,-1,1,-1,1")
  inspect(r_dense.map(c => c.to_string()).join(","), content="0")
  let pair = div_pair_to_string(q, r)
  inspect(pair.trim(), content="x**4 - x**3 + x**2 - x + 1||0")
}

///|
test "euclidtools: resultant oracle parity (x^3-2*x+1, x^2+x+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(3)) + expr_int(-2) * x + expr_int(1))
  let q = b.from_expr((x ^ expr_int(2)) + x + expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (QQ rational coefficients)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(1, 3) * x + expr_rat(-2, 3))
  let q = b.from_expr((x ^ expr_int(2)) + expr_rat(-2, 3) * x + expr_rat(1, 3))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: gcd_univar oracle parity (QQ rational root)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(-1, 2) * x + expr_rat(-1, 8))
  let q = b.from_expr(x + expr_rat(-1, 4))
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
  let d = b.from_expr(x + expr_rat(-1, 2))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: divmod oracle parity (x^4+x^3-x-1) / (x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr(
    (x ^ expr_int(4)) + (x ^ expr_int(3)) + expr_int(-1) * x - expr_int(1),
  )
  let d = b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_div_oracle(p, d)
}

///|
test "euclidtools: resultant oracle parity (x^2+1, x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_int(1))
  let q = b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^3-1, x^3+2*x^2+2*x-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(3)) - expr_int(1))
  let q = b.from_expr(
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
  let q = b.from_expr(x - expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (3*x^3-x, 5*x^2+1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr(expr_int(3) * (x ^ expr_int(3)) + expr_int(-1) * x)
  let q = b.from_expr(expr_int(5) * (x ^ expr_int(2)) + expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^2-2*x+1, x^2-1)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_int(-2) * x + expr_int(1))
  let q = b.from_expr((x ^ expr_int(2)) - expr_int(1))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^2-2*x+7, x^3-x+5)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_int(-2) * x + expr_int(7))
  let q = b.from_expr((x ^ expr_int(3)) + expr_int(-1) * x + expr_int(5))
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
  let q = b.from_expr(
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
  let q = b.from_expr(x + expr_rat(1, 2))
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
  let q = b.from_expr(x + expr_rat(1, 2))
  expect_div_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (x^3-2, x^2-3)" {
  let b = PolyBuilder::new(["x"], Domain::ZZ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(3)) - expr_int(2))
  let q = b.from_expr((x ^ expr_int(2)) - expr_int(3))
  expect_resultant_oracle(p, q)
}

///|
test "euclidtools: resultant oracle parity (QQ quadratic)" {
  let b = PolyBuilder::new(["x"], Domain::QQ)
  let x = expr_sym("x")
  let p = b.from_expr((x ^ expr_int(2)) + expr_rat(1, 2) * x + expr_int(1))
  let q = b.from_expr(x + expr_rat(-1, 2))
  expect_resultant_oracle(p, q)
}

///|
fn euclid_port_dup_triple_repr(
  triple : (Array[FieldElem], Array[FieldElem], Array[FieldElem]),
) -> String {
  "(\{dup_repr(triple.0)},\{dup_repr(triple.1)},\{dup_repr(triple.2)})"
}

///|
fn euclid_port_dup_list_repr(polys : Array[Array[FieldElem]]) -> String {
  "[" + polys.map(poly => dup_repr(poly)).join(",") + "]"
}

///|
fn euclid_port_dmp_triple_repr(
  triple : (DensePoly, DensePoly, DensePoly),
) -> String {
  "(\{dmp_repr(triple.0)},\{dmp_repr(triple.1)},\{dmp_repr(triple.2)})"
}

///|
fn euclid_port_dmp_list_repr(polys : Array[DensePoly]) -> String {
  "[" + polys.map(poly => dmp_repr(poly)).join(",") + "]"
}

///|
test "euclidtools: dense extended Euclidean oracle parity" {
  let f = [feqq(1, 1), feqq(-2, 1), feqq(-6, 1), feqq(12, 1), feqq(15, 1)]
  let g = [feqq(1, 1), feqq(1, 1), feqq(-4, 1), feqq(-4, 1)]
  assert_eq(
    dup_repr_tuple(@sympolys.dup_half_gcdex(f, g, Domain::QQ)),
    dup_half_gcdex(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
  assert_eq(
    euclid_port_dup_triple_repr(@sympolys.dup_gcdex(f, g, Domain::QQ)),
    dup_gcdex(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
}

///|
test "euclidtools: dense inverse oracle parity" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-1, 1)]
  let g = [feqq(2, 1), feqq(-1, 1)]
  assert_eq(
    dup_repr(@sympolys.dup_invert(f, g, Domain::QQ)),
    dup_invert(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
}

///|
test "euclidtools: dense Euclidean PRS oracle parity" {
  let f = [
    feqq(1, 1),
    feqq(0, 1),
    feqq(1, 1),
    feqq(0, 1),
    feqq(-3, 1),
    feqq(-3, 1),
    feqq(8, 1),
    feqq(2, 1),
    feqq(-5, 1),
  ]
  let g = [
    feqq(3, 1),
    feqq(0, 1),
    feqq(5, 1),
    feqq(0, 1),
    feqq(-4, 1),
    feqq(-9, 1),
    feqq(21, 1),
  ]
  assert_eq(
    euclid_port_dup_list_repr(@sympolys.dup_euclidean_prs(f, g, Domain::QQ)),
    dup_euclidean_prs(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
}

///|
test "euclidtools: dense dmp univariate oracle parity" {
  let f = poly_fe([
    feqq(1, 1),
    feqq(-2, 1),
    feqq(-6, 1),
    feqq(12, 1),
    feqq(15, 1),
  ])
  let g = poly_fe([feqq(1, 1), feqq(1, 1), feqq(-4, 1), feqq(-4, 1)])
  assert_eq(
    dmp_pair_repr(@sympolys.dmp_half_gcdex(f, g, 0, Domain::QQ)),
    dmp_half_gcdex(dense_data_of(f), dense_data_of(g), 0, domain="QQ"),
  )
  assert_eq(
    euclid_port_dmp_triple_repr(@sympolys.dmp_gcdex(f, g, 0, Domain::QQ)),
    dmp_gcdex(dense_data_of(f), dense_data_of(g), 0, domain="QQ"),
  )
  let inv_f = poly_fe([feqq(1, 1), feqq(0, 1), feqq(-1, 1)])
  let inv_g = poly_fe([feqq(2, 1), feqq(-1, 1)])
  assert_eq(
    dmp_repr(@sympolys.dmp_invert(inv_f, inv_g, 0, Domain::QQ)),
    dmp_invert(dense_data_of(inv_f), dense_data_of(inv_g), 0, domain="QQ"),
  )
  assert_eq(
    euclid_port_dmp_list_repr(@sympolys.dmp_euclidean_prs(f, g, 0, Domain::QQ)),
    dmp_euclidean_prs(dense_data_of(f), dense_data_of(g), 0, domain="QQ"),
  )
}
