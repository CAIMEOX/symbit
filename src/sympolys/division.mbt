///|
fn check_univar_compat(a : Poly, b : Poly) -> Unit raise PolyError {
  if a.domain.not_equal(b.domain) || a.gens.not_equal(b.gens) {
    raise PolyError::DomainMismatch
  }
  if a.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
/// Helper to build a monomial polynomial for division steps.
fn poly_from_term(
  mono : Monomial,
  coeff : FieldElem,
  gens : Array[String],
  domain : Domain,
  order : TermOrder,
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  add_term(coeffs, mono, coeff, domain)
  Poly::{ coeffs, gens, domain, order }
}

///|
fn leading_data_univar(p : Poly) -> (Int, FieldElem)? {
  match p.leading_term_with_order(p.order) {
    None => None
    Some((m, c)) => Some((m.exps[0], c))
  }
}

///|
fn invert_in_domain(
  val : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  match domain {
    Domain::ZZ => raise PolyError::DomainNotField
    Domain::QQ => fe_inv(val)
    Domain::CC => fe_inv(val)
    Domain::GF(_) | Domain::GFExt(_, _, _) => fe_inv(val)
    Domain::AlgExt(_, _, _) => fe_inv(val)
    Domain::RR => fe_inv(val)
    Domain::Frac(_) => fe_inv(val)
  }
}

///|
/// Dispatch to field/int division.
fn divmod_univar(
  dividend : Poly,
  divisor : Poly,
) -> (Poly, Poly) raise PolyError {
  check_univar_compat(dividend, divisor)
  if divisor.is_zero() {
    raise PolyError::DivisionByZero
  }
  match dividend.domain {
    Domain::ZZ => divmod_univar_int(dividend, divisor)
    Domain::QQ => divmod_univar_rat(dividend, divisor)
    Domain::CC => divmod_univar_rat(dividend, divisor)
    Domain::GF(_) => divmod_univar_rat(dividend, divisor) // GF(p) behaves like a field
    Domain::GFExt(_, _, _) => divmod_univar_rat(dividend, divisor)
    Domain::AlgExt(_, _, _) => raise PolyError::NotImplemented("alg-extension-div")
    Domain::RR => divmod_univar_rat(dividend, divisor)
    Domain::Frac(_) => divmod_univar_rat(dividend, divisor)
  }
}

///|
/// Classic polynomial long division over QQ.
fn divmod_univar_rat(
  dividend : Poly,
  divisor : Poly,
) -> (Poly, Poly) raise PolyError {
  // Dense long division (ascending coefficient arrays) for stability.
  let a0 = try to_dense(dividend) catch { e => raise e } noraise { v => v }
  let b0 = try to_dense(divisor) catch { e => raise e } noraise { v => v }
  let a = trim_trailing_zeros(a0)
  let b = trim_trailing_zeros(b0)
  if b.is_empty() {
    raise PolyError::DivisionByZero
  }
  if a.is_empty() {
    let zero = Poly::zero(dividend.gens, dividend.domain).with_order(dividend.order)
    return (zero, zero)
  }
  let deg_a = a.length() - 1
  let deg_b = b.length() - 1
  if deg_a < deg_b {
    let q0 = Poly::zero(dividend.gens, dividend.domain).with_order(dividend.order)
    let r0 = from_dense(a, dividend.gens, dividend.domain).with_order(dividend.order)
    return (q0, r0)
  }
  let zero = fe_from_int(0, dividend.domain)
  let q_len = deg_a - deg_b + 1
  let q_coeffs : Array[FieldElem] = Array::make(q_len, zero)
  let r_coeffs = a.copy()
  let inv_lc_b = invert_in_domain(b[deg_b], divisor.domain)
  let mut k = deg_a - deg_b
  while k >= 0 {
    let idx = deg_b + k
    let coeff = fe_mul(r_coeffs[idx], inv_lc_b)
    q_coeffs.set(k, coeff)
    for j in 0..=deg_b {
      let pos = j + k
      let updated = fe_sub(r_coeffs[pos], fe_mul(coeff, b[j]))
      r_coeffs.set(pos, updated)
    }
    if k == 0 {
      break
    }
    k = k - 1
  }
  let q_trim = trim_trailing_zeros(q_coeffs)
  let rem_raw : Array[FieldElem] = Array::new()
  for i in 0..<deg_b {
    rem_raw.push(r_coeffs[i])
  }
  let r_trim = trim_trailing_zeros(rem_raw)
  let q_poly = from_dense(q_trim, dividend.gens, dividend.domain).with_order(dividend.order)
  let r_poly = from_dense(r_trim, dividend.gens, dividend.domain).with_order(dividend.order)
  (q_poly, r_poly)
}

///| Trim trailing zeros from ascending coefficient arrays.
fn trim_trailing_zeros(coeffs : Array[FieldElem]) -> Array[FieldElem] {
  let mut end = coeffs.length()
  while end > 0 && fe_is_zero(coeffs[end - 1]) {
    end = end - 1
  }
  if end == coeffs.length() {
    return coeffs
  }
  let out : Array[FieldElem] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
/// Integer division via lift to QQ and rounding.
fn divmod_univar_int(
  dividend : Poly,
  divisor : Poly,
) -> (Poly, Poly) raise PolyError {
  let (lifted_q, lifted_r) = divmod_univar_rat(
    lift_to_qq(dividend),
    lift_to_qq(divisor),
  )
  let q = try_round_to_int(lifted_q)
  let r = try_round_to_int(lifted_r)
  (q, r)
}

///|
fn lift_to_qq(poly : Poly) -> Poly {
  Poly::{
    coeffs: poly.coeffs,
    gens: poly.gens,
    domain: Domain::QQ,
    order: poly.order,
  }
}

///|
fn try_round_to_int(poly : Poly) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in poly.coeffs {
    let r = fe_expect_rational(c)
    if !r.is_integral() {
      raise PolyError::DomainNotField
    }
    coeffs.set(m, FieldElem::QQ(r))
  }
  Poly::{ coeffs, gens: poly.gens, domain: Domain::ZZ, order: poly.order }
}

///|
pub fn Poly::divmod_univar(
  self : Poly,
  other : Poly,
) -> (Poly, Poly) raise PolyError {
  divmod_univar(self, other)
}

///|
/// gcd of integer numerators (content).
fn coeff_content(poly : Poly) -> @symnum.BigRational raise PolyError {
  let mut content = @symnum.BigRational::zero()
  match poly.domain {
    Domain::AlgExt(_, _, _) | Domain::CC => return @symnum.BigRational::one()
    _ => ()
  }
  for _, c in poly.coeffs {
    let r = fe_expect_rational(c)
    let num = r.numerator()
    let abs_num = if num.op_lt(BigInt::from_int(0)) { num.neg() } else { num }
    content = match content.is_zero() {
      true => @symnum.BigRational::from_bigint(abs_num)
      false =>
        @symnum.BigRational::from_bigint(
          @symnum.gcd_bigint(content.numerator(), abs_num),
        )
    }
  }
  if poly.coeffs.is_empty() {
    @symnum.BigRational::zero()
  } else {
    content
  }
}

///|
fn primitive_part(poly : Poly) -> Poly raise PolyError {
  let cont = coeff_content(poly)
  if cont.is_zero() {
    return poly
  }
  match poly.domain {
    Domain::ZZ | Domain::QQ => {
      let inv = cont.reciprocal() catch { _ => raise PolyError::DivisionByZero }
      poly.scale_coeff(FieldElem::QQ(inv))
    }
    Domain::AlgExt(_, _, _) => poly
    _ => poly
  }
}

///|
/// Scale to make leading coefficient 1 when possible.
fn make_monic(poly : Poly) -> Poly raise PolyError {
  match poly.leading_term() {
    None => poly
    Some((_, lc)) => {
      let inv = invert_in_domain(lc, poly.domain)
      poly.scale_coeff(inv)
    }
  }
}

///|
pub fn Poly::gcd_univar(self : Poly, other : Poly) -> Poly raise PolyError {
  check_univar_compat(self, other)
  match self.domain {
    Domain::QQ => gcd_univar_rat(self, other)
    Domain::CC => gcd_univar_rat(self, other)
    Domain::ZZ => gcd_univar_int(self, other)
    Domain::GF(_) => gcd_univar_rat(self, other)
    Domain::GFExt(_, _, _) => gcd_univar_rat(self, other)
    Domain::AlgExt(_, _, _) => raise PolyError::NotImplemented("alg-extension-gcd")
    Domain::RR => gcd_univar_rat(self, other)
    Domain::Frac(_) => gcd_univar_rat(self, other)
  }
}

///|
fn gcd_univar_rat(a : Poly, b : Poly) -> Poly raise PolyError {
  let mut p = a
  let mut q = b
  let mut iter = 0
  while !q.is_zero() {
    iter = iter + 1
    if iter > 64 {
      raise PolyError::NotImplemented("gcd_univar_rat_guard")
    }
    let (_, r) = divmod_univar_rat(p, q)
    p = q
    q = r
  }
  make_monic(p)
}

///|
fn gcd_univar_int(a : Poly, b : Poly) -> Poly raise PolyError {
  let cont_a = coeff_content(a)
  let cont_b = coeff_content(b)
  let prim_a = primitive_part(a)
  let prim_b = primitive_part(b)
  let g_qq = gcd_univar_rat(lift_to_qq(prim_a), lift_to_qq(prim_b))
  let cont_gcd = @symnum.BigRational::from_bigint(
    @symnum.gcd_bigint(cont_a.numerator(), cont_b.numerator()),
  )
  let g_scaled = g_qq.scale_coeff(FieldElem::QQ(cont_gcd))
  try_round_to_int(g_scaled)
}

///|
/// Public helpers for content/primitive parts.
pub fn Poly::content(self : Poly) -> @symnum.BigRational raise PolyError {
  coeff_content(self)
}

///|
pub fn Poly::primitive_part(self : Poly) -> Poly raise PolyError {
  primitive_part(self)
}

///|
/// Exact univariate division (requires zero remainder).
pub fn Poly::div_exact_univar(
  self : Poly,
  other : Poly,
) -> Poly raise PolyError {
  let (q, r) = self.divmod_univar(other)
  if r.is_zero() {
    return q
  }
  raise PolyError::NotImplemented("non-exact-division")
}

///|
/// Pseudo-division for ZZ: lc(other)^k * self = q*other + r where deg r < deg other.
pub fn Poly::pseudo_div_univar_int(
  self : Poly,
  other : Poly,
) -> (Poly, Poly, Int) raise PolyError {
  check_univar_compat(self, other)
  if self.domain is Domain::QQ || other.domain is Domain::QQ {
    raise PolyError::DomainNotField
  }
  let (deg_b, lc_b) = match leading_data_univar(other) {
    Some(v) => v
    None => raise PolyError::DivisionByZero
  }
  let mut q = Poly::zero(self.gens, self.domain)
  let mut r = self
  let mut steps = 0
  while true {
    match leading_data_univar(r) {
      None => break
      Some((deg_r, lc_r)) => {
        if deg_r < deg_b {
          break
        }
        steps = steps + 1
        let k = deg_r - deg_b
        let mono = monomial_one(self.gens.length())
        mono.exps.set(0, k)
        let term = poly_from_term(mono, lc_r, self.gens, self.domain, self.order)
        q = q.scale_coeff(lc_b).add(term)
        let scaled_r = r.scale_coeff(lc_b)
        let subtrahend = other.mul(term)
        r = scaled_r.sub(subtrahend)
      }
    }
  }
  (q, r, steps)
}
