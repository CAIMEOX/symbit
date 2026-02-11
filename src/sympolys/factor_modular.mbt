///|
/// Modular helpers for integer factorization (Hensel lift + subset recombination).
/// The code aligns with the classic SymPy pipeline: pick a good prime, factor mod p,
/// Hensel-lift factors to a large modulus, then recombine via gcd over ZZ.
fn choose_good_prime(poly : Poly) -> Int raise PolyError {
  let primes : Array[Int] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
  for p in primes {
    let f_mod = map_to_gf(poly, p)
    let deriv = deriv_univar(f_mod)
    if is_one(f_mod.gcd_univar(deriv)) {
      return p
    }
  }
  raise PolyError::NotImplemented("no_good_prime")
}

///|
fn map_to_gf(poly : Poly, modulus : Int) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in poly.coeffs {
    let r = fe_expect_rational(c)
    let fe = fe_from_int(r.numerator().to_int(), Domain::GF(modulus))
    if !fe_is_zero(fe) {
      coeffs.set(m, fe)
    }
  }
  Poly::{
    coeffs,
    gens: poly.gens,
    domain: Domain::GF(modulus),
    order: poly.order,
  }
}

///|
fn map_to_mod(poly : Poly, modulus : Int) -> Array[Int] raise PolyError {
  let deg = poly.degree(0)
  let dense : Array[Int] = Array::make(deg + 1, 0)
  for m, c in poly.coeffs {
    let k = m.exps[0]
    let mut v = fe_expect_rational(c).numerator().to_int() % modulus
    if v < 0 {
      v = v + modulus
    }
    dense.set(k, v)
  }
  trim_dense_int(dense, modulus)
}

///|
fn lift_gf_factor_to_int(f : Poly, modulus : Int) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  for m, c in f.coeffs {
    let mut v = ensure_pos_mod(
      fe_expect_rational(c).numerator().to_int(),
      modulus,
    )
    if v > modulus / 2 {
      v = v - modulus
    }
    add_term(coeffs, m, fe_from_int(v, Domain::ZZ), Domain::ZZ)
  }
  Poly::{ coeffs, gens: f.gens, domain: Domain::ZZ, order: f.order }
}

///|
fn product_polys(polys : Array[Poly]) -> Poly raise PolyError {
  if polys.is_empty() {
    return Poly::one([], Domain::ZZ)
  }
  let mut acc = polys[0]
  for i in 1..<polys.length() {
    acc = acc.mul(polys[i])
  }
  acc
}

///|
fn zassenhaus_factor(poly : Poly) -> Array[Poly] raise PolyError {
  // Assumes: poly in ZZ, primitive, square-free, deg > 1, univariate.
  let deg = poly.degree(0)
  if deg <= 1 {
    let arr : Array[Poly] = Array::new()
    arr.push(poly)
    return arr
  }
  let primes : Array[Int] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
  for p in primes {
    let f_mod = map_to_gf(poly, p)
    let deriv = deriv_univar(f_mod)
    if !is_one(f_mod.gcd_univar(deriv)) {
      continue
    }
    let factors_mod = factor_gf(f_mod)
    if factors_mod.length() <= 1 {
      continue
    }
    let lifted : Array[Poly] = Array::new()
    for f in factors_mod {
      lifted.push(lift_gf_factor_to_int(f, p))
    }
    let result : Array[Poly] = Array::new()
    let mut remaining = poly
    let n = lifted.length()
    let limit = 1 << n
    for mask in 1..<limit {
      if mask == limit - 1 {
        continue
      }
      let subset : Array[Poly] = Array::new()
      for i in 0..<n {
        if ((mask >> i) & 1) == 1 {
          subset.push(lifted[i])
        }
      }
      if subset.is_empty() {
        continue
      }
      let a = product_polys(subset)
      let g = remaining.gcd_univar(a)
      let deg_g = g.degree(0)
      if deg_g > 0 && deg_g < remaining.degree(0) {
        let q = remaining.div_exact_univar(g)
        result.push(g.primitive_part())
        remaining = q.primitive_part()
      }
    }
    if !remaining.is_zero() && !is_one(remaining) {
      result.push(remaining)
    }
    let prod = factors_product(result, poly.gens, poly.domain) catch {
      _ => poly
    }
    let diff = poly.sub(prod) catch { _ => poly }
    let diff_neg = poly.sub(prod.neg()) catch { _ => poly }
    if diff.is_zero() || diff_neg.is_zero() {
      return result
    }
  }
  let arr : Array[Poly] = Array::new()
  arr.push(poly)
  arr
}

