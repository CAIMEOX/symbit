///|
/// Symbolic roots for low-degree univariate polynomials (subset).
fn ensure_univar(poly : Poly) -> Unit raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
pub fn roots_linear(poly : Poly) -> Array[FieldElem] raise PolyError {
  ensure_univar(poly)
  let dense = to_dense(poly)
  if dense.length() != 2 {
    raise PolyError::BadExponent
  }
  let b = dense[0]
  let a = dense[1]
  if fe_is_zero(a) {
    raise PolyError::DivisionByZero
  }
  let root = fe_mul(fe_neg(b), fe_inv(a))
  [root]
}

///|
fn int_sqrt(n : Int) -> Int {
  if n <= 0 {
    return 0
  }
  let mut lo = 1
  let mut hi = n
  let mut ans = 0
  while lo <= hi {
    let mid = (lo + hi) / 2
    let sq = mid * mid
    if sq == n {
      return mid
    } else if sq < n {
      ans = mid
      lo = mid + 1
    } else {
      hi = mid - 1
    }
  }
  ans
}

///|
fn sqrt_bigint_opt(n : BigInt) -> BigInt? {
  if n.op_lt(BigInt::from_int(0)) {
    return None
  }
  let v = n.to_int()
  if v < 0 {
    return None
  }
  let r = int_sqrt(v)
  if r * r == v {
    Some(BigInt::from_int(r))
  } else {
    None
  }
}

///|
fn sqrt_rational_opt(
  r : @symnum.BigRational,
) -> @symnum.BigRational? {
  if r.compare(@symnum.BigRational::zero()) < 0 {
    return None
  }
  let num = r.numerator()
  let den = r.denominator()
  match (sqrt_bigint_opt(num), sqrt_bigint_opt(den)) {
    (Some(n), Some(d)) =>
      Some(try! @symnum.BigRational::new(n, d))
    _ => None
  }
}

///|
pub fn roots_quadratic(poly : Poly) -> Array[FieldElem] raise PolyError {
  ensure_univar(poly)
  let dense = to_dense(poly)
  if dense.length() != 3 {
    raise PolyError::BadExponent
  }
  let c = dense[0]
  let b = dense[1]
  let a = dense[2]
  if fe_is_zero(a) {
    raise PolyError::DivisionByZero
  }
  let four = fe_from_int(4, poly.domain)
  let two = fe_from_int(2, poly.domain)
  let disc = fe_sub(fe_mul(b, b), fe_mul(four, fe_mul(a, c)))
  let disc_rat = fe_expect_rational(disc)
  let sqrt_disc = match sqrt_rational_opt(disc_rat) {
    Some(v) => v
    None => raise PolyError::NotImplemented("quadratic: non-square disc")
  }
  let sqrt_fe = fe_from_rational(sqrt_disc, poly.domain)
  let neg_b = fe_neg(b)
  let denom = fe_mul(two, a)
  let r1 = fe_mul(fe_sub(neg_b, sqrt_fe), fe_inv(denom))
  let r2 = fe_mul(fe_add(neg_b, sqrt_fe), fe_inv(denom))
  [r1, r2]
}
