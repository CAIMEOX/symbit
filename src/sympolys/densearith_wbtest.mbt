///|
fn da_wb_fezz(n : Int) -> FieldElem {
  try! fe_from_int(n, Domain::ZZ)
}

///|
fn da_wb_feqq(num : Int, den : Int) -> FieldElem {
  let rat = try! @symnum.BigRational::new(BigInt::from_int(num), BigInt::from_int(den))
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
  let keep_same = try! dup_add_term([da_wb_fezz(1), da_wb_fezz(2)], da_wb_fezz(0), 3, Domain::ZZ)
  guard da_wb_dup_repr(keep_same) == "[1,2]" else {
    fail("dup_add_term zero-coeff branch mismatch")
  }

  let mul_empty = try! dup_mul_ground([], da_wb_fezz(2), Domain::ZZ)
  guard mul_empty.is_empty() else { fail("dup_mul_ground([]) should stay empty") }
  let mul_zero = try! dup_mul_ground([da_wb_fezz(3)], da_wb_fezz(0), Domain::ZZ)
  guard mul_zero.is_empty() else {
    fail("dup_mul_ground(..., 0) should return zero polynomial")
  }

  let quo_empty = try! dup_quo_ground([], da_wb_fezz(1), Domain::ZZ)
  guard quo_empty.is_empty() else { fail("dup_quo_ground([]) should stay empty") }
  let exquo_empty = try! dup_exquo_ground([], da_wb_fezz(1), Domain::ZZ)
  guard exquo_empty.is_empty() else { fail("dup_exquo_ground([]) should stay empty") }

  let quo_zero : Result[Array[FieldElem], PolyError] = try? dup_quo_ground(
    [da_wb_fezz(1)],
    da_wb_fezz(0),
    Domain::ZZ,
  )
  guard quo_zero is Err(PolyError::DivisionByZero) else {
    fail("dup_quo_ground by zero should raise DivisionByZero")
  }
  let exquo_zero : Result[Array[FieldElem], PolyError] = try? dup_exquo_ground(
    [da_wb_fezz(1)],
    da_wb_fezz(0),
    Domain::ZZ,
  )
  guard exquo_zero is Err(PolyError::DivisionByZero) else {
    fail("dup_exquo_ground by zero should raise DivisionByZero")
  }

  let qq_poly = [da_wb_feqq(1, 2), da_wb_feqq(3, 4)]
  let qq_quo = try! dup_quo_ground(qq_poly, da_wb_feqq(1, 4), Domain::QQ)
  guard da_wb_dup_repr(qq_quo) == "[2,3]" else {
    fail("dup_quo_ground QQ branch mismatch")
  }
  let qq_exquo = try! dup_exquo_ground(qq_poly, da_wb_feqq(1, 2), Domain::QQ)
  guard da_wb_dup_repr(qq_exquo) == "[1,3/2]" else {
    fail("dup_exquo_ground QQ branch mismatch")
  }

  guard (try! dup_lshift([], 4, Domain::ZZ)).is_empty() else {
    fail("dup_lshift([]) should stay empty")
  }
  guard (try! dup_rshift([], 4, Domain::ZZ)).is_empty() else {
    fail("dup_rshift([]) should stay empty")
  }
  guard (try! dup_rshift([da_wb_fezz(1)], 1, Domain::ZZ)).is_empty() else {
    fail("dup_rshift with n>=len should be empty")
  }

  let pow_zero = try! dup_pow([da_wb_fezz(3), da_wb_fezz(2)], 0, Domain::ZZ)
  guard da_wb_dup_repr(pow_zero) == "[1]" else { fail("dup_pow(..., 0) should be 1") }
  let pow_neg : Result[Array[FieldElem], PolyError] = try? dup_pow(
    [da_wb_fezz(1)],
    -1,
    Domain::ZZ,
  )
  guard pow_neg is Err(PolyError::BadExponent) else {
    fail("dup_pow negative exponent should raise BadExponent")
  }

  let pdiv_zero : Result[(Array[FieldElem], Array[FieldElem]), PolyError] = try? dup_pdiv(
    [da_wb_fezz(1)],
    [],
    Domain::ZZ,
  )
  guard pdiv_zero is Err(PolyError::DivisionByZero) else {
    fail("dup_pdiv by zero polynomial should raise DivisionByZero")
  }
  let (short_q, short_r) = try! dup_pdiv([da_wb_fezz(1)], [da_wb_fezz(1), da_wb_fezz(0)], Domain::ZZ)
  guard short_q.is_empty() && da_wb_dup_repr(short_r) == "[1]" else {
    fail("dup_pdiv short dividend branch mismatch")
  }

  let pexquo_fail : Result[Array[FieldElem], PolyError] = try? dup_pexquo(
    [da_wb_fezz(1), da_wb_fezz(0), da_wb_fezz(1)],
    [da_wb_fezz(1), da_wb_fezz(-1)],
    Domain::ZZ,
  )
  guard pexquo_fail is Err(PolyError::ExactQuotientFailed) else {
    fail("dup_pexquo should fail for non-exact pseudo-quotient")
  }
}

