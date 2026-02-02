///|
/// Root isolation helpers (subset): Cauchy and Mignotte bounds.
fn abs_rational(r : @symnum.BigRational) -> @symnum.BigRational {
  if r.compare(@symnum.BigRational::zero()) < 0 {
    r.neg()
  } else {
    r
  }
}

///|
fn pow_rational(
  base : @symnum.BigRational,
  exp : Int,
) -> @symnum.BigRational {
  let mut result = @symnum.BigRational::one()
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = result.mul(b)
    }
    e = e / 2
    if e > 0 {
      b = b.mul(b)
    }
  }
  result
}

///|
fn reverse_coeffs(coeffs : Array[FieldElem]) -> Array[FieldElem] {
  let out : Array[FieldElem] = Array::new()
  let mut i = coeffs.length()
  while i > 0 {
    i = i - 1
    out.push(coeffs[i])
  }
  out
}

///|
pub fn dup_cauchy_upper_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let f = dup_strip(coeffs)
  if f.length() < 2 {
    raise PolyError::NotImplemented("cauchy-upper")
  }
  let lc = fe_expect_rational(f[0])
  if lc.is_zero() {
    raise PolyError::DivisionByZero
  }
  let mut max_ratio = @symnum.BigRational::zero()
  for i in 1..<f.length() {
    let ai = abs_rational(fe_expect_rational(f[i]))
    let ratio = try ai.div_r(abs_rational(lc)) catch {
      _ => raise PolyError::NotImplemented("cauchy-upper-div")
    }
    if ratio.compare(max_ratio) > 0 {
      max_ratio = ratio
    }
  }
  let one = @symnum.BigRational::one()
  fe_from_rational(one.add(max_ratio), Domain::QQ)
}

///|
pub fn dup_cauchy_lower_bound(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let g = dup_strip(reverse_coeffs(coeffs))
  if g.length() < 2 {
    raise PolyError::NotImplemented("cauchy-lower")
  }
  let upper = dup_cauchy_upper_bound(g, domain)
  let upper_rat = fe_expect_rational(upper)
  let inv = try upper_rat.reciprocal() catch {
    _ => raise PolyError::NotImplemented("cauchy-lower-div")
  }
  fe_from_rational(inv, Domain::QQ)
}

///|
pub fn dup_mignotte_sep_bound_squared(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let f = dup_strip(coeffs)
  let n = dup_degree(f)
  if n < 2 {
    raise PolyError::NotImplemented("mignotte-sep")
  }
  let asc : Array[FieldElem] = Array::new()
  let mut i = f.length()
  while i > 0 {
    i = i - 1
    asc.push(f[i])
  }
  let poly = from_dense(asc, ["x"], domain)
  let disc = discriminant(poly)
  let disc_rat = abs_rational(fe_expect_rational(disc))
  let l2sq_fe = dup_l2_norm_squared(f, domain)
  let l2sq = fe_expect_rational(l2sq_fe)
  let n_rat = @symnum.BigRational::from_int(n)
  let num = @symnum.BigRational::from_int(3).mul(disc_rat)
  let denom = pow_rational(n_rat, n + 1).mul(
    pow_rational(l2sq, n - 1),
  )
  let bound = try num.div_r(denom) catch {
    _ => raise PolyError::NotImplemented("mignotte-div")
  }
  fe_from_rational(bound, Domain::QQ)
}