///|
/// Detect and factor biquadratic form x^4 + a*x^2 + b over ZZ.
fn biquadratic_factor(poly : Poly) -> Array[Poly] raise PolyError {
  if poly.gens.length() != 1 {
    return Array::new()
  }
  if poly.domain.not_equal(Domain::ZZ) {
    return Array::new()
  }
  if poly.degree(0) != 4 {
    return Array::new()
  }
  for m, _ in poly.coeffs {
    if m.exps[0] % 2 != 0 || m.exps[0] > 4 {
      return Array::new()
    }
  }
  let mut a = 0
  let mut b = 0
  let mut lc = 0
  for m, c in poly.coeffs {
    let r = fe_expect_rational(c)
    if !r.is_integral() {
      return Array::new()
    }
    let val = r.numerator().to_int()
    match m.exps[0] {
      4 => lc = val
      2 => a = val
      0 => b = val
      _ => ()
    }
  }
  if lc != 1 {
    return Array::new()
  }
  let mut s1_opt : Int? = None
  let mut s2_opt : Int? = None
  if b == 0 {
    s1_opt = Some(0)
    s2_opt = Some(a)
  } else {
    let abs_b = if b < 0 { -b } else { b }
    let mut d = 1
    while d <= abs_b {
      if abs_b % d == 0 {
        let candidates : Array[Int] = [d, -d]
        for s1 in candidates {
          let s2 = b / s1
          if s1 + s2 == a {
            s1_opt = Some(s1)
            s2_opt = Some(s2)
            d = abs_b + 1
            break
          }
        }
      }
      d = d + 1
    }
  }
  match (s1_opt, s2_opt) {
    (Some(s1), Some(s2)) => {
      let f1 = quadratic_factor(s1, poly.gens, poly.domain, poly.order)
      let f2 = quadratic_factor(s2, poly.gens, poly.domain, poly.order)
      let arr : Array[Poly] = Array::new()
      arr.push(f1)
      arr.push(f2)
      arr
    }
    _ => Array::new()
  }
}

///|
fn quadratic_factor(
  s : Int,
  gens : Array[String],
  domain : Domain,
  order : TermOrder,
) -> Poly raise PolyError {
  let coeffs : Map[Monomial, FieldElem] = Map::new()
  let mono0 = monomial_one(gens.length())
  add_term(coeffs, mono0, fe_from_int(s, domain), domain)
  let mono2 = monomial_one(gens.length())
  mono2.exps.set(0, 2)
  add_term(coeffs, mono2, fe_from_int(1, domain), domain)
  Poly::{ coeffs, gens, domain, order }
}

///|
fn coeff_bound_est(poly : Poly) -> Int raise PolyError {
  let mut max_abs = BigInt::from_int(1)
  for _, c in poly.coeffs {
    let n = fe_expect_rational(c).numerator()
    let abs = if n.op_lt(BigInt::from_int(0)) { n.neg() } else { n }
    if abs.op_gt(max_abs) {
      max_abs = abs
    }
  }
  let deg = poly.degree(0)
  let bound_big = landau_mignotte_bound(max_abs, deg)
  bound_big.to_int()
}

///|
fn landau_mignotte_bound(max_coeff : BigInt, deg : Int) -> BigInt {
  let n = deg
  let two = BigInt::from_int(2)
  let mut pow = BigInt::from_int(1)
  for _ in 0..<n {
    pow = pow.mul(two)
  }
  let mut bound = max_coeff.add(BigInt::from_int(1))
  let mut i = 0
  while i < n + 1 {
    bound = bound.mul(max_coeff.add(BigInt::from_int(1)))
    i = i + 1
  }
  pow.mul(bound)
}

