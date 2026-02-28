///|
/// Helpers and Berlekamp-style factorization for univariate polynomials.
fn is_one(poly : Poly) -> Bool {
  if poly.coeffs.length() != 1 {
    return false
  }
  for m, c in poly.coeffs {
    if !fe_is_one(c) {
      return false
    }
    if !m.exps.all(e => e == 0) {
      return false
    }
  }
  true
}

///|
fn deriv_univar(poly : Poly) -> Poly raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in poly.coeffs {
    let exp = m.exps[0]
    if exp == 0 {
      continue
    }
    let coeff = fe_mul(c, fe_from_int(exp, poly.domain))
    let mono = monomial_one(poly.gens.length())
    mono.exps.set(0, exp - 1)
    add_term(coeffs, mono, coeff, poly.domain)
  }
  Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
fn pth_root_univar_gf(poly : Poly, p : Int) -> Poly raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  if poly.is_zero() {
    return Poly::zero(poly.gens, poly.domain)
  }
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in poly.coeffs {
    let exp = m.exps[0]
    if exp % p != 0 {
      raise PolyError::BadExponent
    }
    let mono = monomial_one(poly.gens.length())
    mono.exps.set(0, exp / p)
    add_term(coeffs, mono, c, poly.domain)
  }
  Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
}

///|
fn square_free_decompose(poly : Poly) -> Array[(Poly, Int)] raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let res : Array[(Poly, Int)] = Array::new()
  if poly.is_zero() {
    return res
  }
  let f = poly.primitive_part()
  if is_one(f) {
    return res
  }
  let fprime = deriv_univar(f)
  if fprime.is_zero() {
    match poly.domain {
      Domain::GF(p) => {
        let root = pth_root_univar_gf(f, p)
        let parts = square_free_decompose(root)
        for pair in parts {
          let (part, mult) = pair
          res.push((part, mult * p))
        }
        return res
      }
      _ => {
        res.push((f, 1))
        return res
      }
    }
  }
  let mut g = f.gcd_univar(fprime)
  let mut w = f.div_exact_univar(g)
  let mut i = 1
  while !is_one(w) {
    let y = w.gcd_univar(g)
    let f_i = w.div_exact_univar(y)
    if !is_one(f_i) {
      res.push((f_i, i))
    }
    w = y
    g = g.div_exact_univar(y)
    i = i + 1
  }
  if !is_one(g) {
    match poly.domain {
      Domain::GF(p) => {
        let root = pth_root_univar_gf(g, p)
        let parts = square_free_decompose(root)
        for pair in parts {
          let (part, mult) = pair
          res.push((part, mult * p))
        }
      }
      _ => res.push((g, i))
    }
  }
  res
}

///|
fn lift_poly_to_qq(poly : Poly) -> Poly {
  Poly::{
    coeffs: poly.coeffs,
    gens: poly.gens,
    domain: Domain::QQ,
    order: poly.order,
  }
}

///|
fn apply_extension_request(poly : Poly, ext_syms : Array[String]) -> Poly raise PolyError {
  if ext_syms.is_empty() {
    return poly
  }
  if ext_syms.length() != 1 {
    raise PolyError::BadGenerator("extension")
  }
  let _ = ext_syms[0]
  match poly.domain {
    // SymPy extension=True/=[...] generally lifts integer domains to fields;
    // we mirror that behavior minimally by avoiding ZZ-only arithmetic paths.
    Domain::ZZ => lift_poly_to_qq(poly)
    _ => poly
  }
}

