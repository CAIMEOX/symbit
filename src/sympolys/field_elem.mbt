///|
/// Field elements for QQ, GF(p), and GF(p^k) using dense polynomial representation.
pub enum FieldElem {
  QQ(@symnum.BigRational)
  CC(@symnum.BigRational, @symnum.BigRational) // a + b*i
  GFp(Int, Int) // (p, value)
  GFExt(Int, Array[Int], Array[Int]) // (p, coeffs low→high, mod_poly)
  AlgExt(Domain, Array[FieldElem], Poly, String) // (base domain, coeffs, minimal poly, generator name)
}

///|
fn fe_pos_mod(value : Int, modulus : Int) -> Int {
  let mut v = value % modulus
  if v < 0 {
    v = v + modulus
  }
  v
}

///|
fn fe_trim(poly : Array[Int], p : Int) -> Array[Int] {
  let res = poly
  while res.length() > 1 {
    match res.last() {
      Some(v) => if fe_pos_mod(v, p) == 0 { let _ = res.pop() } else { break }
      None => break
    }
  }
  if res.is_empty() {
    Array::make(1, 0)
  } else {
    res
  }
}

///|
fn fe_poly_add(a : Array[Int], b : Array[Int], p : Int) -> Array[Int] {
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let res : Array[Int] = Array::make(n, 0)
  for i in 0..<n {
    let av = if i < a.length() { a[i] } else { 0 }
    let bv = if i < b.length() { b[i] } else { 0 }
    res.set(i, fe_pos_mod(av + bv, p))
  }
  fe_trim(res, p)
}

///|
fn fe_poly_mul(a : Array[Int], b : Array[Int], p : Int) -> Array[Int] {
  let res : Array[Int] = Array::make(a.length() + b.length() - 1, 0)
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      res.set(idx, fe_pos_mod(res[idx] + a[i] * b[j], p))
    }
  }
  fe_trim(res, p)
}

///|
fn fe_mod_inv_int(a : Int, m : Int) -> Int {
  let mut t0 = 0
  let mut t1 = 1
  let mut r0 = m
  let mut r1 = fe_pos_mod(a, m)
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
    fe_pos_mod(t0, m)
  }
}

///|
fn fe_poly_mod(poly : Array[Int], mod_poly : Array[Int], p : Int) -> Array[Int] {
  let mut r = fe_trim(poly, p)
  let m_deg = mod_poly.length() - 1
  let lc = mod_poly[m_deg]
  let lc_inv = fe_mod_inv_int(lc, p)
  while r.length() > m_deg {
    let deg_r = r.length() - 1
    let lead = r[deg_r]
    if lead % p == 0 {
      let _ = r.pop()
      continue
    }
    let coeff = fe_pos_mod(lead * lc_inv, p)
    let shift = deg_r - m_deg
    for i in 0..<mod_poly.length() {
      let idx = i + shift
      r.set(idx, fe_pos_mod(r[idx] - coeff * mod_poly[i], p))
    }
    r = fe_trim(r, p)
  }
  r
}

///|
fn fe_int_pow(base : Int, exp : Int) -> Int {
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
fn fe_pow(base : FieldElem, exp : Int) -> FieldElem raise PolyError {
  if exp < 0 {
    return fe_inv(fe_pow(base, -exp))
  }
  let mut result = match base {
    FieldElem::QQ(_) => FieldElem::QQ(@symnum.BigRational::one())
    FieldElem::CC(_, _) =>
      FieldElem::CC(@symnum.BigRational::one(), @symnum.BigRational::zero())
    FieldElem::GFp(p, _) => FieldElem::GFp(p, 1)
    FieldElem::GFExt(p, _, m) => FieldElem::GFExt(p, [1], m)
    FieldElem::AlgExt(base, _, minpoly, gen) =>
      FieldElem::AlgExt(base, [fe_from_int(1, base)], minpoly, gen)
  }
  let mut b = base
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = fe_mul(result, b)
    }
    e = e / 2
    if e > 0 {
      b = fe_mul(b, b)
    }
  }
  result
}