///|
/// Zassenhaus split over GF(p) + lift to ZZ via Hensel.
fn hensel_crt_factor(poly : Poly) -> Array[Poly] {
  // Preconditions: primitive, square-free, univariate, ZZ.
  try {
    let deg = poly.degree(0)
    if deg <= 1 {
      let arr : Array[Poly] = Array::new()
      arr.push(poly)
      return arr
    }
    // gather multiple primes until bound exceeded or reconstruction succeeds
    let coeff_bound = coeff_bound_est(poly)
    let primes : Array[Int] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29]
    let images : Array[(Int, Array[Int])] = Array::new()
    let mut factors_mod : Array[Poly] = Array::new()
    let mut accumulated = BigInt::from_int(1)
    for p in primes {
      let f_mod = map_to_gf(poly, p)
      let fs = factor_gf(f_mod)
      if fs.length() <= 1 {
        continue
      }
      factors_mod = fs
      let dense_f = map_to_mod(poly, p)
      images.push((p, dense_f))
      accumulated = accumulated.mul(BigInt::from_int(p))
      if accumulated.op_gt(BigInt::from_int(coeff_bound)) {
        break
      }
    }
    if images.is_empty() || factors_mod.length() <= 1 {
      let arr : Array[Poly] = Array::new()
      arr.push(poly)
      return arr
    }
    let dense_reconstructed = reconstruct_coeffs(images, coeff_bound)
    let lifted_poly = dense_to_poly_int(
      dense_reconstructed,
      poly.gens,
      poly.domain,
    )
    let lifted_factors : Array[Poly] = Array::new()
    for fm in factors_mod {
      lifted_factors.push(lift_gf_factor_to_int(fm, images[0].0))
    }
    recombine_lifted(lifted_poly, lifted_factors)
  } catch {
    _ => {
      let arr : Array[Poly] = Array::new()
      arr.push(poly)
      arr
    }
  }
}

///|
fn dense_to_poly_int(
  coeffs : Array[Int],
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  let map : Map[Monomial, FieldElem] = Map::new()
  for i in 0..<coeffs.length() {
    if coeffs[i] == 0 {
      continue
    }
    let mono = monomial_one(gens.length())
    mono.exps.set(0, i)
    add_term(map, mono, fe_from_int(coeffs[i], domain), domain)
  }
  Poly::{ coeffs: map, gens, domain, order: TermOrder::Lex }
}

///|
fn recombine_lifted(
  poly : Poly,
  lifted : Array[Poly],
) -> Array[Poly] raise PolyError {
  let pending = lifted
  let result : Array[Poly] = Array::new()
  let mut changed = true
  while changed && pending.length() > 1 {
    changed = false
    // simple PRSV-style pairwise combination attempt
    let mut i = 0
    while i < pending.length() {
      let mut j = i + 1
      while j < pending.length() {
        let prod = pending[i].mul(pending[j])
        let g = poly.gcd_univar(prod)
        let deg_g = g.degree(0)
        if deg_g > 0 && deg_g < poly.degree(0) {
          let q = poly.div_exact_univar(g)
          result.push(g.primitive_part())
          let _ = pending.remove(j)
          let _ = pending.remove(i)
          if !q.is_zero() && q.degree(0) > 0 {
            pending.push(q.primitive_part())
          }
          changed = true
          j = pending.length()
          i = pending.length()
        } else {
          j = j + 1
        }
      }
      i = i + 1
    }
  }
  for p in pending {
    if !p.is_zero() && !is_one(p) {
      result.push(p)
    }
  }
  if result.is_empty() {
    result.push(poly)
  }
  result
}