///|
pub fn Poly::factor(
  self : Poly,
  modulus? : Int,
  extension? : Array[String],
  seed? : Int,
  gens? : Array[String],
) -> Array[(Poly, Int)] raise PolyError {
  if self.is_zero() {
    return Array::new()
  }
  let resolved_gens = match gens {
    Some(g) =>
      if g.equal(self.gens) {
        g
      } else {
        raise PolyError::DomainMismatch
      }
    None => self.gens
  }
  let requested_mod = match modulus {
    Some(m) => {
      if m <= 1 {
        raise PolyError::BadModulus
      }
      Some(m)
    }
    None =>
      match self.domain {
        Domain::GF(p) => Some(p)
        _ => None
      }
  }
  let requested_extension = match extension {
    Some(ext_syms) => ext_syms
    None => []
  }
  let mut work = self
  match requested_mod {
    Some(m) =>
      match self.domain {
        Domain::GF(p) => if p != m { work = map_to_gf(self, m) }
        _ => work = map_to_gf(self, m)
      }
    None => ()
  }
  if !requested_extension.is_empty() {
    work = apply_extension_request(work, requested_extension)
  }
  if work.gens.not_equal(resolved_gens) {
    raise PolyError::DomainMismatch
  }
  check_univar_compat(work, work)
  let content = work.content()
  let mut primitive = work
  if !content.is_one() {
    primitive = work.primitive_part()
  }
  let sf_parts = square_free_decompose(primitive)
  let factors : Array[(Poly, Int)] = Array::new()
  for part in sf_parts {
    let (p, mult) = part
    if p.domain is Domain::GF(_) {
      let seed_val = match seed {
        Some(s) => s
        None => 42
      }
      let gf_parts = factor_gf_seeded(p, seed_val)
      for lp in gf_parts {
        factors.push((lp, mult))
      }
    } else if p.domain is Domain::ZZ {
      let int_parts_res = try? factor_integer(p)
      let int_parts = match int_parts_res {
        Ok(v) => v
        Err(_) => [p]
      }
      for lp in int_parts {
        factors.push((lp, mult))
      }
    } else if p.domain is Domain::QQ {
      let cleared = clear_denominators(p)
      let int_parts_res = try? factor_integer(cleared)
      let int_parts = match int_parts_res {
        Ok(v) => v
        Err(_) => [cleared]
      }
      for lp in int_parts {
        // rescale back by dividing leading coeff if needed
        let scaled = make_monic(lift_poly_to_qq(lp))
        factors.push((scaled, mult))
      }
    } else if p.domain is Domain::GFExt(_, _, _) {
      // Treat as abstract finite field: return squarefree parts as-is.
      factors.push((p, mult))
    } else if p.domain is Domain::AlgExt(_, _, _) {
      let alg_parts = factor_algext(p)
      for ap in alg_parts {
        factors.push((ap, mult))
      }
    } else {
      let lin_parts = factor_linear_rationals(p)
      for lp in lin_parts {
        factors.push((lp, mult))
      }
    }
  }
  if !content.is_one() {
    let const_coeff = ensure_coeff_domain(content, work.domain)
    let const_poly = poly_from_term(
      monomial_one(work.gens.length()),
      const_coeff,
      work.gens,
      work.domain,
      work.order,
    )
    factors.push((const_poly, 1))
  }
  factors
}

///|
/// Return (content, [(factor, exp)]) with monic primitive factors.
pub fn Poly::factor_list(
  self : Poly,
) -> (@symnum.BigRational, Array[(Poly, Int)]) raise PolyError {
  if self.is_zero() {
    return (@symnum.BigRational::zero(), Array::new())
  }
  let mut content = self.content()
  let mut primitive = self
  if !content.is_one() {
    primitive = self.primitive_part()
  }
  let raw = primitive.factor()
  let normalized : Array[(Poly, Int)] = Array::new()
  for entry in raw {
    let (f, m) = entry
    let (monic, lc) = normalize_factor_for_list(f)
    content = content.mul_r(pow_coeff(lc, m))
    normalized.push((monic, m))
  }
  (content, normalized)
}

///|
/// Square-free part and multiplicities (content separated).
pub fn Poly::sqf_list(
  self : Poly,
) -> (@symnum.BigRational, Array[(Poly, Int)]) raise PolyError {
  if self.is_zero() {
    return (@symnum.BigRational::zero(), Array::new())
  }
  check_univar_compat(self, self)
  let mut content = self.content()
  let mut primitive = self
  if !content.is_one() {
    primitive = self.primitive_part()
  }
  let sf_parts = square_free_decompose(primitive)
  let normalized : Array[(Poly, Int)] = Array::new()
  for entry in sf_parts {
    let (f, m) = entry
    let (monic, lc) = normalize_factor_for_list(f)
    content = content.mul_r(pow_coeff(lc, m))
    normalized.push((monic, m))
  }
  (content, normalized)
}

