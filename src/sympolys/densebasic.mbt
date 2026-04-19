///|
/// Return the leading coefficient of ``f``.

///|
/// Public API `dup_LC`.
///
/// - Does: Provides the `dup_LC` operation for dense polynomial representation.
/// - Input: parameters `coeffs : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_LC(coeffs : Array[FieldElem]) -> FieldElem raise PolyError {
  if coeffs.is_empty() {
    fe_from_int(0, Domain::ZZ)
  } else {
    coeffs[0]
  }
}

///|
/// Return the trailing coefficient of ``f``.

///|
/// Public API `dup_TC`.
///
/// - Does: Provides the `dup_TC` operation for dense polynomial representation.
/// - Input: parameters `coeffs : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_TC(coeffs : Array[FieldElem]) -> FieldElem raise PolyError {
  if coeffs.is_empty() {
    fe_from_int(0, Domain::ZZ)
  } else {
    coeffs[coeffs.length() - 1]
  }
}

///|
/// Return the leading degree of ``f`` in ``K[x]``.

///|
/// Public API `dup_degree`.
///
/// - Does: Provides the `dup_degree` operation for dense polynomial representation.
/// - Input: parameters `coeffs : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `Int` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dup_degree(coeffs : Array[FieldElem]) -> Int {
  if coeffs.is_empty() {
    -1
  } else {
    coeffs.length() - 1
  }
}

///|
/// Remove leading zeros from ``f`` in ``K[x]``.

///|
/// Public API `dup_strip`.
///
/// - Does: Provides the `dup_strip` operation for dense polynomial representation.
/// - Input: parameters `coeffs : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Compute ``x**n * f(1/x)``, i.e.: reverse ``f`` in ``K[x]``.

///|
/// Public API `dup_reverse`.
///
/// - Does: Provides the `dup_reverse` operation for dense polynomial representation.
/// - Input: parameters `coeffs : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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

///|
/// Public enum `DensePoly`.
///
/// - Does: Defines the `DensePoly` variants for dense polynomial representation.
/// - Input: constructed or referenced by callers through the declared public type shape.
/// - Returns: a `enum` declaration used by callers.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub enum DensePoly {
  Coef(FieldElem)
  Poly(Array[DensePoly])
}

///|
/// Dense polynomial with rational coefficients.

///|
/// Public enum `DenseRat`.
///
/// - Does: Defines the `DenseRat` variants for dense polynomial representation.
/// - Input: constructed or referenced by callers through the declared public type shape.
/// - Returns: a `enum` declaration used by callers.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub enum DenseRat {
  Coef(@symnum.BigRational)
  Poly(Array[DenseRat])
}

///|
/// Dense polynomial with polynomial coefficients (for inject/eject helpers).

///|
/// Public enum `DensePolyPoly`.
///
/// - Does: Defines the `DensePolyPoly` variants for dense polynomial representation.
/// - Input: constructed or referenced by callers through the declared public type shape.
/// - Returns: a `enum` declaration used by callers.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub enum DensePolyPoly {
  Coef(Poly)
  Poly(Array[DensePolyPoly])
}

///|
/// Wrap a scalar rational as a `DenseRat` coefficient node.

///|
/// Public API `dense_rat_coef`.
///
/// - Does: Provides the `dense_rat_coef` operation for dense polynomial representation.
/// - Input: parameters `c : @symnum.BigRational`, using the package representation
/// expected by the signature.
/// - Returns: a `DenseRat` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dense_rat_coef(c : @symnum.BigRational) -> DenseRat {
  DenseRat::Coef(c)
}

///|
/// Wrap child nodes as a recursive `DenseRat` polynomial node.

///|
/// Public API `dense_rat_poly`.
///
/// - Does: Provides the `dense_rat_poly` operation for dense polynomial representation.
/// - Input: parameters `items : Array[DenseRat]`, using the package representation
/// expected by the signature.
/// - Returns: a `DenseRat` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dense_rat_poly(items : Array[DenseRat]) -> DenseRat {
  DenseRat::Poly(items)
}

///|
/// Wrap a `Poly` value as a coefficient node in `DensePolyPoly`.

///|
/// Public API `dense_poly_poly_coef`.
///
/// - Does: Provides the `dense_poly_poly_coef` operation for dense polynomial representation.
/// - Input: parameters `p : Poly`, using the package representation expected by the
/// signature.
/// - Returns: a `DensePolyPoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dense_poly_poly_coef(p : Poly) -> DensePolyPoly {
  DensePolyPoly::Coef(p)
}

///|
/// Wrap child nodes as a recursive `DensePolyPoly` polynomial node.

///|
/// Public API `dense_poly_poly`.
///
/// - Does: Provides the `dense_poly_poly` operation for dense polynomial representation.
/// - Input: parameters `items : Array[DensePolyPoly]`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePolyPoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dense_poly_poly(items : Array[DensePolyPoly]) -> DensePolyPoly {
  DensePolyPoly::Poly(items)
}

///|
/// Wrap a scalar `FieldElem` as a `DensePoly` coefficient node.

///|
/// Public API `dense_coef`.
///
/// - Does: Provides the `dense_coef` operation for dense polynomial representation.
/// - Input: parameters `c : FieldElem`, using the package representation expected by
/// the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dense_coef(c : FieldElem) -> DensePoly {
  DensePoly::Coef(c)
}

