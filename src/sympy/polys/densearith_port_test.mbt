///|
fn fezz(n : Int) -> FieldElem raise PolyError {
  @sympolys.fe_from_int(n, Domain::ZZ)
}

///|
fn feqq(num : Int, den : Int) -> FieldElem raise PolyError {
  @sympolys.fe_from_rational(
    @symnum.BigRational::from_int(num).div_r(@symnum.BigRational::from_int(den)),
    Domain::QQ,
  )
}

///|
fn dup_repr_tuple(pair : (Array[FieldElem], Array[FieldElem])) -> String {
  let (a, b) = pair
  let left = dup_repr(a)
  let right = dup_repr(b)
  "(\{left},\{right})"
}

///|
fn dup_to_rats(coeffs : Array[FieldElem]) -> Array[@symnum.BigRational] raise PolyError {
  let out : Array[@symnum.BigRational] = Array::new()
  for c in coeffs {
    out.push(@sympolys.fe_expect_rational(c))
  }
  out
}

///|
fn dup_list_to_rats(
  polys : Array[Array[FieldElem]],
) -> Array[Array[@symnum.BigRational]] raise PolyError {
  let out : Array[Array[@symnum.BigRational]] = Array::new()
  for f in polys {
    out.push(dup_to_rats(f))
  }
  out
}

///|

///|
fn poly_int(vals : Array[Int]) -> DensePoly raise PolyError {
  let items : Array[DensePoly] = Array::new()
  for v in vals {
    items.push(@sympolys.dense_coef(fezz(v)))
  }
  @sympolys.dense_poly(items)
}