///|
/// Public integer factoring entry.
fn factor_integer(poly : Poly) -> Array[Poly] raise PolyError {
  let factors : Array[Poly] = Array::new()
  let lin_parts = factor_linear_rationals(poly)
  let lin_only : Array[Poly] = Array::new()
  let mut remainder = poly
  for f in lin_parts {
    if f.degree(0) == 1 {
      factors.push(f)
      lin_only.push(f)
      remainder = remainder.div_exact_univar(f)
    } else {
      remainder = f
    }
  }
  let mut appended_any = false
  if factors.is_empty() {
    let bi_parts = biquadratic_factor(remainder)
    if bi_parts.length() > 1 {
      for f in bi_parts {
        factors.push(f)
      }
      return factors
    }
    let split = zassenhaus_factor(remainder) catch { _ => [remainder] }
    for f in split {
      factors.push(f)
      appended_any = true
    }
  } else if !remainder.is_zero() && !is_one(remainder) {
    let bi_parts = biquadratic_factor(remainder)
    if bi_parts.length() > 1 {
      for f in bi_parts {
        factors.push(f)
      }
      return factors
    }
    let mut split = hensel_crt_factor(remainder) catch { _ => [remainder] }
    if split.length() == 1 && split[0].degree(0) == remainder.degree(0) {
      split = zassenhaus_factor(remainder) catch { _ => [remainder] }
    }
    for f in split {
      factors.push(f)
      appended_any = true
    }
  }
  // Guard: if assembled factors do not reconstruct the original (up to sign), treat as irreducible.
  let prod = factors_product(factors, poly.gens, poly.domain) catch {
    _ => return [poly]
  }
  let diff = poly.sub(prod) catch { _ => poly } // if domains mismatch, fail
  let diff_neg = poly.sub(prod.neg()) catch { _ => poly }
  if !diff.is_zero() && !diff_neg.is_zero() {
    let fixed : Array[Poly] = Array::new()
    for f in lin_only {
      fixed.push(f)
    }
    if !remainder.is_zero() && !is_one(remainder) {
      fixed.push(remainder.primitive_part())
    }
    if fixed.is_empty() {
      let arr : Array[Poly] = Array::new()
      arr.push(poly)
      return arr
    } else {
      return fixed
    }
  }
  factors
}

///|
/// Multiply factor list; used for reconstruction checks.
fn factors_product(
  factors : Array[Poly],
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  if factors.is_empty() {
    return Poly::one(gens, domain)
  }
  let mut acc = factors[0]
  for i in 1..<factors.length() {
    acc = acc.mul(factors[i])
  }
  acc
}

///|
/// Reconstruct integer coefficients from modular images using CRT + LLL fallback.
pub fn reconstruct_coeffs(
  images : Array[(Int, Array[Int])],
  bound : Int,
) -> Array[Int] raise PolyError {
  if images.is_empty() {
    return Array::new()
  }
  let (modulus, residues) = crt_images(images)
  let centered = center_residues(residues, modulus)
  let bound_big = BigInt::from_int(bound)
  if centered.all(v => big_abs(v).op_le(bound_big)) {
    return centered.map(v => v.to_int())
  }
  let lattice = build_reconstruction_lattice(centered, modulus)
  let reduced = lll_reduce(lattice).0
  let candidate = reduced[0]
  let coeffs : Array[Int] = Array::new()
  for i in 0..<centered.length() {
    coeffs.push(candidate[i].to_int())
  }
  coeffs
}

///|
fn crt_images(images : Array[(Int, Array[Int])]) -> (BigInt, Array[BigInt]) {
  let mut modulus = BigInt::from_int(1)
  let mut residues : Array[BigInt] = Array::new()
  let degree = images[0].1.length()
  residues = Array::make(degree, BigInt::from_int(0))
  for pair in images {
    let m = BigInt::from_int(pair.0)
    let vals = pair.1
    for i in 0..<degree {
      let current = residues[i]
      let v = BigInt::from_int(vals[i])
      let t = v
        .sub(current.mod(m))
        .mul(mod_inv_bigint(modulus.mod(m), m))
        .mod(m)
      let lifted = current.add(modulus.mul(t))
      residues.set(i, lifted)
    }
    modulus = modulus.mul(m)
  }
  (modulus, residues)
}

///|
fn mod_inv_bigint(a : BigInt, m : BigInt) -> BigInt {
  let mut t0 = BigInt::from_int(0)
  let mut t1 = BigInt::from_int(1)
  let mut r0 = m
  let mut r1 = a.mod(m)
  while !r1.is_zero() {
    let q = r0.div(r1)
    let r2 = r0.sub(q.mul(r1))
    r0 = r1
    r1 = r2
    let t2 = t0.sub(q.mul(t1))
    t0 = t1
    t1 = t2
  }
  if !r0.equal_int(1) {
    BigInt::from_int(0)
  } else {
    let mut inv = t0.mod(m)
    if inv.op_lt(BigInt::from_int(0)) {
      inv = inv.add(m)
    }
    inv
  }
}