///|
/// Wrap child nodes as a recursive `DensePoly` polynomial node.

///|
/// Public API `dense_poly`.
///
/// - Does: Provides the `dense_poly` operation for dense polynomial representation.
/// - Input: parameters `items : Array[DensePoly]`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return the number of levels in ``f`` and recursively strip it.

///|
/// Public API `dmp_validate`.
///
/// - Does: Provides the `dmp_validate` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly) -> (DensePoly`, `Int`, using the package
/// representation expected by the signature.
/// - Returns: a `(DensePoly, Int)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return the leading coefficient of ``f``.

///|
/// Public API `dmp_LC`.
///
/// - Does: Provides the `dmp_LC` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, using the package representation expected by
/// the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return the trailing coefficient of ``f``.

///|
/// Public API `dmp_TC`.
///
/// - Does: Provides the `dmp_TC` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, using the package representation expected by
/// the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return the ground leading coefficient.

///|
/// Public API `dmp_ground_LC`.
///
/// - Does: Provides the `dmp_ground_LC` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return the ground trailing coefficient.

///|
/// Public API `dmp_ground_TC`.
///
/// - Does: Provides the `dmp_ground_TC` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return the leading term ``c * x_1**n_1 ... x_k**n_k``.

///|
/// Public API `dmp_true_LT`.
///
/// - Does: Provides the `dmp_true_LT` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, `u : Int`, `) -> (Array[Int]`, `FieldElem`,
/// using the package representation expected by the signature.
/// - Returns: a `(Array[Int], FieldElem)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return the leading degree of ``f`` in ``x_0`` in ``K[X]``.

///|
/// Public API `dmp_degree`.
///
/// - Does: Provides the `dmp_degree` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Int` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return the leading degree of ``f`` in ``x_j`` in ``K[X]``.

///|
/// Public API `dmp_degree_in`.
///
/// - Does: Provides the `dmp_degree_in` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, `var_idx : Int`, `u : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Int` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a list of degrees of ``f`` in ``K[X]``.

///|
/// Public API `dmp_degree_list`.
///
/// - Does: Provides the `dmp_degree_list` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[Int]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_degree_list(p : DensePoly, u : Int) -> Array[Int] raise PolyError {
  let exps : Array[Int] = Array::make(u + 1, -1)
  for i in 0..<=u {
    exps.set(i, dmp_degree_in(p, i, u))
  }
  exps
}

///|
/// Remove leading zeros from ``f`` in ``K[X]``.

///|
/// Public API `dmp_strip`.
///
/// - Does: Provides the `dmp_strip` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, using the package representation expected by
/// the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_strip(p : DensePoly) -> DensePoly raise PolyError {
  let u = dense_var_count(p)
  if u < 0 {
    p
  } else {
    dense_strip_with_u(p, u)
  }
}

///|
/// Reverse ``f`` in ``K[X]`` by reversing coefficients at each recursive level.

///|
/// Public API `dmp_reverse`.
///
/// - Does: Provides the `dmp_reverse` operation for dense polynomial representation.
/// - Input: parameters `p : DensePoly`, using the package representation expected by
/// the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Create a new copy of a polynomial ``f`` in ``K[x]``.

///|
/// Public API `dup_copy`.
///
/// - Does: Provides the `dup_copy` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Create a new copy of a polynomial ``f`` in ``K[X]``.

///|
/// Public API `dmp_copy`.
///
/// - Does: Provides the `dmp_copy` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Convert `f` into a tuple.

///|
/// Public API `dup_to_tuple`.
///
/// - Does: Provides the `dup_to_tuple` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_to_tuple(f : Array[FieldElem]) -> Array[FieldElem] raise PolyError {
  dup_copy(f)
}

///|
/// Convert `f` into a nested tuple of tuples.

///|
/// Public API `dmp_to_tuple`.
///
/// - Does: Provides the `dmp_to_tuple` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dmp_to_tuple(f : DensePoly, u : Int) -> DensePoly {
  dmp_copy(f, u)
}

///|
/// Normalize univariate polynomial in the given domain.

///|
/// Public API `dup_normal`.
///
/// - Does: Provides the `dup_normal` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_normal(f : Array[FieldElem]) -> Array[FieldElem] raise PolyError {
  dup_strip(f)
}

///|
/// Normalize a multivariate polynomial in the given domain.

///|
/// Public API `dmp_normal`.
///
/// - Does: Provides the `dmp_normal` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_normal(f : DensePoly, u : Int) -> DensePoly raise PolyError {
  if u == 0 {
    match f {
      DensePoly::Poly(items) => {
        let coeffs : Array[FieldElem] = Array::new()
        for it in items {
          match it {
            DensePoly::Coef(c) => coeffs.push(c)
            DensePoly::Poly(_) => coeffs.push(fe_from_int(0, Domain::QQ))
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
          mapped.set(i, dmp_normal(items[i], u - 1))
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
/// Convert the ground domain of ``f`` from ``K0`` to ``K1``.

///|
/// Public API `dup_convert`.
///
/// - Does: Provides the `dup_convert` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `_k0 : Domain`, `k1 : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Convert the ground domain of ``f`` from ``K0`` to ``K1``.

///|
/// Public API `dmp_convert`.
///
/// - Does: Provides the `dmp_convert` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `k0 : Domain`, `k1 : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
            DensePoly::Poly(_) => coeffs.push(fe_from_int(0, k1))
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
          mapped.set(i, dmp_convert(items[i], u - 1, k0, k1))
        }
        dmp_strip(DensePoly::Poly(mapped))
      }
      DensePoly::Coef(c) => DensePoly::Coef(fe_convert_domain(c, k1))
    }
  }
}

