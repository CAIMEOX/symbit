///|
/// Routh-Hurwitz and Schur stability condition front doors.
///
/// Current Limits:
/// - The main polynomial variable is selected by `gen_index`, defaulting to the
///   first generator. Other generators are treated as symbolic coefficients.
/// - Complex coefficient domains are rejected, matching SymPy's front-door
///   restriction for these criteria.

///|
fn rootcond_coeff_domain(domain : Domain) -> Domain raise PolyError {
  match domain {
    Domain::ZZ => Domain::QQ
    Domain::CC | Domain::ZZ_I | Domain::QQ_I => raise PolyError::DomainMismatch
    _ => domain
  }
}

///|
fn rootcond_dup_domain(domain : Domain) -> Domain raise PolyError {
  match domain {
    Domain::CC | Domain::ZZ_I | Domain::QQ_I => raise PolyError::DomainMismatch
    _ => domain
  }
}

///|
fn rootcond_dup_neg_one(domain : Domain) -> FieldElem raise PolyError {
  fe_neg(fe_from_int(1, domain))
}

///|
fn rootcond_dup_array_exact_quotient(
  coeffs : Array[FieldElem],
  denominator : FieldElem,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for coeff in coeffs {
    out.push(fe_exquo_ground(coeff, denominator, domain))
  }
  dup_strip(out)
}

///|
fn rootcond_dup_routh_hurwitz_fraction_free(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let mut p = dup_strip(coeffs)
  if p.is_empty() {
    raise PolyError::NonPolynomial
  }
  if p.length() == 1 {
    return []
  } else if p.length() == 2 {
    return [fe_mul(p[0], p[1])]
  } else if p.length() == 3 {
    return [fe_mul(p[0], p[1]), fe_mul(p[0], p[2])]
  }

  let leading = p[0]
  let trailing = p[p.length() - 1]
  let monic = fe_is_one(leading)
  let p1s : Array[FieldElem] = [p[1]]
  while p.length() > 3 {
    let qs : Array[FieldElem] = Array::new()
    for i in 1..<p.length() {
      qs.push(fe_mul(p[1], p[i]))
    }
    let mut i = 1
    while i < qs.length() - 1 {
      qs[i] = fe_sub(qs[i], fe_mul(p[i + 2], p[0]))
      i += 2
    }
    p = qs
    let mut p1 = p[1]
    if fe_is_zero(p1) {
      return [rootcond_dup_neg_one(domain)]
    }
    if p1s.length() >= 2 {
      p1 = fe_exquo_ground(p1, p1s[p1s.length() - 2], domain)
    }
    if p1s.length() >= 3 {
      let divisor = p1s[p1s.length() - 3]
      p1 = fe_exquo_ground(p1, divisor, domain)
      p1 = fe_exquo_ground(p1, divisor, domain)
      p = rootcond_dup_array_exact_quotient(p, divisor, domain)
      p = rootcond_dup_array_exact_quotient(p, divisor, domain)
    }
    p1s.push(p1)
  }
  if !monic {
    let mut i = 0
    while i < p1s.length() {
      p1s[i] = fe_mul(p1s[i], leading)
      i += 2
    }
  }
  p1s.push(fe_mul(leading, trailing))
  p1s
}

///|
fn rootcond_dup_series_trim(poly : Array[FieldElem]) -> Array[FieldElem] {
  let mut end = poly.length()
  while end > 0 && fe_is_zero(poly[end - 1]) {
    end -= 1
  }
  Array::makei(end, i => poly[i])
}

///|
fn rootcond_dup_series_add(
  lhs : Array[FieldElem],
  rhs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if lhs.is_empty() {
    return rhs
  }
  if rhs.is_empty() {
    return lhs
  }
  let len = if lhs.length() > rhs.length() {
    lhs.length()
  } else {
    rhs.length()
  }
  let zero = fe_from_int(0, domain)
  let out = Array::makei(len, _ => zero)
  for i in 0..<len {
    let a = if i < lhs.length() { lhs[i] } else { zero }
    let b = if i < rhs.length() { rhs[i] } else { zero }
    out[i] = fe_add(a, b)
  }
  rootcond_dup_series_trim(out)
}