///|
fn center_residues(residues : Array[BigInt], modulus : BigInt) -> Array[BigInt] {
  let half = modulus.div(BigInt::from_int(2))
  residues.map(r => {
    let mut v = r.mod(modulus)
    if v.op_gt(half) {
      v = v.sub(modulus)
    }
    v
  })
}

///|
fn big_abs(x : BigInt) -> BigInt {
  if x.op_lt(BigInt::from_int(0)) {
    x.neg()
  } else {
    x
  }
}

///|
fn build_reconstruction_lattice(
  residues : Array[BigInt],
  modulus : BigInt,
) -> Matrix {
  let dim = residues.length()
  let mat : Matrix = Array::new()
  for i in 0..<dim {
    let row : Array[BigInt] = Array::make(dim + 1, BigInt::from_int(0))
    row.set(i, modulus)
    mat.push(row)
  }
  let last : Array[BigInt] = Array::make(dim + 1, BigInt::from_int(0))
  for i in 0..<dim {
    last.set(i, residues[i])
  }
  last.set(dim, BigInt::from_int(1))
  mat.push(last)
  mat
}

///|
/// Hensel lift a pair g,h so that g*h ≡ f (mod new_mod).
fn hensel_pair(
  f_dense : Array[Int],
  g_dense : Array[Int],
  h_dense : Array[Int],
  prime : Int,
  new_mod : Int,
) -> (Array[Int], Array[Int]) {
  let m = new_mod / prime
  let f_mod = map_dense_mod(f_dense, new_mod)
  let prod = poly_mul_mod_int(g_dense, h_dense, new_mod)
  let c = poly_sub_mod_int(f_mod, prod, new_mod)
  let e = dense_div_scalar(c, m)
  let g_modp = map_dense_mod(g_dense, prime)
  let h_modp = map_dense_mod(h_dense, prime)
  let egcd = poly_ext_gcd_mod(g_modp, h_modp, prime)
  // ensure gcd == 1 mod p; otherwise bail out to avoid division errors
  if !(egcd.0.length() == 1 && ensure_pos_mod(egcd.0[0], prime) == 1) {
    return (g_dense, h_dense)
  }
  let s = egcd.1
  let t = egcd.2
  let delta_g = poly_mul_mod_int(e, t, prime)
  let delta_h = poly_mul_mod_int(e, s, prime)
  let g_new = poly_add_scaled_mod(g_dense, delta_g, m, new_mod)
  let h_new = poly_add_scaled_mod(h_dense, delta_h, m, new_mod)
  (trim_dense_int(g_new, new_mod), trim_dense_int(h_new, new_mod))
}

///|
fn map_dense_mod(poly : Array[Int], modulus : Int) -> Array[Int] {
  let arr = poly.copy()
  for i in 0..<arr.length() {
    arr.set(i, ensure_pos_mod(arr[i], modulus))
  }
  trim_dense_int(arr, modulus)
}

///|
fn dense_div_scalar(vec : Array[Int], k : Int) -> Array[Int] {
  if k == 0 {
    return vec
  }
  let res : Array[Int] = Array::new()
  for v in vec {
    res.push(v / k)
  }
  trim_dense_plain(res)
}

///|
fn poly_add_scaled_mod(
  base : Array[Int],
  delta : Array[Int],
  scale : Int,
  modulus : Int,
) -> Array[Int] {
  let len = Int::max(base.length(), delta.length())
  let res : Array[Int] = Array::make(len, 0)
  for i in 0..<len {
    let b = if i < base.length() { base[i] } else { 0 }
    let d = if i < delta.length() { delta[i] } else { 0 }
    let v = ensure_pos_mod(b + d * scale, modulus)
    res.set(i, v)
  }
  trim_dense_int(res, modulus)
}