///|
/// Square-free part (product of distinct factors with content).
pub fn Poly::sqf_part(self : Poly) -> Poly raise PolyError {
  if self.is_zero() {
    return self
  }
  let (_, parts) = self.sqf_list()
  let mut acc = Poly::one(self.gens, self.domain)
  for entry in parts {
    let (f, _) = entry
    acc = acc.mul(f)
  }
  acc
}

///|
fn normalize_factor_for_list(
  poly : Poly,
) -> (Poly, @symnum.BigRational) raise PolyError {
  match poly.leading_term() {
    None => (poly, @symnum.BigRational::one())
    Some((_, lc_fe)) =>
      match poly.domain {
        Domain::GFExt(_, _, _) => (make_monic(poly), @symnum.BigRational::one())
        Domain::AlgExt(_, _, _) =>
          (make_monic(poly), @symnum.BigRational::one())
        Domain::ZZ => {
          let lc = fe_expect_rational(lc_fe)
          if lc.is_one() {
            (poly, lc)
          } else if lc.neg_r().is_one() {
            (
              poly.scale_coeff(FieldElem::QQ(@symnum.BigRational::from_int(-1))),
              lc,
            )
          } else {
            (poly, lc)
          }
        }
        _ => {
          let lc = fe_expect_rational(lc_fe)
          (make_monic(poly), lc)
        }
      }
  }
}

///|
fn pow_coeff(base : @symnum.BigRational, exp : Int) -> @symnum.BigRational {
  let mut res = @symnum.BigRational::one()
  for _ in 0..<exp {
    res = res.mul_r(base)
  }
  res
}

///|
fn eval_univar(
  poly : Poly,
  val : @symnum.BigRational,
) -> @symnum.BigRational raise PolyError {
  let mut acc = @symnum.BigRational::zero()
  for m, c in poly.coeffs {
    let coeff = fe_expect_rational(c)
    let exp = m.exps[0]
    let mut pow = @symnum.BigRational::one()
    let mut k = exp
    let mut base = val
    while k > 0 {
      if k % 2 == 1 {
        pow = pow.mul_r(base)
      }
      k = k / 2
      if k > 0 {
        base = base.mul_r(base)
      }
    }
    acc = acc.add_r(coeff.mul_r(pow))
  }
  acc
}

///|
fn eval_univar_mod(
  poly : Poly,
  val : Int,
  modulus : Int,
) -> Int raise PolyError {
  if modulus <= 1 {
    raise PolyError::BadModulus
  }
  let p = BigInt::from_int(modulus)
  let mut acc = BigInt::from_int(0)
  for m, c in poly.coeffs {
    let coeff = fe_expect_rational(c)
    let exp = m.exps[0]
    let mut pow = BigInt::from_int(1)
    let mut base = BigInt::from_int(val)
    let mut k = exp
    while k > 0 {
      if k % 2 == 1 {
        pow = pow.mul(base).mod(p)
      }
      k = k / 2
      if k > 0 {
        base = base.mul(base).mod(p)
      }
    }
    let num = coeff.numerator().mod(p)
    acc = acc.add(num.mul(pow)).mod(p)
  }
  acc.to_int()
}