///|
fn rootcond_dup_series_mul(
  lhs : Array[FieldElem],
  rhs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if lhs.is_empty() || rhs.is_empty() {
    return []
  }
  let zero = fe_from_int(0, domain)
  let out = Array::makei(lhs.length() + rhs.length() - 1, _ => zero)
  for i in 0..<lhs.length() {
    for j in 0..<rhs.length() {
      out[i + j] = fe_add(out[i + j], fe_mul(lhs[i], rhs[j]))
    }
  }
  rootcond_dup_series_trim(out)
}

///|
fn rootcond_dup_series_scale(
  poly : Array[FieldElem],
  scalar : FieldElem,
  _domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if poly.is_empty() || fe_is_zero(scalar) {
    return []
  }
  rootcond_dup_series_trim(poly.map(coeff => fe_mul(coeff, scalar)))
}

///|
fn rootcond_dup_series_pow(
  base : Array[FieldElem],
  exp : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if base.is_empty() {
    return []
  }
  let mut result = [fe_from_int(1, domain)]
  let mut power = base
  let mut n = exp
  while n > 0 {
    if n % 2 == 1 {
      result = rootcond_dup_series_mul(result, power, domain)
    }
    n = n / 2
    if n > 0 {
      power = rootcond_dup_series_mul(power, power, domain)
    }
  }
  result
}

///|
fn rootcond_dup_schur_transform_desc(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let p = dup_strip(coeffs)
  if p.is_empty() {
    raise PolyError::NonPolynomial
  }
  let degree = p.length() - 1
  let one = fe_from_int(1, domain)
  let neg_one = fe_neg(one)
  let plus = [one, one]
  let minus = [one, neg_one]
  let mut acc : Array[FieldElem] = []
  for i in 0..<p.length() {
    let left = rootcond_dup_series_pow(plus, degree - i, domain)
    let right = rootcond_dup_series_pow(minus, i, domain)
    let term = rootcond_dup_series_scale(
      rootcond_dup_series_mul(left, right, domain),
      p[i],
      domain,
    )
    acc = rootcond_dup_series_add(acc, term, domain)
  }
  let trimmed = rootcond_dup_series_trim(acc)
  let desc = Array::makei(trimmed.length(), i => {
    trimmed[trimmed.length() - 1 - i]
  })
  dup_strip(desc)
}

///|
fn rootcond_dup_eval_at_minus_one(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let p = dup_strip(coeffs)
  if p.is_empty() {
    raise PolyError::NonPolynomial
  }
  let neg_one = rootcond_dup_neg_one(domain)
  let mut acc = fe_from_int(0, domain)
  for coeff in p {
    acc = fe_add(fe_mul(acc, neg_one), coeff)
  }
  acc
}

///|
fn rootcond_coeff_zero(gens : Array[String], domain : Domain) -> Poly {
  Poly::zero(gens, domain)
}

///|
fn rootcond_coeff_one(
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  Poly::one(gens, domain)
}

///|
fn rootcond_coeff_neg_one(
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  Poly::one(gens, domain).neg()
}

///|
fn rootcond_coeff_poly_is_one(poly : Poly) -> Bool {
  if poly.coeffs.length() != 1 {
    return false
  }
  for m, c in poly.coeffs {
    if !fe_is_one(c) || !m.exps.all(e => e == 0) {
      return false
    }
  }
  true
}

///|
fn rootcond_coeff_exact_quotient(
  numerator : Poly,
  denominator : Poly,
) -> Poly raise PolyError {
  if denominator.is_zero() {
    raise PolyError::DivisionByZero
  }
  if numerator.is_zero() {
    return Poly::zero(numerator.gens, numerator.domain)
  }
  let (quotient, remainder) = if numerator.gens.length() == 1 {
    numerator.divmod_univar(denominator)
  } else {
    let (quotients, remainder) = numerator.divmod_multivar([denominator])
    (quotients[0], remainder)
  }
  if remainder.is_zero() {
    quotient
  } else {
    raise PolyError::ExactQuotientFailed
  }
}