///|
test "densearith wb: dmp u=0 and zero-shape branches" {
  let f0 = DensePoly::Coef(da_wb_fezz(2))
  let c0 = DensePoly::Coef(da_wb_fezz(3))
  let add0 = try! dmp_add_term(f0, c0, 0, 0, Domain::ZZ)
  guard da_wb_dense_repr(add0) == "[5]" else {
    fail("dmp_add_term u=0 branch mismatch")
  }
  let mul0 = try! dmp_mul_term(f0, c0, 1, 0, Domain::ZZ)
  guard da_wb_dense_repr(mul0) == "[6,0]" else {
    fail("dmp_mul_term u=0 branch mismatch")
  }
  let add_ground0 = try! dmp_add_ground(f0, da_wb_fezz(4), 0, Domain::ZZ)
  guard da_wb_dense_repr(add_ground0) == "[6]" else {
    fail("dmp_add_ground u=0 branch mismatch")
  }
  let sub_ground0 = try! dmp_sub_ground(f0, da_wb_fezz(4), 0, Domain::ZZ)
  guard da_wb_dense_repr(sub_ground0) == "[-2]" else {
    fail("dmp_sub_ground u=0 branch mismatch")
  }

  let nested_univar_err : Result[DensePoly, PolyError] = try? dmp_add_term(
    dense_poly([dense_poly([dense_coef(da_wb_fezz(1))])]),
    dense_coef(da_wb_fezz(1)),
    0,
    0,
    Domain::ZZ,
  )
  guard nested_univar_err is Err(PolyError::NotUnivariate) else {
    fail("dmp_to_coeffs should reject nested poly for u=0")
  }

  let lifted = try! dmp_add_term(DensePoly::Coef(da_wb_fezz(1)), dmp_ground(da_wb_fezz(2), 0), 1, 1, Domain::ZZ)
  guard da_wb_dense_repr(lifted) != "[]" else {
    fail("dmp_items(Coef) branch mismatch")
  }

  let from_empty = try! dmp_add_term(dense_poly([]), dmp_ground(da_wb_fezz(7), 0), 2, 1, Domain::ZZ)
  guard da_wb_dense_repr(from_empty).contains("7") else {
    fail("dmp_add_term deg<0 branch mismatch")
  }

  let mul_zero = try! dmp_mul_ground(dmp_ground(da_wb_fezz(3), 1), da_wb_fezz(0), 1, Domain::ZZ)
  guard dmp_zero_p(mul_zero, 1) else {
    fail("dmp_mul_ground zero-scalar branch mismatch")
  }

  let z1 = dmp_zero(1)
  let nz1 = dense_poly([dense_coef(da_wb_fezz(5))])
  guard da_wb_dense_repr(try! dmp_add(z1, nz1, 1, Domain::ZZ)) == "[5]" else {
    fail("dmp_add left-zero branch mismatch")
  }
  guard da_wb_dense_repr(try! dmp_add(nz1, z1, 1, Domain::ZZ)) == "[5]" else {
    fail("dmp_add right-zero branch mismatch")
  }
  guard da_wb_dense_repr(try! dmp_sub(nz1, z1, 1, Domain::ZZ)) == "[5]" else {
    fail("dmp_sub right-zero branch mismatch")
  }
  guard da_wb_dense_repr(try! dmp_sub(z1, nz1, 1, Domain::ZZ)).contains("5") else {
    fail("dmp_sub left-zero branch mismatch")
  }
  guard dmp_zero_p(try! dmp_mul(z1, nz1, 1, Domain::ZZ), 1) else {
    fail("dmp_mul zero branch mismatch")
  }

  let dmp_pow_neg : Result[DensePoly, PolyError] = try? dmp_pow(nz1, -2, 1, Domain::ZZ)
  guard dmp_pow_neg is Err(PolyError::BadExponent) else {
    fail("dmp_pow negative exponent should raise BadExponent")
  }

  let _u0_pair = try! dmp_pdiv(
    DensePoly::Coef(da_wb_fezz(6)),
    DensePoly::Coef(da_wb_fezz(2)),
    0,
    Domain::ZZ,
  )

  let dmp_div_zero : Result[(DensePoly, DensePoly), PolyError] = try? dmp_pdiv(nz1, dmp_zero(1), 1, Domain::ZZ)
  guard dmp_div_zero is Err(PolyError::DivisionByZero) else {
    fail("dmp_pdiv by zero polynomial should raise DivisionByZero")
  }

  let big = dense_poly([dense_coef(da_wb_fezz(1)), dense_coef(da_wb_fezz(0))])
  let (q_short, r_short) = try! dmp_pdiv(nz1, big, 1, Domain::ZZ)
  guard dmp_zero_p(q_short, 1) && da_wb_dense_repr(r_short) == "[5]" else {
    fail("dmp_pdiv short dividend branch mismatch")
  }

  let dmp_pexquo_fail : Result[DensePoly, PolyError] = try? dmp_pexquo(nz1, big, 1, Domain::ZZ)
  guard dmp_pexquo_fail is Err(PolyError::ExactQuotientFailed) else {
    fail("dmp_pexquo should fail when remainder is non-zero")
  }
}