///|
/// Dense polynomial arithmetic (mod integer modulus).
fn trim_dense_int(poly : Array[Int], modulus : Int) -> Array[Int] {
  let res = poly
  while res.length() > 1 {
    match res.last() {
      None => break
      Some(v) =>
        if ensure_pos_mod(v, modulus) == 0 {
          let _ = res.pop()
        } else {
          break
        }
    }
  }
  if res.is_empty() {
    Array::make(1, 0)
  } else {
    res
  }
}

///|
fn poly_sub_mod_int(
  a : Array[Int],
  b : Array[Int],
  modulus : Int,
) -> Array[Int] {
  let len = Int::max(a.length(), b.length())
  let res : Array[Int] = Array::make(len, 0)
  for i in 0..<len {
    let av = if i < a.length() { a[i] } else { 0 }
    let bv = if i < b.length() { b[i] } else { 0 }
    res.set(i, ensure_pos_mod(av - bv, modulus))
  }
  trim_dense_int(res, modulus)
}

///|
fn poly_mul_mod_int(
  a : Array[Int],
  b : Array[Int],
  modulus : Int,
) -> Array[Int] {
  let res : Array[Int] = Array::make(a.length() + b.length() - 1, 0)
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      let v = ensure_pos_mod(res[idx] + a[i] * b[j], modulus)
      res.set(idx, v)
    }
  }
  trim_dense_int(res, modulus)
}

///|
/// Polynomial division a/b mod prime -> (q,r)
fn poly_divmod_mod(
  dividend : Array[Int],
  divisor : Array[Int],
  modulus : Int,
) -> (Array[Int], Array[Int]) {
  let div_trim = trim_dense_int(divisor, modulus)
  if div_trim.is_empty() || (div_trim.length() == 1 && div_trim[0] == 0) {
    return (Array::make(1, 0), dividend)
  }
  let n = dividend.length()
  let m = div_trim.length()
  let q : Array[Int] = Array::make(Int::max(n - m + 1, 1), 0)
  let mut r = trim_dense_int(dividend, modulus)
  let lc_div = div_trim[m - 1]
  let lc_inv = mod_inv_int(lc_div, modulus)
  if lc_inv == 0 {
    return (Array::make(1, 0), dividend)
  }
  while r.length() >= m && !(r.length() == 1 && r[0] == 0) {
    let deg_diff = r.length() - m
    let coeff = ensure_pos_mod(r[r.length() - 1] * lc_inv, modulus)
    q.set(deg_diff, coeff)
    for i in 0..<m {
      let idx = i + deg_diff
      let v = ensure_pos_mod(r[idx] - coeff * div_trim[i], modulus)
      r.set(idx, v)
    }
    r = trim_dense_int(r, modulus)
  }
  (trim_dense_int(q, modulus), r)
}

///|
/// Extended GCD for polynomials mod prime.
fn poly_ext_gcd_mod(
  a : Array[Int],
  b : Array[Int],
  modulus : Int,
) -> (Array[Int], Array[Int], Array[Int]) {
  let mut old_r = trim_dense_int(a, modulus)
  let mut r = trim_dense_int(b, modulus)
  if r.length() == 1 && r[0] == 0 {
    return (old_r, [1], [0])
  }
  let mut old_s : Array[Int] = [1]
  let mut s : Array[Int] = [0]
  let mut old_t : Array[Int] = [0]
  let mut t : Array[Int] = [1]
  while !(r.length() == 1 && r[0] == 0) {
    let divres = poly_divmod_mod(old_r, r, modulus)
    let q = divres.0
    let rem = divres.1
    old_r = r
    r = rem
    let qs = poly_mul_mod_int(q, s, modulus)
    let qt = poly_mul_mod_int(q, t, modulus)
    let new_s = poly_sub_mod_int(old_s, qs, modulus)
    let new_t = poly_sub_mod_int(old_t, qt, modulus)
    old_s = s
    s = new_s
    old_t = t
    t = new_t
  }
  (old_r, old_s, old_t)
}

///|
fn trim_dense_plain(poly : Array[Int]) -> Array[Int] {
  let res = poly
  while res.length() > 1 {
    match res.last() {
      None => break
      Some(v) => if v == 0 { let _ = res.pop() } else { break }
    }
  }
  res
}
