///|
/// Dense <-> sparse conversions for univariate polys.

///|
/// Public API `to_dense`.
///
/// - Does: Provides the `to_dense` operation for dense polynomial conversion.
/// - Input: parameters `poly : Poly`, `degree : Int`, using the package representation
/// expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn to_dense(poly : Poly, degree? : Int) -> Array[FieldElem] raise PolyError {
  if poly.gens.length() != 1 {
    raise NotUnivariate
  }
  let deg = match degree {
    Some(d) => d
    None => poly.degree(0)
  }
  let dense : Array[FieldElem] = Array::make(
    deg + 1,
    fe_from_int(0, poly.domain),
  )
  for m, c in poly.coeffs {
    let k = m.exps[0]
    if k <= deg {
      dense.set(k, c)
    }
  }
  dense
}

///|
/// Build a sparse `Poly` from dense univariate coefficients.

///|
/// Public API `from_dense`.
///
/// - Does: Provides the `from_dense` operation for dense polynomial conversion.
/// - Input: parameters `coeffs : Array[FieldElem]`, `gens : Array[String]`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `Poly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn from_dense(
  coeffs : Array[FieldElem],
  gens : Array[String],
  domain : Domain,
) -> Poly raise PolyError {
  if gens.length() != 1 {
    raise NotUnivariate
  }
  let map : Map[Monomial, FieldElem] = Map([])
  for i in 0..<coeffs.length() {
    let c = coeffs[i]
    if fe_is_zero(c) {
      continue
    }
    let mono = monomial_one(gens.length())
    mono.exps.set(0, i)
    add_term(map, mono, c, domain)
  }
  { coeffs: map, gens, domain, order: Lex }
}

///|
/// Multivariate dense encoding: coeffs are in row-major order with strides
/// given by degrees (length per generator minus 1).

///|
/// Public API `to_dense_multi`.
///
/// - Does: Provides the `to_dense_multi` operation for dense polynomial conversion.
/// - Input: parameters `poly : Poly`, `degrees : Array[Int]`, using the package
/// representation expected by the signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn to_dense_multi(
  poly : Poly,
  degrees : Array[Int],
) -> Array[FieldElem] raise PolyError {
  if poly.gens.length() != degrees.length() {
    raise BadGenerator("degree-shape")
  }
  let total = total_size(degrees)
  let dense : Array[FieldElem] = Array::make(total, fe_from_int(0, poly.domain))
  let strides = compute_strides(degrees)
  for m, c in poly.coeffs {
    if m.exps.length() != degrees.length() {
      continue
    }
    let mut idx = 0
    let mut in_bounds = true
    for i in 0..<degrees.length() {
      if m.exps[i] > degrees[i] {
        in_bounds = false
        break
      }
      idx = idx + m.exps[i] * strides[i]
    }
    if in_bounds {
      dense.set(idx, c)
    }
  }
  dense
}

///|
/// Build a sparse `Poly` from dense multivariate coefficients.

///|
/// Public API `from_dense_multi`.
///
/// - Does: Provides the `from_dense_multi` operation for dense polynomial conversion.
/// - Input: parameters `coeffs : Array[FieldElem]`, `gens : Array[String]`, `domain :
/// Domain`, `degrees : Array[Int]`, using the package representation expected by the
/// signature.
/// - Returns: a `Poly` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn from_dense_multi(
  coeffs : Array[FieldElem],
  gens : Array[String],
  domain : Domain,
  degrees : Array[Int],
) -> Poly raise PolyError {
  if gens.length() != degrees.length() {
    raise BadGenerator("degree-shape")
  }
  let total = total_size(degrees)
  if coeffs.length() != total {
    raise BadGenerator("dense-length")
  }
  let strides = compute_strides(degrees)
  let map : Map[Monomial, FieldElem] = Map([])
  for idx in 0..<coeffs.length() {
    let c = coeffs[idx]
    if fe_is_zero(c) {
      continue
    }
    let exps = index_to_exps(idx, strides, degrees)
    let mono = Monomial::{ exps, }
    add_term(map, mono, c, domain)
  }
  { coeffs: map, gens, domain, order: Lex }
}

///|
fn total_size(degrees : Array[Int]) -> Int {
  let mut total = 1
  for d in degrees {
    total = total * (d + 1)
  }
  total
}

///|
fn compute_strides(degrees : Array[Int]) -> Array[Int] {
  let n = degrees.length()
  let strides : Array[Int] = Array::make(n, 1)
  let mut acc = 1
  for i in 0..<n {
    strides.set(i, acc)
    acc = acc * (degrees[i] + 1)
  }
  strides
}

///|
fn index_to_exps(
  idx : Int,
  strides : Array[Int],
  degrees : Array[Int],
) -> Array[Int] {
  let exps : Array[Int] = Array::make(degrees.length(), 0)
  let mut rem = idx
  let mut pos = degrees.length()
  while pos > 0 {
    let i = pos - 1
    let stride = strides[i]
    let exp = rem / stride
    rem = rem % stride
    exps.set(i, exp)
    pos = pos - 1
  }
  exps
}
