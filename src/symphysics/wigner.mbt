///|
/// Exact Wigner 3j symbols and Clebsch-Gordan coefficients.

///|
fn wigner_expr_from_bigint(value : BigInt) -> @symcore.Expr {
  @symcore.number(@symnum.BigRational::from_bigint(value))
}

///|
fn wigner_rational_expr(num : BigInt, den : BigInt) -> @symcore.Expr {
  @symcore.number(try! @symnum.BigRational::new(num, den))
}

///|
fn wigner_phase_expr(k : Int) -> @symcore.Expr {
  let parity = if k < 0 { (-k) % 2 } else { k % 2 }
  if parity == 0 { @symcore.int(1) } else { @symcore.int(-1) }
}

///|
fn wigner_binomial_bigint(n : Int, k : Int) -> BigInt {
  if k < 0 || k > n {
    return BigInt::from_int(0)
  }
  let kk = if k > n - k { n - k } else { k }
  let mut acc = BigInt::from_int(1)
  let mut i = 1
  while i <= kk {
    acc = acc * BigInt::from_int(n - kk + i)
    acc = acc / BigInt::from_int(i)
    i = i + 1
  }
  acc
}

///|
fn wigner_doubled_int(value : @symcore.Expr) -> Int raise PhysicsError {
  match expr_number_value(value) {
    Some(q) => {
      let num = q.numerator()
      let den = q.denominator()
      if den.equal_int(1) {
        return (num * BigInt::from_int(2)).to_int()
      }
      if den.equal_int(2) {
        return num.to_int()
      }
      raise PhysicsError::ValueError(
        "expecting integer or half-integer, got \{@symprint.to_string(value)}",
      )
    }
    None =>
      raise PhysicsError::ValueError(
        "expecting integer or half-integer, got \{@symprint.to_string(value)}",
      )
  }
}

///|
fn wigner_check_dj_couple(dj1 : Int, dj2 : Int, dj3 : Int) -> Bool {
  if (dj1 + dj2 + dj3) % 2 != 0 {
    return false
  }
  if dj1 > dj2 + dj3 || dj2 > dj1 + dj3 || dj3 > dj1 + dj2 {
    return false
  }
  true
}

///|
pub fn wigner_3j(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  m_1 : @symcore.Expr,
  m_2 : @symcore.Expr,
  m_3 : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  let dj1 = wigner_doubled_int(j_1)
  let dj2 = wigner_doubled_int(j_2)
  let dj3 = wigner_doubled_int(j_3)
  let dm1 = wigner_doubled_int(m_1)
  let dm2 = wigner_doubled_int(m_2)
  let dm3 = wigner_doubled_int(m_3)

  if dm1 + dm2 + dm3 != 0 {
    return @symcore.int(0)
  }
  if !wigner_check_dj_couple(dj1, dj2, dj3) {
    return @symcore.int(0)
  }
  if dm1.abs() > dj1 || dm2.abs() > dj2 || dm3.abs() > dj3 {
    return @symcore.int(0)
  }
  if (dj1 - dm1) % 2 != 0 || (dj2 - dm2) % 2 != 0 || (dj3 - dm3) % 2 != 0 {
    return @symcore.int(0)
  }

  let sumj = (dj1 + dj2 + dj3) / 2
  let jm1 = sumj - dj1
  let jm2 = sumj - dj2
  let jm3 = sumj - dj3
  let j1mm1 = (dj1 - dm1) / 2
  let j2mm2 = (dj2 - dm2) / 2
  let j3mm3 = (dj3 - dm3) / 2
  let j1pm1 = (dj1 + dm1) / 2

  let imin = Int::max(0, Int::max(j1pm1 - jm2, j2mm2 - jm1))
  let imax = Int::min(jm3, Int::min(j1pm1, j2mm2))
  let mut sumres = BigInt::from_int(0)
  for ii in imin..<(imax + 1) {
    let term = wigner_binomial_bigint(jm3, ii) *
      wigner_binomial_bigint(jm2, j1pm1 - ii) *
      wigner_binomial_bigint(jm1, j2mm2 - ii)
    sumres = term - sumres
  }
  if sumres.is_zero() {
    return @symcore.int(0)
  }

  let res_num = wigner_binomial_bigint(dj1, jm2) * wigner_binomial_bigint(dj2, jm1)
  let res_den = wigner_binomial_bigint(sumj, jm3) *
    wigner_binomial_bigint(dj1, j1mm1) *
    wigner_binomial_bigint(dj2, j2mm2) *
    wigner_binomial_bigint(dj3, j3mm3) *
    BigInt::from_int(sumj + 1)
  let root = @symelem.sqrt(wigner_rational_expr(res_num, res_den))
  let phase = wigner_phase_expr(dj1 + (dj3 + dm3) / 2 + imax)
  phase * wigner_expr_from_bigint(sumres) * root
}

///|
pub fn clebsch_gordan(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  m_1 : @symcore.Expr,
  m_2 : @symcore.Expr,
  m_3 : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  let dj1 = wigner_doubled_int(j_1)
  let dj2 = wigner_doubled_int(j_2)
  let dm3 = wigner_doubled_int(m_3)
  let phase = wigner_phase_expr((dj1 - dj2 + dm3) / 2)
  phase *
    @symelem.sqrt((@symcore.int(2) * j_3) + @symcore.int(1)) *
    (try! wigner_3j(j_1, j_2, j_3, m_1, m_2, @symcore.int(-1) * m_3))
}
