///|
/// Dense (descending degree, SymPy-compatible) helpers for univariate coefficient arrays.
pub fn dup_LC(coeffs : Array[FieldElem]) -> FieldElem raise PolyError {
  if coeffs.is_empty() {
    fe_from_int(0, Domain::ZZ)
  } else {
    coeffs[0]
  }
}

///|
pub fn dup_TC(coeffs : Array[FieldElem]) -> FieldElem raise PolyError {
  if coeffs.is_empty() {
    fe_from_int(0, Domain::ZZ)
  } else {
    coeffs[coeffs.length() - 1]
  }
}

///|
pub fn dup_degree(coeffs : Array[FieldElem]) -> Int raise PolyError {
  if coeffs.is_empty() {
    -1
  } else {
    coeffs.length() - 1
  }
}

///|
pub fn dup_strip(coeffs : Array[FieldElem]) -> Array[FieldElem] raise PolyError {
  let mut start = 0
  let n = coeffs.length()
  while start < n && fe_is_zero(coeffs[start]) {
    start = start + 1
  }
  if start == n {
    return Array::new()
  }
  let zero = fe_from_int(0, Domain::QQ)
  let out_len = n - start
  let out : Array[FieldElem] = Array::make(out_len, zero)
  for i in 0..<out_len {
    out.set(i, coeffs[start + i])
  }
  out
}