///|
pub fn fe_is_zero(a : FieldElem) -> Bool {
  match a {
    FieldElem::QQ(x) => x.is_zero()
    FieldElem::CC(a, b) => a.is_zero() && b.is_zero()
    FieldElem::GFp(_, v) => v == 0
    FieldElem::GFExt(_, coeffs, _) => coeffs.all(v => v == 0)
    FieldElem::AlgExt(_, coeffs, _, _) => coeffs.all(v => fe_is_zero(v))
  }
}

///|
pub fn fe_is_one(a : FieldElem) -> Bool {
  match a {
    FieldElem::QQ(x) => x.is_one()
    FieldElem::CC(a, b) => a.is_one() && b.is_zero()
    FieldElem::GFp(_, v) => v == 1
    FieldElem::GFExt(_, coeffs, _) => coeffs.length() == 1 && coeffs[0] == 1
    FieldElem::AlgExt(_, coeffs, _, _) =>
      coeffs.length() == 1 && fe_is_one(coeffs[0])
  }
}

///|
pub fn fe_is_negative(a : FieldElem) -> Bool {
  match a {
    FieldElem::QQ(x) => x.compare(@symnum.BigRational::zero()) < 0
    FieldElem::CC(_, _) => false
    FieldElem::GFp(_, _) => false
    FieldElem::GFExt(_, _, _) => false
    FieldElem::AlgExt(_, _, _, _) => false
  }
}

///|
pub fn fe_is_positive(a : FieldElem) -> Bool {
  match a {
    FieldElem::QQ(x) => x.compare(@symnum.BigRational::zero()) > 0
    FieldElem::CC(_, _) => false
    FieldElem::GFp(_, _) => false
    FieldElem::GFExt(_, _, _) => false
    FieldElem::AlgExt(_, _, _, _) => false
  }
}

///|
pub fn fe_expect_rational(a : FieldElem) -> @symnum.BigRational raise PolyError {
  match a {
    FieldElem::QQ(x) => x
    FieldElem::CC(_, _) =>
      raise PolyError::NotImplemented("complex-as-rational")
    FieldElem::GFp(_, v) => @symnum.BigRational::from_int(v)
    FieldElem::GFExt(_, _, _) =>
      raise PolyError::NotImplemented("gfext-as-rational")
    FieldElem::AlgExt(_, _, _, _) =>
      raise PolyError::NotImplemented("algext-as-rational")
  }
}

