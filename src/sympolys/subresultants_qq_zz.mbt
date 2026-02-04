///|
/// Minimal subresultants/resultant helpers over QQ/ZZ (subset).
fn ensure_univar_pair(a : Poly, b : Poly) -> Unit raise PolyError {
  if a.gens.length() != 1 || b.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
pub fn res(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  ensure_univar_pair(p, q)
  p.resultant(q, 0)
}

///|
pub fn res_q(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  res(p, q)
}

///|
pub fn res_z(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  res(p, q)
}

///|
pub fn subresultants_rem(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants(p, q)
}