///|
fn factor_linear_rationals(poly : Poly) -> Array[Poly] raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let mut remaining = poly
  let factors : Array[Poly] = Array::new()
  let const_candidates : Array[Int] = Array::new()
  let mut ct = BigInt::from_int(0)
  for _, c in remaining.coeffs {
    if ct.is_zero() {
      ct = fe_expect_rational(c).numerator()
    }
  }
  let abs_ct = if ct.op_lt(BigInt::from_int(0)) { ct.neg() } else { ct }
  let abs_ct_int = abs_ct.to_int()
  const_candidates.push(0)
  for d in 1..<=abs_ct_int {
    if abs_ct_int % d == 0 {
      const_candidates.push(d)
      const_candidates.push(-d)
    }
  }
  let mut changed = true
  while changed {
    changed = false
    if remaining.degree(0) == 0 {
      break
    }
    for cand in const_candidates {
      if remaining.degree(0) == 0 {
        break
      }
      let r = @symnum.BigRational::from_int(cand)
      if eval_univar(remaining, r).is_zero() {
        let factor_poly = Poly::from_expr(
          @symcore.symbol(remaining.gens[0]) - @symcore.int(cand),
          remaining.gens,
          remaining.domain,
        )
        factors.push(factor_poly)
        remaining = remaining.div_exact_univar(factor_poly)
        changed = true
        break
      }
    }
  }
  if !is_one(remaining) && !remaining.is_zero() {
    factors.push(remaining)
  }
  factors
}

///|
fn normalize_poly_mod(poly : Poly) -> Poly raise PolyError {
  match poly.domain {
    Domain::GF(p) => {
      let coeffs : Map[Monomial, FieldElem] = Map::new()
      for m, c in poly.coeffs {
        if fe_is_zero(c) {
          continue
        }
        let val = fe_expect_rational(c).numerator().to_int() % p
        let norm = fe_from_int(val, poly.domain)
        if !fe_is_zero(norm) {
          coeffs.set(m, norm)
        }
      }
      Poly::{ coeffs, gens: poly.gens, domain: poly.domain, order: poly.order }
    }
    Domain::GFExt(_, _, _) => poly
    _ => poly
  }
}

///|
fn strip_linear_roots_gf(
  poly : Poly,
  modulus : Int,
) -> (Poly, Array[Poly]) raise PolyError {
  let mut remaining = make_monic(normalize_poly_mod(poly))
  let factors : Array[Poly] = Array::new()
  if remaining.degree(0) == 0 {
    return (remaining, factors)
  }
  for r in 0..<modulus {
    while remaining.degree(0) > 0 && eval_univar_mod(remaining, r, modulus) == 0 {
      let factor_poly = Poly::from_expr(
        @symcore.symbol(remaining.gens[0]) - @symcore.int(r),
        remaining.gens,
        remaining.domain,
      )
      factors.push(normalize_poly_mod(factor_poly))
      remaining = make_monic(
        normalize_poly_mod(remaining.div_exact_univar(factor_poly)),
      )
      if remaining.degree(0) == 0 {
        break
      }
    }
  }
  (remaining, factors)
}

///|
/// Complete GF(p) factorization: squarefree -> distinct-degree -> equal-degree (Cantor–Zassenhaus).
fn factor_gf(poly : Poly) -> Array[Poly] raise PolyError {
  factor_gf_seeded(poly, 42)
}

///|
fn factor_gf_seeded(poly : Poly, seed : Int) -> Array[Poly] raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let (p, k, field_size, mod_poly) = match poly.domain {
    Domain::GF(p) => (p, 1, p, None)
    Domain::GFExt(p, k, m) => (p, k, int_pow(p, k), Some(m))
    _ => raise PolyError::NotUnivariate
  }
  let mut work = make_monic(normalize_poly_mod(poly))
  let factors : Array[Poly] = Array::new()
  // 1) strip linear roots (only for prime fields)
  if work.domain is Domain::GF(_) {
    let stripped = strip_linear_roots_gf(work, p)
    work = stripped.0
    for lf in stripped.1 {
      factors.push(lf)
    }
  }
  if work.is_zero() || is_one(work) {
    return factors
  }
  // 2) squarefree check
  let deriv = deriv_univar(work)
  let g = work.gcd_univar(deriv)
  if !g.is_zero() && !is_one(g) {
    let reduced = work.div_exact_univar(g)
    let squarefree_parts = factor_gf_seeded(reduced, seed + 1)
    for f in squarefree_parts {
      factors.push(f)
    }
    return factors
  }
  // 3) distinct-degree decomposition
  let ddf_parts = distinct_degree_decompose(work, field_size)
  for part in ddf_parts {
    if part.degree(0) == 1 {
      factors.push(part)
    } else {
      let edf_parts = equal_degree_factor(
        part,
        part.degree(0),
        field_size,
        p,
        k,
        seed + 7,
        mod_poly,
      )
      for f in edf_parts {
        factors.push(f)
      }
    }
  }
  factors
}