///|
/// Convert the ground domain of ``f`` from SymPy to ``K``.

///|
/// Public API `dup_from_sympy`.
///
/// - Does: Provides the `dup_from_sympy` operation for dense polynomial representation.
/// - Input: parameters `f : Array[@symnum.BigRational]`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_from_sympy(
  f : Array[@symnum.BigRational],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if f.is_empty() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::new()
  for c in f {
    out.push(fe_from_rational(c, domain))
  }
  dup_strip(out)
}

///|
fn dense_rat_to_dense(
  f : DenseRat,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u <= 0 {
    match f {
      DenseRat::Coef(c) => {
        let coeffs : Array[FieldElem] = [fe_from_rational(c, domain)]
        dense_from_coeffs(dup_strip(coeffs))
      }
      DenseRat::Poly(items) => {
        let coeffs : Array[FieldElem] = Array::new()
        for it in items {
          match it {
            DenseRat::Coef(c) => coeffs.push(fe_from_rational(c, domain))
            DenseRat::Poly(_) => raise PolyError::NonPolynomial
          }
        }
        dense_from_coeffs(dup_strip(coeffs))
      }
    }
  } else {
    match f {
      DenseRat::Coef(c) => dmp_ground(fe_from_rational(c, domain), u)
      DenseRat::Poly(items) => {
        let out : Array[DensePoly] = Array::new()
        for it in items {
          out.push(dense_rat_to_dense(it, u - 1, domain))
        }
        dmp_strip(DensePoly::Poly(out))
      }
    }
  }
}

///|
/// Convert the ground domain of ``f`` from SymPy to ``K``.

///|
/// Public API `dmp_from_sympy`.
///
/// - Does: Provides the `dmp_from_sympy` operation for dense polynomial representation.
/// - Input: parameters `f : DenseRat`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_from_sympy(
  f : DenseRat,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dense_rat_to_dense(f, u, domain)
}

///|
/// Return the ``n``-th coefficient of ``f`` in ``K[x]``.

///|
/// Public API `dup_nth`.
///
/// - Does: Provides the `dup_nth` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `n : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return the ``n``-th coefficient of ``f`` in ``K[x]``.

///|
/// Public API `dmp_nth`.
///
/// - Does: Provides the `dmp_nth` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `n : Int`, `u : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a multivariate zero.

///|
/// Public API `dmp_zero`.
///
/// - Does: Provides the `dmp_zero` operation for dense polynomial representation.
/// - Input: parameters `u : Int`, using the package representation expected by the
/// signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return ``True`` if ``f`` is zero in ``K[X]``.

///|
/// Public API `dmp_zero_p`.
///
/// - Does: Provides the `dmp_zero_p` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return a multivariate constant.

///|
/// Public API `dmp_ground`.
///
/// - Does: Provides the `dmp_ground` operation for dense polynomial representation.
/// - Input: parameters `c : FieldElem`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return True if ``f`` is constant in ``K[X]``.

///|
/// Public API `dmp_ground_p`.
///
/// - Does: Provides the `dmp_ground_p` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `c : FieldElem`, `u : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a multivariate one over ``K``.

///|
/// Public API `dmp_one`.
///
/// - Does: Provides the `dmp_one` operation for dense polynomial representation.
/// - Input: parameters `u : Int`, `domain : Domain`, using the package representation
/// expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_one(u : Int, domain : Domain) -> DensePoly raise PolyError {
  let one = fe_from_int(1, domain)
  dmp_ground(one, u)
}

///|
/// Return ``True`` if ``f`` is one in ``K[X]``.

///|
/// Public API `dmp_one_p`.
///
/// - Does: Provides the `dmp_one_p` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_one_p(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> Bool raise PolyError {
  let one = fe_from_int(1, domain)
  dmp_ground_p(f, Some(one), u)
}

///|
/// Return the ground ``n``-th coefficient of ``f`` in ``K[x]``.

///|
/// Public API `dmp_ground_nth`.
///
/// - Does: Provides the `dmp_ground_nth` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `nlist : Array[Int]`, `u : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a list of multivariate zeros.

///|
/// Public API `dmp_zeros`.
///
/// - Does: Provides the `dmp_zeros` operation for dense polynomial representation.
/// - Input: parameters `n : Int`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[DensePoly]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a list of multivariate constants.

///|
/// Public API `dmp_grounds`.
///
/// - Does: Provides the `dmp_grounds` operation for dense polynomial representation.
/// - Input: parameters `c : FieldElem`, `n : Int`, `u : Int`, `_domain : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `Array[DensePoly]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Return ``True`` if ``LC(f)`` is negative.

///|
/// Public API `dmp_negative_p`.
///
/// - Does: Provides the `dmp_negative_p` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_negative_p(f : DensePoly, u : Int) -> Bool raise PolyError {
  let lc = dmp_ground_LC(f, u)
  fe_is_negative(lc)
}

///|
/// Return ``True`` if ``LC(f)`` is positive.

