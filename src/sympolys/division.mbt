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
    Domain::AlgExt(_, _, _) => divmod_univar_rat(dividend, divisor)
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
  let a0 = to_dense(dividend)
  let b0 = to_dense(divisor)
  let a = trim_trailing_zeros(a0)
  let b = trim_trailing_zeros(b0)
  if b.is_empty() {
    raise PolyError::DivisionByZero
  }
  if a.is_empty() {
    let zero = Poly::zero(dividend.gens, dividend.domain).with_order(
      dividend.order,
    )
    return (zero, zero)
  }
  let deg_a = a.length() - 1
  let deg_b = b.length() - 1
  if deg_a < deg_b {
    let q0 = Poly::zero(dividend.gens, dividend.domain).with_order(
      dividend.order,
    )
    let r0 = from_dense(a, dividend.gens, dividend.domain).with_order(
      dividend.order,
    )
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
    for j in 0..<=deg_b {
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
  let q_poly = from_dense(q_trim, dividend.gens, dividend.domain).with_order(
    dividend.order,
  )
  let r_poly = from_dense(r_trim, dividend.gens, dividend.domain).with_order(
    dividend.order,
  )
  (q_poly, r_poly)
}

///|
/// Trim trailing zeros from ascending coefficient arrays.
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
  let mut g_num = BigInt::from_int(0)
  let mut lcm_den = BigInt::from_int(1)
  match poly.domain {
    Domain::AlgExt(_, _, _)
    | Domain::CC
    | Domain::GFExt(_, _, _) => return @symnum.BigRational::one()
    _ => ()
  }
  for _, c in poly.coeffs {
    let r = fe_expect_rational(c)
    let num = r.numerator()
    let den = r.denominator()
    let abs_num = if num.op_lt(BigInt::from_int(0)) { num.neg() } else { num }
    if g_num.is_zero() {
      g_num = abs_num
    } else {
      g_num = @symnum.gcd_bigint(g_num, abs_num)
    }
    let g = @symnum.gcd_bigint(lcm_den, den)
    lcm_den = lcm_den.mul(den.div(g))
  }
  if poly.coeffs.is_empty() || g_num.is_zero() {
    return @symnum.BigRational::zero()
  }
  let num_r = @symnum.BigRational::from_bigint(g_num)
  let den_r = @symnum.BigRational::from_bigint(lcm_den)
  num_r.div_r(den_r) catch {
    _ => raise PolyError::DivisionByZero
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
    Domain::AlgExt(_, _, _) => gcd_univar_rat(self, other)
    Domain::RR => gcd_univar_rat(self, other)
    Domain::Frac(_) => gcd_univar_rat(self, other)
  }
}