///|
fn poly_fe(vals : Array[FieldElem]) -> DensePoly {
  let items : Array[DensePoly] = Array::new()
  for v in vals {
    items.push(@sympolys.dense_coef(v))
  }
  @sympolys.dense_poly(items)
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
fn dense_data_list(polys : Array[DensePoly]) -> Array[DenseData] raise PolyError {
  let out : Array[DenseData] = Array::new()
  for p in polys {
    out.push(dense_data_of(p))
  }
  out
}

///|
test "densearith: dup_add_term parity" {
  let f = [fezz(1), fezz(1), fezz(1)]
  let ours = dup_repr(@sympolys.dup_add_term(f, fezz(1), 0, Domain::ZZ))
  let oracle = dup_add_term(dup_to_rats(f), br_int(1), 0)
  assert_eq(ours, oracle)
  let ours2 = dup_repr(@sympolys.dup_add_term(f, fezz(1), 4, Domain::ZZ))
  let oracle2 = dup_add_term(dup_to_rats(f), br_int(1), 4)
  assert_eq(ours2, oracle2)
}

///|
test "densearith: dup_sub_term parity" {
  let f = [fezz(1), fezz(1), fezz(1)]
  let ours = dup_repr(@sympolys.dup_sub_term(f, fezz(2), 1, Domain::ZZ))
  let oracle = dup_sub_term(dup_to_rats(f), br_int(2), 1)
  assert_eq(ours, oracle)
}

///|
test "densearith: dup_mul_term parity" {
  let f = [fezz(1), fezz(2), fezz(3)]
  let ours = dup_repr(@sympolys.dup_mul_term(f, fezz(2), 2, Domain::ZZ))
  let oracle = dup_mul_term(dup_to_rats(f), br_int(2), 2)
  assert_eq(ours, oracle)
}

///|
test "densearith: dup_ground ops parity" {
  let f = [fezz(1), fezz(2), fezz(3), fezz(4)]
  let ours_add = dup_repr(@sympolys.dup_add_ground(f, fezz(4), Domain::ZZ))
  let oracle_add = dup_add_ground(dup_to_rats(f), br_int(4))
  assert_eq(ours_add, oracle_add)
  let ours_sub = dup_repr(@sympolys.dup_sub_ground(f, fezz(4), Domain::ZZ))
  let oracle_sub = dup_sub_ground(dup_to_rats(f), br_int(4))
  assert_eq(ours_sub, oracle_sub)
  let ours_mul = dup_repr(@sympolys.dup_mul_ground(f, fezz(2), Domain::ZZ))
  let oracle_mul = dup_mul_ground(dup_to_rats(f), br_int(2))
  assert_eq(ours_mul, oracle_mul)
}

///|
test "densearith: dup_quo/exquo_ground parity" {
  let f = [fezz(6), fezz(2), fezz(8)]
  let ours = dup_repr(@sympolys.dup_quo_ground(f, fezz(3), Domain::ZZ))
  let oracle = dup_quo_ground(dup_to_rats(f), br_int(3))
  assert_eq(ours, oracle)
  let ours2 = dup_repr(@sympolys.dup_exquo_ground(f, fezz(2), Domain::ZZ))
  let oracle2 = dup_exquo_ground(dup_to_rats(f), br_int(2))
  assert_eq(ours2, oracle2)
}

///|
test "densearith: dup_shift parity" {
  let f = [fezz(1), fezz(2), fezz(3)]
  let ours_l = dup_repr(@sympolys.dup_lshift(f, 2, Domain::ZZ))
  let oracle_l = dup_lshift(dup_to_rats(f), 2)
  assert_eq(ours_l, oracle_l)
  let ours_r = dup_repr(@sympolys.dup_rshift([fezz(1), fezz(0), fezz(1)], 1, Domain::ZZ))
  let oracle_r = dup_rshift(
    dup_to_rats([fezz(1), fezz(0), fezz(1)]),
    1,
  )
  assert_eq(ours_r, oracle_r)
}

///|
test "densearith: dup_neg/abs parity" {
  let f = [fezz(1), fezz(-2), fezz(3)]
  let ours_neg = dup_repr(@sympolys.dup_neg(f, Domain::ZZ))
  let oracle_neg = dup_neg(dup_to_rats(f))
  assert_eq(ours_neg, oracle_neg)
  let ours_abs = dup_repr(@sympolys.dup_abs(f, Domain::ZZ))
  let oracle_abs = dup_abs(dup_to_rats(f))
  assert_eq(ours_abs, oracle_abs)
}

///|
test "densearith: dup_add/sub/mul/sqr/pow parity" {
  let f = [fezz(1), fezz(2), fezz(3)]
  let g = [fezz(3), fezz(1)]
  let ours_add = dup_repr(@sympolys.dup_add(f, g, Domain::ZZ))
  let oracle_add = dup_add(dup_to_rats(f), dup_to_rats(g))
  assert_eq(ours_add, oracle_add)
  let ours_sub = dup_repr(@sympolys.dup_sub(f, g, Domain::ZZ))
  let oracle_sub = dup_sub(dup_to_rats(f), dup_to_rats(g))
  assert_eq(ours_sub, oracle_sub)
  let ours_mul = dup_repr(@sympolys.dup_mul(f, g, Domain::ZZ))
  let oracle_mul = dup_mul(dup_to_rats(f), dup_to_rats(g))
  assert_eq(ours_mul, oracle_mul)
  let ours_sqr = dup_repr(@sympolys.dup_sqr(f, Domain::ZZ))
  let oracle_sqr = dup_sqr(dup_to_rats(f))
  assert_eq(ours_sqr, oracle_sqr)
  let ours_pow = dup_repr(@sympolys.dup_pow([fezz(1), fezz(1)], 3, Domain::ZZ))
  let oracle_pow = dup_pow(dup_to_rats([fezz(1), fezz(1)]), 3)
  assert_eq(ours_pow, oracle_pow)
}

///|
test "densearith: dup_div family parity" {
  let f = [fezz(1), fezz(0), fezz(1)]
  let g = [fezz(1), fezz(-1)]
  let ours_rr = dup_repr_tuple(@sympolys.dup_rr_div(f, g, Domain::ZZ))
  let oracle_rr = dup_rr_div(dup_to_rats(f), dup_to_rats(g))
  assert_eq(ours_rr, oracle_rr)
  let f_ex = [fezz(1), fezz(0), fezz(-1)]
  let g_ex = [fezz(1), fezz(-1)]
  let ours_ex = dup_repr(@sympolys.dup_exquo(f_ex, g_ex, Domain::ZZ))
  let oracle_ex = dup_exquo(dup_to_rats(f_ex), dup_to_rats(g_ex))
  assert_eq(ours_ex, oracle_ex)
  let fq = [feqq(1, 1), feqq(0, 1), feqq(1, 1)]
  let gq = [feqq(2, 1), feqq(-4, 1)]
  let ours_ff = dup_repr_tuple(@sympolys.dup_ff_div(fq, gq, Domain::QQ))
  let oracle_ff = dup_ff_div(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  assert_eq(ours_ff, oracle_ff)
  let ours_div = dup_repr_tuple(@sympolys.dup_div(fq, gq, Domain::QQ))
  let oracle_div = dup_div(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  assert_eq(ours_div, oracle_div)
  let ours_rem = dup_repr(@sympolys.dup_rem(fq, gq, Domain::QQ))
  let oracle_rem = dup_rem(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  assert_eq(ours_rem, oracle_rem)
  let ours_quo = dup_repr(@sympolys.dup_quo(fq, gq, Domain::QQ))
  let oracle_quo = dup_quo(
    dup_to_rats(fq),
    dup_to_rats(gq),
    domain="QQ",
  )
  assert_eq(ours_quo, oracle_quo)
}

///|
test "densearith: dup_pexquo parity" {
  let f = [fezz(1), fezz(0), fezz(-1)]
  let g = [fezz(1), fezz(-1)]
  let ours = dup_repr(@sympolys.dup_pexquo(f, g, Domain::ZZ))
  let oracle = dup_pexquo(dup_to_rats(f), dup_to_rats(g))
  assert_eq(ours, oracle)
}

///|
test "densearith: dmp_add_term parity" {
  let f = @sympolys.dense_poly([poly_int([1, 2]), poly_int([3])])
  let c = poly_int([1])
  let ours = dmp_repr(@sympolys.dmp_add_term(f, c, 2, 1, Domain::ZZ))
  let oracle = dmp_add_term(
    dense_data_of(f),
    dense_data_of(c),
    2,
    1,
  )
  assert_eq(ours, oracle)
  let zero_term = @sympolys.dmp_zero(0)
  let ours_zero = dmp_repr(@sympolys.dmp_add_term(f, zero_term, 3, 1, Domain::ZZ))
  let oracle_zero = dmp_add_term(
    dense_data_of(f),
    dense_data_of(zero_term),
    3,
    1,
  )
  assert_eq(ours_zero, oracle_zero)
}

///|
test "densearith: dmp_sub_term parity" {
  let f = @sympolys.dense_poly([poly_int([1, 2]), poly_int([3])])
  let c = poly_int([2])
  let ours = dmp_repr(@sympolys.dmp_sub_term(f, c, 1, 1, Domain::ZZ))
  let oracle = dmp_sub_term(
    dense_data_of(f),
    dense_data_of(c),
    1,
    1,
  )
  assert_eq(ours, oracle)
}

///|
test "densearith: dmp_mul_term parity" {
  let f = @sympolys.dense_poly([poly_int([1, 2]), poly_int([3])])
  let c = poly_int([2])
  let ours = dmp_repr(@sympolys.dmp_mul_term(f, c, 1, 1, Domain::ZZ))
  let oracle = dmp_mul_term(
    dense_data_of(f),
    dense_data_of(c),
    1,
    1,
  )
  assert_eq(ours, oracle)
}

///|
test "densearith: dmp_ground ops parity" {
  let f = @sympolys.dense_poly([poly_int([1, 0]), poly_int([2])])
  let ours_add = dmp_repr(@sympolys.dmp_add_ground(f, fezz(4), 1, Domain::ZZ))
  let oracle_add = dmp_add_ground(dense_data_of(f), br_int(4), 1)
  assert_eq(ours_add, oracle_add)
  let ours_sub = dmp_repr(@sympolys.dmp_sub_ground(f, fezz(4), 1, Domain::ZZ))
  let oracle_sub = dmp_sub_ground(dense_data_of(f), br_int(4), 1)
  assert_eq(ours_sub, oracle_sub)
  let ours_mul = dmp_repr(@sympolys.dmp_mul_ground(f, fezz(2), 1, Domain::ZZ))
  let oracle_mul = dmp_mul_ground(dense_data_of(f), br_int(2), 1)
  assert_eq(ours_mul, oracle_mul)
  let fqq = @sympolys.dense_poly([
    poly_fe([feqq(1, 5), feqq(2, 5)]),
    poly_fe([feqq(3, 5)]),
  ])
  let ours_mul_q = dmp_repr(@sympolys.dmp_mul_ground(fqq, feqq(2, 3), 1, Domain::QQ))
  let oracle_mul_q = dmp_mul_ground(
    dense_data_of(fqq),
    br_rat(2, 3),
    1,
    domain="QQ",
  )
  assert_eq(ours_mul_q, oracle_mul_q)
}

///|
test "densearith: dmp_quo/exquo_ground parity" {
  let f = @sympolys.dense_poly([poly_int([6]), poly_int([2]), poly_int([8])])
  let ours = dmp_repr(@sympolys.dmp_quo_ground(f, fezz(2), 1, Domain::ZZ))
  let oracle = dmp_quo_ground(dense_data_of(f), br_int(2), 1)
  assert_eq(ours, oracle)
  let ours_ex = dmp_repr(@sympolys.dmp_exquo_ground(f, fezz(2), 1, Domain::ZZ))
  let oracle_ex = dmp_exquo_ground(dense_data_of(f), br_int(2), 1)
  assert_eq(ours_ex, oracle_ex)
}

///|
test "densearith: dmp_neg/abs parity" {
  let f = @sympolys.dmp_ground(fezz(-7), 2)
  let ours_abs = dmp_repr(@sympolys.dmp_abs(f, 2, Domain::ZZ))
  let oracle_abs = dmp_abs(dense_data_of(f), 2)
  assert_eq(ours_abs, oracle_abs)
  let f2 = @sympolys.dmp_ground(fezz(3), 2)
  let ours_neg = dmp_repr(@sympolys.dmp_neg(f2, 2, Domain::ZZ))
  let oracle_neg = dmp_neg(dense_data_of(f2), 2)
  assert_eq(ours_neg, oracle_neg)
  let fq = @sympolys.dmp_ground(feqq(-7, 9), 2)
  let ours_abs_q = dmp_repr(@sympolys.dmp_abs(fq, 2, Domain::QQ))
  let oracle_abs_q = dmp_abs(dense_data_of(fq), 2, domain="QQ")
  assert_eq(ours_abs_q, oracle_abs_q)
}

///|
test "densearith: dmp_add/sub/mul/sqr/pow parity" {
  let f = @sympolys.dense_poly([poly_int([1, 2]), poly_int([3])])
  let g = @sympolys.dense_poly([poly_int([2]), poly_int([1, 1])])
  let ours_add = dmp_repr(@sympolys.dmp_add(f, g, 1, Domain::ZZ))
  let oracle_add = dmp_add(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_add, oracle_add)
  let ours_sub = dmp_repr(@sympolys.dmp_sub(f, g, 1, Domain::ZZ))
  let oracle_sub = dmp_sub(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_sub, oracle_sub)
  let ours_mul = dmp_repr(@sympolys.dmp_mul(f, g, 1, Domain::ZZ))
  let oracle_mul = dmp_mul(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_mul, oracle_mul)
  let ours_sqr = dmp_repr(@sympolys.dmp_sqr(f, 1, Domain::ZZ))
  let oracle_sqr = dmp_sqr(dense_data_of(f), 1)
  assert_eq(ours_sqr, oracle_sqr)
  let h = @sympolys.dense_poly([poly_int([1]), poly_int([1])])
  let ours_pow = dmp_repr(@sympolys.dmp_pow(h, 2, 1, Domain::ZZ))
  let oracle_pow = dmp_pow(dense_data_of(h), 2, 1)
  assert_eq(ours_pow, oracle_pow)
  let fq = @sympolys.dense_poly([poly_fe([feqq(1, 2)]), poly_fe([feqq(1, 3)])])
  let gq = @sympolys.dense_poly([poly_fe([feqq(2, 5)])])
  let ours_add_q = dmp_repr(@sympolys.dmp_add(fq, gq, 1, Domain::QQ))
  let oracle_add_q = dmp_add(
    dense_data_of(fq),
    dense_data_of(gq),
    1,
    domain="QQ",
  )
  assert_eq(ours_add_q, oracle_add_q)
  let ours_mul_q = dmp_repr(@sympolys.dmp_mul(fq, gq, 1, Domain::QQ))
  let oracle_mul_q = dmp_mul(
    dense_data_of(fq),
    dense_data_of(gq),
    1,
    domain="QQ",
  )
  assert_eq(ours_mul_q, oracle_mul_q)
}

///|
test "densearith: dmp_add_mul/sub_mul parity" {
  let f = @sympolys.dense_poly([poly_int([1, 0]), poly_int([2])])
  let g = @sympolys.dense_poly([poly_int([1])])
  let h = @sympolys.dense_poly([poly_int([2, 1])])
  let ours_add = dmp_repr(@sympolys.dmp_add_mul(f, g, h, 1, Domain::ZZ))
  let oracle_add = dmp_add_mul(
    dense_data_of(f),
    dense_data_of(g),
    dense_data_of(h),
    1,
  )
  assert_eq(ours_add, oracle_add)
  let ours_sub = dmp_repr(@sympolys.dmp_sub_mul(f, g, h, 1, Domain::ZZ))
  let oracle_sub = dmp_sub_mul(
    dense_data_of(f),
    dense_data_of(g),
    dense_data_of(h),
    1,
  )
  assert_eq(ours_sub, oracle_sub)
}

///|
test "densearith: dmp_pdiv/prem/pquo/pexquo parity" {
  let f = @sympolys.dense_poly([poly_int([1, 0]), poly_int([0])])
  let g = @sympolys.dense_poly([poly_int([1]), poly_int([0])])
  let ours_pair = dmp_pair_repr(@sympolys.dmp_pdiv(f, g, 1, Domain::ZZ))
  let oracle_pair = dmp_pdiv(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_pair, oracle_pair)
  let ours_prem = dmp_repr(@sympolys.dmp_prem(f, g, 1, Domain::ZZ))
  let oracle_prem = dmp_prem(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_prem, oracle_prem)
  let ours_pquo = dmp_repr(@sympolys.dmp_pquo(f, g, 1, Domain::ZZ))
  let oracle_pquo = dmp_pquo(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_pquo, oracle_pquo)
  let ours_pex = dmp_repr(@sympolys.dmp_pexquo(f, g, 1, Domain::ZZ))
  let oracle_pex = dmp_pexquo(
    dense_data_of(f),
    dense_data_of(g),
    1,
  )
  assert_eq(ours_pex, oracle_pex)
}

///|
test "densearith: dmp_rr/ff/div family parity" {
  let f = @sympolys.dense_poly([poly_int([1, 0, 0]), poly_int([0]), poly_int([1])])
  let g = @sympolys.dense_poly([poly_int([1, 0]), poly_int([-1])])
  let ours_rr = dmp_pair_repr(@sympolys.dmp_rr_div(f, g, 1, Domain::ZZ))
  let oracle_rr = dmp_rr_div(dense_data_of(f), dense_data_of(g), 1)
  assert_eq(ours_rr, oracle_rr)
  let fq = poly_fe([feqq(1, 1), feqq(0, 1), feqq(-1, 1)])
  let gq = poly_fe([feqq(1, 1), feqq(-1, 1)])
  let ours_ff = dmp_pair_repr(@sympolys.dmp_ff_div(fq, gq, 0, Domain::QQ))
  let oracle_ff = dmp_ff_div(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  assert_eq(ours_ff, oracle_ff)
  let ours_div = dmp_pair_repr(@sympolys.dmp_div(fq, gq, 0, Domain::QQ))
  let oracle_div = dmp_div(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  assert_eq(ours_div, oracle_div)
  let ours_rem = dmp_repr(@sympolys.dmp_rem(fq, gq, 0, Domain::QQ))
  let oracle_rem = dmp_rem(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  assert_eq(ours_rem, oracle_rem)
  let ours_quo = dmp_repr(@sympolys.dmp_quo(fq, gq, 0, Domain::QQ))
  let oracle_quo = dmp_quo(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  assert_eq(ours_quo, oracle_quo)
  let ours_ex = dmp_repr(@sympolys.dmp_exquo(fq, gq, 0, Domain::QQ))
  let oracle_ex = dmp_exquo(
    dense_data_of(fq),
    dense_data_of(gq),
    0,
    domain="QQ",
  )
  assert_eq(ours_ex, oracle_ex)
}

///|
test "densearith: dmp_ff_div QQ multivariate u=1" {
  let g = @sympolys.dense_poly([poly_fe([feqq(1, 1)]), poly_fe([feqq(1, 1), feqq(0, 1)])])
  let f = @sympolys.dense_poly([
    poly_fe([feqq(1, 1)]),
    poly_fe([feqq(2, 1), feqq(0, 1)]),
    poly_fe([feqq(1, 1), feqq(0, 1), feqq(0, 1)]),
  ])
  let ours = dmp_pair_repr(@sympolys.dmp_ff_div(f, g, 1, Domain::QQ))
  let oracle = dmp_ff_div(
    dense_data_of(f),
    dense_data_of(g),
    1,
    domain="QQ",
  )
  assert_eq(ours, oracle)
}

///|
test "densearith: dup/dmp norms parity" {
  let f = [fezz(1), fezz(-4), fezz(2), fezz(3)]
  let max_ours = @sympolys.dup_max_norm(f, Domain::ZZ)
  let max_oracle = dup_max_norm(dup_to_rats(f))
  inspect(max_ours, content=max_oracle)
  let l1_ours = @sympolys.dup_l1_norm(f, Domain::ZZ)
  let l1_oracle = dup_l1_norm(dup_to_rats(f))
  inspect(l1_ours, content=l1_oracle)
  let l2_ours = @sympolys.dup_l2_norm_squared(f, Domain::ZZ)
  let l2_oracle = dup_l2_norm_squared(dup_to_rats(f))
  inspect(l2_ours, content=l2_oracle)
  let f2 = poly([poly([coef(1), coef(-2)]), poly([coef(3), coef(4)])])
  let max2_ours = @sympolys.dmp_max_norm(f2, 1, Domain::ZZ)
  let max2_oracle = dmp_max_norm(dense_data_of(f2), 1)
  inspect(max2_ours, content=max2_oracle)
  let l1_ours2 = @sympolys.dmp_l1_norm(f2, 1, Domain::ZZ)
  let l1_oracle2 = dmp_l1_norm(dense_data_of(f2), 1)
  inspect(l1_ours2, content=l1_oracle2)
  let l2_ours2 = @sympolys.dmp_l2_norm_squared(f2, 1, Domain::ZZ)
  let l2_oracle2 = dmp_l2_norm_squared(dense_data_of(f2), 1)
  inspect(l2_ours2, content=l2_oracle2)
}

///|
test "densearith: dup/dmp expand parity" {
  let polys : Array[Array[FieldElem]] = [
    [fezz(1), fezz(2), fezz(3)],
    [fezz(1), fezz(2)],
    [fezz(7), fezz(5), fezz(4), fezz(3)],
  ]
  let ours = dup_repr(@sympolys.dup_expand(polys, Domain::ZZ))
  let oracle = dup_expand(dup_list_to_rats(polys))
  assert_eq(ours, oracle)
  let p1 = poly([poly([coef(1)]), poly([coef(2)]), poly([coef(3)])])
  let p2 = poly([poly([coef(1)]), poly([coef(2)])])
  let p3 = poly([
    poly([coef(7)]),
    poly([coef(5)]),
    poly([coef(4)]),
    poly([coef(3)]),
  ])
  let polys2 = [p1, p2, p3]
  let ours2 = dmp_repr(@sympolys.dmp_expand(polys2, 1, Domain::ZZ))
  let oracle2 = dmp_expand(dense_data_list(polys2), 1)
  assert_eq(ours2, oracle2)
}