///|
pub fn dup_reverse(
  coeffs : Array[FieldElem],
) -> Array[FieldElem] raise PolyError {
  let n = coeffs.length()
  if n == 0 {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::new()
  let mut i = n
  while i > 0 {
    i = i - 1
    out.push(coeffs[i])
  }
  dup_strip(out)
}

///|
/// Helper to create a zero-like FieldElem sharing domain with sample.
fn fe_zero_like(sample : FieldElem) -> FieldElem raise PolyError {
  match sample {
    FieldElem::QQ(_) | FieldElem::CC(_, _) => fe_from_int(0, Domain::QQ)
    FieldElem::GFp(p, _) => fe_from_int(0, Domain::GF(p))
    FieldElem::GFExt(p, _, m) => FieldElem::GFExt(p, [0], m)
    FieldElem::AlgExt(base, _, _, _) => fe_from_int(0, base)
  }
}

///|
/// Recursive dense polynomial representation for helpers below.
pub enum DensePoly {
  Coef(FieldElem)
  Poly(Array[DensePoly])
}

///|
pub fn dense_coef(c : FieldElem) -> DensePoly {
  DensePoly::Coef(c)
}

///|
pub fn dense_poly(items : Array[DensePoly]) -> DensePoly {
  DensePoly::Poly(items)
}

///|
fn dense_from_coeffs(coeffs : Array[FieldElem]) -> DensePoly {
  if coeffs.is_empty() {
    DensePoly::Poly(Array::new())
  } else {
    let out : Array[DensePoly] = Array::make(
      coeffs.length(),
      DensePoly::Coef(coeffs[0]),
    )
    for i in 0..<coeffs.length() {
      out.set(i, DensePoly::Coef(coeffs[i]))
    }
    DensePoly::Poly(out)
  }
}

///|
/// Convert a univariate DensePoly into coefficient array.
fn dense_to_coeffs(p : DensePoly) -> Array[FieldElem] raise PolyError {
  match p {
    DensePoly::Coef(c) => {
      let coeffs : Array[FieldElem] = [c]
      dup_strip(coeffs)
    }
    DensePoly::Poly(items) => {
      if items.is_empty() {
        return Array::new()
      }
      let coeffs : Array[FieldElem] = Array::new()
      for it in items {
        match it {
          DensePoly::Coef(c) => coeffs.push(c)
          DensePoly::Poly(_) => raise PolyError::NotUnivariate
        }
      }
      dup_strip(coeffs)
    }
  }
}

///|
fn dense_is_zero(p : DensePoly) -> Bool {
  match p {
    DensePoly::Coef(c) => fe_is_zero(c)
    DensePoly::Poly(items) => {
      for it in items {
        if !dense_is_zero(it) {
          return false
        }
      }
      true
    }
  }
}

///|
/// Compute variable count for a dense polynomial.
fn dense_var_count(p : DensePoly) -> Int {
  match p {
    DensePoly::Coef(_) => -1
    DensePoly::Poly(items) =>
      if items.is_empty() {
        0
      } else {
        let mut max_depth = -1
        for it in items {
          let d = dense_var_count(it)
          if d > max_depth {
            max_depth = d
          }
        }
        max_depth + 1
      }
  }
}

///|
/// Collect min/max nesting levels; mismatched levels imply invalid structure.
fn dense_level_range(p : DensePoly, depth : Int) -> (Int, Int) {
  match p {
    DensePoly::Coef(_) => (depth - 1, depth - 1)
    DensePoly::Poly(items) =>
      if items.is_empty() {
        (depth, depth)
      } else {
        let (min_level0, max_level0) = dense_level_range(items[0], depth + 1)
        let mut min_level = min_level0
        let mut max_level = max_level0
        for i in 1..<items.length() {
          let (cmin, cmax) = dense_level_range(items[i], depth + 1)
          if cmin < min_level {
            min_level = cmin
          }
          if cmax > max_level {
            max_level = cmax
          }
        }
        (min_level, max_level)
      }
  }
}

///|
pub fn dmp_validate(p : DensePoly) -> (DensePoly, Int) raise PolyError {
  let (min_level, max_level) = dense_level_range(p, 0)
  if min_level != max_level {
    raise PolyError::NonPolynomial
  }
  let u = max_level
  let stripped = dmp_strip(p)
  (stripped, u)
}

///|
fn dense_strip_with_u(p : DensePoly, u : Int) -> DensePoly raise PolyError {
  if u <= 0 {
    match p {
      DensePoly::Coef(_) => p
      DensePoly::Poly(items) => {
        let mut all_coef = true
        let coeffs : Array[FieldElem] = Array::new()
        for it in items {
          match it {
            DensePoly::Coef(c) => coeffs.push(c)
            DensePoly::Poly(_) => {
              all_coef = false
              break
            }
          }
        }
        if all_coef {
          let stripped = dup_strip(coeffs)
          return dense_from_coeffs(stripped)
        }
        DensePoly::Poly(items)
      }
    }
  } else {
    match p {
      DensePoly::Coef(_) => p
      DensePoly::Poly(items) => {
        if dmp_zero_p(p, u) {
          return p
        }
        let stripped : Array[DensePoly] = Array::new()
        for it in items {
          stripped.push(dense_strip_with_u(it, u - 1))
        }
        let mut start = 0
        while start < stripped.length() && dmp_zero_p(stripped[start], u - 1) {
          start = start + 1
        }
        if start == stripped.length() {
          return dmp_zero(u)
        }
        let out_len = stripped.length() - start
        let out : Array[DensePoly] = Array::make(out_len, stripped[start])
        for i in 0..<out_len {
          out.set(i, stripped[start + i])
        }
        DensePoly::Poly(out)
      }
    }
  }
}

///|
pub fn dmp_LC(p : DensePoly) -> DensePoly {
  match p {
    DensePoly::Coef(_) => p
    DensePoly::Poly(items) =>
      if items.is_empty() {
        DensePoly::Poly(Array::new())
      } else {
        items[0]
      }
  }
}

///|
pub fn dmp_TC(p : DensePoly) -> DensePoly {
  match p {
    DensePoly::Coef(_) => p
    DensePoly::Poly(items) =>
      if items.is_empty() {
        DensePoly::Poly(Array::new())
      } else {
        items[items.length() - 1]
      }
  }
}

///|
pub fn dmp_ground_LC(p : DensePoly, u : Int) -> FieldElem raise PolyError {
  if u <= 0 {
    match p {
      DensePoly::Coef(c) => c
      DensePoly::Poly(items) =>
        if items.is_empty() {
          fe_from_int(0, Domain::QQ)
        } else {
          match items[0] {
            DensePoly::Coef(c) => c
            DensePoly::Poly(_) => fe_from_int(0, Domain::QQ)
          }
        }
    }
  } else {
    match p {
      DensePoly::Coef(c) => c
      DensePoly::Poly(items) =>
        if items.is_empty() {
          fe_from_int(0, Domain::QQ)
        } else {
          dmp_ground_LC(items[0], u - 1)
        }
    }
  }
}

///|
pub fn dmp_ground_TC(p : DensePoly, u : Int) -> FieldElem raise PolyError {
  if u <= 0 {
    match p {
      DensePoly::Coef(c) => c
      DensePoly::Poly(items) =>
        if items.is_empty() {
          fe_from_int(0, Domain::QQ)
        } else {
          match items[items.length() - 1] {
            DensePoly::Coef(c) => c
            DensePoly::Poly(_) => fe_from_int(0, Domain::QQ)
          }
        }
    }
  } else {
    match p {
      DensePoly::Coef(c) => c
      DensePoly::Poly(items) =>
        if items.is_empty() {
          fe_from_int(0, Domain::QQ)
        } else {
          dmp_ground_TC(items[items.length() - 1], u - 1)
        }
    }
  }
}

///|
pub fn dmp_true_LT(
  p : DensePoly,
  u : Int,
) -> (Array[Int], FieldElem) raise PolyError {
  let exps = Array::make(u + 1, 0)
  let mut cur = p
  let mut depth = u
  let mut idx = 0
  while depth > 0 {
    match cur {
      DensePoly::Coef(c) => {
        exps.set(idx, 0)
        return (exps, c)
      }
      DensePoly::Poly(items) => {
        if items.is_empty() {
          let z = fe_from_int(0, Domain::QQ)
          return (exps, z)
        }
        exps.set(idx, items.length() - 1)
        cur = items[0]
      }
    }
    idx = idx + 1
    depth = depth - 1
  }
  match cur {
    DensePoly::Coef(c) => {
      exps.set(idx, 0)
      (exps, c)
    }
    DensePoly::Poly(items) =>
      if items.is_empty() {
        let z = fe_from_int(0, Domain::QQ)
        (exps, z)
      } else {
        exps.set(idx, items.length() - 1)
        match items[0] {
          DensePoly::Coef(c) => (exps, c)
          DensePoly::Poly(_) => {
            let z = fe_from_int(0, Domain::QQ)
            (exps, z)
          }
        }
      }
  }
}

///|
pub fn dmp_degree(p : DensePoly, u : Int) -> Int {
  if dmp_zero_p(p, u) {
    -1
  } else {
    match p {
      DensePoly::Coef(_) => 0
      DensePoly::Poly(items) => items.length() - 1
    }
  }
}

///|
pub fn dmp_degree_in(
  p : DensePoly,
  var_idx : Int,
  u : Int,
) -> Int raise PolyError {
  if var_idx < 0 || var_idx > u {
    raise PolyError::BadExponent
  }
  if var_idx == 0 {
    return dmp_degree(p, u)
  }
  match p {
    DensePoly::Coef(c) => if fe_is_zero(c) { -1 } else { 0 }
    DensePoly::Poly(items) => {
      let mut max_deg = -1
      for item in items {
        let d = dmp_degree_in(item, var_idx - 1, u - 1)
        if d > max_deg {
          max_deg = d
        }
      }
      max_deg
    }
  }
}

///|
pub fn dmp_degree_list(p : DensePoly, u : Int) -> Array[Int] raise PolyError {
  let exps : Array[Int] = Array::make(u + 1, -1)
  for i in 0..<=u {
    exps.set(i, dmp_degree_in(p, i, u))
  }
  exps
}

///|
pub fn dmp_strip(p : DensePoly) -> DensePoly raise PolyError {
  let u = dense_var_count(p)
  if u < 0 {
    p
  } else {
    dense_strip_with_u(p, u)
  }
}

///|
pub fn dmp_reverse(p : DensePoly) -> DensePoly raise PolyError {
  match p {
    DensePoly::Coef(_) => p
    DensePoly::Poly(items) => {
      let mut all_coef = true
      let coeffs : Array[FieldElem] = Array::new()
      for it in items {
        match it {
          DensePoly::Coef(c) => coeffs.push(c)
          DensePoly::Poly(_) => {
            all_coef = false
            break
          }
        }
      }
      if all_coef {
        let rev = dup_reverse(coeffs)
        return dense_from_coeffs(rev)
      }
      let n = items.length()
      if n == 0 {
        return DensePoly::Poly(Array::new())
      }
      let out : Array[DensePoly] = Array::make(n, DensePoly::Poly(Array::new()))
      for i in 0..<n {
        let child = dmp_reverse(items[i])
        out.set(n - 1 - i, child)
      }
      let rev = DensePoly::Poly(out)
      dmp_strip(rev)
    }
  }
}

///|
pub fn dup_copy(f : Array[FieldElem]) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::make(f.length(), fe_zero_like(f[0]))
  for i in 0..<f.length() {
    out.set(i, f[i])
  }
  out
}