///|
/// Public API `dmp_positive_p`.
///
/// - Does: Provides the `dmp_positive_p` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Create a ``K[x]`` polynomial from a ``dict``.

///|
/// Public API `dup_from_dict`.
///
/// - Does: Provides the `dup_from_dict` operation for dense polynomial representation.
/// - Input: parameters `f : Map[Monomial, FieldElem]`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Create a ``K[x]`` polynomial from a raw ``dict``.

///|
/// Public API `dup_from_raw_dict`.
///
/// - Does: Provides the `dup_from_raw_dict` operation for dense polynomial representation.
/// - Input: parameters `f : Map[Int, FieldElem]`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Create a ``K[X]`` polynomial from a ``dict``.

///|
/// Public API `dmp_from_dict`.
///
/// - Does: Provides the `dmp_from_dict` operation for dense polynomial representation.
/// - Input: parameters `f : Map[Monomial, FieldElem]`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Convert ``K[x]`` polynomial to a ``dict``.

///|
/// Public API `dup_to_dict`.
///
/// - Does: Provides the `dup_to_dict` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `_domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Map[Monomial, FieldElem]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Convert a ``K[x]`` polynomial to a raw ``dict``.

///|
/// Public API `dup_to_raw_dict`.
///
/// - Does: Provides the `dup_to_raw_dict` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `_domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Map[Int, FieldElem]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Convert a ``K[X]`` polynomial to a ``dict````.

///|
/// Public API `dmp_to_dict`.
///
/// - Does: Provides the `dmp_to_dict` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `Map[Monomial, FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Convert a ``K[X]`` polynomial to a raw ``dict``.

///|
/// Public API `dmp_to_raw_dict`.
///
/// - Does: Provides the `dmp_to_raw_dict` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `_domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Map[Int, DensePoly]` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
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
/// Transform ``K[..x_i..x_j..]`` to ``K[..x_j..x_i..]``.

///|
/// Public API `dmp_swap`.
///
/// - Does: Provides the `dmp_swap` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `i : Int`, `j : Int`, `u : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a polynomial in ``K[x_{P(1)},..,x_{P(n)}]``.

///|
/// Public API `dmp_permute`.
///
/// - Does: Provides the `dmp_permute` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `p : Array[Int]`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Return a multivariate value nested ``l``-levels.

///|
/// Public API `dmp_nest`.
///
/// - Does: Provides the `dmp_nest` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `l : Int`, `_domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dmp_nest(f : DensePoly, l : Int, _domain : Domain) -> DensePoly {
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
/// Return a multivariate polynomial raised ``l``-levels.

///|
/// Public API `dmp_raise`.
///
/// - Does: Provides the `dmp_raise` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `l : Int`, `u : Int`, `domain : Domain`, using
/// the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Map ``x**m`` to ``y`` in a polynomial in ``K[x]``.