///|
pub fn fe_add(a : FieldElem, b : FieldElem) -> FieldElem raise PolyError {
  match (a, b) {
    (FieldElem::QQ(x), FieldElem::QQ(y)) => FieldElem::QQ(x.add_r(y))
    (FieldElem::CC(a1, b1), FieldElem::CC(a2, b2)) =>
      FieldElem::CC(a1.add_r(a2), b1.add_r(b2))
    (FieldElem::CC(a1, b1), FieldElem::QQ(y)) => FieldElem::CC(a1.add_r(y), b1)
    (FieldElem::QQ(x), FieldElem::CC(a2, b2)) => FieldElem::CC(x.add_r(a2), b2)
    (FieldElem::GFp(p1, x), FieldElem::GFp(p2, y)) =>
      if p1 != p2 {
        raise PolyError::DomainMismatch
      } else {
        FieldElem::GFp(p1, fe_pos_mod(x + y, p1))
      }
    (FieldElem::GFExt(p, coeffs, mod_poly), FieldElem::GFExt(p2, c2, m2)) =>
      if p != p2 || !mod_poly.equal(m2) {
        raise PolyError::DomainMismatch
      } else {
        FieldElem::GFExt(p, fe_poly_add(coeffs, c2, p), mod_poly)
      }
    (FieldElem::AlgExt(base, c1, m1, g1), FieldElem::AlgExt(base2, c2, m2, g2)) =>
      if base.not_equal(base2) || !minpoly_equal(m1, m2) || g1 != g2 {
        raise PolyError::DomainMismatch
      } else {
        FieldElem::AlgExt(base, fe_alg_poly_add(c1, c2), m1, g1)
      }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn fe_neg(a : FieldElem) -> FieldElem {
  match a {
    FieldElem::QQ(x) => FieldElem::QQ(x.neg_r())
    FieldElem::CC(a, b) => FieldElem::CC(a.neg_r(), b.neg_r())
    FieldElem::GFp(p, x) => FieldElem::GFp(p, fe_pos_mod(-x, p))
    FieldElem::GFExt(p, coeffs, mod_poly) =>
      FieldElem::GFExt(p, coeffs.map(v => fe_pos_mod(-v, p)), mod_poly)
    FieldElem::AlgExt(base, coeffs, minpoly, gen) =>
      FieldElem::AlgExt(base, coeffs.map(v => fe_neg(v)), minpoly, gen)
  }
}

///|
pub fn fe_sub(a : FieldElem, b : FieldElem) -> FieldElem raise PolyError {
  fe_add(a, fe_neg(b))
}

///|
pub fn fe_mul(a : FieldElem, b : FieldElem) -> FieldElem raise PolyError {
  match (a, b) {
    (FieldElem::QQ(x), FieldElem::QQ(y)) => FieldElem::QQ(x.mul_r(y))
    (FieldElem::CC(a1, b1), FieldElem::CC(a2, b2)) => {
      let real = a1.mul_r(a2).add_r(b1.mul_r(b2).neg_r())
      let imag = a1.mul_r(b2).add_r(b1.mul_r(a2))
      FieldElem::CC(real, imag)
    }
    (FieldElem::CC(a1, b1), FieldElem::QQ(y)) =>
      FieldElem::CC(a1.mul_r(y), b1.mul_r(y))
    (FieldElem::QQ(x), FieldElem::CC(a2, b2)) =>
      FieldElem::CC(x.mul_r(a2), x.mul_r(b2))
    (FieldElem::GFp(p1, x), FieldElem::GFp(p2, y)) =>
      if p1 != p2 {
        raise PolyError::DomainMismatch
      } else {
        FieldElem::GFp(p1, fe_pos_mod(x * y, p1))
      }
    (FieldElem::GFExt(p, coeffs, mod_poly), FieldElem::GFExt(p2, c2, m2)) =>
      if p != p2 || !mod_poly.equal(m2) {
        raise PolyError::DomainMismatch
      } else {
        let prod = fe_poly_mul(coeffs, c2, p)
        FieldElem::GFExt(p, fe_poly_mod(prod, mod_poly, p), mod_poly)
      }
    (FieldElem::AlgExt(base, c1, m1, g1), FieldElem::AlgExt(base2, c2, m2, g2)) =>
      if base.not_equal(base2) || !minpoly_equal(m1, m2) || g1 != g2 {
        raise PolyError::DomainMismatch
      } else {
        let prod = fe_alg_poly_mul(c1, c2, m1)
        FieldElem::AlgExt(base, fe_alg_poly_mod(prod, m1), m1, g1)
      }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn fe_inv(a : FieldElem) -> FieldElem raise PolyError {
  match a {
    FieldElem::QQ(x) =>
      FieldElem::QQ(
        x.reciprocal() catch {
          _ => raise PolyError::DivisionByZero
        },
      )
    FieldElem::CC(a, b) => {
      let denom = a.mul_r(a).add_r(b.mul_r(b))
      if denom.is_zero() {
        raise PolyError::DivisionByZero
      }
      let real = a.div_r(denom) catch { _ => raise PolyError::DivisionByZero }
      let imag = b.neg_r().div_r(denom) catch {
          _ => raise PolyError::DivisionByZero
        }
      FieldElem::CC(real, imag)
    }
    FieldElem::GFp(p, x) => {
      if x == 0 {
        raise PolyError::DivisionByZero
      }
      FieldElem::GFp(p, fe_mod_inv_int(x, p))
    }
    FieldElem::GFExt(p, coeffs, mod_poly) => {
      if fe_is_zero(FieldElem::GFExt(p, coeffs, mod_poly)) {
        raise PolyError::DivisionByZero
      }
      let deg = mod_poly.length() - 1
      let q = fe_int_pow(p, deg)
      fe_pow(FieldElem::GFExt(p, coeffs, mod_poly), q - 2)
    }
    FieldElem::AlgExt(base, coeffs, minpoly, gen) => {
      if fe_is_zero(FieldElem::AlgExt(base, coeffs, minpoly, gen)) {
        raise PolyError::DivisionByZero
      }
      let inv_coeffs = fe_alg_poly_inv(coeffs, minpoly)
      FieldElem::AlgExt(base, inv_coeffs, minpoly, gen)
    }
  }
}

///|
pub fn fe_from_int(val : Int, domain : Domain) -> FieldElem raise PolyError {
  match domain {
    Domain::QQ | Domain::ZZ => FieldElem::QQ(@symnum.BigRational::from_int(val))
    Domain::CC =>
      FieldElem::CC(
        @symnum.BigRational::from_int(val),
        @symnum.BigRational::zero(),
      )
    Domain::GF(p) => FieldElem::GFp(p, fe_pos_mod(val, p))
    Domain::GFExt(p, _, m) => FieldElem::GFExt(p, [fe_pos_mod(val, p)], m)
    Domain::AlgExt(base, gens, rels) => {
      let (minpoly, gen) = load_algext_minpoly(base, gens, rels)
      let base_const = fe_from_int(val, base)
      FieldElem::AlgExt(base, [base_const], minpoly, gen)
    }
    Domain::RR => FieldElem::QQ(@symnum.BigRational::from_int(val))
    Domain::Frac(_) => raise PolyError::NotImplemented("frac-from-int")
  }
}

///|
pub fn fe_from_rational(
  val : @symnum.BigRational,
  domain : Domain,
) -> FieldElem raise PolyError {
  match domain {
    Domain::QQ => FieldElem::QQ(val)
    Domain::ZZ =>
      if val.is_integral() {
        FieldElem::QQ(val)
      } else {
        raise PolyError::CoefficientNotInteger
      }
    Domain::CC => FieldElem::CC(val, @symnum.BigRational::zero())
    Domain::RR => FieldElem::QQ(val)
    Domain::GF(p) => {
      let norm = normalize_mod(val, Domain::GF(p))
      FieldElem::GFp(p, fe_pos_mod(norm.numerator().to_int(), p))
    }
    Domain::GFExt(p, _, m) => {
      let norm = normalize_mod(val, Domain::GFExt(p, 1, m))
      FieldElem::GFExt(p, [fe_pos_mod(norm.numerator().to_int(), p)], m)
    }
    Domain::Frac(inner) => fe_from_rational(val, inner)
    Domain::AlgExt(base, gens, rels) => {
      let (minpoly, gen) = load_algext_minpoly(base, gens, rels)
      let base_const = fe_from_rational(val, base)
      FieldElem::AlgExt(base, [base_const], minpoly, gen)
    }
  }
}

///|
pub fn fe_to_string(a : FieldElem) -> String {
  match a {
    FieldElem::QQ(x) => x.to_string()
    FieldElem::CC(a, b) => {
      let sb = StringBuilder::new()
      sb.write_string(a.to_string())
      if !b.is_zero() {
        let neg = b.numerator().op_lt(BigInt::from_int(0))
        if neg {
          sb.write_string(" - ")
          sb.write_string(b.neg_r().to_string())
        } else {
          sb.write_string(" + ")
          sb.write_string(b.to_string())
        }
        sb.write_char('i')
      }
      sb.to_string()
    }
    FieldElem::GFp(_, v) => v.to_string()
    FieldElem::GFExt(_, coeffs, _) => coeffs.to_string()
    FieldElem::AlgExt(_, coeffs, minpoly, gen) =>
      fe_algext_to_string(coeffs, gen, minpoly)
  }
}

///|
fn fe_algext_to_string(
  coeffs : Array[FieldElem],
  gen : String,
  _minpoly : Poly,
) -> String {
  let sb = StringBuilder::new()
  let mut first = true
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if fe_is_zero(c) {
      continue
    }
    if !first {
      sb.write_string(" + ")
    }
    first = false
    let coeff_str = fe_to_string(c)
    if i == 0 {
      sb.write_string(coeff_str)
    } else {
      if !fe_is_one(c) {
        sb.write_string(coeff_str)
        sb.write_char('*')
      }
      sb.write_string(gen)
      if i > 1 {
        sb.write_char('^')
        sb.write_string(i.to_string())
      }
    }
  }
  if first {
    "0"
  } else {
    sb.to_string()
  }
}

///|
fn minpoly_equal(a : Poly, b : Poly) -> Bool {
  a.to_string().equal(b.to_string())
}

///|
/// Dense helpers for algebraic extension arithmetic.
fn fe_alg_poly_trim(coeffs : Array[FieldElem]) -> Array[FieldElem] {
  let res = coeffs
  while res.length() > 1 {
    match res.last() {
      Some(v) => if fe_is_zero(v) { let _ = res.pop() } else { break }
      None => break
    }
  }
  if res.is_empty() {
    res.push(FieldElem::QQ(@symnum.BigRational::zero()))
  }
  res
}

///|
fn fe_alg_poly_add(
  a : Array[FieldElem],
  b : Array[FieldElem],
) -> Array[FieldElem] raise PolyError {
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let res : Array[FieldElem] = Array::make(
    n,
    FieldElem::QQ(@symnum.BigRational::zero()),
  )
  for i in 0..<n {
    let av = if i < a.length() {
      a[i]
    } else {
      FieldElem::QQ(@symnum.BigRational::zero())
    }
    let bv = if i < b.length() {
      b[i]
    } else {
      FieldElem::QQ(@symnum.BigRational::zero())
    }
    res.set(i, fe_add(av, bv))
  }
  fe_alg_poly_trim(res)
}

///|
fn fe_alg_poly_sub(
  a : Array[FieldElem],
  b : Array[FieldElem],
) -> Array[FieldElem] raise PolyError {
  let n = if a.length() > b.length() { a.length() } else { b.length() }
  let res : Array[FieldElem] = Array::make(
    n,
    FieldElem::QQ(@symnum.BigRational::zero()),
  )
  for i in 0..<n {
    let av = if i < a.length() {
      a[i]
    } else {
      FieldElem::QQ(@symnum.BigRational::zero())
    }
    let bv = if i < b.length() {
      b[i]
    } else {
      FieldElem::QQ(@symnum.BigRational::zero())
    }
    res.set(i, fe_sub(av, bv))
  }
  fe_alg_poly_trim(res)
}

///|
fn dense_from_poly(poly : Poly) -> Array[FieldElem] {
  let deg = poly.degree(0)
  let res : Array[FieldElem] = Array::make(
    deg + 1,
    FieldElem::QQ(@symnum.BigRational::zero()),
  )
  for m, c in poly.coeffs {
    let k = m.exps[0]
    res.set(k, c)
  }
  res
}

///|
fn fe_alg_poly_mod(
  poly : Array[FieldElem],
  minpoly : Poly,
) -> Array[FieldElem] raise PolyError {
  let mut r = fe_alg_poly_trim(poly)
  let m_deg = minpoly.degree(0)
  let m_dense = dense_from_poly(minpoly)
  if fe_is_zero(m_dense[m_deg]) || !fe_is_one(m_dense[m_deg]) {
    raise PolyError::DomainNotField
  }
  while r.length() - 1 >= m_deg {
    let deg_r = r.length() - 1
    let lead = r[deg_r]
    if fe_is_zero(lead) {
      let _ = r.pop()
      continue
    }
    let shift = deg_r - m_deg
    for i in 0..<=m_deg {
      let idx = i + shift
      let coeff = fe_mul(lead, m_dense[i])
      let cur = r[idx]
      r.set(idx, fe_sub(cur, coeff))
    }
    r = fe_alg_poly_trim(r)
  }
  r
}

///|
fn fe_alg_poly_mul(
  a : Array[FieldElem],
  b : Array[FieldElem],
  minpoly : Poly,
) -> Array[FieldElem] raise PolyError {
  let res : Array[FieldElem] = Array::make(
    a.length() + b.length() - 1,
    FieldElem::QQ(@symnum.BigRational::zero()),
  )
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      let accum = res[idx]
      res.set(idx, fe_add(accum, fe_mul(a[i], b[j])))
    }
  }
  fe_alg_poly_mod(res, minpoly)
}

///|
fn fe_alg_poly_divmod(
  dividend : Array[FieldElem],
  divisor : Array[FieldElem],
) -> (Array[FieldElem], Array[FieldElem]) raise PolyError {
  let div_trim = fe_alg_poly_trim(divisor)
  if div_trim.is_empty() || (div_trim.length() == 1 && fe_is_zero(div_trim[0])) {
    return (
      Array::make(1, FieldElem::QQ(@symnum.BigRational::zero())),
      dividend,
    )
  }
  let n = dividend.length()
  let m = div_trim.length()
  let q : Array[FieldElem] = Array::make(
    if n >= m {
      n - m + 1
    } else {
      1
    },
    FieldElem::QQ(@symnum.BigRational::zero()),
  )
  let mut r = fe_alg_poly_trim(dividend)
  let lc_div = div_trim[m - 1]
  let lc_inv = fe_inv(lc_div)
  while r.length() >= m && !(r.length() == 1 && fe_is_zero(r[0])) {
    let deg_diff = r.length() - m
    let coeff = fe_mul(r[r.length() - 1], lc_inv)
    q.set(deg_diff, coeff)
    for i in 0..<m {
      let idx = i + deg_diff
      let v = fe_sub(r[idx], fe_mul(coeff, div_trim[i]))
      r.set(idx, v)
    }
    r = fe_alg_poly_trim(r)
  }
  (fe_alg_poly_trim(q), r)
}

///|
fn fe_alg_poly_inv(
  a : Array[FieldElem],
  minpoly : Poly,
) -> Array[FieldElem] raise PolyError {
  let mut old_r = dense_from_poly(minpoly)
  let mut r = fe_alg_poly_trim(a)
  if r.length() == 1 && fe_is_zero(r[0]) {
    raise PolyError::DivisionByZero
  }
  let zero = FieldElem::QQ(@symnum.BigRational::zero())
  let one = FieldElem::QQ(@symnum.BigRational::one())
  let mut old_s : Array[FieldElem] = [one]
  let mut s : Array[FieldElem] = [zero]
  let mut old_t : Array[FieldElem] = [zero]
  let mut t : Array[FieldElem] = [one]
  while !(r.length() == 1 && fe_is_zero(r[0])) {
    let (q, rem) = fe_alg_poly_divmod(old_r, r)
    old_r = r
    r = rem
    let qs = fe_alg_poly_mul(q, s, minpoly)
    let qt = fe_alg_poly_mul(q, t, minpoly)
    let new_s = fe_alg_poly_sub(old_s, qs)
    let new_t = fe_alg_poly_sub(old_t, qt)
    old_s = s
    s = new_s
    old_t = t
    t = new_t
  }
  if !(old_r.length() == 1 && fe_is_one(old_r[0])) {
    raise PolyError::DomainNotField
  }
  s
}

///|
fn load_algext_minpoly(
  base : Domain,
  gens : Array[String],
  rels : Array[@symcore.Expr],
) -> (Poly, String) raise PolyError {
  if gens.length() != 1 || rels.length() != 1 {
    raise PolyError::BadGenerator("algext")
  }
  let gen = gens[0]
  match base {
    Domain::QQ | Domain::GF(_) | Domain::GFExt(_, _, _) => ()
    _ => raise PolyError::DomainNotField
  }
  let builder = PolyBuilder::new([gen], base)
  let minpoly = builder.from_expr(rels[0]) catch { e => raise e }
  if minpoly.degree(0) <= 0 {
    raise PolyError::BadExponent
  }
  (make_monic_if_field(minpoly), gen)
}

///|
pub impl Show for FieldElem with output(self, logger : &Logger) -> Unit {
  logger.write_string(fe_to_string(self))
}

///|
test "GF(p) arithmetic basics" {
  let a = FieldElem::GFp(5, 2)
  let b = FieldElem::GFp(5, 4)
  inspect(fe_add(a, b).to_string(), content="1")
  inspect(fe_mul(a, b).to_string(), content="3")
  inspect(fe_inv(a).to_string(), content="3")
}

///|
test "GF(p^2) multiplication and inverse" {
  // GF(3^2) with modulus x^2 + 1 over GF(3)
  let m = [1, 0, 1]
  let a = FieldElem::GFExt(3, [1, 1], m) // 1 + x
  let b = FieldElem::GFExt(3, [2, 1], m) // 2 + x
  let prod = fe_mul(a, b)
  inspect(prod.to_string(), content="[1]")
  let inv = fe_inv(a)
  inspect(fe_mul(a, inv).to_string(), content="[1]")
}
