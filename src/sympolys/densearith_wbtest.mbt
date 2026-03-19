///|
fn da_wb_fezz(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
}

///|
fn da_wb_feqq(num : Int, den : Int) -> FieldElem {
  let rat = try! @symnum.BigRational::new(
    BigInt::from_int(num),
    BigInt::from_int(den),
  )
  try! fe_from_rational(rat, Domain::QQ)
}

///|
fn da_wb_dense_repr(p : DensePoly) -> String {
  match p {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) => {
      let parts : Array[String] = Array::new()
      for item in items {
        parts.push(da_wb_dense_repr(item))
      }
      let joined = parts.join(",")
      "[\{joined}]"
    }
  }
}

///|
fn da_wb_dup_repr(coeffs : Array[FieldElem]) -> String {
  let parts : Array[String] = Array::new()
  for c in coeffs {
    parts.push(c.to_string())
  }
  let joined = parts.join(",")
  "[\{joined}]"
}

///|
test "densearith wb: dup guard and error branches" {
  let keep_same = dup_add_term(
    [da_wb_fezz(1), da_wb_fezz(2)],
    da_wb_fezz(0),
    3,
    Domain::ZZ,
  )
  assert_eq(da_wb_dup_repr(keep_same), "[1,2]")

  let mul_empty = dup_mul_ground([], da_wb_fezz(2), Domain::ZZ)
  assert_true(mul_empty.is_empty())
  let mul_zero = dup_mul_ground([da_wb_fezz(3)], da_wb_fezz(0), Domain::ZZ)
  assert_true(mul_zero.is_empty())

  let quo_empty = dup_quo_ground([], da_wb_fezz(1), Domain::ZZ)
  assert_true(quo_empty.is_empty())
  let exquo_empty = dup_exquo_ground([], da_wb_fezz(1), Domain::ZZ)
  assert_true(exquo_empty.is_empty())

  let quo_zero : Result[Array[FieldElem], PolyError] = try? dup_quo_ground(
    [da_wb_fezz(1)],
    da_wb_fezz(0),
    Domain::ZZ,
  )
  assert_true(quo_zero is Err(PolyError::DivisionByZero))
  let exquo_zero : Result[Array[FieldElem], PolyError] = try? dup_exquo_ground(
    [da_wb_fezz(1)],
    da_wb_fezz(0),
    Domain::ZZ,
  )
  assert_true(exquo_zero is Err(PolyError::DivisionByZero))

  let qq_poly = [da_wb_feqq(1, 2), da_wb_feqq(3, 4)]
  let qq_quo = dup_quo_ground(qq_poly, da_wb_feqq(1, 4), Domain::QQ)
  assert_eq(da_wb_dup_repr(qq_quo), "[2,3]")
  let qq_exquo = dup_exquo_ground(qq_poly, da_wb_feqq(1, 2), Domain::QQ)
  assert_eq(da_wb_dup_repr(qq_exquo), "[1,3/2]")

  assert_true(dup_lshift([], 4, Domain::ZZ).is_empty())
  assert_true(dup_rshift([], 4, Domain::ZZ).is_empty())
  assert_true(dup_rshift([da_wb_fezz(1)], 1, Domain::ZZ).is_empty())

  let pow_zero = dup_pow([da_wb_fezz(3), da_wb_fezz(2)], 0, Domain::ZZ)
  assert_eq(da_wb_dup_repr(pow_zero), "[1]")
  let pow_neg : Result[Array[FieldElem], PolyError] = try? dup_pow(
    [da_wb_fezz(1)],
    -1,
    Domain::ZZ,
  )
  assert_true(pow_neg is Err(PolyError::BadExponent))

  let pdiv_zero : Result[(Array[FieldElem], Array[FieldElem]), PolyError] = try? dup_pdiv(
    [da_wb_fezz(1)],
    [],
    Domain::ZZ,
  )
  assert_true(pdiv_zero is Err(PolyError::DivisionByZero))
  let (short_q, short_r) = dup_pdiv(
    [da_wb_fezz(1)],
    [da_wb_fezz(1), da_wb_fezz(0)],
    Domain::ZZ,
  )
  assert_true(short_q.is_empty() && da_wb_dup_repr(short_r) == "[1]")

  let pexquo_fail : Result[Array[FieldElem], PolyError] = try? dup_pexquo(
    [da_wb_fezz(1), da_wb_fezz(0), da_wb_fezz(1)],
    [da_wb_fezz(1), da_wb_fezz(-1)],
    Domain::ZZ,
  )
  assert_true(pexquo_fail is Err(PolyError::ExactQuotientFailed))
}