///|
test "densearith wb: internal helper branches" {
  guard domain_is_field(Domain::GF(5)) else {
    fail("GF(p) should be treated as field")
  }

  let inv = try! fe_pow_local(da_wb_feqq(2, 1), -1)
  guard inv.to_string() == "1/2" else {
    fail("fe_pow_local negative exponent branch mismatch")
  }
  let cube = try! fe_pow_local(da_wb_fezz(2), 3)
  guard cube.to_string() == "8" else {
    fail("fe_pow_local binary exponentiation branch mismatch")
  }

  let cc_one = FieldElem::CC(@symnum.BigRational::one(), @symnum.BigRational::zero())
  let cc_pow = try! fe_pow_local(cc_one, 2)
  match cc_pow {
    FieldElem::CC(_, _) => ()
    _ => fail("fe_pow_local should keep CC type")
  }

  let div_zero : Result[(Bool, FieldElem), PolyError] = try? fe_divides(
    da_wb_fezz(1),
    da_wb_fezz(0),
    Domain::ZZ,
  )
  guard div_zero is Err(PolyError::DivisionByZero) else {
    fail("fe_divides by zero should raise DivisionByZero")
  }

  let (ok_field, q_field) = try! fe_divides(da_wb_feqq(1, 1), da_wb_feqq(2, 1), Domain::QQ)
  guard ok_field && q_field.to_string() == "1/2" else {
    fail("fe_divides field branch mismatch")
  }

  let (ok_non_integral, q_non_integral) = try! fe_divides(
    da_wb_feqq(1, 2),
    da_wb_fezz(1),
    Domain::ZZ,
  )
  guard !ok_non_integral && q_non_integral.to_string() == "0" else {
    fail("fe_divides non-integral guard branch mismatch")
  }

  let (ok_not_div, q_not_div) = try! fe_divides(da_wb_fezz(3), da_wb_fezz(2), Domain::ZZ)
  guard !ok_not_div && q_not_div.to_string() == "0" else {
    fail("fe_divides inexact ZZ branch mismatch")
  }

  let a = @symcore.symbol("a")
  let default_domain = Domain::AlgExt(
    Domain::ZZ,
    ["a"],
    [(a ^ @symcore.int(2)) + @symcore.int(1)],
  )
  let default_div : Result[(Bool, FieldElem), PolyError] = try? fe_divides(
    da_wb_feqq(1, 1),
    da_wb_feqq(2, 1),
    default_domain,
  )
  guard default_div is Err(PolyError::DomainNotField) else {
    fail("fe_divides invalid AlgExt domain should raise DomainNotField")
  }
}