///|
fn rootcond_coeff_array_exact_quotient(
  coeffs : Array[Poly],
  denominator : Poly,
) -> Array[Poly] raise PolyError {
  coeffs.map(coeff => rootcond_coeff_exact_quotient(coeff, denominator))
}

///|
fn rootcond_coeff_poly_to_expr(poly : Poly) -> Expr {
  poly.to_expr()
}

///|
fn rootcond_coeffs_desc(
  poly : Poly,
  gen_index : Int,
) -> Array[Poly] raise PolyError {
  if poly.is_zero() {
    raise PolyError::NonPolynomial
  }
  if gen_index < 0 || gen_index >= poly.gens.length() {
    raise PolyError::BadGenerator(gen_index.to_string())
  }
  let coeff_domain = rootcond_coeff_domain(poly.domain)
  let coeff_gens = remove_gen(poly.gens, gen_index)
  let degree = poly.degree(gen_index)
  let coeffs = Array::makei(degree + 1, _ => {
    rootcond_coeff_zero(coeff_gens, coeff_domain)
  })
  for mono, coeff in poly.coeffs {
    let coeff_mono = monomial_one(coeff_gens.length())
    let mut out_pos = 0
    for i in 0..<mono.exps.length() {
      if i == gen_index {
        continue
      }
      coeff_mono.exps.set(out_pos, mono.exps[i])
      out_pos += 1
    }
    let term_coeffs : Map[Monomial, FieldElem] = {}
    add_term(term_coeffs, coeff_mono, coeff, coeff_domain)
    let term = Poly::{
      coeffs: term_coeffs,
      gens: coeff_gens,
      domain: coeff_domain,
      order: poly.order,
    }
    let target = degree - mono.exps[gen_index]
    coeffs[target] = coeffs[target].add(term)
  }
  coeffs
}

///|
fn rootcond_trim_desc(coeffs : Array[Poly]) -> Array[Poly] {
  let mut start = 0
  while start < coeffs.length() && coeffs[start].is_zero() {
    start += 1
  }
  if start == coeffs.length() {
    return []
  }
  Array::makei(coeffs.length() - start, i => coeffs[start + i])
}

///|
fn rootcond_routh_hurwitz_coeffs(
  coeffs : Array[Poly],
) -> Array[Poly] raise PolyError {
  let mut p = rootcond_trim_desc(coeffs)
  if p.is_empty() {
    raise PolyError::NonPolynomial
  }
  if p.length() == 1 {
    return []
  } else if p.length() == 2 {
    return [p[0].mul(p[1])]
  } else if p.length() == 3 {
    return [p[0].mul(p[1]), p[0].mul(p[2])]
  }

  let leading = p[0]
  let trailing = p[p.length() - 1]
  let monic = rootcond_coeff_poly_is_one(leading)
  let p1s : Array[Poly] = [p[1]]
  while p.length() > 3 {
    let qs : Array[Poly] = []
    for i in 1..<p.length() {
      qs.push(p[1].mul(p[i]))
    }
    let mut i = 1
    while i < qs.length() - 1 {
      qs[i] = qs[i].sub(p[i + 2].mul(p[0]))
      i += 2
    }
    p = rootcond_trim_desc(qs)
    if p.length() <= 1 {
      let neg_one = rootcond_coeff_neg_one(leading.gens, leading.domain)
      return [neg_one]
    }
    let mut p1 = p[1]
    if p1.is_zero() {
      let neg_one = rootcond_coeff_neg_one(leading.gens, leading.domain)
      return [neg_one]
    }
    if p1s.length() >= 2 {
      p1 = rootcond_coeff_exact_quotient(p1, p1s[p1s.length() - 2])
    }
    if p1s.length() >= 3 {
      let divisor = p1s[p1s.length() - 3]
      p1 = rootcond_coeff_exact_quotient(p1, divisor)
      p1 = rootcond_coeff_exact_quotient(p1, divisor)
      p = rootcond_coeff_array_exact_quotient(p, divisor)
      p = rootcond_coeff_array_exact_quotient(p, divisor)
    }
    p1s.push(p1)
  }
  if !monic {
    let mut i = 0
    while i < p1s.length() {
      p1s[i] = p1s[i].mul(leading)
      i += 2
    }
  }
  p1s.push(leading.mul(trailing))
  p1s
}