///|
pub fn dmp_copy(f : DensePoly, u : Int) -> DensePoly {
  if u == 0 {
    match f {
      DensePoly::Poly(items) => {
        let out : Array[DensePoly] = Array::make(
          items.length(),
          DensePoly::Poly(Array::new()),
        )
        for i in 0..<items.length() {
          out.set(i, dmp_copy(items[i], 0))
        }
        DensePoly::Poly(out)
      }
      DensePoly::Coef(c) => DensePoly::Coef(c)
    }
  } else {
    match f {
      DensePoly::Poly(items) => {
        let out : Array[DensePoly] = Array::make(
          items.length(),
          DensePoly::Poly(Array::new()),
        )
        for i in 0..<items.length() {
          out.set(i, dmp_copy(items[i], u - 1))
        }
        DensePoly::Poly(out)
      }
      DensePoly::Coef(c) => DensePoly::Coef(c)
    }
  }
}

///|
pub fn dup_normal(f : Array[FieldElem]) -> Array[FieldElem] raise PolyError {
  dup_strip(f)
}

///|
pub fn dmp_normal(f : DensePoly, u : Int) -> DensePoly raise PolyError {
  if u == 0 {
    match f {
      DensePoly::Poly(items) => {
        let coeffs : Array[FieldElem] = Array::new()
        for it in items {
          match it {
            DensePoly::Coef(c) => coeffs.push(c)
            DensePoly::Poly(_) =>
              coeffs.push(
                fe_from_int(0, Domain::QQ),
              )
          }
        }
        let stripped = dup_strip(coeffs)
        if stripped.is_empty() {
          DensePoly::Poly(Array::new())
        } else {
          let out : Array[DensePoly] = Array::make(
            stripped.length(),
            DensePoly::Coef(stripped[0]),
          )
          for i in 0..<stripped.length() {
            out.set(i, DensePoly::Coef(stripped[i]))
          }
          DensePoly::Poly(out)
        }
      }
      DensePoly::Coef(c) => DensePoly::Coef(c)
    }
  } else {
    match f {
      DensePoly::Poly(items) => {
        let mapped : Array[DensePoly] = Array::make(
          items.length(),
          DensePoly::Poly(Array::new()),
        )
        for i in 0..<items.length() {
          mapped.set(
            i,
            dmp_normal(items[i], u - 1),
          )
        }
        dmp_strip(DensePoly::Poly(mapped))
      }
      DensePoly::Coef(c) => DensePoly::Coef(c)
    }
  }
}