///|
/// GF(p) helpers for DDF/EDF
fn gf_pow_mod(
  base : Poly,
  exp : Int,
  modulus_poly : Poly,
) -> Poly raise PolyError {
  let mut result = Poly::one(base.gens, base.domain)
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      let divres = b.mul(result).divmod_univar(modulus_poly)
      result = divres.1
    }
    e = e / 2
    if e > 0 {
      let divres2 = b.mul(b).divmod_univar(modulus_poly)
      b = divres2.1
    }
  }
  make_monic(normalize_poly_mod(result))
}

///|
fn distinct_degree_decompose(
  poly : Poly,
  field_size : Int,
) -> Array[Poly] raise PolyError {
  let res : Array[Poly] = Array::new()
  let mut f = make_monic(poly)
  let x_poly = Poly::from_expr(
    @symcore.symbol(poly.gens[0]),
    poly.gens,
    poly.domain,
  )
  let mut pow = x_poly
  let mut i = 1
  while 2 * i <= f.degree(0) {
    pow = gf_pow_mod(pow, field_size, f)
    let g = pow.sub(x_poly)
    let d = f.gcd_univar(g)
    if !is_one(d) {
      res.push(make_monic(d))
      f = make_monic(f.div_exact_univar(d))
    }
    i = i + 1
  }
  if !is_one(f) {
    res.push(f)
  }
  res
}

///|
fn equal_degree_factor(
  poly : Poly,
  d : Int,
  field_size : Int,
  p : Int,
  k : Int,
  seed : Int,
  mod_poly : Array[Int]?,
) -> Array[Poly] raise PolyError {
  let res : Array[Poly] = Array::new()
  let stack : Array[Poly] = Array::new()
  stack.push(poly)
  let x_poly = Poly::from_expr(
    @symcore.symbol(poly.gens[0]),
    poly.gens,
    poly.domain,
  )
  let mut rng = seed
  while true {
    match stack.pop() {
      None => break
      Some(f) => {
        if f.degree(0) == d {
          res.push(f)
          continue
        }
        let exp = (int_pow(field_size, d) - 1) / 2
        let mut split_done = false
        let mut trials = 0
        while trials < 32 {
          trials = trials + 1
          rng = lcg_next(rng, field_size)
          let const_elem = field_elem_from_seed(
            rng,
            p,
            k,
            mod_poly,
            poly.domain,
          )
          let g = x_poly.add(
            poly_const_from_fe(const_elem, poly.gens, poly.domain),
          )
          let h = gf_pow_mod(g, exp, f)
          let s = h.sub(Poly::one(poly.gens, poly.domain))
          let factor = f.gcd_univar(s)
          let deg_factor = factor.degree(0)
          if deg_factor > 0 && deg_factor < f.degree(0) {
            stack.push(make_monic(factor))
            stack.push(make_monic(f.div_exact_univar(factor)))
            split_done = true
            break
          }
        }
        if !split_done {
          res.push(f)
        }
      }
    }
  }
  res
}

///|
fn field_elem_from_seed(
  value : Int,
  p : Int,
  k : Int,
  mod_poly : Array[Int]?,
  domain : Domain,
) -> FieldElem raise PolyError {
  match domain {
    Domain::GF(_) => fe_from_int(value, domain)
    Domain::GFExt(_, _, _) => {
      let mut v = value
      let coeffs : Array[Int] = Array::new()
      for _ in 0..<k {
        coeffs.push(v % p)
        v = v / p
      }
      let m = match mod_poly {
        Some(mp) => mp
        None => []
      }
      FieldElem::GFExt(p, coeffs, m)
    }
    _ => fe_from_int(value, domain)
  }
}

