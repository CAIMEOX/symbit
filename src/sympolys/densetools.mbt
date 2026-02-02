///|
/// Advanced dense tools for recursive polynomials (subset).
pub fn dup_integrate(
  f : Array[FieldElem],
  m : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if m <= 0 || f.is_empty() {
    return f
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(m, zero)
  let n = f.length()
  for i in 0..<n {
    let idx = n - 1 - i
    let c = f[idx]
    let mut denom = i + 1
    if m > 1 {
      for j in 1..<m {
        denom = denom * (i + j + 1)
      }
    }
    let inv = fe_inv(fe_from_int(denom, domain))
    out.insert(0, fe_mul(c, inv))
  }
  out
}

///|
pub fn dmp_integrate(
  f : DensePoly,
  m : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_integrate(coeffs, m, domain))
  }
  if m <= 0 || dmp_zero_p(f, u) {
    return f
  }
  let out = dmp_zeros(m, u - 1, domain)
  let items = dmp_items(f)
  let n = items.length()
  for i in 0..<n {
    let idx = n - 1 - i
    let c = items[idx]
    let mut denom = i + 1
    if m > 1 {
      for j in 1..<m {
        denom = denom * (i + j + 1)
      }
    }
    let inv = fe_from_int(denom, domain)
    out.insert(0, dmp_exquo_ground(c, inv, u - 1, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
fn rec_integrate_in(
  g : DensePoly,
  m : Int,
  v : Int,
  i : Int,
  j : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i == j {
    return dmp_integrate(g, m, v, domain)
  }
  let items = dmp_items(g)
  let w = v - 1
  let out : Array[DensePoly] = Array::new()
  for c in items {
    out.push(rec_integrate_in(c, m, w, i + 1, j, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
pub fn dmp_integrate_in(
  f : DensePoly,
  m : Int,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  rec_integrate_in(f, m, u, 0, j, domain)
}

///|
pub fn dup_diff(
  f : Array[FieldElem],
  m : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if m <= 0 {
    return f
  }
  let n = dup_degree(f)
  if n < m {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::new()
  if m == 1 {
    let mut k = n
    for i in 0..<(f.length() - m) {
      let coeff = fe_mul(fe_from_int(k, domain), f[i])
      out.push(coeff)
      k = k - 1
    }
  } else {
    let mut k = n
    for i in 0..<(f.length() - m) {
      let mut scale = k
      let mut t = k - 1
      let mut left = m - 1
      while left > 0 {
        scale = scale * t
        t = t - 1
        left = left - 1
      }
      let coeff = fe_mul(fe_from_int(scale, domain), f[i])
      out.push(coeff)
      k = k - 1
    }
  }
  dup_strip(out)
}

///|
pub fn dmp_diff(
  f : DensePoly,
  m : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dmp_to_coeffs(f)
    return dmp_from_coeffs(dup_diff(coeffs, m, domain))
  }
  if m <= 0 || dmp_zero_p(f, u) {
    return f
  }
  let n = dmp_degree(f, u)
  if n < m {
    return dmp_zero(u)
  }
  let items = dmp_items(f)
  let out : Array[DensePoly] = Array::new()
  if m == 1 {
    let mut k = n
    for i in 0..<(items.length() - m) {
      let coeff = dmp_mul_ground(items[i], fe_from_int(k, domain), u - 1, domain)
      out.push(coeff)
      k = k - 1
    }
  } else {
    let mut k = n
    for i in 0..<(items.length() - m) {
      let mut scale = k
      let mut t = k - 1
      let mut left = m - 1
      while left > 0 {
        scale = scale * t
        t = t - 1
        left = left - 1
      }
      let coeff = dmp_mul_ground(items[i], fe_from_int(scale, domain), u - 1, domain)
      out.push(coeff)
      k = k - 1
    }
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
fn rec_diff_in(
  g : DensePoly,
  m : Int,
  v : Int,
  i : Int,
  j : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i == j {
    return dmp_diff(g, m, v, domain)
  }
  let items = dmp_items(g)
  let w = v - 1
  let out : Array[DensePoly] = Array::new()
  for c in items {
    out.push(rec_diff_in(c, m, w, i + 1, j, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
pub fn dmp_diff_in(
  f : DensePoly,
  m : Int,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  rec_diff_in(f, m, u, 0, j, domain)
}

///|
pub fn dup_eval(
  f : Array[FieldElem],
  a : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(a) {
    return dup_TC(f)
  }
  let mut result = fe_from_int(0, domain)
  for c in f {
    result = fe_add(fe_mul(result, a), c)
  }
  result
}

///|
pub fn dmp_eval(
  f : DensePoly,
  a : FieldElem,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dmp_to_coeffs(f)
    return dmp_ground(dup_eval(coeffs, a, domain), -1)
  }
  if fe_is_zero(a) {
    return dmp_TC(f)
  }
  let items = dmp_items(f)
  let mut result = dmp_LC(f)
  let v = u - 1
  for i in 1..<items.length() {
    result = dmp_mul_ground(result, a, v, domain)
    result = dmp_add(result, items[i], v, domain)
  }
  result
}

///|
fn rec_eval_in(
  g : DensePoly,
  a : FieldElem,
  v : Int,
  i : Int,
  j : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i == j {
    return dmp_eval(g, a, v, domain)
  }
  let items = dmp_items(g)
  let w = v - 1
  let out : Array[DensePoly] = Array::new()
  for c in items {
    out.push(rec_eval_in(c, a, w, i + 1, j, domain))
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
pub fn dmp_eval_in(
  f : DensePoly,
  a : FieldElem,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  rec_eval_in(f, a, u, 0, j, domain)
}

///|
pub fn dup_monic(
  f : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return f
  }
  let lc = dup_LC(f)
  if fe_is_one(lc) {
    f
  } else {
    dup_exquo_ground(f, lc, domain)
  }
}

///|
pub fn dmp_ground_monic(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    return dmp_from_coeffs(dup_monic(dmp_to_coeffs(f), domain))
  }
  if dmp_zero_p(f, u) {
    return f
  }
  let lc = dmp_ground_LC(f, u)
  if fe_is_one(lc) {
    f
  } else {
    dmp_exquo_ground(f, lc, u, domain)
  }
}
