///|
/// Dense univariate polynomial helpers over GF(p) with Int coefficients.
fn mod_pos(value : Int, p : Int) -> Int {
  let mut v = value % p
  if v < 0 {
    v = v + p
  }
  v
}

///|
fn inv_mod(a : Int, p : Int) -> Int raise PolyError {
  if p <= 1 {
    raise PolyError::BadModulus
  }
  let mut t0 = 0
  let mut t1 = 1
  let mut r0 = p
  let mut r1 = mod_pos(a, p)
  while r1 != 0 {
    let q = r0 / r1
    let r2 = r0 - q * r1
    r0 = r1
    r1 = r2
    let t2 = t0 - q * t1
    t0 = t1
    t1 = t2
  }
  if r0 != 1 {
    raise PolyError::DivisionByZero
  }
  mod_pos(t0, p)
}

///|
pub fn gf_degree(f : Array[Int]) -> Int {
  f.length() - 1
}

///|
pub fn gf_LC(f : Array[Int]) -> Int {
  if f.is_empty() { 0 } else { f[0] }
}

///|
pub fn gf_TC(f : Array[Int]) -> Int {
  if f.is_empty() { 0 } else { f[f.length() - 1] }
}

///|
pub fn gf_strip(f : Array[Int]) -> Array[Int] {
  if f.is_empty() || f[0] != 0 {
    return f
  }
  let mut k = 0
  for coeff in f {
    if coeff != 0 {
      break
    }
    k = k + 1
  }
  if k >= f.length() {
    return Array::new()
  }
  let out : Array[Int] = Array::new()
  for i in k..<f.length() {
    out.push(f[i])
  }
  out
}

///|
pub fn gf_trunc(f : Array[Int], p : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for c in f {
    out.push(mod_pos(c, p))
  }
  gf_strip(out)
}

///|
pub fn gf_add(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if f.is_empty() { return gf_trunc(g, p) }
  if g.is_empty() { return gf_trunc(f, p) }
  let len = if f.length() > g.length() { f.length() } else { g.length() }
  let out : Array[Int] = Array::make(len, 0)
  for i in 0..<len {
    let fi = i - (len - f.length())
    let gi = i - (len - g.length())
    let a = if fi >= 0 { f[fi] } else { 0 }
    let b = if gi >= 0 { g[gi] } else { 0 }
    out.set(i, mod_pos(a + b, p))
  }
  gf_strip(out)
}

///|
pub fn gf_sub(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if f.is_empty() {
    let out : Array[Int] = Array::new()
    for c in g {
      out.push(mod_pos(-c, p))
    }
    return gf_strip(out)
  }
  if g.is_empty() { return gf_trunc(f, p) }
  let len = if f.length() > g.length() { f.length() } else { g.length() }
  let out : Array[Int] = Array::make(len, 0)
  for i in 0..<len {
    let fi = i - (len - f.length())
    let gi = i - (len - g.length())
    let a = if fi >= 0 { f[fi] } else { 0 }
    let b = if gi >= 0 { g[gi] } else { 0 }
    out.set(i, mod_pos(a - b, p))
  }
  gf_strip(out)
}

///|
pub fn gf_mul(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] {
  if f.is_empty() || g.is_empty() {
    return Array::new()
  }
  let out_len = f.length() + g.length() - 1
  let out : Array[Int] = Array::make(out_len, 0)
  for i in 0..<f.length() {
    for j in 0..<g.length() {
      let idx = i + j
      out.set(idx, mod_pos(out[idx] + f[i] * g[j], p))
    }
  }
  gf_strip(out)
}

///|
pub fn gf_monic(f : Array[Int], p : Int) -> Array[Int] raise PolyError {
  if f.is_empty() {
    return f
  }
  let lc = mod_pos(f[0], p)
  if lc == 1 {
    return gf_trunc(f, p)
  }
  let inv = inv_mod(lc, p)
  let out : Array[Int] = Array::new()
  for c in f {
    out.push(mod_pos(c * inv, p))
  }
  gf_strip(out)
}

///|
pub fn gf_div(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> (Array[Int], Array[Int]) raise PolyError {
  let ff = gf_strip(f)
  let gg = gf_strip(g)
  if gg.is_empty() {
    raise PolyError::DivisionByZero
  }
  if ff.is_empty() {
    return (Array::new(), Array::new())
  }
  let df = ff.length() - 1
  let dg = gg.length() - 1
  if df < dg {
    return (Array::new(), ff)
  }
  let inv_lc = inv_mod(gg[0], p)
  let q_len = df - dg + 1
  let q : Array[Int] = Array::make(q_len, 0)
  let r = ff.copy()
  for i in 0..<q_len {
    let coeff = mod_pos(r[i] * inv_lc, p)
    q.set(i, coeff)
    if coeff != 0 {
      for j in 0..<=dg {
        let idx = i + j
        r.set(idx, mod_pos(r[idx] - coeff * gg[j], p))
      }
    }
  }
  let rem : Array[Int] = Array::new()
  for i in q_len..<r.length() {
    rem.push(r[i])
  }
  (gf_strip(q), gf_strip(rem))
}

///|
pub fn gf_quo(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] raise PolyError {
  let (q, _) = gf_div(f, g, p)
  q
}

///|
pub fn gf_rem(f : Array[Int], g : Array[Int], p : Int) -> Array[Int] raise PolyError {
  let (_, r) = gf_div(f, g, p)
  r
}

///|
pub fn gf_gcd(
  f : Array[Int],
  g : Array[Int],
  p : Int,
) -> Array[Int] raise PolyError {
  let mut a = gf_strip(f)
  let mut b = gf_strip(g)
  while !b.is_empty() {
    let (_, r) = gf_div(a, b, p)
    a = b
    b = r
  }
  gf_monic(a, p)
}
