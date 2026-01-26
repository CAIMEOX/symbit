///|
/// Modular arithmetic helpers for GF(p) domains.
pub fn normalize_mod(
  value : @symnum.BigRational,
  domain : Domain,
) -> @symnum.BigRational raise PolyError {
  match domain {
    Domain::GF(p) | Domain::GFExt(p, _, _) => {
      if p <= 1 {
        raise PolyError::BadModulus
      }
      let m = BigInt::from_int(p)
      let mut num = value.numerator().mod(m)
      let mut den = value.denominator().mod(m)
      if num.op_lt(BigInt::from_int(0)) {
        num = num.add(m)
      }
      if den.op_lt(BigInt::from_int(0)) {
        den = den.add(m)
      }
      if den.is_zero() {
        raise PolyError::DivisionByZero
      }
      let inv_den = mod_inv(den, m)
      @symnum.BigRational::from_bigint(num.mul(inv_den))
    }
    Domain::AlgExt(_, _, _) => raise PolyError::NotImplemented("algebraic-extension-mod")
    _ => value
  }
}

///|
/// Extended Euclid for modular inverses.
fn mod_inv(a : BigInt, m : BigInt) -> BigInt raise PolyError {
  let mut r0 = m
  let mut r1 = a.mod(m)
  let mut t0 = BigInt::from_int(0)
  let mut t1 = BigInt::from_int(1)
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
    raise PolyError::DivisionByZero
  }
  let mut inv = t0.mod(m)
  if inv.op_lt(BigInt::from_int(0)) {
    inv = inv.add(m)
  }
  inv
}
