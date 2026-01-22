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
  coeff : @symnum.BigRational,
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
  add_term(coeffs, mono, coeff, domain)
  Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
}

///|
fn leading_data_univar(p : Poly) -> (Int, @symnum.BigRational)? {
  match p.leading_term() {
    None => None
    Some((m, c)) => Some((m.exps[0], c))
  }
}

///|
fn invert_in_domain(
  val : @symnum.BigRational,
  domain : Domain,
) -> @symnum.BigRational raise PolyError {
  match domain {
    Domain::ZZ => raise PolyError::DomainNotField
    Domain::QQ =>
      val.reciprocal() catch {
        _ => raise PolyError::DivisionByZero
      }
    Domain::GF(_) =>
      normalize_mod(
        val.reciprocal() catch {
          _ => raise PolyError::DivisionByZero
        },
        domain,
      )
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
    Domain::GF(_) => divmod_univar_rat(dividend, divisor) // GF(p) behaves like a field
  }
}

///|
/// Classic polynomial long division over QQ.
fn divmod_univar_rat(
  dividend : Poly,
  divisor : Poly,
) -> (Poly, Poly) raise PolyError {
  let (deg_b, lc_b) = match leading_data_univar(divisor) {
    Some(data) => data
    None => raise PolyError::DivisionByZero
  }
  let inv_lc_b = invert_in_domain(lc_b, divisor.domain)
  let mut q = Poly::zero(dividend.gens, dividend.domain)
  let mut r = dividend
  let mut iter = 0
  while true {
    iter = iter + 1
    if iter > 256 {
      raise PolyError::NotImplemented("divmod_univar_rat_guard")
    }
    match leading_data_univar(r) {
      None => break
      Some((deg_r, lc_r)) => {
        if deg_r < deg_b {
          break
        }
        let exp_diff = deg_r - deg_b
        let coeff_ratio = lc_r.mul_r(inv_lc_b)
        let mono = monomial_one(dividend.gens.length())
        mono.exps.set(0, exp_diff)
        let term_poly = poly_from_term(
          mono,
          coeff_ratio,
          dividend.gens,
          dividend.domain,
        )
        q = q.add(term_poly)
        let product = divisor.mul(term_poly)
        r = r.sub(product)
      }
    }
  }
  (q, r)
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
  let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
  for m, c in poly.coeffs {
    if !c.is_integral() {
      raise PolyError::DomainNotField
    }
    coeffs.set(m, c)
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
fn coeff_content(poly : Poly) -> @symnum.BigRational {
  let mut content = @symnum.BigRational::zero()
  for _, c in poly.coeffs {
    let num = c.numerator()
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
  let inv = cont.reciprocal() catch { _ => raise PolyError::DivisionByZero }
  poly.scale_coeff(inv)
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
    Domain::ZZ => gcd_univar_int(self, other)
    Domain::GF(_) => gcd_univar_rat(self, other)
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
  let g_scaled = g_qq.scale_coeff(cont_gcd)
  try_round_to_int(g_scaled)
}

///|
/// Public helpers for content/primitive parts.
pub fn Poly::content(self : Poly) -> @symnum.BigRational {
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
  // Normalize remainder coefficients under domain to see if they vanish (e.g., GF).
  let coeffs : Map[Monomial, @symnum.BigRational] = Map::new()
  for m, c in r.coeffs {
    let norm = ensure_coeff_domain(c, r.domain)
    if !norm.is_zero() {
      coeffs.set(m, norm)
    }
  }
  if coeffs.is_empty() {
    q
  } else {
    raise PolyError::NotImplemented("non-exact-division")
  }
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
        let term = poly_from_term(mono, lc_r, self.gens, self.domain)
        q = q.scale_coeff(lc_b).add(term)
        let scaled_r = r.scale_coeff(lc_b)
        let subtrahend = other.mul(term)
        r = scaled_r.sub(subtrahend)
      }
    }
  }
  (q, r, steps)
}