///|
fn fe_convert_domain(
  c : FieldElem,
  target : Domain,
) -> FieldElem raise PolyError {
  let r = fe_expect_rational(c)
  ensure_coeff_domain(r, target)
}

///|
pub fn dup_convert(
  f : Array[FieldElem],
  _k0 : Domain,
  k1 : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::make(f.length(), fe_zero_like(f[0]))
  for i in 0..<f.length() {
    out.set(i, fe_convert_domain(f[i], k1))
  }
  dup_strip(out)
}

///|
pub fn dmp_convert(
  f : DensePoly,
  u : Int,
  k0 : Domain,
  k1 : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    match f {
      DensePoly::Poly(items) => {
        let coeffs : Array[FieldElem] = Array::new()
        for it in items {
          match it {
            DensePoly::Coef(c) => coeffs.push(fe_convert_domain(c, k1))
            DensePoly::Poly(_) =>
              coeffs.push(
                fe_from_int(0, k1),
              )
          }
        }
        let stripped = dup_strip(coeffs)
        if stripped.is_empty() {
          DensePoly::Poly(Array::new())
        } else {
          let out : Array[DensePoly] = Array::make(
            stripped.length(),
            DensePoly::Coef(stripped[0]),
          )
          for i in 0..<stripped.length() {
            out.set(i, DensePoly::Coef(stripped[i]))
          }
          DensePoly::Poly(out)
        }
      }
      DensePoly::Coef(c) => DensePoly::Coef(fe_convert_domain(c, k1))
    }
  } else {
    match f {
      DensePoly::Poly(items) => {
        let mapped : Array[DensePoly] = Array::make(
          items.length(),
          DensePoly::Poly(Array::new()),
        )
        for i in 0..<items.length() {
          mapped.set(
            i,
            dmp_convert(items[i], u - 1, k0, k1),
          )
        }
        dmp_strip(DensePoly::Poly(mapped))
      }
      DensePoly::Coef(c) => DensePoly::Coef(fe_convert_domain(c, k1))
    }
  }
}

///|
pub fn dup_nth(f : Array[FieldElem], n : Int) -> FieldElem raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  if f.is_empty() {
    return fe_from_int(0, Domain::ZZ)
  }
  let deg = dup_degree(f)
  if n > deg {
    return fe_zero_like(f[0])
  }
  let idx = f.length() - 1 - n
  f[idx]
}

///|
pub fn dmp_nth(f : DensePoly, n : Int, u : Int) -> DensePoly raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  match f {
    DensePoly::Poly(items) => {
      let deg = dmp_degree(f, u)
      if n > deg {
        return dmp_zero(u - 1)
      }
      let idx = items.length() - 1 - n
      items[idx]
    }
    DensePoly::Coef(c) =>
      if n == 0 {
        DensePoly::Coef(c)
      } else {
        dmp_zero(u - 1)
      }
  }
}

///|
pub fn dmp_zero(u : Int) -> DensePoly {
  let mut p : DensePoly = DensePoly::Poly(Array::new())
  if u < 0 {
    return p
  }
  let mut i = 0
  while i < u {
    let arr : Array[DensePoly] = Array::make(1, p)
    p = DensePoly::Poly(arr)
    i = i + 1
  }
  p
}

///|
pub fn dmp_zero_p(f : DensePoly, u : Int) -> Bool {
  if u == 0 {
    match f {
      DensePoly::Poly(items) => items.is_empty()
      DensePoly::Coef(c) => fe_is_zero(c)
    }
  } else {
    match f {
      DensePoly::Poly(items) =>
        if items.length() != 1 {
          false
        } else {
          dmp_zero_p(items[0], u - 1)
        }
      DensePoly::Coef(_) => false
    }
  }
}

///|
pub fn dmp_ground(c : FieldElem, u : Int) -> DensePoly {
  if fe_is_zero(c) {
    return dmp_zero(u)
  }
  if u < 0 {
    return DensePoly::Coef(c)
  }
  let mut p : DensePoly = DensePoly::Poly([DensePoly::Coef(c)])
  let mut i = 0
  while i < u {
    p = DensePoly::Poly([p])
    i = i + 1
  }
  p
}

