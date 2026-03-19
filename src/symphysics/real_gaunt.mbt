///|
/// Exact real Gaunt coefficients via the real-spherical-harmonic basis transform.

///|
priv struct RealGauntCoeff {
  real : Int
  imag : Int
  sqrt2_pow : Int
}

///|
fn real_gaunt_phase_int(k : Int) -> Int {
  if k % 2 == 0 {
    1
  } else {
    -1
  }
}

///|
fn real_gaunt_coeff_mul(
  a : RealGauntCoeff,
  b : RealGauntCoeff,
) -> RealGauntCoeff {
  RealGauntCoeff::{
    real: a.real * b.real - a.imag * b.imag,
    imag: a.real * b.imag + a.imag * b.real,
    sqrt2_pow: a.sqrt2_pow + b.sqrt2_pow,
  }
}

///|
fn real_gaunt_coeff_real_expr(coeff : RealGauntCoeff) -> Expr {
  if coeff.real == 0 {
    return int(0)
  }
  let half_pow = coeff.sqrt2_pow / 2
  let denom = if half_pow == 0 { 1 } else { 1 << half_pow }
  let base = rational_expr(coeff.real, denom)
  if coeff.sqrt2_pow % 2 == 0 {
    base
  } else {
    base * (@symelem.sqrt(int(2)) ^ int(-1))
  }
}

///|
fn real_gaunt_u(a : Int, b : Int) -> RealGauntCoeff? {
  if a.abs() != b.abs() {
    return None
  }
  if b == 0 {
    return if a == 0 {
      Some(RealGauntCoeff::{ real: 1, imag: 0, sqrt2_pow: 0 })
    } else {
      None
    }
  }
  if b > 0 {
    if a == b {
      return Some(RealGauntCoeff::{ real: 1, imag: 0, sqrt2_pow: 1 })
    }
    if a == -b {
      return Some(RealGauntCoeff::{
        real: real_gaunt_phase_int(a),
        imag: 0,
        sqrt2_pow: 1,
      })
    }
    return None
  }
  if a == b {
    return Some(RealGauntCoeff::{ real: 0, imag: -1, sqrt2_pow: 1 })
  }
  if a == -b {
    return Some(RealGauntCoeff::{
      real: 0,
      imag: real_gaunt_phase_int(b),
      sqrt2_pow: 1,
    })
  }
  None
}

///|
fn real_gaunt_candidates(mu : Int) -> Array[Int] {
  if mu == 0 {
    [0]
  } else {
    [mu, -mu]
  }
}

///|
pub fn real_gaunt(
  l_1 : Expr,
  l_2 : Expr,
  l_3 : Expr,
  mu_1 : Expr,
  mu_2 : Expr,
  mu_3 : Expr,
) -> Expr raise PhysicsError {
  gaunt_require_integer(l_1)
  gaunt_require_integer(l_2)
  gaunt_require_integer(l_3)
  gaunt_require_integer(mu_1)
  gaunt_require_integer(mu_2)
  gaunt_require_integer(mu_3)
  let l1 = expr_integer_value(l_1).unwrap()
  let l2 = expr_integer_value(l_2).unwrap()
  let l3 = expr_integer_value(l_3).unwrap()
  let mu1 = expr_integer_value(mu_1).unwrap()
  let mu2 = expr_integer_value(mu_2).unwrap()
  let mu3 = expr_integer_value(mu_3).unwrap()

  let mut neg_count = 0
  for item in [mu1, mu2, mu3] {
    if item < 0 {
      neg_count = neg_count + 1
    }
  }
  if neg_count % 2 != 0 {
    return int(0)
  }
  if (l1 + l2 + l3) % 2 != 0 {
    return int(0)
  }
  let lmax = l2 + l3
  let mut lmin = wigner_int_max(
    (l2 - l3).abs(),
    wigner_int_min((mu2 + mu3).abs(), (mu2 - mu3).abs()),
  )
  if (lmin + lmax) % 2 != 0 {
    lmin = lmin + 1
  }
  let mut admissible = false
  let mut probe = lmax
  while probe >= lmin {
    if probe == l1 {
      admissible = true
      break
    }
    probe = probe - 2
  }
  if !admissible {
    return int(0)
  }

  let mut acc = int(0)
  for m1 in real_gaunt_candidates(mu1) {
    let u1 = match real_gaunt_u(m1, mu1) {
      Some(v) => v
      None => continue
    }
    for m2 in real_gaunt_candidates(mu2) {
      let u2 = match real_gaunt_u(m2, mu2) {
        Some(v) => v
        None => continue
      }
      let m3 = -m1 - m2
      let u3 = match real_gaunt_u(m3, mu3) {
        Some(v) => v
        None => continue
      }
      let coeff = real_gaunt_coeff_mul(real_gaunt_coeff_mul(u1, u2), u3)
      let coeff_expr = real_gaunt_coeff_real_expr(coeff)
      match expr_number_value(coeff_expr) {
        Some(n) if n.is_zero() => ()
        _ =>
          acc = acc +
            coeff_expr *
            (try! gaunt(
              l_1,
              l_2,
              l_3,
              int(m1),
              int(m2),
              int(m3),
            ))
      }
    }
  }
  acc
}