///|
/// Public API `dup_deflate`.
///
/// - Does: Provides the `dup_deflate` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `_domain : Domain`, `) -> (Int`,
/// `Array[FieldElem]`, using the package representation expected by the signature.
/// - Returns: a `(Int, Array[FieldElem])` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dup_deflate(
  f : Array[FieldElem],
  _domain : Domain,
) -> (Int, Array[FieldElem]) {
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
/// Map ``x_i**m_i`` to ``y_i`` in a polynomial in ``K[X]``.

///|
/// Public API `dmp_deflate`.
///
/// - Does: Provides the `dmp_deflate` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, `) ->
/// (Array[Int]`, `DensePoly`, using the package representation expected by the
/// signature.
/// - Returns: a `(Array[Int], DensePoly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Map ``x**m`` to ``y`` in a set of polynomials in ``K[x]``.

///|
/// Public API `dup_multi_deflate`.
///
/// - Does: Provides the `dup_multi_deflate` operation for dense polynomial representation.
/// - Input: parameters `polys : Array[Array[FieldElem]]`, `_domain : Domain`, `) ->
/// (Int`, `Array[Array[FieldElem]]`, using the package representation expected by the
/// signature.
/// - Returns: a `(Int, Array[Array[FieldElem]])` value.
/// - Limits: Does not add a separate error channel beyond the called helpers; inputs
/// must already satisfy the representation invariants expected by this compatibility
/// layer.
pub fn dup_multi_deflate(
  polys : Array[Array[FieldElem]],
  _domain : Domain,
) -> (Int, Array[Array[FieldElem]]) {
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
/// Map ``x_i**m_i`` to ``y_i`` in a set of polynomials in ``K[X]``.

///|
/// Public API `dmp_multi_deflate`.
///
/// - Does: Provides the `dmp_multi_deflate` operation for dense polynomial representation.
/// - Input: parameters `polys : Array[DensePoly]`, `u : Int`, `domain : Domain`, `) ->
/// (Array[Int]`, `Array[DensePoly]`, using the package representation expected by the
/// signature.
/// - Returns: a `(Array[Int], Array[DensePoly])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Map ``y`` to ``x**m`` in a polynomial in ``K[x]``.

///|
/// Public API `dup_inflate`.
///
/// - Does: Provides the `dup_inflate` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `m : Int`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
/// Map ``y_i`` to ``x_i**k_i`` in a polynomial in ``K[X]``.

///|
/// Public API `dmp_inflate`.
///
/// - Does: Provides the `dmp_inflate` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `m : Array[Int]`, `u : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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

///|
fn dpp_zero(u : Int) -> DensePolyPoly {
  let mut p : DensePolyPoly = DensePolyPoly::Poly(Array::new())
  if u < 0 {
    return p
  }
  let mut i = 0
  while i < u {
    p = DensePolyPoly::Poly([p])
    i = i + 1
  }
  p
}

///|
fn dpp_zero_p(f : DensePolyPoly) -> Bool {
  match f {
    DensePolyPoly::Coef(p) => p.is_zero()
    DensePolyPoly::Poly(items) =>
      if items.is_empty() {
        true
      } else {
        for it in items {
          if !dpp_zero_p(it) {
            return false
          }
        }
        true
      }
  }
}

///|
fn dpp_strip_leading(items : Array[DensePolyPoly]) -> Array[DensePolyPoly] {
  let mut start = 0
  while start < items.length() && dpp_zero_p(items[start]) {
    start = start + 1
  }
  if start == items.length() {
    return Array::new()
  }
  let out : Array[DensePolyPoly] = Array::new()
  for i in start..<items.length() {
    out.push(items[i])
  }
  out
}

///|
fn dpp_from_dict(
  f : Map[Monomial, Poly],
  u : Int,
  gens : Array[String],
  domain : Domain,
) -> DensePolyPoly raise PolyError {
  if u == 0 {
    if f.is_empty() {
      return DensePolyPoly::Poly(Array::new())
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
    let zero_poly = Poly::zero(gens, domain)
    let out : Array[DensePolyPoly] = Array::make(
      max_exp + 1,
      DensePolyPoly::Coef(zero_poly),
    )
    for m, coeff in f {
      let exp = m.to_array()[0]
      let idx = max_exp - exp
      out.set(idx, DensePolyPoly::Coef(coeff))
    }
    let stripped = dpp_strip_leading(out)
    return DensePolyPoly::Poly(stripped)
  }
  if f.is_empty() {
    return dpp_zero(u)
  }
  let mut max_exp = 0
  let mut first = true
  let grouped : Map[Int, Map[Monomial, Poly]] = Map::new()
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
        let inner : Map[Monomial, Poly] = Map::new()
        inner.set(tail, coeff)
        grouped.set(head, inner)
      }
      Some(inner) => {
        inner.set(tail, coeff)
        grouped.set(head, inner)
      }
    }
  }
  let out : Array[DensePolyPoly] = Array::new()
  let v = u - 1
  let mut exp = max_exp
  while exp >= 0 {
    match grouped.get(exp) {
      Some(inner) => out.push(dpp_from_dict(inner, v, gens, domain))
      None => out.push(dpp_zero(v))
    }
    exp = exp - 1
  }
  let stripped = dpp_strip_leading(out)
  if stripped.is_empty() {
    dpp_zero(u)
  } else {
    DensePolyPoly::Poly(stripped)
  }
}

///|
fn dpp_to_dict(
  f : DensePolyPoly,
  u : Int,
) -> Map[Monomial, Poly] raise PolyError {
  let out : Map[Monomial, Poly] = Map::new()
  if u == 0 {
    match f {
      DensePolyPoly::Coef(p) =>
        if !p.is_zero() {
          out.set(monom_from_exp(0), p)
        }
      DensePolyPoly::Poly(items) => {
        let deg = items.length() - 1
        for i in 0..<items.length() {
          match items[i] {
            DensePolyPoly::Coef(p) =>
              if !p.is_zero() {
                let exp = deg - i
                out.set(monom_from_exp(exp), p)
              }
            DensePolyPoly::Poly(_) => raise PolyError::NonPolynomial
          }
        }
      }
    }
    return out
  }
  match f {
    DensePolyPoly::Coef(p) =>
      if !p.is_zero() {
        let zeros = Array::make(u + 1, 0)
        out.set(Monomial::{ exps: zeros }, p)
      }
    DensePolyPoly::Poly(items) => {
      let deg = items.length() - 1
      let v = u - 1
      for i in 0..<items.length() {
        let exp = deg - i
        let child_map = dpp_to_dict(items[i], v)
        for m, coeff in child_map {
          out.set(monom_prepend(exp, m), coeff)
        }
      }
    }
  }
  out
}

///|
/// Exclude useless levels from ``f``.

///|
/// Public API `dmp_exclude`.
///
/// - Does: Provides the `dmp_exclude` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, `) ->
/// (Array[Int]`, `DensePoly` and 1 more parameter(s), using the package representation
/// expected by the signature.
/// - Returns: a `(Array[Int], DensePoly, Int)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_exclude(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (Array[Int], DensePoly, Int) raise PolyError {
  if u == 0 || dmp_ground_p(f, None, u) {
    return (Array::new(), f, u)
  }
  let dict = dmp_to_dict(f, u, domain)
  let jlist : Array[Int] = Array::new()
  for j in 0..<=u {
    let mut any_nonzero = false
    for m, _ in dict {
      let exps = m.to_array()
      if exps[j] != 0 {
        any_nonzero = true
        break
      }
    }
    if !any_nonzero {
      jlist.push(j)
    }
  }
  if jlist.is_empty() {
    return (Array::new(), f, u)
  }
  let out : Map[Monomial, FieldElem] = Map::new()
  for m, coeff in dict {
    let exps = copy_int_array(m.to_array())
    let mut idx = jlist.length()
    while idx > 0 {
      idx = idx - 1
      let j = jlist[idx]
      let _ = exps.remove(j)
    }
    out.set(Monomial::{ exps, }, coeff)
  }
  let new_u = u - jlist.length()
  (jlist, dmp_from_dict(out, new_u, domain), new_u)
}

