///|
fn fezz(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
}

///|
fn feqq(num : Int, den : Int) -> FieldElem {
  let br = try! @symnum.BigRational::new(
    BigInt::from_int(num),
    BigInt::from_int(den),
  )
  try! fe_from_rational(br, Domain::QQ)
}

///|
fn dup_repr_tuple(pair : (Array[FieldElem], Array[FieldElem])) -> String {
  let (a, b) = pair
  let left = dup_repr(a)
  let right = dup_repr(b)
  "(\{left},\{right})"
}

///|
fn dup_to_rats(coeffs : Array[FieldElem]) -> Array[@symnum.BigRational] {
  let out : Array[@symnum.BigRational] = Array::new()
  for c in coeffs {
    out.push(try! fe_expect_rational(c))
  }
  out
}

///|
fn dup_list_to_rats(
  polys : Array[Array[FieldElem]],
) -> Array[Array[@symnum.BigRational]] {
  let out : Array[Array[@symnum.BigRational]] = Array::new()
  for f in polys {
    out.push(dup_to_rats(f))
  }
  out
}

///|

///|
fn poly_int(vals : Array[Int]) -> DensePoly {
  let items : Array[DensePoly] = Array::new()
  for v in vals {
    items.push(dense_coef(fezz(v)))
  }
  dense_poly(items)
}

///|
fn poly_fe(vals : Array[FieldElem]) -> DensePoly {
  let items : Array[DensePoly] = Array::new()
  for v in vals {
    items.push(dense_coef(v))
  }
  dense_poly(items)
}

///|