///|
fn rootcond_series_trim(poly : Array[Poly]) -> Array[Poly] {
  let mut end = poly.length()
  while end > 0 && poly[end - 1].is_zero() {
    end -= 1
  }
  Array::makei(end, i => poly[i])
}

///|
fn rootcond_series_add(
  lhs : Array[Poly],
  rhs : Array[Poly],
) -> Array[Poly] raise PolyError {
  if lhs.is_empty() {
    return rhs
  }
  if rhs.is_empty() {
    return lhs
  }
  let len = if lhs.length() > rhs.length() {
    lhs.length()
  } else {
    rhs.length()
  }
  let zero = rootcond_coeff_zero(lhs[0].gens, lhs[0].domain)
  let out = Array::makei(len, _ => zero)
  for i in 0..<len {
    let a = if i < lhs.length() { lhs[i] } else { zero }
    let b = if i < rhs.length() { rhs[i] } else { zero }
    out[i] = a.add(b)
  }
  rootcond_series_trim(out)
}

///|
fn rootcond_series_mul(
  lhs : Array[Poly],
  rhs : Array[Poly],
) -> Array[Poly] raise PolyError {
  if lhs.is_empty() || rhs.is_empty() {
    return []
  }
  let zero = rootcond_coeff_zero(lhs[0].gens, lhs[0].domain)
  let out = Array::makei(lhs.length() + rhs.length() - 1, _ => zero)
  for i in 0..<lhs.length() {
    for j in 0..<rhs.length() {
      out[i + j] = out[i + j].add(lhs[i].mul(rhs[j]))
    }
  }
  rootcond_series_trim(out)
}

///|
fn rootcond_series_scale(
  poly : Array[Poly],
  scalar : Poly,
) -> Array[Poly] raise PolyError {
  if poly.is_empty() || scalar.is_zero() {
    return []
  }
  rootcond_series_trim(poly.map(coeff => coeff.mul(scalar)))
}

///|
fn rootcond_series_pow(
  base : Array[Poly],
  exp : Int,
) -> Array[Poly] raise PolyError {
  if base.is_empty() {
    return []
  }
  let mut result = [rootcond_coeff_one(base[0].gens, base[0].domain)]
  let mut power = base
  let mut n = exp
  while n > 0 {
    if n % 2 == 1 {
      result = rootcond_series_mul(result, power)
    }
    n = n / 2
    if n > 0 {
      power = rootcond_series_mul(power, power)
    }
  }
  result
}

///|
fn rootcond_schur_transform_desc(
  coeffs : Array[Poly],
) -> Array[Poly] raise PolyError {
  let p = rootcond_trim_desc(coeffs)
  if p.is_empty() {
    raise PolyError::NonPolynomial
  }
  let degree = p.length() - 1
  let one = rootcond_coeff_one(p[0].gens, p[0].domain)
  let neg_one = one.neg()
  let plus = [one, one]
  let minus = [one, neg_one]
  let mut acc : Array[Poly] = []
  for i in 0..<p.length() {
    let left = rootcond_series_pow(plus, degree - i)
    let right = rootcond_series_pow(minus, i)
    let term = rootcond_series_scale(rootcond_series_mul(left, right), p[i])
    acc = rootcond_series_add(acc, term)
  }
  let trimmed = rootcond_series_trim(acc)
  let desc = Array::makei(trimmed.length(), i => {
    trimmed[trimmed.length() - 1 - i]
  })
  rootcond_trim_desc(desc)
}