///|
/// Include useless levels in ``f``.

///|
/// Public API `dmp_include`.
///
/// - Does: Provides the `dmp_include` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `jlist : Array[Int]`, `u : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_include(
  f : DensePoly,
  jlist : Array[Int],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if jlist.is_empty() {
    return f
  }
  let dict = dmp_to_dict(f, u, domain)
  let out : Map[Monomial, FieldElem] = Map::new()
  for m, coeff in dict {
    let exps = copy_int_array(m.to_array())
    for j in jlist {
      exps.insert(j, 0)
    }
    out.set(Monomial::{ exps, }, coeff)
  }
  let new_u = u + jlist.length()
  dmp_from_dict(out, new_u, domain)
}

///|
/// Convert ``f`` from ``K[X][Y]`` to ``K[X,Y]``.

///|
/// Public API `dmp_inject`.
///
/// - Does: Provides the `dmp_inject` operation for dense polynomial representation.
/// - Input: parameters `f : DensePolyPoly`, `u : Int`, `gens : Array[String]`, `domain
/// : Domain`, `front : Bool = false` and 2 more parameter(s), using the package
/// representation expected by the signature.
/// - Returns: a `(DensePoly, Int)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_inject(
  f : DensePolyPoly,
  u : Int,
  gens : Array[String],
  domain : Domain,
  front? : Bool = false,
) -> (DensePoly, Int) raise PolyError {
  let dict = dpp_to_dict(f, u)
  let v = gens.length() - 1
  let out : Map[Monomial, FieldElem] = Map::new()
  for f_monom, poly in dict {
    if !poly.gens.equal(gens) {
      raise PolyError::DomainMismatch
    }
    for g_monom, coeff in poly.coeffs {
      let f_exps = f_monom.to_array()
      let g_exps = g_monom.to_array()
      let total_len = f_exps.length() + g_exps.length()
      let merged : Array[Int] = Array::make(total_len, 0)
      if front {
        for i in 0..<g_exps.length() {
          merged.set(i, g_exps[i])
        }
        for i in 0..<f_exps.length() {
          merged.set(i + g_exps.length(), f_exps[i])
        }
      } else {
        for i in 0..<f_exps.length() {
          merged.set(i, f_exps[i])
        }
        for i in 0..<g_exps.length() {
          merged.set(i + f_exps.length(), g_exps[i])
        }
      }
      add_term(out, Monomial::{ exps: merged }, coeff, domain)
    }
  }
  let w = u + v + 1
  (dmp_from_dict(out, w, domain), w)
}

///|
/// Convert ``f`` from ``K[X,Y]`` to ``K[X][Y]``.

///|
/// Public API `dmp_eject`.
///
/// - Does: Provides the `dmp_eject` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `gens : Array[String]`, `domain :
/// Domain`, `front : Bool = false`, using the package representation expected by the
/// signature.
/// - Returns: a `DensePolyPoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_eject(
  f : DensePoly,
  u : Int,
  gens : Array[String],
  domain : Domain,
  front? : Bool = false,
) -> DensePolyPoly raise PolyError {
  let n = gens.length()
  if u + 1 < n {
    raise PolyError::BadExponent
  }
  let dict = dmp_to_dict(f, u, domain)
  let grouped : Map[Monomial, Map[Monomial, FieldElem]] = Map::new()
  for monom, coeff in dict {
    let exps = monom.to_array()
    let split = exps.length() - n
    let (g_exps, f_exps) = if front {
      let g : Array[Int] = Array::make(n, 0)
      let f0 : Array[Int] = Array::make(exps.length() - n, 0)
      for i in 0..<n {
        g.set(i, exps[i])
      }
      for i in 0..<(exps.length() - n) {
        f0.set(i, exps[i + n])
      }
      (g, f0)
    } else {
      let f0 : Array[Int] = Array::make(split, 0)
      let g : Array[Int] = Array::make(n, 0)
      for i in 0..<split {
        f0.set(i, exps[i])
      }
      for i in 0..<n {
        g.set(i, exps[split + i])
      }
      (g, f0)
    }
    let g_monom = Monomial::{ exps: g_exps }
    let f_monom = Monomial::{ exps: f_exps }
    match grouped.get(f_monom) {
      None => {
        let inner : Map[Monomial, FieldElem] = Map::new()
        add_term(inner, g_monom, coeff, domain)
        grouped.set(f_monom, inner)
      }
      Some(inner) => {
        add_term(inner, g_monom, coeff, domain)
        grouped.set(f_monom, inner)
      }
    }
  }
  let out : Map[Monomial, Poly] = Map::new()
  for monom, coeffs in grouped {
    let poly = Poly::{ coeffs, gens, domain, order: TermOrder::Lex }
    out.set(monom, poly)
  }
  let v = u - n
  dpp_from_dict(out, v, gens, domain)
}

///|
/// Remove GCD of terms from ``f`` in ``K[x]``.