///|
fn dmp_repr(p : DensePoly) -> String {
  match p {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) => {
      let parts : Array[String] = Array::new()
      for it in items {
        parts.push(dmp_repr(it))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
  }
}

///|
fn dmp_pair_repr(pair : (DensePoly, DensePoly)) -> String {
  let (a, b) = pair
  let left = dmp_repr(a)
  let right = dmp_repr(b)
  "(\{left},\{right})"
}

///|

///|
fn dense_data_list(polys : Array[DensePoly]) -> Array[@sympy_polys.DenseData] {
  let out : Array[@sympy_polys.DenseData] = Array::new()
  for p in polys {
    out.push(dense_data_of(p))
  }
  out
}

///|
test "densearith: dup_add_term parity" {
  let f = [fezz(1), fezz(1), fezz(1)]
  let ours = dup_repr(dup_add_term(f, fezz(1), 0, Domain::ZZ))
  let oracle = @sympy_polys.dup_add_term(dup_to_rats(f), br_int(1), 0)
  guard ours == oracle else { fail("dup_add_term mismatch") }
  let ours2 = dup_repr(dup_add_term(f, fezz(1), 4, Domain::ZZ))
  let oracle2 = @sympy_polys.dup_add_term(dup_to_rats(f), br_int(1), 4)
  guard ours2 == oracle2 else { fail("dup_add_term mismatch 2") }
}

///|
test "densearith: dup_sub_term parity" {
  let f = [fezz(1), fezz(1), fezz(1)]
  let ours = dup_repr(dup_sub_term(f, fezz(2), 1, Domain::ZZ))
  let oracle = @sympy_polys.dup_sub_term(dup_to_rats(f), br_int(2), 1)
  guard ours == oracle else { fail("dup_sub_term mismatch") }
}

///|
test "densearith: dup_mul_term parity" {
  let f = [fezz(1), fezz(2), fezz(3)]
  let ours = dup_repr(dup_mul_term(f, fezz(2), 2, Domain::ZZ))
  let oracle = @sympy_polys.dup_mul_term(dup_to_rats(f), br_int(2), 2)
  guard ours == oracle else { fail("dup_mul_term mismatch") }
}

///|
test "densearith: dup_ground ops parity" {
  let f = [fezz(1), fezz(2), fezz(3), fezz(4)]
  let ours_add = dup_repr(dup_add_ground(f, fezz(4), Domain::ZZ))
  let oracle_add = @sympy_polys.dup_add_ground(dup_to_rats(f), br_int(4))
  guard ours_add == oracle_add else { fail("dup_add_ground mismatch") }
  let ours_sub = dup_repr(dup_sub_ground(f, fezz(4), Domain::ZZ))
  let oracle_sub = @sympy_polys.dup_sub_ground(dup_to_rats(f), br_int(4))
  guard ours_sub == oracle_sub else { fail("dup_sub_ground mismatch") }
  let ours_mul = dup_repr(dup_mul_ground(f, fezz(2), Domain::ZZ))
  let oracle_mul = @sympy_polys.dup_mul_ground(dup_to_rats(f), br_int(2))
  guard ours_mul == oracle_mul else { fail("dup_mul_ground mismatch") }
}

///|
test "densearith: dup_quo/exquo_ground parity" {
  let f = [fezz(6), fezz(2), fezz(8)]
  let ours = dup_repr(dup_quo_ground(f, fezz(3), Domain::ZZ))
  let oracle = @sympy_polys.dup_quo_ground(dup_to_rats(f), br_int(3))
  guard ours == oracle else { fail("dup_quo_ground mismatch") }
  let ours2 = dup_repr(dup_exquo_ground(f, fezz(2), Domain::ZZ))
  let oracle2 = @sympy_polys.dup_exquo_ground(dup_to_rats(f), br_int(2))
  guard ours2 == oracle2 else { fail("dup_exquo_ground mismatch") }
}

///|
test "densearith: dup_shift parity" {
  let f = [fezz(1), fezz(2), fezz(3)]
  let ours_l = dup_repr(dup_lshift(f, 2, Domain::ZZ))
  let oracle_l = @sympy_polys.dup_lshift(dup_to_rats(f), 2)
  guard ours_l == oracle_l else { fail("dup_lshift mismatch") }
  let ours_r = dup_repr(dup_rshift([fezz(1), fezz(0), fezz(1)], 1, Domain::ZZ))
  let oracle_r = @sympy_polys.dup_rshift(
    dup_to_rats([fezz(1), fezz(0), fezz(1)]),
    1,
  )
  guard ours_r == oracle_r else { fail("dup_rshift mismatch") }
}

///|
test "densearith: dup_neg/abs parity" {
  let f = [fezz(1), fezz(-2), fezz(3)]
  let ours_neg = dup_repr(dup_neg(f, Domain::ZZ))
  let oracle_neg = @sympy_polys.dup_neg(dup_to_rats(f))
  guard ours_neg == oracle_neg else { fail("dup_neg mismatch") }
  let ours_abs = dup_repr(dup_abs(f, Domain::ZZ))
  let oracle_abs = @sympy_polys.dup_abs(dup_to_rats(f))
  guard ours_abs == oracle_abs else { fail("dup_abs mismatch") }
}

///|
test "densearith: dup_add/sub/mul/sqr/pow parity" {
  let f = [fezz(1), fezz(2), fezz(3)]
  let g = [fezz(3), fezz(1)]
  let ours_add = dup_repr(dup_add(f, g, Domain::ZZ))
  let oracle_add = @sympy_polys.dup_add(dup_to_rats(f), dup_to_rats(g))
  guard ours_add == oracle_add else { fail("dup_add mismatch") }
  let ours_sub = dup_repr(dup_sub(f, g, Domain::ZZ))
  let oracle_sub = @sympy_polys.dup_sub(dup_to_rats(f), dup_to_rats(g))
  guard ours_sub == oracle_sub else { fail("dup_sub mismatch") }
  let ours_mul = dup_repr(dup_mul(f, g, Domain::ZZ))
  let oracle_mul = @sympy_polys.dup_mul(dup_to_rats(f), dup_to_rats(g))
  guard ours_mul == oracle_mul else { fail("dup_mul mismatch") }
  let ours_sqr = dup_repr(dup_sqr(f, Domain::ZZ))
  let oracle_sqr = @sympy_polys.dup_sqr(dup_to_rats(f))
  guard ours_sqr == oracle_sqr else { fail("dup_sqr mismatch") }
  let ours_pow = dup_repr(dup_pow([fezz(1), fezz(1)], 3, Domain::ZZ))
  let oracle_pow = @sympy_polys.dup_pow(dup_to_rats([fezz(1), fezz(1)]), 3)
  guard ours_pow == oracle_pow else { fail("dup_pow mismatch") }
}

///|
test "densearith: dup_div family parity" {
  let f = [fezz(1), fezz(0), fezz(1)]
  let g = [fezz(1), fezz(-1)]
  let ours_rr = dup_repr_tuple(dup_rr_div(f, g, Domain::ZZ))
  let oracle_rr = @sympy_polys.dup_rr_div(dup_to_rats(f), dup_to_rats(g))
  guard ours_rr == oracle_rr else { fail("dup_rr_div mismatch") }
  let f_ex = [fezz(1), fezz(0), fezz(-1)]
  let g_ex = [fezz(1), fezz(-1)]
  let ours_ex = dup_repr(dup_exquo(f_ex, g_ex, Domain::ZZ))
  let oracle_ex = @sympy_polys.dup_exquo(dup_to_rats(f_ex), dup_to_rats(g_ex))
  guard ours_ex == oracle_ex else { fail("dup_exquo mismatch") }
  let fq = [feqq(1, 1), feqq(0, 1), feqq(1, 1)]
  let gq = [feqq(2, 1), feqq(-4, 1)]
  let ours_ff = dup_repr_tuple(dup_ff_div(fq, gq, Domain::QQ))
  let oracle_ff = @sympy_polys.dup_ff_div(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  guard ours_ff == oracle_ff else { fail("dup_ff_div mismatch") }
  let ours_div = dup_repr_tuple(dup_div(fq, gq, Domain::QQ))
  let oracle_div = @sympy_polys.dup_div(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  guard ours_div == oracle_div else { fail("dup_div mismatch") }
  let ours_rem = dup_repr(dup_rem(fq, gq, Domain::QQ))
  let oracle_rem = @sympy_polys.dup_rem(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  guard ours_rem == oracle_rem else { fail("dup_rem mismatch") }
  let ours_quo = dup_repr(dup_quo(fq, gq, Domain::QQ))
  let oracle_quo = @sympy_polys.dup_quo(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  guard ours_quo == oracle_quo else { fail("dup_quo mismatch") }
}

///|
test "densearith: dup_pexquo parity" {
  let f = [fezz(1), fezz(0), fezz(-1)]
  let g = [fezz(1), fezz(-1)]
  let ours = dup_repr(dup_pexquo(f, g, Domain::ZZ))
  let oracle = @sympy_polys.dup_pexquo(dup_to_rats(f), dup_to_rats(g))
  guard ours == oracle else { fail("dup_pexquo mismatch") }
}

///|
test "densearith: dmp_add_term parity" {
  let f = dense_poly([poly_int([1, 2]), poly_int([3])])
  let c = poly_int([1])
  let ours = dmp_repr(dmp_add_term(f, c, 2, 1, Domain::ZZ))
  let oracle = @sympy_polys.dmp_add_term(
    dense_data_of(f),
    dense_data_of(c),
    2,
    1,
  )
  guard ours == oracle else { fail("dmp_add_term mismatch") }
  let zero_term = dmp_zero(0)
  let ours_zero = dmp_repr(dmp_add_term(f, zero_term, 3, 1, Domain::ZZ))
  let oracle_zero = @sympy_polys.dmp_add_term(
    dense_data_of(f),
    dense_data_of(zero_term),
    3,
    1,
  )
  guard ours_zero == oracle_zero else { fail("dmp_add_term zero mismatch") }
}

///|
test "densearith: dmp_sub_term parity" {
  let f = dense_poly([poly_int([1, 2]), poly_int([3])])
  let c = poly_int([2])
  let ours = dmp_repr(dmp_sub_term(f, c, 1, 1, Domain::ZZ))
  let oracle = @sympy_polys.dmp_sub_term(
    dense_data_of(f),
    dense_data_of(c),
    1,
    1,
  )
  guard ours == oracle else { fail("dmp_sub_term mismatch") }
}

///|
test "densearith: dmp_mul_term parity" {
  let f = dense_poly([poly_int([1, 2]), poly_int([3])])
  let c = poly_int([2])
  let ours = dmp_repr(dmp_mul_term(f, c, 1, 1, Domain::ZZ))
  let oracle = @sympy_polys.dmp_mul_term(
    dense_data_of(f),
    dense_data_of(c),
    1,
    1,
  )
  guard ours == oracle else { fail("dmp_mul_term mismatch") }
}

///|
test "densearith: dmp_ground ops parity" {
  let f = dense_poly([poly_int([1, 0]), poly_int([2])])
  let ours_add = dmp_repr(dmp_add_ground(f, fezz(4), 1, Domain::ZZ))
  let oracle_add = @sympy_polys.dmp_add_ground(dense_data_of(f), br_int(4), 1)
  guard ours_add == oracle_add else { fail("dmp_add_ground mismatch") }
  let ours_sub = dmp_repr(dmp_sub_ground(f, fezz(4), 1, Domain::ZZ))
  let oracle_sub = @sympy_polys.dmp_sub_ground(dense_data_of(f), br_int(4), 1)
  guard ours_sub == oracle_sub else { fail("dmp_sub_ground mismatch") }
  let ours_mul = dmp_repr(dmp_mul_ground(f, fezz(2), 1, Domain::ZZ))
  let oracle_mul = @sympy_polys.dmp_mul_ground(dense_data_of(f), br_int(2), 1)
  guard ours_mul == oracle_mul else { fail("dmp_mul_ground mismatch") }
  let fqq = dense_poly([
    poly_fe([feqq(1, 5), feqq(2, 5)]),
    poly_fe([feqq(3, 5)]),
  ])
  let ours_mul_q = dmp_repr(dmp_mul_ground(fqq, feqq(2, 3), 1, Domain::QQ))
  let oracle_mul_q = @sympy_polys.dmp_mul_ground(
    dense_data_of(fqq),
    br_rat(2, 3),
    1,
    domain="QQ",
  )
  guard ours_mul_q == oracle_mul_q else { fail("dmp_mul_ground QQ mismatch") }
}

///|
test "densearith: dmp_quo/exquo_ground parity" {
  let f = dense_poly([poly_int([6]), poly_int([2]), poly_int([8])])
  let ours = dmp_repr(dmp_quo_ground(f, fezz(2), 1, Domain::ZZ))
  let oracle = @sympy_polys.dmp_quo_ground(dense_data_of(f), br_int(2), 1)
  guard ours == oracle else { fail("dmp_quo_ground mismatch") }
  let ours_ex = dmp_repr(dmp_exquo_ground(f, fezz(2), 1, Domain::ZZ))
  let oracle_ex = @sympy_polys.dmp_exquo_ground(dense_data_of(f), br_int(2), 1)
  guard ours_ex == oracle_ex else { fail("dmp_exquo_ground mismatch") }
}

///|
test "densearith: dmp_neg/abs parity" {
  let f = dmp_ground(fezz(-7), 2)
  let ours_abs = dmp_repr(dmp_abs(f, 2, Domain::ZZ))
  let oracle_abs = @sympy_polys.dmp_abs(dense_data_of(f), 2)
  guard ours_abs == oracle_abs else { fail("dmp_abs mismatch") }
  let f2 = dmp_ground(fezz(3), 2)
  let ours_neg = dmp_repr(dmp_neg(f2, 2, Domain::ZZ))
  let oracle_neg = @sympy_polys.dmp_neg(dense_data_of(f2), 2)
  guard ours_neg == oracle_neg else { fail("dmp_neg mismatch") }
  let fq = dmp_ground(feqq(-7, 9), 2)
  let ours_abs_q = dmp_repr(dmp_abs(fq, 2, Domain::QQ))
  let oracle_abs_q = @sympy_polys.dmp_abs(dense_data_of(fq), 2, domain="QQ")
  guard ours_abs_q == oracle_abs_q else { fail("dmp_abs QQ mismatch") }
}

///|
test "densearith: dmp_add/sub/mul/sqr/pow parity" {
  let f = dense_poly([poly_int([1, 2]), poly_int([3])])
  let g = dense_poly([poly_int([2]), poly_int([1, 1])])
  let ours_add = dmp_repr(dmp_add(f, g, 1, Domain::ZZ))
  let oracle_add = @sympy_polys.dmp_add(dense_data_of(f), dense_data_of(g), 1)
  guard ours_add == oracle_add else { fail("dmp_add mismatch") }
  let ours_sub = dmp_repr(dmp_sub(f, g, 1, Domain::ZZ))
  let oracle_sub = @sympy_polys.dmp_sub(dense_data_of(f), dense_data_of(g), 1)
  guard ours_sub == oracle_sub else { fail("dmp_sub mismatch") }
  let ours_mul = dmp_repr(dmp_mul(f, g, 1, Domain::ZZ))
  let oracle_mul = @sympy_polys.dmp_mul(dense_data_of(f), dense_data_of(g), 1)
  guard ours_mul == oracle_mul else { fail("dmp_mul mismatch") }
  let ours_sqr = dmp_repr(dmp_sqr(f, 1, Domain::ZZ))
  let oracle_sqr = @sympy_polys.dmp_sqr(dense_data_of(f), 1)
  guard ours_sqr == oracle_sqr else { fail("dmp_sqr mismatch") }
  let h = dense_poly([poly_int([1]), poly_int([1])])
  let ours_pow = dmp_repr(dmp_pow(h, 2, 1, Domain::ZZ))
  let oracle_pow = @sympy_polys.dmp_pow(dense_data_of(h), 2, 1)
  guard ours_pow == oracle_pow else { fail("dmp_pow mismatch") }
  let fq = dense_poly([poly_fe([feqq(1, 2)]), poly_fe([feqq(1, 3)])])
  let gq = dense_poly([poly_fe([feqq(2, 5)])])
  let ours_add_q = dmp_repr(dmp_add(fq, gq, 1, Domain::QQ))
  let oracle_add_q = @sympy_polys.dmp_add(
    dense_data_of(fq),
    dense_data_of(gq),
    1,
    domain="QQ",
  )
  guard ours_add_q == oracle_add_q else { fail("dmp_add QQ mismatch") }
  let ours_mul_q = dmp_repr(dmp_mul(fq, gq, 1, Domain::QQ))
  let oracle_mul_q = @sympy_polys.dmp_mul(
    dense_data_of(fq),
    dense_data_of(gq),
    1,
    domain="QQ",
  )
  guard ours_mul_q == oracle_mul_q else { fail("dmp_mul QQ mismatch") }
}

///|
test "densearith: dmp_add_mul/sub_mul parity" {
  let f = dense_poly([poly_int([1, 0]), poly_int([2])])
  let g = dense_poly([poly_int([1])])
  let h = dense_poly([poly_int([2, 1])])
  let ours_add = dmp_repr(dmp_add_mul(f, g, h, 1, Domain::ZZ))
  let oracle_add = @sympy_polys.dmp_add_mul(
    dense_data_of(f),
    dense_data_of(g),
    dense_data_of(h),
    1,
  )
  guard ours_add == oracle_add else { fail("dmp_add_mul mismatch") }
  let ours_sub = dmp_repr(dmp_sub_mul(f, g, h, 1, Domain::ZZ))
  let oracle_sub = @sympy_polys.dmp_sub_mul(
    dense_data_of(f),
    dense_data_of(g),
    dense_data_of(h),
    1,
  )
  guard ours_sub == oracle_sub else { fail("dmp_sub_mul mismatch") }
}

///|
test "densearith: dmp_pdiv/prem/pquo/pexquo parity" {
  let f = dense_poly([poly_int([1, 0]), poly_int([0])])
  let g = dense_poly([poly_int([1]), poly_int([0])])
  let ours_pair = dmp_pair_repr(dmp_pdiv(f, g, 1, Domain::ZZ))
  let oracle_pair = @sympy_polys.dmp_pdiv(dense_data_of(f), dense_data_of(g), 1)
  guard ours_pair == oracle_pair else { fail("dmp_pdiv mismatch") }
  let ours_prem = dmp_repr(dmp_prem(f, g, 1, Domain::ZZ))
  let oracle_prem = @sympy_polys.dmp_prem(dense_data_of(f), dense_data_of(g), 1)
  guard ours_prem == oracle_prem else { fail("dmp_prem mismatch") }
  let ours_pquo = dmp_repr(dmp_pquo(f, g, 1, Domain::ZZ))
  let oracle_pquo = @sympy_polys.dmp_pquo(dense_data_of(f), dense_data_of(g), 1)
  guard ours_pquo == oracle_pquo else { fail("dmp_pquo mismatch") }
  let ours_pex = dmp_repr(dmp_pexquo(f, g, 1, Domain::ZZ))
  let oracle_pex = @sympy_polys.dmp_pexquo(
    dense_data_of(f),
    dense_data_of(g),
    1,
  )
  guard ours_pex == oracle_pex else { fail("dmp_pexquo mismatch") }
}

///|
test "densearith: dmp_rr/ff/div family parity" {
  let f = dense_poly([poly_int([1, 0, 0]), poly_int([0]), poly_int([1])])
  let g = dense_poly([poly_int([1, 0]), poly_int([-1])])
  let ours_rr = dmp_pair_repr(dmp_rr_div(f, g, 1, Domain::ZZ))
  let oracle_rr = @sympy_polys.dmp_rr_div(dense_data_of(f), dense_data_of(g), 1)
  guard ours_rr == oracle_rr else { fail("dmp_rr_div mismatch") }
  let fq = poly_fe([feqq(1, 1), feqq(0, 1), feqq(-1, 1)])
  let gq = poly_fe([feqq(1, 1), feqq(-1, 1)])
  let ours_ff = dmp_pair_repr(dmp_ff_div(fq, gq, 0, Domain::QQ))
  let oracle_ff = @sympy_polys.dmp_ff_div(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  guard ours_ff == oracle_ff else { fail("dmp_ff_div mismatch") }
  let ours_div = dmp_pair_repr(dmp_div(fq, gq, 0, Domain::QQ))
  let oracle_div = @sympy_polys.dmp_div(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  guard ours_div == oracle_div else { fail("dmp_div mismatch") }
  let ours_rem = dmp_repr(dmp_rem(fq, gq, 0, Domain::QQ))
  let oracle_rem = @sympy_polys.dmp_rem(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  guard ours_rem == oracle_rem else { fail("dmp_rem mismatch") }
  let ours_quo = dmp_repr(dmp_quo(fq, gq, 0, Domain::QQ))
  let oracle_quo = @sympy_polys.dmp_quo(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  guard ours_quo == oracle_quo else { fail("dmp_quo mismatch") }
  let ours_ex = dmp_repr(dmp_exquo(fq, gq, 0, Domain::QQ))
  let oracle_ex = @sympy_polys.dmp_exquo(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  guard ours_ex == oracle_ex else { fail("dmp_exquo mismatch") }
}

///|
test "densearith: dmp_ff_div QQ multivariate u=1" {
  let g = dense_poly([poly_fe([feqq(1, 1)]), poly_fe([feqq(1, 1), feqq(0, 1)])])
  let f = dense_poly([
    poly_fe([feqq(1, 1)]),
    poly_fe([feqq(2, 1), feqq(0, 1)]),
    poly_fe([feqq(1, 1), feqq(0, 1), feqq(0, 1)]),
  ])
  let ours = dmp_pair_repr(dmp_ff_div(f, g, 1, Domain::QQ))
  let oracle = @sympy_polys.dmp_ff_div(
    dense_data_of(f),
    dense_data_of(g),
    1,
    domain="QQ",
  )
  guard ours == oracle else { fail("dmp_ff_div QQ u=1 mismatch") }
}

///|
test "densearith: dup/dmp norms parity" {
  let f = [fezz(1), fezz(-4), fezz(2), fezz(3)]
  let max_ours = dup_max_norm(f, Domain::ZZ)
  let max_oracle = @sympy_polys.dup_max_norm(dup_to_rats(f))
  inspect(max_ours, content=max_oracle)
  let l1_ours = dup_l1_norm(f, Domain::ZZ)
  let l1_oracle = @sympy_polys.dup_l1_norm(dup_to_rats(f))
  inspect(l1_ours, content=l1_oracle)
  let l2_ours = dup_l2_norm_squared(f, Domain::ZZ)
  let l2_oracle = @sympy_polys.dup_l2_norm_squared(dup_to_rats(f))
  inspect(l2_ours, content=l2_oracle)
  let f2 = poly([poly([coef(1), coef(-2)]), poly([coef(3), coef(4)])])
  let max2_ours = dmp_max_norm(f2, 1, Domain::ZZ)
  let max2_oracle = @sympy_polys.dmp_max_norm(dense_data_of(f2), 1)
  inspect(max2_ours, content=max2_oracle)
  let l1_ours2 = dmp_l1_norm(f2, 1, Domain::ZZ)
  let l1_oracle2 = @sympy_polys.dmp_l1_norm(dense_data_of(f2), 1)
  inspect(l1_ours2, content=l1_oracle2)
  let l2_ours2 = dmp_l2_norm_squared(f2, 1, Domain::ZZ)
  let l2_oracle2 = @sympy_polys.dmp_l2_norm_squared(dense_data_of(f2), 1)
  inspect(l2_ours2, content=l2_oracle2)
}

///|
test "densearith: dup/dmp expand parity" {
  let polys : Array[Array[FieldElem]] = [
    [fezz(1), fezz(2), fezz(3)],
    [fezz(1), fezz(2)],
    [fezz(7), fezz(5), fezz(4), fezz(3)],
  ]
  let ours = dup_repr(dup_expand(polys, Domain::ZZ))
  let oracle = @sympy_polys.dup_expand(dup_list_to_rats(polys))
  guard ours == oracle else { fail("dup_expand mismatch") }
  let p1 = poly([poly([coef(1)]), poly([coef(2)]), poly([coef(3)])])
  let p2 = poly([poly([coef(1)]), poly([coef(2)])])
  let p3 = poly([
    poly([coef(7)]),
    poly([coef(5)]),
    poly([coef(4)]),
    poly([coef(3)]),
  ])
  let polys2 = [p1, p2, p3]
  let ours2 = dmp_repr(dmp_expand(polys2, 1, Domain::ZZ))
  let oracle2 = @sympy_polys.dmp_expand(dense_data_list(polys2), 1)
  guard ours2 == oracle2 else { fail("dmp_expand mismatch") }
}