///|
fn rootcond_eval_at_minus_one(coeffs : Array[Poly]) -> Poly raise PolyError {
  let p = rootcond_trim_desc(coeffs)
  if p.is_empty() {
    raise PolyError::NonPolynomial
  }
  let neg_one = rootcond_coeff_neg_one(p[0].gens, p[0].domain)
  let mut acc = rootcond_coeff_zero(p[0].gens, p[0].domain)
  for coeff in p {
    acc = acc.mul(neg_one).add(coeff)
  }
  acc
}

///|
/// Compute dense Routh-Hurwitz stability conditions.
///
/// - Does: Returns the fraction-free Routh-Hurwitz condition list for a
///   univariate dense polynomial.
/// - Input: Dense coefficients in descending degree order plus a coefficient
///   domain.
/// - Returns: Dense-domain coefficients whose positivity gives the Hurwitz
///   criterion.
/// - Limits: Raises on zero input and complex coefficient domains; expression
///   domains use the available `FieldElem` representation only.
pub fn dup_routh_hurwitz(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let checked_domain = rootcond_dup_domain(domain)
  rootcond_dup_routh_hurwitz_fraction_free(coeffs, checked_domain)
}

///|
/// Compute dense Schur stability conditions.
///
/// - Does: Applies the Cayley transform `z = (1 + s)/(1 - s)` to the dense
///   polynomial and then uses `dup_routh_hurwitz`.
/// - Input: Dense coefficients in descending degree order plus a coefficient
///   domain.
/// - Returns: Dense-domain coefficients whose positivity gives the Schur
///   criterion.
/// - Limits: Returns `[-1]` when `-1` is a root, matching SymPy's transform
///   guard; complex coefficient domains are rejected.
pub fn dup_schur_conditions(
  coeffs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let checked_domain = rootcond_dup_domain(domain)
  if fe_is_zero(rootcond_dup_eval_at_minus_one(coeffs, checked_domain)) {
    return [rootcond_dup_neg_one(checked_domain)]
  }
  rootcond_dup_routh_hurwitz_fraction_free(
    rootcond_dup_schur_transform_desc(coeffs, checked_domain),
    checked_domain,
  )
}

///|
/// Compute Routh-Hurwitz stability conditions.
///
/// - Does: Returns conditions that are positive exactly when all roots have
///   strictly negative real part and the leading coefficient is nonzero.
/// - Input: A `Poly`, with optional `gen_index` selecting the main variable.
/// - Returns: `Array[Expr]` containing symbolic coefficient conditions.
/// - Limits: Raises on zero input and complex coefficient domains; Python-only
///   domain wrapper classes are not modeled.
pub fn hurwitz_conditions(
  poly : Poly,
  gen_index? : Int = 0,
) -> Array[Expr] raise PolyError {
  let coeffs = rootcond_coeffs_desc(poly, gen_index)
  rootcond_routh_hurwitz_coeffs(coeffs).map(rootcond_coeff_poly_to_expr)
}

///|
/// Compute Schur stability conditions.
///
/// - Does: Maps the unit circle to the left half-plane with
///   `z = (1 + s)/(1 - s)`, then applies Routh-Hurwitz.
/// - Input: A `Poly`, with optional `gen_index` selecting the main variable.
/// - Returns: `Array[Expr]` containing symbolic coefficient conditions.
/// - Limits: Returns `[-1]` when `-1` is a root, matching SymPy's exceptional
///   transform guard.
pub fn schur_conditions(
  poly : Poly,
  gen_index? : Int = 0,
) -> Array[Expr] raise PolyError {
  let coeffs = rootcond_coeffs_desc(poly, gen_index)
  if rootcond_eval_at_minus_one(coeffs).is_zero() {
    let domain = rootcond_coeff_domain(poly.domain)
    return [
      rootcond_coeff_neg_one(remove_gen(poly.gens, gen_index), domain).to_expr(),
    ]
  }
  rootcond_routh_hurwitz_coeffs(rootcond_schur_transform_desc(coeffs)).map(
    rootcond_coeff_poly_to_expr,
  )
}