///|
pub fn Poly::gcd_multivar(self : Poly, other : Poly) -> Poly raise PolyError {
  if self.gens.length() == 1 {
    return self.gcd_univar(other)
  }
  if self.domain.not_equal(other.domain) || self.gens.not_equal(other.gens) {
    raise PolyError::DomainMismatch
  }
  match self.domain {
    Domain::ZZ => {
      let gq = gcd_multivar_field(lift_to_qq(self), lift_to_qq(other))
      try_round_to_int(gq)
    }
    Domain::QQ | Domain::GF(_) | Domain::GFExt(_, _, _) | Domain::AlgExt(_, _, _) => {
      gcd_multivar_field(self, other)
    }
    _ => raise PolyError::NotImplemented("gcd-multivar-domain")
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
fn remove_gen(gens : Array[String], idx : Int) -> Array[String] {
  let out : Array[String] = Array::new()
  for i in 0..<gens.length() {
    if i != idx {
      out.push(gens[i])
    }
  }
  out
}

///|
fn poly_is_const(poly : Poly) -> Bool {
  if poly.coeffs.length() != 1 {
    return false
  }
  for m, _ in poly.coeffs {
    if !m.exps.all(e => e == 0) {
      return false
    }
  }
  true
}

///|
fn poly_const_coeff(poly : Poly) -> FieldElem? {
  if !poly_is_const(poly) {
    return None
  }
  for _, c in poly.coeffs {
    return Some(c)
  }
  None
}

///|
fn poly_zero(gens : Array[String], domain : Domain) -> Poly {
  Poly::{ coeffs: Map::new(), gens, domain, order: TermOrder::Lex }
}

///|
fn poly_to_univar_coeffs(
  poly : Poly,
  var_index : Int,
) -> Array[Poly] raise PolyError {
  let rest_gens = remove_gen(poly.gens, var_index)
  let mut max_exp = 0
  let by_exp : Map[Int, Poly] = Map::new()
  for m, c in poly.coeffs {
    let exp = m.exps[var_index]
    if exp > max_exp {
      max_exp = exp
    }
    let rest_m = monomial_one(rest_gens.length())
    let mut k = 0
    for i in 0..<m.exps.length() {
      if i == var_index {
        continue
      }
      rest_m.exps.set(k, m.exps[i])
      k = k + 1
    }
    let coeff_poly = match by_exp.get(exp) {
      Some(p) => p
      None => Poly::{ coeffs: Map::new(), gens: rest_gens, domain: poly.domain, order: poly.order }
    }
    add_term(coeff_poly.coeffs, rest_m, c, poly.domain)
    by_exp.set(exp, coeff_poly)
  }
  let coeffs : Array[Poly] = Array::new()
  for i in 0..=max_exp {
    match by_exp.get(i) {
      Some(p) => coeffs.push(p)
      None => coeffs.push(poly_zero(rest_gens, poly.domain))
    }
  }
  coeffs
}

///|
fn univar_coeffs_to_poly(
  coeffs : Array[Poly],
  var_index : Int,
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  let out_coeffs : Map[Monomial, FieldElem] = Map::new()
  for exp in 0..<coeffs.length() {
    let coeff_poly = coeffs[exp]
    for m, c in coeff_poly.coeffs {
      let full = monomial_one(gens.length())
      let mut k = 0
      for i in 0..<gens.length() {
        if i == var_index {
          full.exps.set(i, exp)
        } else {
          full.exps.set(i, m.exps[k])
          k = k + 1
        }
      }
      add_term(out_coeffs, full, c, domain)
    }
  }
  Poly::{ coeffs: out_coeffs, gens, domain, order: TermOrder::Lex }
}

///|
fn trim_univar_coeffs(coeffs : Array[Poly]) -> Array[Poly] {
  let mut end = coeffs.length()
  while end > 0 && coeffs[end - 1].is_zero() {
    end = end - 1
  }
  if end == coeffs.length() {
    return coeffs
  }
  let out : Array[Poly] = Array::new()
  for i in 0..<end {
    out.push(coeffs[i])
  }
  out
}

///|
fn poly_div_exact(a : Poly, b : Poly) -> Poly raise PolyError {
  let (qs, r) = a.divmod_multivar([b])
  if r.is_zero() {
    return qs[0]
  }
  raise PolyError::NotImplemented("poly-div-exact")
}

///|
fn coeffs_content(
  coeffs : Array[Poly],
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  if coeffs.is_empty() {
    return poly_zero(gens, domain)
  }
  let mut g : Poly? = None
  for c in coeffs {
    if c.is_zero() {
      continue
    }
    g = match g {
      None => Some(c)
      Some(curr) => Some(curr.gcd_multivar(c))
    }
  }
  match g {
    None => poly_zero(gens, domain)
    Some(v) => v
  }
}

///|
fn coeffs_primitive_part(
  coeffs : Array[Poly],
  gens : Array[String],
  domain : Domain,
) -> (Array[Poly], Poly) raise PolyError {
  if coeffs.is_empty() {
    return (coeffs, poly_zero(gens, domain))
  }
  let content = coeffs_content(coeffs, gens, domain)
  if content.is_zero() {
    return (coeffs, content)
  }
  let out : Array[Poly] = Array::new()
  for c in coeffs {
    if c.is_zero() {
      out.push(c)
    } else {
      out.push(poly_div_exact(c, content))
    }
  }
  (out, content)
}

///|
fn coeffs_mul_poly(coeffs : Array[Poly], k : Poly) -> Array[Poly] raise PolyError {
  let out : Array[Poly] = Array::new()
  for c in coeffs {
    out.push(c.mul(k))
  }
  out
}

///|
fn coeffs_shift_mul(
  coeffs : Array[Poly],
  k : Poly,
  shift : Int,
) -> Array[Poly] raise PolyError {
  let out : Array[Poly] = Array::new()
  for _ in 0..<shift {
    out.push(poly_zero(k.gens, k.domain))
  }
  for c in coeffs {
    out.push(c.mul(k))
  }
  out
}

///|
fn coeffs_sub(a : Array[Poly], b : Array[Poly]) -> Array[Poly] raise PolyError {
  let len = if a.length() > b.length() { a.length() } else { b.length() }
  let gens = if a.is_empty() { b[0].gens } else { a[0].gens }
  let dom = if a.is_empty() { b[0].domain } else { a[0].domain }
  let out : Array[Poly] = Array::new()
  for i in 0..<len {
    let pa = if i < a.length() { a[i] } else { poly_zero(gens, dom) }
    let pb = if i < b.length() { b[i] } else { poly_zero(gens, dom) }
    out.push(pa.sub(pb))
  }
  trim_univar_coeffs(out)
}

///|
fn coeffs_prem(
  f : Array[Poly],
  g : Array[Poly],
) -> Array[Poly] raise PolyError {
  let mut r = trim_univar_coeffs(f)
  let g_trim = trim_univar_coeffs(g)
  if g_trim.is_empty() {
    raise PolyError::DivisionByZero
  }
  let deg_g = g_trim.length() - 1
  let lc_g = g_trim[deg_g]
  while !r.is_empty() && r.length() - 1 >= deg_g {
    let deg_r = r.length() - 1
    let d = deg_r - deg_g
    let lc_r = r[deg_r]
    let left = coeffs_mul_poly(r, lc_g)
    let right = coeffs_shift_mul(g_trim, lc_r, d)
    r = coeffs_sub(left, right)
  }
  r
}

///|
fn coeffs_make_monic(
  coeffs : Array[Poly],
) -> Array[Poly] raise PolyError {
  let trimmed = trim_univar_coeffs(coeffs)
  if trimmed.is_empty() {
    return trimmed
  }
  let lc = trimmed[trimmed.length() - 1]
  match poly_const_coeff(lc) {
    Some(c) => {
      let inv = invert_in_domain(c, lc.domain)
      let inv_rat : @symnum.BigRational? = match inv {
        FieldElem::QQ(r) => Some(r)
        FieldElem::GFp(_, v) => Some(@symnum.BigRational::from_int(v))
        _ => None
      }
      match inv_rat {
        Some(r) => {
          let scalar_poly = Poly::from_expr(
            @symcore.number(r),
            lc.gens,
            lc.domain,
          )
          let out : Array[Poly] = Array::new()
          for poly in trimmed {
            out.push(poly.mul(scalar_poly))
          }
          out
        }
        None => trimmed
      }
    }
    None => trimmed
  }
}

///|
fn gcd_multivar_field(a : Poly, b : Poly) -> Poly raise PolyError {
  if a.is_zero() {
    return b
  }
  if b.is_zero() {
    return a
  }
  let var_index = 0
  let coeff_gens = remove_gen(a.gens, var_index)
  let fa = poly_to_univar_coeffs(a, var_index)
  let fb = poly_to_univar_coeffs(b, var_index)
  let (pa, ca) = coeffs_primitive_part(fa, coeff_gens, a.domain)
  let (pb, cb) = coeffs_primitive_part(fb, coeff_gens, a.domain)
  let content_gcd = if ca.is_zero() {
    cb
  } else if cb.is_zero() {
    ca
  } else {
    ca.gcd_multivar(cb)
  }
  let mut f = coeffs_make_monic(pa)
  let mut g = coeffs_make_monic(pb)
  while !g.is_empty() {
    let r = coeffs_prem(f, g)
    let (rp, _) = coeffs_primitive_part(r, coeff_gens, a.domain)
    f = g
    g = coeffs_make_monic(rp)
  }
  let gcd_prim = if f.is_empty() {
    poly_zero(remove_gen(a.gens, var_index), a.domain)
  } else {
    univar_coeffs_to_poly(f, var_index, a.gens, a.domain)
  }
  if content_gcd.is_zero() {
    return gcd_prim
  }
  let content_full = univar_coeffs_to_poly([content_gcd], var_index, a.gens, a.domain)
  gcd_prim.mul(content_full)
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
        let term = poly_from_term(
          mono,
          lc_r,
          self.gens,
          self.domain,
          self.order,
        )
        q = q.scale_coeff(lc_b).add(term)
        let scaled_r = r.scale_coeff(lc_b)
        let subtrahend = other.mul(term)
        r = scaled_r.sub(subtrahend)
      }
    }
  }
  (q, r, steps)
}