///|
/// Public API `dup_terms_gcd`.
///
/// - Does: Provides the `dup_terms_gcd` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `_domain : Domain`, `) -> (Int`,
/// `Array[FieldElem]`, using the package representation expected by the signature.
/// - Returns: a `(Int, Array[FieldElem])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_terms_gcd(
  f : Array[FieldElem],
  _domain : Domain,
) -> (Int, Array[FieldElem]) raise PolyError {
  if f.is_empty() || !fe_is_zero(dup_TC(f)) {
    return (0, f)
  }
  let mut i = 0
  let mut idx = f.length()
  while idx > 0 {
    idx = idx - 1
    if fe_is_zero(f[idx]) {
      i = i + 1
    } else {
      break
    }
  }
  if i == 0 {
    return (0, f)
  }
  let out : Array[FieldElem] = Array::new()
  for j in 0..<(f.length() - i) {
    out.push(f[j])
  }
  (i, out)
}

///|
/// Remove GCD of terms from ``f`` in ``K[X]``.

///|
/// Public API `dmp_terms_gcd`.
///
/// - Does: Provides the `dmp_terms_gcd` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, `) ->
/// (Array[Int]`, `DensePoly`, using the package representation expected by the
/// signature.
/// - Returns: a `(Array[Int], DensePoly)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_terms_gcd(
  f : DensePoly,
  u : Int,
  domain : Domain,
) -> (Array[Int], DensePoly) raise PolyError {
  if !fe_is_zero(dmp_ground_TC(f, u)) || dmp_zero_p(f, u) {
    return (Array::make(u + 1, 0), f)
  }
  let dict = dmp_to_dict(f, u, domain)
  let monoms : Array[Monomial] = Array::new()
  for m, _ in dict {
    monoms.push(m)
  }
  let g = monomial_min(monoms)
  let exps = g.to_array()
  let mut all_zero = true
  for v in exps {
    if v != 0 {
      all_zero = false
      break
    }
  }
  if all_zero {
    return (exps, f)
  }
  let out : Map[Monomial, FieldElem] = Map::new()
  for m, coeff in dict {
    let old = m.to_array()
    let new_exps : Array[Int] = Array::make(old.length(), 0)
    for i in 0..<old.length() {
      new_exps.set(i, old[i] - exps[i])
    }
    out.set(Monomial::{ exps: new_exps }, coeff)
  }
  (exps, dmp_from_dict(out, u, domain))
}

///|
/// List all non-zero terms from ``f`` in the given order ``order``.

///|
/// Public API `dmp_list_terms`.
///
/// - Does: Provides the `dmp_list_terms` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `u : Int`, `domain : Domain`, `order :
/// TermOrder`, `) -> Array[(Array[Int], FieldElem`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[(Array[Int], FieldElem)]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_list_terms(
  f : DensePoly,
  u : Int,
  domain : Domain,
  order? : TermOrder,
) -> Array[(Array[Int], FieldElem)] raise PolyError {
  let dict = dmp_to_dict(f, u, domain)
  if dict.is_empty() {
    let zeros = Array::make(u + 1, 0)
    return [(zeros, fe_from_int(0, domain))]
  }
  let terms : Array[(Array[Int], FieldElem)] = Array::new()
  for m, coeff in dict {
    terms.push((m.to_array(), coeff))
  }
  let ord = match order {
    Some(o) => o
    None => TermOrder::Lex
  }
  terms.sort_by((a, b) => {
    let ma = Monomial::{ exps: a.0 }
    let mb = Monomial::{ exps: b.0 }
    compare_monomial_order(mb, ma, ord)
  })
  terms
}

///|
/// Apply ``h`` to pairs of coefficients of ``f`` and ``g``.

///|
/// Public API `dup_apply_pairs`.
///
/// - Does: Provides the `dup_apply_pairs` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `g : Array[FieldElem]`, `h : (FieldElem,
/// FieldElem, Array[FieldElem]) -> FieldElem`, `args : Array[FieldElem]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `FieldElem, args : Array[FieldElem], domain : Domain, ) ->
/// Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_apply_pairs(
  f : Array[FieldElem],
  g : Array[FieldElem],
  h : (FieldElem, FieldElem, Array[FieldElem]) -> FieldElem,
  args : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let n = f.length()
  let m = g.length()
  let zero = fe_from_int(0, domain)
  let mut f0 = f
  let mut g0 = g
  if n != m {
    if n > m {
      let pad : Array[FieldElem] = Array::make(n - m, zero)
      let out : Array[FieldElem] = Array::new()
      for c in pad {
        out.push(c)
      }
      for c in g0 {
        out.push(c)
      }
      g0 = out
    } else {
      let pad : Array[FieldElem] = Array::make(m - n, zero)
      let out : Array[FieldElem] = Array::new()
      for c in pad {
        out.push(c)
      }
      for c in f0 {
        out.push(c)
      }
      f0 = out
    }
  }
  let result : Array[FieldElem] = Array::new()
  for i in 0..<f0.length() {
    result.push(h(f0[i], g0[i], args))
  }
  dup_strip(result)
}

///|
/// Apply ``h`` to pairs of coefficients of ``f`` and ``g``.

