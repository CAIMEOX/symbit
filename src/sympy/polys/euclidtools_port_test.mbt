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
fn euclid_port_field_list_repr(values : Array[FieldElem]) -> String {
  "[" + values.map(value => value.to_string()).join(",") + "]"
}

///|
fn euclid_port_inner_subres_repr(
  value : (Array[Array[FieldElem]], Array[FieldElem]),
) -> String {
  "(\{euclid_port_dup_list_repr(value.0)},\{euclid_port_field_list_repr(value.1)})"
}

///|
fn euclid_port_prs_resultant_repr(
  value : (FieldElem, Array[Array[FieldElem]]),
) -> String {
  "(\{value.0},\{euclid_port_dup_list_repr(value.1)})"
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
fn euclid_port_dmp_pair_list_repr(
  value : (DensePoly, Array[DensePoly]),
) -> String {
  "(\{dmp_repr(value.0)},\{euclid_port_dmp_list_repr(value.1)})"
}

///|
fn euclid_port_dmp_inner_subres_repr(
  value : (Array[DensePoly], Array[DensePoly]),
) -> String {
  "(\{euclid_port_dmp_list_repr(value.0)},\{euclid_port_dmp_list_repr(value.1)})"
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

///|
test "euclidtools: dense primitive and subresultant oracle parity" {
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
    euclid_port_dup_list_repr(@sympolys.dup_primitive_prs(f, g, Domain::ZZ)),
    dup_primitive_prs(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )
  let a = [feqq(1, 1), feqq(0, 1), feqq(1, 1)]
  let b = [feqq(1, 1), feqq(0, 1), feqq(-1, 1)]
  assert_eq(
    euclid_port_inner_subres_repr(
      @sympolys.dup_inner_subresultants(a, b, Domain::ZZ),
    ),
    dup_inner_subresultants(dup_to_rats(a), dup_to_rats(b), domain="ZZ"),
  )
  assert_eq(
    euclid_port_dup_list_repr(@sympolys.dup_subresultants(a, b, Domain::ZZ)),
    dup_subresultants(dup_to_rats(a), dup_to_rats(b), domain="ZZ"),
  )
  assert_eq(
    euclid_port_prs_resultant_repr(
      @sympolys.dup_prs_resultant(a, b, Domain::ZZ),
    ),
    dup_prs_resultant(dup_to_rats(a), dup_to_rats(b), domain="ZZ"),
  )
  assert_eq(
    @sympolys.dup_resultant(a, b, Domain::ZZ).to_string(),
    dup_resultant(dup_to_rats(a), dup_to_rats(b), domain="ZZ"),
  )
}

///|
test "euclidtools: dense discriminant and dmp resultant oracle parity" {
  let f = [feqq(1, 1), feqq(2, 1), feqq(3, 1)]
  assert_eq(
    @sympolys.dup_discriminant(f, Domain::ZZ).to_string(),
    dup_discriminant(dup_to_rats(f), domain="ZZ"),
  )
  let a = poly_fe([feqq(1, 1), feqq(0, 1), feqq(1, 1)])
  let b = poly_fe([feqq(1, 1), feqq(0, 1), feqq(-1, 1)])
  assert_eq(
    euclid_port_dmp_inner_subres_repr(
      @sympolys.dmp_inner_subresultants(a, b, 0, Domain::ZZ),
    ),
    dmp_inner_subresultants(dense_data_of(a), dense_data_of(b), 0, domain="ZZ"),
  )
  assert_eq(
    euclid_port_dmp_list_repr(@sympolys.dmp_subresultants(a, b, 0, Domain::ZZ)),
    dmp_subresultants(dense_data_of(a), dense_data_of(b), 0, domain="ZZ"),
  )
  assert_eq(
    euclid_port_dmp_pair_list_repr(
      @sympolys.dmp_prs_resultant(a, b, 0, Domain::ZZ),
    ),
    dmp_prs_resultant(dense_data_of(a), dense_data_of(b), 0, domain="ZZ"),
  )
  assert_eq(
    dmp_repr(@sympolys.dmp_resultant(a, b, 0, Domain::ZZ)),
    dmp_resultant(dense_data_of(a), dense_data_of(b), 0, domain="ZZ"),
  )
  assert_eq(
    dmp_repr(@sympolys.dmp_discriminant(poly_fe(f), 0, Domain::ZZ)),
    dmp_discriminant(dense_data_of(poly_fe(f)), 0, domain="ZZ"),
  )
}

///|
test "euclidtools: dense gcd lcm cancel oracle parity over ZZ" {
  let f = [feqq(1, 1), feqq(0, 1), feqq(-1, 1)]
  let g = [feqq(1, 1), feqq(-3, 1), feqq(2, 1)]
  assert_eq(
    euclid_port_dup_triple_repr(@sympolys.dup_rr_prs_gcd(f, g, Domain::ZZ)),
    dup_rr_prs_gcd(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )
  assert_eq(
    euclid_port_dup_triple_repr(@sympolys.dup_inner_gcd(f, g, Domain::ZZ)),
    dup_inner_gcd(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_gcd(f, g, Domain::ZZ)),
    dup_gcd(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_rr_lcm(f, g, Domain::ZZ)),
    dup_rr_lcm(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_lcm(f, g, Domain::ZZ)),
    dup_lcm(dup_to_rats(f), dup_to_rats(g), domain="ZZ"),
  )
  let n = [feqq(2, 1), feqq(0, 1), feqq(-2, 1)]
  let d = [feqq(1, 1), feqq(-2, 1), feqq(1, 1)]
  assert_eq(
    dup_repr_tuple(@sympolys.dup_cancel(n, d, Domain::ZZ)),
    dup_cancel(dup_to_rats(n), dup_to_rats(d), domain="ZZ"),
  )
}

///|
test "euclidtools: dense gcd lcm oracle parity over QQ" {
  let f = [feqq(1, 2), feqq(7, 4), feqq(3, 2)]
  let g = [feqq(1, 2), feqq(1, 1), feqq(0, 1)]
  assert_eq(
    euclid_port_dup_triple_repr(@sympolys.dup_ff_prs_gcd(f, g, Domain::QQ)),
    dup_ff_prs_gcd(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_gcd(f, g, Domain::QQ)),
    dup_gcd(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_ff_lcm(f, g, Domain::QQ)),
    dup_ff_lcm(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
  assert_eq(
    dup_repr(@sympolys.dup_lcm(f, g, Domain::QQ)),
    dup_lcm(dup_to_rats(f), dup_to_rats(g), domain="QQ"),
  )
}

///|
test "euclidtools: dense dmp gcd lcm cancel oracle parity" {
  let f = poly_fe([feqq(1, 1), feqq(0, 1), feqq(-1, 1)])
  let g = poly_fe([feqq(1, 1), feqq(-3, 1), feqq(2, 1)])
  assert_eq(
    euclid_port_dmp_triple_repr(@sympolys.dmp_rr_prs_gcd(f, g, 0, Domain::ZZ)),
    dmp_rr_prs_gcd(dense_data_of(f), dense_data_of(g), 0, domain="ZZ"),
  )
  assert_eq(
    euclid_port_dmp_triple_repr(@sympolys.dmp_inner_gcd(f, g, 0, Domain::ZZ)),
    dmp_inner_gcd(dense_data_of(f), dense_data_of(g), 0, domain="ZZ"),
  )
  assert_eq(
    dmp_repr(@sympolys.dmp_gcd(f, g, 0, Domain::ZZ)),
    dmp_gcd(dense_data_of(f), dense_data_of(g), 0, domain="ZZ"),
  )
  assert_eq(
    dmp_repr(@sympolys.dmp_lcm(f, g, 0, Domain::ZZ)),
    dmp_lcm(dense_data_of(f), dense_data_of(g), 0, domain="ZZ"),
  )
  let n = poly_fe([feqq(2, 1), feqq(0, 1), feqq(-2, 1)])
  let d = poly_fe([feqq(1, 1), feqq(-2, 1), feqq(1, 1)])
  assert_eq(
    dmp_pair_repr(@sympolys.dmp_cancel(n, d, 0, Domain::ZZ)),
    dmp_cancel(dense_data_of(n), dense_data_of(d), 0, domain="ZZ"),
  )
  let fq = poly_fe([feqq(1, 2), feqq(7, 4), feqq(3, 2)])
  let gq = poly_fe([feqq(1, 2), feqq(1, 1), feqq(0, 1)])
  assert_eq(
    euclid_port_dmp_triple_repr(@sympolys.dmp_ff_prs_gcd(fq, gq, 0, Domain::QQ)),
    dmp_ff_prs_gcd(dense_data_of(fq), dense_data_of(gq), 0, domain="QQ"),
  )
  assert_eq(
    dmp_repr(@sympolys.dmp_ff_lcm(fq, gq, 0, Domain::QQ)),
    dmp_ff_lcm(dense_data_of(fq), dense_data_of(gq), 0, domain="QQ"),
  )
}

///|
test "euclidtools: dense dmp content primitive oracle parity" {
  let xy = @sympolys.dense_poly([poly_int([2, 6]), poly_int([4, 12])])
  assert_eq(
    dmp_repr(@sympolys.dmp_content(xy, 1, Domain::ZZ)),
    dmp_content(dense_data_of(xy), 1, domain="ZZ"),
  )
  let ours = @sympolys.dmp_primitive(xy, 1, Domain::ZZ)
  let ours_str = "(\{dmp_repr(ours.0)},\{dmp_repr(ours.1)})"
  assert_eq(ours_str, dmp_primitive(dense_data_of(xy), 1, domain="ZZ"))
}