///|
pub fn dmp_ground_p(
  f : DensePoly,
  c : FieldElem?,
  u : Int,
) -> Bool raise PolyError {
  if c is Some(cc) && fe_is_zero(cc) {
    return dmp_zero_p(f, u)
  }
  let mut cur = f
  let mut depth = u
  while depth > 0 {
    match cur {
      DensePoly::Poly(items) =>
        if items.length() != 1 {
          return false
        } else {
          cur = items[0]
        }
      DensePoly::Coef(_) => return false
    }
    depth = depth - 1
  }
  match c {
    None =>
      match cur {
        DensePoly::Poly(items) => items.length() <= 1
        DensePoly::Coef(_) => true
      }
    Some(cc) =>
      match cur {
        DensePoly::Poly(items) =>
          if items.length() != 1 {
            false
          } else {
            match items[0] {
              DensePoly::Coef(c0) => fe_is_zero(fe_sub(c0, cc))
              DensePoly::Poly(_) => false
            }
          }
        DensePoly::Coef(c0) => fe_is_zero(fe_sub(c0, cc))
      }
  }
}

///|
pub fn dmp_one(u : Int, domain : Domain) -> DensePoly raise PolyError {
  let one = fe_from_int(1, domain)
  dmp_ground(one, u)
}

///|
pub fn dmp_one_p(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Bool raise PolyError {
  let one = fe_from_int(1, domain)
  dmp_ground_p(f, Some(one), u)
}

///|
pub fn dmp_ground_nth(
  f : DensePoly,
  nlist : Array[Int],
  u : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  let zero = fe_from_int(0, domain)
  let mut cur = f
  let mut v = u
  for n in nlist {
    if n < 0 {
      raise PolyError::BadExponent
    }
    match cur {
      DensePoly::Poly(items) => {
        if n >= items.length() {
          return zero
        }
        let d = dmp_degree(cur, v)
        let idx = d - n
        if idx < 0 || idx >= items.length() {
          return zero
        }
        cur = items[idx]
        v = v - 1
      }
      DensePoly::Coef(_) => {
        if n != 0 {
          return zero
        }
        v = v - 1
      }
    }
  }
  match cur {
    DensePoly::Coef(c) => c
    DensePoly::Poly(items) =>
      if items.is_empty() {
        zero
      } else if items.length() == 1 {
        match items[0] {
          DensePoly::Coef(c0) => c0
          DensePoly::Poly(_) => zero
        }
      } else {
        zero
      }
  }
}

///|
pub fn dmp_zeros(
  n : Int,
  u : Int,
  domain : Domain,
) -> Array[DensePoly] raise PolyError {
  if n <= 0 {
    return Array::new()
  }
  if u < 0 {
    let zero = fe_from_int(0, domain)
    let out : Array[DensePoly] = Array::make(n, DensePoly::Coef(zero))
    return out
  }
  let out : Array[DensePoly] = Array::new()
  for _ in 0..<n {
    out.push(dmp_zero(u))
  }
  out
}

///|
pub fn dmp_grounds(
  c : FieldElem,
  n : Int,
  u : Int,
  _domain : Domain,
) -> Array[DensePoly] {
  if n <= 0 {
    return Array::new()
  }
  let out : Array[DensePoly] = Array::new()
  if u < 0 {
    for _ in 0..<n {
      out.push(DensePoly::Coef(c))
    }
    return out
  }
  for _ in 0..<n {
    out.push(dmp_ground(c, u))
  }
  out
}

///|
pub fn dmp_negative_p(f : DensePoly, u : Int) -> Bool raise PolyError {
  let lc = dmp_ground_LC(f, u)
  fe_is_negative(lc)
}

///|
pub fn dmp_positive_p(f : DensePoly, u : Int) -> Bool raise PolyError {
  let lc = dmp_ground_LC(f, u)
  fe_is_positive(lc)
}

///|
/// Integer gcd (non-negative).
fn igcd(a : Int, b : Int) -> Int {
  let mut x = if a < 0 { -a } else { a }
  let mut y = if b < 0 { -b } else { b }
  while y != 0 {
    let r = x % y
    x = y
    y = r
  }
  x
}

///|
fn copy_int_array(xs : Array[Int]) -> Array[Int] {
  let out : Array[Int] = Array::make(xs.length(), 0)
  for i in 0..<xs.length() {
    out.set(i, xs[i])
  }
  out
}

///|
fn monom_from_exp(exp : Int) -> Monomial {
  Monomial::{ exps: [exp] }
}

///|
fn monom_prepend(exp : Int, m : Monomial) -> Monomial {
  let old = m.to_array()
  let out : Array[Int] = Array::make(old.length() + 1, 0)
  out.set(0, exp)
  for i in 0..<old.length() {
    out.set(i + 1, old[i])
  }
  Monomial::{ exps: out }
}

///|
pub fn dup_from_dict(
  f : Map[Monomial, FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let mut max_exp = 0
  let mut first = true
  for m, _ in f {
    let exps = m.to_array()
    if exps.length() != 1 {
      raise PolyError::DomainMismatch
    }
    if first || exps[0] > max_exp {
      max_exp = exps[0]
      first = false
    }
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(max_exp + 1, zero)
  for m, coeff in f {
    let exp = m.to_array()[0]
    let idx = max_exp - exp
    out.set(idx, coeff)
  }
  dup_strip(out)
}

///|
pub fn dup_from_raw_dict(
  f : Map[Int, FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let mut max_exp = 0
  let mut first = true
  for exp, _ in f {
    if first || exp > max_exp {
      max_exp = exp
      first = false
    }
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::make(max_exp + 1, zero)
  for exp, coeff in f {
    let idx = max_exp - exp
    out.set(idx, coeff)
  }
  dup_strip(out)
}

///|
pub fn dmp_from_dict(
  f : Map[Monomial, FieldElem],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dup_from_dict(f, domain)
    return dense_from_coeffs(coeffs)
  }
  if f.is_empty() {
    return dmp_zero(u)
  }
  let mut max_exp = 0
  let mut first = true
  let grouped : Map[Int, Map[Monomial, FieldElem]] = Map::new()
  for m, coeff in f {
    let exps = m.to_array()
    if exps.length() != u + 1 {
      raise PolyError::DomainMismatch
    }
    let head = exps[0]
    if first || head > max_exp {
      max_exp = head
      first = false
    }
    let tail_len = exps.length() - 1
    let tail_exps : Array[Int] = Array::make(tail_len, 0)
    for i in 0..<tail_len {
      tail_exps.set(i, exps[i + 1])
    }
    let tail = Monomial::{ exps: tail_exps }
    let sub = grouped.get(head)
    match sub {
      None => {
        let inner : Map[Monomial, FieldElem] = Map::new()
        inner.set(tail, coeff)
        grouped.set(head, inner)
      }
      Some(inner) => {
        inner.set(tail, coeff)
        grouped.set(head, inner)
      }
    }
  }
  let out : Array[DensePoly] = Array::new()
  let v = u - 1
  let mut exp = max_exp
  while exp >= 0 {
    match grouped.get(exp) {
      Some(inner) => out.push(dmp_from_dict(inner, v, domain))
      None => out.push(dmp_zero(v))
    }
    exp = exp - 1
  }
  dmp_strip(DensePoly::Poly(out))
}

///|
pub fn dup_to_dict(
  f : Array[FieldElem],
  _domain : Domain,
) -> Map[Monomial, FieldElem] {
  let out : Map[Monomial, FieldElem] = Map::new()
  let deg = f.length() - 1
  for i in 0..<f.length() {
    let coeff = f[i]
    if !fe_is_zero(coeff) {
      let exp = deg - i
      out.set(monom_from_exp(exp), coeff)
    }
  }
  out
}

///|
pub fn dup_to_raw_dict(
  f : Array[FieldElem],
  _domain : Domain,
) -> Map[Int, FieldElem] {
  let out : Map[Int, FieldElem] = Map::new()
  let deg = f.length() - 1
  for i in 0..<f.length() {
    let coeff = f[i]
    if !fe_is_zero(coeff) {
      let exp = deg - i
      out.set(exp, coeff)
    }
  }
  out
}

///|
pub fn dmp_to_dict(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Map[Monomial, FieldElem] raise PolyError {
  let stripped = dmp_strip(f)
  if u == 0 {
    let coeffs = dense_to_coeffs(stripped)
    return dup_to_dict(coeffs, domain)
  }
  let out : Map[Monomial, FieldElem] = Map::new()
  match stripped {
    DensePoly::Poly(items) => {
      let deg = dmp_degree(stripped, u)
      let v = u - 1
      if deg >= 0 {
        for i in 0..<items.length() {
          let exp = deg - i
          let child = items[i]
          let child_map = dmp_to_dict(child, v, domain)
          for m, coeff in child_map {
            out.set(monom_prepend(exp, m), coeff)
          }
        }
      }
    }
    DensePoly::Coef(c) =>
      if !fe_is_zero(c) {
        let m = Monomial::{ exps: Array::make(u + 1, 0) }
        out.set(m, c)
      }
  }
  out
}

///|
pub fn dmp_to_raw_dict(
  f : DensePoly,
  u : Int,
  _domain : Domain,
) -> Map[Int, DensePoly] {
  let out : Map[Int, DensePoly] = Map::new()
  let stripped = dmp_strip(f) catch { _ => f }
  match stripped {
    DensePoly::Poly(items) => {
      let v = u - 1
      let deg = if items.is_empty() { -1 } else { items.length() - 1 }
      for i in 0..<items.length() {
        let child = items[i]
        if !dmp_zero_p(child, v) {
          let exp = deg - i
          out.set(exp, child)
        }
      }
    }
    DensePoly::Coef(_) => ()
  }
  out
}

///|
pub fn dmp_swap(
  f : DensePoly,
  i : Int,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if i < 0 || j < 0 || i > u || j > u {
    raise PolyError::BadExponent
  }
  if i == j {
    return f
  }
  let dict = dmp_to_dict(f, u, domain)
  let out : Map[Monomial, FieldElem] = Map::new()
  for m, coeff in dict {
    let exps = copy_int_array(m.to_array())
    let tmp = exps[i]
    exps.set(i, exps[j])
    exps.set(j, tmp)
    out.set(Monomial::{ exps, }, coeff)
  }
  dmp_from_dict(out, u, domain)
}

///|
pub fn dmp_permute(
  f : DensePoly,
  p : Array[Int],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  let dict = dmp_to_dict(f, u, domain)
  let out : Map[Monomial, FieldElem] = Map::new()
  for m, coeff in dict {
    let old = m.to_array()
    let len = old.length()
    let exps : Array[Int] = Array::make(len, 0)
    for i in 0..<len {
      let idx = p[i]
      if idx < 0 || idx >= len {
        raise PolyError::BadExponent
      }
      exps.set(idx, old[i])
    }
    out.set(Monomial::{ exps, }, coeff)
  }
  dmp_from_dict(out, u, domain)
}

///|
pub fn dmp_nest(
  f : DensePoly,
  l : Int,
  _domain : Domain,
) -> DensePoly raise PolyError {
  if l <= 0 {
    return f
  }
  match f {
    DensePoly::Coef(c) => dmp_ground(c, l)
    DensePoly::Poly(_) => {
      let mut out = f
      for _ in 0..<l {
        out = DensePoly::Poly([out])
      }
      out
    }
  }
}

///|
pub fn dmp_raise(
  f : DensePoly,
  l : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if l == 0 {
    return f
  }
  if u == 0 {
    match f {
      DensePoly::Poly(items) => {
        if items.is_empty() {
          return dmp_zero(l)
        }
        let k = l - 1
        let out : Array[DensePoly] = Array::new()
        for it in items {
          match it {
            DensePoly::Coef(c) => out.push(dmp_ground(c, k))
            DensePoly::Poly(_) => raise PolyError::NotUnivariate
          }
        }
        DensePoly::Poly(out)
      }
      DensePoly::Coef(c) => dmp_ground(c, l)
    }
  } else {
    match f {
      DensePoly::Poly(items) => {
        let v = u - 1
        let out : Array[DensePoly] = Array::make(
          items.length(),
          DensePoly::Poly(Array::new()),
        )
        for i in 0..<items.length() {
          out.set(i, dmp_raise(items[i], l, v, domain))
        }
        DensePoly::Poly(out)
      }
      DensePoly::Coef(c) => dmp_ground(c, l)
    }
  }
}

///|
pub fn dup_deflate(
  f : Array[FieldElem],
  _domain : Domain,
) -> (Int, Array[FieldElem]) raise PolyError {
  if dup_degree(f) <= 0 {
    return (1, f)
  }
  let mut g = 0
  let len = f.length()
  for i in 0..<len {
    let coeff = f[len - 1 - i]
    if fe_is_zero(coeff) {
      continue
    }
    g = igcd(g, i)
    if g == 1 {
      return (1, f)
    }
  }
  if g <= 1 {
    return (1, f)
  }
  let out : Array[FieldElem] = Array::new()
  let mut idx = 0
  while idx < f.length() {
    out.push(f[idx])
    idx = idx + g
  }
  (g, out)
}

///|
pub fn dmp_deflate(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (Array[Int], DensePoly) raise PolyError {
  if dmp_zero_p(f, u) {
    return (Array::make(u + 1, 1), f)
  }
  let dict = dmp_to_dict(f, u, domain)
  let b : Array[Int] = Array::make(u + 1, 0)
  for m, _ in dict {
    let exps = m.to_array()
    for i in 0..<exps.length() {
      b.set(i, igcd(b[i], exps[i]))
    }
  }
  for i in 0..<b.length() {
    if b[i] == 0 {
      b.set(i, 1)
    }
  }
  let mut all_one = true
  for i in 0..<b.length() {
    if b[i] != 1 {
      all_one = false
      break
    }
  }
  if all_one {
    return (b, f)
  }
  let out : Map[Monomial, FieldElem] = Map::new()
  for m, coeff in dict {
    let old = m.to_array()
    let exps : Array[Int] = Array::make(old.length(), 0)
    for i in 0..<old.length() {
      exps.set(i, old[i] / b[i])
    }
    out.set(Monomial::{ exps, }, coeff)
  }
  (b, dmp_from_dict(out, u, domain))
}

///|
pub fn dup_multi_deflate(
  polys : Array[Array[FieldElem]],
  domain : Domain,
) -> (Int, Array[Array[FieldElem]]) raise PolyError {
  if polys.is_empty() {
    return (1, polys)
  }
  let mut g_all = 0
  for p in polys {
    if dup_degree(p) <= 0 {
      return (1, polys)
    }
    let mut g = 0
    let len = p.length()
    for i in 0..<len {
      let coeff = p[len - 1 - i]
      if fe_is_zero(coeff) {
        continue
      }
      g = igcd(g, i)
      if g == 1 {
        return (1, polys)
      }
    }
    g_all = if g_all == 0 { g } else { igcd(g_all, g) }
    if g_all == 1 {
      return (1, polys)
    }
  }
  if g_all <= 1 {
    return (1, polys)
  }
  let out : Array[Array[FieldElem]] = Array::new()
  for p in polys {
    let deflated : Array[FieldElem] = Array::new()
    let mut idx = 0
    while idx < p.length() {
      deflated.push(p[idx])
      idx = idx + g_all
    }
    out.push(deflated)
  }
  (g_all, out)
}

///|
pub fn dmp_multi_deflate(
  polys : Array[DensePoly],
  u : Int,
  domain : Domain,
) -> (Array[Int], Array[DensePoly]) raise PolyError {
  if polys.is_empty() {
    return (Array::make(u + 1, 1), polys)
  }
  if u == 0 {
    let coeffs : Array[Array[FieldElem]] = Array::new()
    for p in polys {
      coeffs.push(dense_to_coeffs(p))
    }
    let (m, deflated) = dup_multi_deflate(coeffs, domain)
    let out : Array[DensePoly] = Array::new()
    for f in deflated {
      out.push(dense_from_coeffs(f))
    }
    return ([m], out)
  }
  let dicts : Array[Map[Monomial, FieldElem]] = Array::new()
  let b : Array[Int] = Array::make(u + 1, 0)
  for p in polys {
    let d = dmp_to_dict(p, u, domain)
    if !dmp_zero_p(p, u) {
      for m, _ in d {
        let exps = m.to_array()
        for i in 0..<exps.length() {
          b.set(i, igcd(b[i], exps[i]))
        }
      }
    }
    dicts.push(d)
  }
  for i in 0..<b.length() {
    if b[i] == 0 {
      b.set(i, 1)
    }
  }
  let mut all_one = true
  for i in 0..<b.length() {
    if b[i] != 1 {
      all_one = false
      break
    }
  }
  if all_one {
    return (b, polys)
  }
  let out : Array[DensePoly] = Array::new()
  for d in dicts {
    let new_map : Map[Monomial, FieldElem] = Map::new()
    for m, coeff in d {
      let old = m.to_array()
      let exps : Array[Int] = Array::make(old.length(), 0)
      for i in 0..<old.length() {
        exps.set(i, old[i] / b[i])
      }
      new_map.set(Monomial::{ exps, }, coeff)
    }
    out.push(dmp_from_dict(new_map, u, domain))
  }
  (b, out)
}

///|
pub fn dup_inflate(
  f : Array[FieldElem],
  m : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if m <= 0 {
    raise PolyError::BadExponent
  }
  if m == 1 || f.is_empty() {
    return f
  }
  let zero = fe_from_int(0, domain)
  let out : Array[FieldElem] = Array::new()
  out.push(f[0])
  for i in 1..<f.length() {
    for _ in 1..<m {
      out.push(zero)
    }
    out.push(f[i])
  }
  out
}

///|
fn rec_inflate(
  g : DensePoly,
  m : Array[Int],
  v : Int,
  i : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if v == 0 {
    let coeffs = dense_to_coeffs(g)
    let inflated = dup_inflate(coeffs, m[i], domain)
    return dense_from_coeffs(inflated)
  }
  if m[i] <= 0 {
    raise PolyError::BadExponent
  }
  let w = v - 1
  let j = i + 1
  match g {
    DensePoly::Poly(items) => {
      let mapped : Array[DensePoly] = Array::new()
      for item in items {
        mapped.push(rec_inflate(item, m, w, j, domain))
      }
      if mapped.is_empty() {
        return DensePoly::Poly(Array::new())
      }
      let out : Array[DensePoly] = Array::new()
      out.push(mapped[0])
      for idx in 1..<mapped.length() {
        for _ in 1..<m[i] {
          out.push(dmp_zero(w))
        }
        out.push(mapped[idx])
      }
      DensePoly::Poly(out)
    }
    DensePoly::Coef(c) => dmp_ground(c, v)
  }
}

///|
pub fn dmp_inflate(
  f : DensePoly,
  m : Array[Int],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let coeffs = dense_to_coeffs(f)
    let inflated = dup_inflate(coeffs, m[0], domain)
    return dense_from_coeffs(inflated)
  }
  let mut all_one = true
  for i in 0..<m.length() {
    if m[i] != 1 {
      all_one = false
      break
    }
  }
  if all_one {
    return f
  }
  rec_inflate(f, m, u, 0, domain)
}