///|
fn poly_const_from_fe(
  coeff : FieldElem,
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  if fe_is_zero(coeff) {
    return Poly::zero(gens, domain)
  }
  let mono = monomial_one(gens.length())
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  add_term(coeffs, mono, coeff, domain)
  Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
}

///|
fn factor_algext(poly : Poly) -> Array[Poly] raise PolyError {
  if poly.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
  let (base, gens, rels) = match poly.domain {
    Domain::AlgExt(b, g, r) => (b, g, r)
    _ => raise PolyError::DomainMismatch
  }
  let (minpoly, _) = load_algext_minpoly(base, gens, rels)
  let work = poly
  if work.is_zero() || is_one(work) {
    return Array::new()
  }
  let sf_parts = square_free_decompose(work)
  let factors : Array[Poly] = Array::new()
  for entry in sf_parts {
    let (part, mult) = entry
    let split = factor_algext_squarefree(part, base, minpoly)
    for f in split {
      for _ in 0..<mult {
        factors.push(f)
      }
    }
  }
  factors
}

///|
fn factor_algext_squarefree(
  poly : Poly,
  base : Domain,
  minpoly : Poly,
) -> Array[Poly] raise PolyError {
  if poly.is_zero() || is_one(poly) {
    return Array::new()
  }
  let degree = poly.degree(0)
  if degree <= 1 {
    return [poly]
  }
  let norm = algext_norm(poly, base, minpoly)
  let (_, factors) = norm.factor_list()
  let mut remaining = poly
  let out : Array[Poly] = Array::new()
  let lifted_factors : Array[Poly] = Array::new()
  for entry in factors {
    let (f_base, _) = entry
    let lifted = lift_base_poly_to_algext(f_base, poly.domain)
    lifted_factors.push(lifted)
  }
  for lf in lifted_factors {
    if remaining.is_zero() || is_one(remaining) {
      break
    }
    let g = remaining.gcd_univar(lf)
    if !g.is_zero() && !is_one(g) && g.degree(0) > 0 {
      out.push(g)
      remaining = remaining.div_exact_univar(g)
    }
  }
  if !remaining.is_zero() && !is_one(remaining) {
    out.push(remaining)
  }
  if out.is_empty() {
    [poly]
  } else {
    out
  }
}

///|
/// resultants-based norm for K[x] where K=base(α) with minpoly(α)=0
fn algext_norm(
  poly : Poly,
  base : Domain,
  minpoly : Poly,
) -> Poly raise PolyError {
  let x_gen = poly.gens[0]
  let t_coeffs = algext_poly_to_t_coeffs(poly, base, x_gen)
  let m_coeffs = minpoly_to_t_coeffs(minpoly, base, x_gen)
  resultant_poly_coeffs(t_coeffs, m_coeffs, base, x_gen)
}

///|
fn algext_poly_to_t_coeffs(
  poly : Poly,
  base : Domain,
  x_gen : String,
) -> Array[Poly] raise PolyError {
  let mut max_j = 0
  for _, c in poly.coeffs {
    match c {
      FieldElem::AlgExt(_, coeffs, _, _) =>
        if coeffs.length() - 1 > max_j {
          max_j = coeffs.length() - 1
        }
      _ => ()
    }
  }
  let buckets : Array[Map[Monomial, FieldElem]] = Array::new()
  for _ in 0..<=max_j {
    buckets.push(Map::new())
  }
  for m, c in poly.coeffs {
    let exp_x = m.exps[0]
    let coeffs = match c {
      FieldElem::AlgExt(_, arr, _, _) => arr
      _ => [c]
    }
    for j in 0..<coeffs.length() {
      let mono = monomial_one(1)
      mono.exps.set(0, exp_x)
      add_term(buckets[j], mono, coeffs[j], base)
    }
  }
  let out : Array[Poly] = Array::new()
  for bucket in buckets {
    out.push(Poly::{
      coeffs: bucket,
      gens: [x_gen],
      domain: base,
      order: TermOrder::Lex,
    })
  }
  out
}

