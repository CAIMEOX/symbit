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
      raise PolyError::NotImplemented("gf-pth-root")
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
  match extension {
    Some(ext_syms) =>
      if !ext_syms.is_empty() {
        raise PolyError::NotImplemented("algebraic-extension")
      }
    None => ()
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
      // Treat as an abstract field: assume irreducible after squarefree split.
      factors.push((p, mult))
    } else {
      let lin_parts = factor_linear_rationals(p)
      for lp in lin_parts {
        factors.push((lp, mult))
      }
    }
  }
  if !content.is_one() {
    let const_coeff = ensure_coeff_domain(content, self.domain)
    let const_poly = poly_from_term(
      monomial_one(self.gens.length()),
      const_coeff,
      self.gens,
      self.domain,
      self.order,
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
    Some((_, lc_fe)) => {
      match poly.domain {
        Domain::GFExt(_, _, _) => (make_monic(poly), @symnum.BigRational::one())
        Domain::AlgExt(_, _, _) => (make_monic(poly), @symnum.BigRational::one())
        Domain::ZZ =>
          {
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
fn try_split_with_nullspace(
  poly : Poly,
  basis : Array[Array[Int]],
  modulus : Int,
) -> (Poly, Poly)? raise PolyError {
  let deg_f = poly.degree(0)
  if deg_f <= 1 || basis.length() <= 1 {
    return None
  }
  for vec in basis {
    if vec.length() <= 1 {
      continue
    }
    for a in 0..<modulus {
      let shifted = dense_shift_constant(vec, a, modulus)
      let g_poly = dense_to_poly(shifted, poly.gens, poly.domain)
      let g = poly.gcd_univar(g_poly)
      let deg_g = g.degree(0)
      if deg_g > 0 && deg_g < deg_f {
        let q = poly.div_exact_univar(g)
        let left = make_monic(normalize_poly_mod(g))
        let right = make_monic(normalize_poly_mod(q))
        return Some((left, right))
      }
    }
  }
  None
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
          let const_elem =
            field_elem_from_seed(rng, p, k, mod_poly, poly.domain)
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

///|
fn dense_shift_constant(
  vec : Array[Int],
  shift : Int,
  modulus : Int,
) -> Array[Int] {
  let res = vec.copy()
  if res.is_empty() {
    res.push(0)
  }
  let val = ensure_pos_mod(res[0] - shift, modulus)
  res.set(0, val)
  res
}

///|
/// Dense helpers for GF(p)
fn ensure_pos_mod(value : Int, modulus : Int) -> Int {
  let mut v = value % modulus
  if v < 0 {
    v = v + modulus
  }
  v
}

///|
fn poly_to_dense_gf(poly : Poly, modulus : Int) -> Array[Int] raise PolyError {
  let deg = poly.degree(0)
  let coeffs : Array[Int] = Array::make(deg + 1, 0)
  for m, c in poly.coeffs {
    let k = m.exps[0]
    let norm = fe_expect_rational(c)
    let v = ensure_pos_mod(norm.numerator().to_int(), modulus)
    coeffs.set(k, v)
  }
  coeffs
}

///|
fn dense_to_poly(
  coeffs : Array[Int],
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  let map : Map[Monomial, FieldElem] = Map::new()
  let modulus = match domain {
    Domain::GF(p) => p
    _ => 0
  }
  for i in 0..<coeffs.length() {
    let raw = if modulus == 0 {
      coeffs[i]
    } else {
      ensure_pos_mod(coeffs[i], modulus)
    }
    if raw == 0 {
      continue
    }
    let mono = monomial_one(gens.length())
    mono.exps.set(0, i)
    add_term(map, mono, fe_from_int(raw, domain), domain)
  }
  Poly::{ coeffs: map, gens, domain, order: TermOrder::Lex }
}

///|
fn mod_inv_int(a : Int, m : Int) -> Int {
  let mut t0 = 0
  let mut t1 = 1
  let mut r0 = m
  let mut r1 = ensure_pos_mod(a, m)
  while r1 != 0 {
    let q = r0 / r1
    let temp_r = r0 - q * r1
    r0 = r1
    r1 = temp_r
    let temp_t = t0 - q * t1
    t0 = t1
    t1 = temp_t
  }
  if r0 != 1 {
    0
  } else {
    ensure_pos_mod(t0, m)
  }
}

///|
fn poly_mul_mod(a : Array[Int], b : Array[Int], modulus : Int) -> Array[Int] {
  let res : Array[Int] = Array::make(a.length() + b.length() - 1, 0)
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      let val = ensure_pos_mod(res[idx] + a[i] * b[j], modulus)
      res.set(idx, val)
    }
  }
  res
}

///|
fn poly_mod_poly(g : Array[Int], f : Array[Int], modulus : Int) -> Array[Int] {
  let mut r = trim_dense(g.copy(), modulus)
  let n = f.length()
  if n == 0 {
    return r
  }
  let denom_deg = n - 1
  let lc = f[denom_deg]
  if lc == 0 {
    return r
  }
  let lc_inv = mod_inv_int(lc, modulus)
  while r.length() > denom_deg {
    match r.last() {
      None => break
      Some(lead) => {
        let deg_r = r.length() - 1
        if lead % modulus == 0 {
          let _ = r.pop()
          continue
        }
        let coeff = ensure_pos_mod(lead * lc_inv, modulus)
        let shift = deg_r - denom_deg
        for i in 0..<f.length() {
          let idx = i + shift
          let val = ensure_pos_mod(r[idx] - coeff * f[i], modulus)
          r.set(idx, val)
        }
        r = trim_dense(r, modulus)
      }
    }
  }
  if r.is_empty() {
    Array::make(1, 0)
  } else {
    r
  }
}

///|
fn trim_dense(poly : Array[Int], modulus : Int) -> Array[Int] {
  let r = poly
  while r.length() > 1 {
    match r.last() {
      None => break
      Some(v) =>
        if v % modulus == 0 {
          let _ = r.pop()

        } else {
          break
        }
    }
  }
  if r.is_empty() {
    Array::make(1, 0)
  } else {
    r
  }
}

///|
fn pow_x_mod(exp : Int, modulus : Int, f : Array[Int]) -> Array[Int] {
  let mut res : Array[Int] = Array::make(1, 1)
  let mut base : Array[Int] = Array::make(2, 0)
  base.set(1, 1)
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      res = poly_mod_poly(poly_mul_mod(res, base, modulus), f, modulus)
    }
    e = e / 2
    if e > 0 {
      base = poly_mod_poly(poly_mul_mod(base, base, modulus), f, modulus)
    }
  }
  res
}

///|
fn berlekamp_nullspace(
  poly : Poly,
  modulus : Int,
) -> Array[Array[Int]] raise PolyError {
  let f_coeffs = poly_to_dense_gf(poly, modulus)
  let n = f_coeffs.length() - 1
  if n <= 0 {
    return Array::new()
  }
  let q_matrix : Array[Array[Int]] = Array::make(n, Array::make(n, 0))
  for col_idx in 0..<n {
    let col = pow_x_mod(modulus * col_idx, modulus, f_coeffs)
    for row in 0..<n {
      let v = if row < col.length() { col[row] } else { 0 }
      q_matrix[row][col_idx] = ensure_pos_mod(v, modulus)
    }
  }
  for i in 0..<n {
    q_matrix[i][i] = ensure_pos_mod(q_matrix[i][i] - 1, modulus)
  }
  row_reduce_nullspace(q_matrix, modulus)
}

///|
fn row_reduce_nullspace(
  mat : Array[Array[Int]],
  modulus : Int,
) -> Array[Array[Int]] {
  let rows = mat.length()
  if rows == 0 {
    return Array::new()
  }
  let cols = mat[0].length()
  let m = mat
  let pivot_cols : Array[Int] = Array::new()
  let mut r = 0
  for c in 0..<cols {
    let mut pivot = r
    while pivot < rows && ensure_pos_mod(m[pivot][c], modulus) == 0 {
      pivot = pivot + 1
    }
    if pivot == rows {
      continue
    }
    m.swap(r, pivot)
    let inv = mod_inv_int(m[r][c], modulus)
    for j in c..<cols {
      let val = ensure_pos_mod(m[r][j] * inv, modulus)
      m[r][j] = val
    }
    for i in 0..<rows {
      if i == r {
        continue
      }
      let factor = ensure_pos_mod(m[i][c], modulus)
      if factor == 0 {
        continue
      }
      for j in c..<cols {
        let val = ensure_pos_mod(m[i][j] - factor * m[r][j], modulus)
        m[i][j] = val
      }
    }
    pivot_cols.push(c)
    r = r + 1
    if r == rows {
      break
    }
  }
  let pivot_set : Map[Int, Unit] = Map::new()
  for c in pivot_cols {
    pivot_set.set(c, ())
  }
  let basis : Array[Array[Int]] = Array::new()
  for free_col in 0..<cols {
    if pivot_set.contains(free_col) {
      continue
    }
    let vec : Array[Int] = Array::make(cols, 0)
    vec.set(free_col, 1)
    let mut idx = 0
    for c in pivot_cols {
      let coeff = m[idx][free_col]
      let val = ensure_pos_mod(-coeff, modulus)
      vec.set(c, val)
      idx = idx + 1
    }
    basis.push(vec)
  }
  if basis.is_empty() {
    let v : Array[Int] = Array::make(cols, 0)
    basis.push(v)
  }
  basis
}
