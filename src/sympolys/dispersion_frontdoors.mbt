///|
fn dispersion_coeff(poly : Poly, exp : Int) -> FieldElem raise PolyError {
  guard poly.gens.length() == 1 else { raise NotUnivariate }
  match poly.coeffs.get(monomial_from_array([exp])) {
    Some(coeff) => coeff
    None => fe_from_int(0, poly.domain)
  }
}

///|
fn dispersion_fe_equal(a : FieldElem, b : FieldElem) -> Bool raise PolyError {
  fe_is_zero(fe_sub(a, b))
}

///|
fn dispersion_poly_equal(a : Poly, b : Poly) -> Bool raise PolyError {
  if Eq::not_equal(a.domain, b.domain) || !same_gens(a.gens, b.gens) {
    return false
  }
  a.sub(b).is_zero()
}

///|
fn dispersion_alpha(s : Poly, t : Poly, degree : Int) -> Int? raise PolyError {
  let an = s.lc()
  let bn = t.lc()
  if !dispersion_fe_equal(an, bn) {
    return None
  }
  let anm1 = dispersion_coeff(s, degree - 1)
  let bnm1 = dispersion_coeff(t, degree - 1)
  let numer = fe_sub(anm1, bnm1)
  let denom = fe_mul(fe_from_int(degree, s.domain), bn)
  let alpha_elem = fe_mul(numer, fe_inv(denom))
  let alpha = fe_expect_rational(alpha_elem)
  if !alpha.is_integral() {
    return None
  }
  let value = alpha.numerator().to_int()
  if value < 0 {
    None
  } else {
    Some(value)
  }
}

///|
fn dispersion_push_unique(values : Array[Int], value : Int) -> Unit {
  for item in values {
    if item == value {
      return
    }
  }
  values.push(value)
}

///|
/// Compute the dispersion set of one or two univariate polynomials.
///
/// - Does: Returns all non-negative shifts `a` such that
///   `gcd(p(x), q(x+a))` has positive degree, following SymPy's factor-pair
///   algorithm.
/// - Input: One `Poly`, or two compatible univariate `Poly` values.
/// - Returns: A sorted `Array[Int]`.
/// - Limits: Algebraic or symbolic coefficient shifts whose candidate `alpha`
///   is not representable as an exact rational integer are skipped.
pub fn dispersionset(p : Poly, q? : Poly) -> Array[Int] raise PolyError {
  let same = q is None
  let rhs = match q {
    Some(poly) => poly
    None => p
  }
  guard p.gens.length() == 1 && rhs.gens.length() == 1 else {
    raise NotUnivariate
  }
  guard p.gens[0] == rhs.gens[0] else { raise DomainMismatch }
  guard !Eq::not_equal(p.domain, rhs.domain) else { raise DomainMismatch }
  if p.degree(0) < 1 || rhs.degree(0) < 1 {
    return [0]
  }

  let (_, p_factors) = p.factor_list()
  let q_factors = if same {
    p_factors
  } else {
    let (_, factors) = rhs.factor_list()
    factors
  }
  let out : Array[Int] = []
  for left in p_factors {
    let s = left.0
    let m = s.degree(0)
    for right in q_factors {
      let t = right.0
      let n = t.degree(0)
      if n != m {
        continue
      }
      match dispersion_alpha(s, t, n) {
        Some(alpha) =>
          if n <= 1 || dispersion_poly_equal(s, poly_shift_int(t, alpha)) {
            dispersion_push_unique(out, alpha)
          }
        None => ()
      }
    }
  }
  out.sort()
  out
}

///|
/// Compute the dispersion of one or two univariate polynomials.
///
/// - Does: Returns the maximum element of `dispersionset`.
/// - Input: One `Poly`, or two compatible univariate `Poly` values.
/// - Returns: The maximum shift as `Int`.
/// - Limits: Returns `-1` as this package's finite sentinel for SymPy's
///   `-oo` when the dispersion set is empty.
pub fn dispersion(p : Poly, q? : Poly) -> Int raise PolyError {
  let j = match q {
    Some(poly) => dispersionset(p, q=poly)
    None => dispersionset(p)
  }
  if j.is_empty() {
    -1
  } else {
    j[j.length() - 1]
  }
}
