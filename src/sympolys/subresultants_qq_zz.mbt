///|
/// Subresultants/resultant helpers over QQ/ZZ.
fn ensure_univar_pair(a : Poly, b : Poly) -> Unit raise PolyError {
  if a.gens.length() != 1 || b.gens.length() != 1 {
    raise PolyError::NotUnivariate
  }
}

///|
fn lift_pair_to_qq(p : Poly, q : Poly) -> (Poly, Poly) raise PolyError {
  ensure_univar_pair(p, q)
  if p.domain.not_equal(q.domain) || p.gens.not_equal(q.gens) {
    raise PolyError::DomainMismatch
  }
  match p.domain {
    Domain::QQ => (p, q)
    Domain::ZZ => (lift_to_qq(p), lift_to_qq(q))
    _ => raise PolyError::DomainMismatch
  }
}

///|
/// Compute resultant over a generic coefficient domain.
pub fn res(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  ensure_univar_pair(p, q)
  p.resultant(q, 0)
}

///|
/// Compute resultant specialized for `QQ`.
pub fn res_q(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  res(p, q)
}

///|
/// Compute resultant specialized for `ZZ`.
pub fn res_z(p : Poly, q : Poly) -> @symnum.BigRational raise PolyError {
  res(p, q)
}

///|
/// Return the subresultant remainder sequence for `(p, q)`.
pub fn subresultants_rem(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  subresultants(p, q)
}

///|
/// Euclidean PRS over QQ.
pub fn euclid_q(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  let (a0, b0) = lift_pair_to_qq(p, q)
  let seq : Array[Poly] = Array::new()
  seq.push(a0)
  seq.push(b0)
  let mut a = a0
  let mut b = b0
  while !b.is_zero() {
    let (_, r) = divmod_univar_rat(a, b)
    if r.is_zero() {
      break
    }
    seq.push(r)
    a = b
    b = r
  }
  seq
}

///|
/// Sturmian PRS over QQ.
pub fn sturm_q(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  let (a0, b0) = lift_pair_to_qq(p, q)
  let seq : Array[Poly] = Array::new()
  seq.push(a0)
  seq.push(b0)
  let mut a = a0
  let mut b = b0
  while !b.is_zero() {
    let (_, r) = divmod_univar_rat(a, b)
    if r.is_zero() {
      break
    }
    let neg_r = r.scale_coeff(fe_from_int(-1, Domain::QQ))
    seq.push(neg_r)
    a = b
    b = neg_r
  }
  seq
}

///|
/// Return the polynomial remainder in `ZZ[x]`.
pub fn rem_z(p : Poly, q : Poly) -> Poly raise PolyError {
  ensure_univar_pair(p, q)
  let (_, r) = p.divmod_univar(q)
  r
}

///|
/// Return the polynomial quotient in `ZZ[x]`.
pub fn quo_z(p : Poly, q : Poly) -> Poly raise PolyError {
  ensure_univar_pair(p, q)
  let (quo, _) = p.divmod_univar(q)
  quo
}

///|
/// Pell-Gordon compatibility aliases.
pub fn subresultants_pg(p : Poly, q : Poly) -> Array[Poly] raise PolyError {
  euclid_q(p, q)
}

///|
/// Pell-Gordon compatibility aliases.
pub fn modified_subresultants_pg(
  p : Poly,
  q : Poly,
) -> Array[Poly] raise PolyError {
  sturm_q(p, q)
}