///|
test "densearith wb: dmp u=0 and zero-shape branches" {
  let f0 = DensePoly::Coef(da_wb_fezz(2))
  let c0 = DensePoly::Coef(da_wb_fezz(3))
  let add0 = dmp_add_term(f0, c0, 0, 0, Domain::ZZ)
  assert_eq(da_wb_dense_repr(add0), "[5]")
  let mul0 = dmp_mul_term(f0, c0, 1, 0, Domain::ZZ)
  assert_eq(da_wb_dense_repr(mul0), "[6,0]")
  let add_ground0 = dmp_add_ground(f0, da_wb_fezz(4), 0, Domain::ZZ)
  assert_eq(da_wb_dense_repr(add_ground0), "[6]")
  let sub_ground0 = dmp_sub_ground(f0, da_wb_fezz(4), 0, Domain::ZZ)
  assert_eq(da_wb_dense_repr(sub_ground0), "[-2]")

  let nested_univar_err : Result[DensePoly, PolyError] = try? dmp_add_term(
    dense_poly([dense_poly([dense_coef(da_wb_fezz(1))])]),
    dense_coef(da_wb_fezz(1)),
    0,
    0,
    Domain::ZZ,
  )
  assert_true(nested_univar_err is Err(PolyError::NotUnivariate))

  let lifted = dmp_add_term(
    DensePoly::Coef(da_wb_fezz(1)),
    dmp_ground(da_wb_fezz(2), 0),
    1,
    1,
    Domain::ZZ,
  )
  assert_true(da_wb_dense_repr(lifted) != "[]")

  let from_empty = dmp_add_term(
    dense_poly([]),
    dmp_ground(da_wb_fezz(7), 0),
    2,
    1,
    Domain::ZZ,
  )
  assert_true(da_wb_dense_repr(from_empty).contains("7"))

  let mul_zero = dmp_mul_ground(
    dmp_ground(da_wb_fezz(3), 1),
    da_wb_fezz(0),
    1,
    Domain::ZZ,
  )
  assert_true(dmp_zero_p(mul_zero, 1))

  let z1 = dmp_zero(1)
  let nz1 = dense_poly([dense_coef(da_wb_fezz(5))])
  assert_eq(da_wb_dense_repr(dmp_add(z1, nz1, 1, Domain::ZZ)), "[5]")
  assert_eq(da_wb_dense_repr(dmp_add(nz1, z1, 1, Domain::ZZ)), "[5]")
  assert_eq(da_wb_dense_repr(dmp_sub(nz1, z1, 1, Domain::ZZ)), "[5]")
  assert_true(da_wb_dense_repr(dmp_sub(z1, nz1, 1, Domain::ZZ)).contains("5"))
  assert_true(dmp_zero_p(dmp_mul(z1, nz1, 1, Domain::ZZ), 1))

  let dmp_pow_neg : Result[DensePoly, PolyError] = try? dmp_pow(
    nz1,
    -2,
    1,
    Domain::ZZ,
  )
  assert_true(dmp_pow_neg is Err(PolyError::BadExponent))

  let _u0_pair = dmp_pdiv(
    DensePoly::Coef(da_wb_fezz(6)),
    DensePoly::Coef(da_wb_fezz(2)),
    0,
    Domain::ZZ,
  )

  let dmp_div_zero : Result[(DensePoly, DensePoly), PolyError] = try? dmp_pdiv(
    nz1,
    dmp_zero(1),
    1,
    Domain::ZZ,
  )
  assert_true(dmp_div_zero is Err(PolyError::DivisionByZero))

  let big = dense_poly([dense_coef(da_wb_fezz(1)), dense_coef(da_wb_fezz(0))])
  let (q_short, r_short) = dmp_pdiv(nz1, big, 1, Domain::ZZ)
  assert_true(dmp_zero_p(q_short, 1) && da_wb_dense_repr(r_short) == "[5]")

  let dmp_pexquo_fail : Result[DensePoly, PolyError] = try? dmp_pexquo(
    nz1,
    big,
    1,
    Domain::ZZ,
  )
  assert_true(dmp_pexquo_fail is Err(PolyError::ExactQuotientFailed))
}

///|
test "densearith wb: internal helper branches" {
  assert_true(domain_is_field(Domain::GF(5)))

  let inv = fe_pow_local(da_wb_feqq(2, 1), -1)
  assert_eq(inv.to_string(), "1/2")
  let cube = fe_pow_local(da_wb_fezz(2), 3)
  assert_eq(cube.to_string(), "8")

  let cc_one = FieldElem::CC(
    @symnum.BigRational::one(),
    @symnum.BigRational::zero(),
  )
  let cc_pow = fe_pow_local(cc_one, 2)
  match cc_pow {
    FieldElem::CC(_, _) => ()
    _ => fail("fe_pow_local should keep CC type")
  }

  let div_zero : Result[(Bool, FieldElem), PolyError] = try? fe_divides(
    da_wb_fezz(1),
    da_wb_fezz(0),
    Domain::ZZ,
  )
  assert_true(div_zero is Err(PolyError::DivisionByZero))

  let (ok_field, q_field) = fe_divides(
    da_wb_feqq(1, 1),
    da_wb_feqq(2, 1),
    Domain::QQ,
  )
  assert_true(ok_field && q_field.to_string() == "1/2")

  let (ok_non_integral, q_non_integral) = fe_divides(
    da_wb_feqq(1, 2),
    da_wb_fezz(1),
    Domain::ZZ,
  )
  assert_true(!ok_non_integral && q_non_integral.to_string() == "0")

  let (ok_not_div, q_not_div) = fe_divides(
    da_wb_fezz(3),
    da_wb_fezz(2),
    Domain::ZZ,
  )
  assert_true(!ok_not_div && q_not_div.to_string() == "0")

  let a = @symcore.symbol("a")
  let default_domain = Domain::AlgExt(Domain::ZZ, ["a"], [
    (a ^ @symcore.int(2)) + @symcore.int(1),
  ])
  let default_div : Result[(Bool, FieldElem), PolyError] = try? fe_divides(
    da_wb_feqq(1, 1),
    da_wb_feqq(2, 1),
    default_domain,
  )
  assert_true(default_div is Err(PolyError::DomainNotField))
}