///|
fn minpoly_to_t_coeffs(
  minpoly : Poly,
  base : Domain,
  x_gen : String,
) -> Array[Poly] raise PolyError {
  let deg = minpoly.degree(0)
  let coeffs : Array[Poly] = Array::new()
  for _ in 0..<=deg {
    coeffs.push(Poly::zero([x_gen], base))
  }
  for m, c in minpoly.coeffs {
    let exp_t = m.exps[0]
    let mono = monomial_one(1)
    mono.exps.set(0, 0)
    let coeffs_map : Map[Monomial, FieldElem] = Map::new()
    add_term(coeffs_map, mono, c, base)
    coeffs.set(exp_t, Poly::{
      coeffs: coeffs_map,
      gens: [x_gen],
      domain: base,
      order: TermOrder::Lex,
    })
  }
  coeffs
}

///|
fn resultant_poly_coeffs(
  f : Array[Poly],
  g : Array[Poly],
  base : Domain,
  x_gen : String,
) -> Poly raise PolyError {
  let m = f.length() - 1
  let n = g.length() - 1
  let size = m + n
  if size <= 0 {
    return Poly::zero([x_gen], base)
  }
  let zero = Poly::zero([x_gen], base)
  let mat : Array[Array[Poly]] = Array::new()
  for _ in 0..<size {
    let row : Array[Poly] = Array::make(size, zero)
    mat.push(row)
  }
  for i in 0..<n {
    for j in 0..<=m {
      mat[i].set(i + j, f[j])
    }
  }
  for i in 0..<m {
    for j in 0..<=n {
      mat[n + i].set(i + j, g[j])
    }
  }
  poly_det(mat, base, x_gen)
}

///|
fn poly_det(
  mat : Array[Array[Poly]],
  base : Domain,
  x_gen : String,
) -> Poly raise PolyError {
  let n = mat.length()
  if n == 0 {
    return Poly::one([x_gen], base)
  }
  if n == 1 {
    return mat[0][0]
  }
  let a : Array[Array[Poly]] = Array::new()
  for i in 0..<n {
    let row : Array[Poly] = Array::new()
    for j in 0..<n {
      row.push(mat[i][j])
    }
    a.push(row)
  }
  let mut det_sign = 1
  let mut pivot_prev = Poly::one([x_gen], base)
  for k in 0..<(n - 1) {
    if a[k][k].is_zero() {
      let mut swap_row : Int? = None
      for r in (k + 1)..<n {
        if !a[r][k].is_zero() {
          swap_row = Some(r)
          break
        }
      }
      match swap_row {
        None => return Poly::zero([x_gen], base)
        Some(r) => {
          let tmp = a[k]
          a.set(k, a[r])
          a.set(r, tmp)
          det_sign = -det_sign
        }
      }
    }
    let pivot = a[k][k]
    for i in (k + 1)..<n {
      for j in (k + 1)..<n {
        let num = a[i][j].mul(pivot).sub(a[i][k].mul(a[k][j]))
        if k == 0 {
          a[i].set(j, num)
        } else {
          a[i].set(j, num.div_exact_univar(pivot_prev))
        }
      }
      a[i].set(k, Poly::zero([x_gen], base))
    }
    pivot_prev = pivot
  }
  let mut det = a[n - 1][n - 1]
  if det_sign < 0 {
    det = det.neg()
  }
  det
}

///|
fn lift_base_poly_to_algext(
  poly : Poly,
  domain : Domain,
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in poly.coeffs {
    let r = fe_expect_rational(c)
    let lifted = fe_from_rational(r, domain)
    add_term(coeffs, m, lifted, domain)
  }
  Poly::{ coeffs, gens: poly.gens, domain, order: poly.order }
}

///|
fn int_pow(base : Int, exp : Int) -> Int {
  let mut res = 1
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      res = res * b
    }
    e = e / 2
    if e > 0 {
      b = b * b
    }
  }
  res
}