///|
/// Public API `dmp_apply_pairs`.
///
/// - Does: Provides the `dmp_apply_pairs` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `g : DensePoly`, `h : (FieldElem, FieldElem,
/// Array[FieldElem]) -> FieldElem`, `args : Array[FieldElem]`, `u : Int` and 1 more
/// parameter(s), using the package representation expected by the signature.
/// - Returns: a `FieldElem, args : Array[FieldElem], u : Int, domain : Domain, ) ->
/// DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_apply_pairs(
  f : DensePoly,
  g : DensePoly,
  h : (FieldElem, FieldElem, Array[FieldElem]) -> FieldElem,
  args : Array[FieldElem],
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if u == 0 {
    let fcoeffs = dense_to_coeffs(f)
    let gcoeffs = dense_to_coeffs(g)
    let res = dup_apply_pairs(fcoeffs, gcoeffs, h, args, domain)
    return dense_from_coeffs(res)
  }
  let v = u - 1
  let items_f = match f {
    DensePoly::Poly(items) => items
    DensePoly::Coef(c) => [dmp_ground(c, v)]
  }
  let items_g = match g {
    DensePoly::Poly(items) => items
    DensePoly::Coef(c) => [dmp_ground(c, v)]
  }
  let n = items_f.length()
  let m = items_g.length()
  let mut f0 = items_f
  let mut g0 = items_g
  if n != m {
    if n > m {
      let pad = dmp_zeros(n - m, v, domain)
      let out : Array[DensePoly] = Array::new()
      for p in pad {
        out.push(p)
      }
      for p in g0 {
        out.push(p)
      }
      g0 = out
    } else {
      let pad = dmp_zeros(m - n, v, domain)
      let out : Array[DensePoly] = Array::new()
      for p in pad {
        out.push(p)
      }
      for p in f0 {
        out.push(p)
      }
      f0 = out
    }
  }
  let result : Array[DensePoly] = Array::new()
  for i in 0..<f0.length() {
    result.push(dmp_apply_pairs(f0[i], g0[i], h, args, v, domain))
  }
  dmp_strip(DensePoly::Poly(result))
}

///|
/// Take a continuous subsequence of terms of ``f`` in ``K[x]``.

///|
/// Public API `dup_slice`.
///
/// - Does: Provides the `dup_slice` operation for dense polynomial representation.
/// - Input: parameters `f : Array[FieldElem]`, `m : Int`, `n : Int`, `domain : Domain`,
/// using the package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_slice(
  f : Array[FieldElem],
  m : Int,
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let k = f.length()
  let m0 = if k >= m { k - m } else { 0 }
  let n0 = if k >= n { k - n } else { 0 }
  let slice : Array[FieldElem] = Array::new()
  for i in n0..<m0 {
    slice.push(f[i])
  }
  let mut start = 0
  while start < slice.length() && fe_is_zero(slice[start]) {
    start = start + 1
  }
  if start == slice.length() {
    return Array::new()
  }
  let out : Array[FieldElem] = Array::new()
  for i in start..<slice.length() {
    out.push(slice[i])
  }
  let zero = fe_from_int(0, domain)
  for _ in 0..<m {
    out.push(zero)
  }
  out
}

///|
/// Take a continuous subsequence of terms of ``f`` in ``K[X]``.

///|
/// Public API `dmp_slice`.
///
/// - Does: Provides the `dmp_slice` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `m : Int`, `n : Int`, `u : Int`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_slice(
  f : DensePoly,
  m : Int,
  n : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  dmp_slice_in(f, m, n, 0, u, domain)
}

///|
/// Take a continuous subsequence of terms of ``f`` in ``x_j`` in ``K[X]``.

///|
/// Public API `dmp_slice_in`.
///
/// - Does: Provides the `dmp_slice_in` operation for dense polynomial representation.
/// - Input: parameters `f : DensePoly`, `m : Int`, `n : Int`, `j : Int`, `u : Int` and
/// 1 more parameter(s), using the package representation expected by the signature.
/// - Returns: a `DensePoly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dmp_slice_in(
  f : DensePoly,
  m : Int,
  n : Int,
  j : Int,
  u : Int,
  domain : Domain,
) -> DensePoly raise PolyError {
  if j < 0 || j > u {
    raise PolyError::BadExponent
  }
  if u == 0 {
    let coeffs = dense_to_coeffs(f)
    let sliced = dup_slice(coeffs, m, n, domain)
    return dense_from_coeffs(sliced)
  }
  let dict = dmp_to_dict(f, u, domain)
  let out : Map[Monomial, FieldElem] = Map::new()
  for monom, coeff in dict {
    let exps = copy_int_array(monom.to_array())
    let k = exps[j]
    if k < m || k >= n {
      exps.set(j, 0)
    }
    add_term(out, Monomial::{ exps, }, coeff, domain)
  }
  dmp_from_dict(out, u, domain)
}

///|
/// Return a polynomial of degree ``n`` with coefficients in ``[a, b]``.

///|
/// Public API `dup_random`.
///
/// - Does: Provides the `dup_random` operation for dense polynomial representation.
/// - Input: parameters `n : Int`, `a : Int`, `b : Int`, `domain : Domain`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn dup_random(
  n : Int,
  a : Int,
  b : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let mut seed = n + a + b + 12345
  let span = if b >= a { b - a + 1 } else { 1 }
  let coeffs : Array[FieldElem] = Array::make(n + 1, fe_from_int(0, domain))
  for i in 0..<=n {
    seed = lcg_next(seed, 2147483647)
    let mut val = a + seed % span
    if i == 0 && val == 0 {
      val = if a != 0 { a } else if b != 0 { b } else { 1 }
    }
    coeffs.set(i, fe_from_int(val, domain))
  }
  coeffs
}
