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
  let parity = if k < 0 { -k % 2 } else { k % 2 }
  if parity == 0 {
    @symcore.int(1)
  } else {
    @symcore.int(-1)
  }
}

///|
fn wigner_int_max(a : Int, b : Int) -> Int {
  if a >= b {
    a
  } else {
    b
  }
}

///|
fn wigner_int_min(a : Int, b : Int) -> Int {
  if a <= b {
    a
  } else {
    b
  }
}

///|
fn wigner_int_max4(a : Int, b : Int, c : Int, d : Int) -> Int {
  wigner_int_max(wigner_int_max(a, b), wigner_int_max(c, d))
}

///|
fn wigner_int_min3(a : Int, b : Int, c : Int) -> Int {
  wigner_int_min(wigner_int_min(a, b), c)
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
fn wigner_expr_from_doubled_int(value : Int) -> @symcore.Expr {
  if value % 2 == 0 {
    @symcore.int(value / 2)
  } else {
    rational_expr(value, 2)
  }
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

  let res_num = wigner_binomial_bigint(dj1, jm2) *
    wigner_binomial_bigint(dj2, jm1)
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
  @symelem.sqrt(@symcore.int(2) * j_3 + @symcore.int(1)) *
  (try! wigner_3j(j_1, j_2, j_3, m_1, m_2, @symcore.int(-1) * m_3))
}

///|
pub fn wigner_6j(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  j_4 : @symcore.Expr,
  j_5 : @symcore.Expr,
  j_6 : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  let dj1 = wigner_doubled_int(j_1)
  let dj2 = wigner_doubled_int(j_2)
  let dj3 = wigner_doubled_int(j_3)
  let dj4 = wigner_doubled_int(j_4)
  let dj5 = wigner_doubled_int(j_5)
  let dj6 = wigner_doubled_int(j_6)
  if !wigner_check_dj_couple(dj1, dj2, dj3) ||
    !wigner_check_dj_couple(dj1, dj5, dj6) ||
    !wigner_check_dj_couple(dj4, dj2, dj6) ||
    !wigner_check_dj_couple(dj4, dj5, dj3) {
    return @symcore.int(0)
  }
  let j123 = (dj1 + dj2 + dj3) / 2
  let j156 = (dj1 + dj5 + dj6) / 2
  let j426 = (dj4 + dj2 + dj6) / 2
  let j453 = (dj4 + dj5 + dj3) / 2
  let jpm123 = (dj1 + dj2 - dj3) / 2
  let jpm132 = (dj1 + dj3 - dj2) / 2
  let jpm231 = (dj2 + dj3 - dj1) / 2
  let jpm156 = (dj1 + dj5 - dj6) / 2
  let jpm426 = (dj4 + dj2 - dj6) / 2
  let jpm453 = (dj4 + dj5 - dj3) / 2
  let imin = wigner_int_max4(j123, j453, j426, j156)
  let imax = wigner_int_max(
    jpm123 + j453,
    wigner_int_max(jpm132 + j426, jpm231 + j156),
  )
  let mut sumres = BigInt::from_int(0)
  for ii in imin..<(imax + 1) {
    let term = wigner_binomial_bigint(ii + 1, j123 + 1) *
      wigner_binomial_bigint(jpm123, ii - j453) *
      wigner_binomial_bigint(jpm132, ii - j426) *
      wigner_binomial_bigint(jpm231, ii - j156)
    sumres = term - sumres
  }
  if sumres.is_zero() {
    return @symcore.int(0)
  }
  if imax % 2 != 0 {
    sumres = BigInt::from_int(0) - sumres
  }
  let res_num = wigner_binomial_bigint(j123 + 1, dj1 + 1) *
    wigner_binomial_bigint(dj1, jpm123)
  let mut res_den = wigner_binomial_bigint(j156 + 1, dj1 + 1) *
    wigner_binomial_bigint(dj1, jpm156) *
    wigner_binomial_bigint(j426 + 1, dj4 + 1) *
    wigner_binomial_bigint(dj4, jpm426) *
    wigner_binomial_bigint(j453 + 1, dj4 + 1) *
    wigner_binomial_bigint(dj4, jpm453)
  res_den = res_den * BigInt::from_int((dj4 + 1) * (dj4 + 1))
  wigner_expr_from_bigint(sumres) *
  @symelem.sqrt(wigner_rational_expr(res_num, res_den))
}

///|
pub fn racah(
  aa : @symcore.Expr,
  bb : @symcore.Expr,
  cc : @symcore.Expr,
  dd : @symcore.Expr,
  ee : @symcore.Expr,
  ff : @symcore.Expr,
) -> @symcore.Expr {
  let res = try! wigner_6j(aa, bb, ee, dd, cc, ff)
  match expr_number_value(res) {
    Some(n) if n.is_zero() => @symcore.int(0)
    _ => {
      let daa = try! wigner_doubled_int(aa)
      let dbb = try! wigner_doubled_int(bb)
      let dcc = try! wigner_doubled_int(cc)
      let ddd = try! wigner_doubled_int(dd)
      let phase = wigner_phase_expr((daa + dbb + dcc + ddd) / 2)
      phase * res
    }
  }
}

///|
pub fn wigner_9j(
  j_1 : @symcore.Expr,
  j_2 : @symcore.Expr,
  j_3 : @symcore.Expr,
  j_4 : @symcore.Expr,
  j_5 : @symcore.Expr,
  j_6 : @symcore.Expr,
  j_7 : @symcore.Expr,
  j_8 : @symcore.Expr,
  j_9 : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  let dj1 = wigner_doubled_int(j_1)
  let dj2 = wigner_doubled_int(j_2)
  let dj3 = wigner_doubled_int(j_3)
  let dj4 = wigner_doubled_int(j_4)
  let dj5 = wigner_doubled_int(j_5)
  let dj6 = wigner_doubled_int(j_6)
  let dj7 = wigner_doubled_int(j_7)
  let dj8 = wigner_doubled_int(j_8)
  let dj9 = wigner_doubled_int(j_9)
  if !wigner_check_dj_couple(dj1, dj2, dj3) ||
    !wigner_check_dj_couple(dj4, dj5, dj6) ||
    !wigner_check_dj_couple(dj7, dj8, dj9) ||
    !wigner_check_dj_couple(dj1, dj4, dj7) ||
    !wigner_check_dj_couple(dj2, dj5, dj8) ||
    !wigner_check_dj_couple(dj3, dj6, dj9) {
    return @symcore.int(0)
  }
  let j123 = (dj1 + dj2 + dj3) / 2
  let j456 = (dj4 + dj5 + dj6) / 2
  let j789 = (dj7 + dj8 + dj9) / 2
  let j147 = (dj1 + dj4 + dj7) / 2
  let j258 = (dj2 + dj5 + dj8) / 2
  let j369 = (dj3 + dj6 + dj9) / 2
  let pm123 = (dj1 + dj2 - dj3) / 2
  let pm132 = (dj1 + dj3 - dj2) / 2
  let pm231 = (dj2 + dj3 - dj1) / 2
  let pm456 = (dj4 + dj5 - dj6) / 2
  let pm465 = (dj4 + dj6 - dj5) / 2
  let pm564 = (dj5 + dj6 - dj4) / 2
  let pm789 = (dj7 + dj8 - dj9) / 2
  let pm798 = (dj7 + dj9 - dj8) / 2
  let pm897 = (dj8 + dj9 - dj7) / 2
  let dtmin = wigner_int_max(
    (dj2 - dj6).abs(),
    wigner_int_max((dj4 - dj8).abs(), (dj1 - dj9).abs()),
  )
  let dtmax = wigner_int_min3(dj2 + dj6, dj4 + dj8, dj1 + dj9)
  let mut sumres = BigInt::from_int(0)
  let mut dt = dtmin
  while dt <= dtmax {
    let j19t = (dj1 + dj9 + dt) / 2
    let j26t = (dj2 + dj6 + dt) / 2
    let j48t = (dj4 + dj8 + dt) / 2

    let xmin = wigner_int_max4(j123, j369, j26t, j19t)
    let xmax = wigner_int_min3(pm123 + j369, pm132 + j26t, pm231 + j19t)
    let mut suma = BigInt::from_int(0)
    for x in xmin..<(xmax + 1) {
      let ax = wigner_binomial_bigint(x + 1, j19t + 1) *
        wigner_binomial_bigint((dj1 + dj9 - dt) / 2, x - j26t) *
        wigner_binomial_bigint((dj1 + dt - dj9) / 2, x - j369) *
        wigner_binomial_bigint((dt + dj9 - dj1) / 2, x - j123)
      suma = ax - suma
    }

    let ymin = wigner_int_max4(j456, j258, j26t, j48t)
    let ymax = wigner_int_min3(pm456 + j26t, pm465 + j258, pm564 + j48t)
    let mut sumb = BigInt::from_int(0)
    for y in ymin..<(ymax + 1) {
      let by = wigner_binomial_bigint(y + 1, j26t + 1) *
        wigner_binomial_bigint((dj2 + dj6 - dt) / 2, y - j48t) *
        wigner_binomial_bigint((dt + dj6 - dj2) / 2, y - j258) *
        wigner_binomial_bigint((dj2 + dt - dj6) / 2, y - j456)
      sumb = by - sumb
    }

    let zmin = wigner_int_max4(j789, j147, j48t, j19t)
    let zmax = wigner_int_min3(pm789 + j19t, pm798 + j48t, pm897 + j147)
    let mut sumc = BigInt::from_int(0)
    for z in zmin..<(zmax + 1) {
      let cz = wigner_binomial_bigint(z + 1, j48t + 1) *
        wigner_binomial_bigint((dj4 + dj8 - dt) / 2, z - j19t) *
        wigner_binomial_bigint((dt + dj8 - dj4) / 2, z - j147) *
        wigner_binomial_bigint((dj4 + dt - dj8) / 2, z - j789)
      sumc = cz - sumc
    }

    let mut abc = BigInt::from_int(dt + 1) * suma * sumb * sumc
    if (xmax + ymax + zmax) % 2 != 0 {
      abc = BigInt::from_int(0) - abc
    }
    sumres = sumres + abc
    dt = dt + 2
  }
  if sumres.is_zero() {
    return @symcore.int(0)
  }
  if dtmax % 2 != 0 {
    sumres = BigInt::from_int(0) - sumres
  }
  let mut res_den = BigInt::from_int(
    (dj3 + 1) * (dj6 + 1) * (dj9 + 1) * (dj7 + 1) * (dj8 + 1) * (dj9 + 1),
  )
  res_den = res_den *
    wigner_binomial_bigint(j123 + 1, dj3 + 1) *
    wigner_binomial_bigint(dj3, pm231) *
    wigner_binomial_bigint(j456 + 1, dj6 + 1) *
    wigner_binomial_bigint(dj6, pm564) *
    wigner_binomial_bigint(j789 + 1, dj9 + 1) *
    wigner_binomial_bigint(dj9, pm897) *
    wigner_binomial_bigint(j147 + 1, dj7 + 1) *
    wigner_binomial_bigint(dj7, (dj4 + dj7 - dj1) / 2) *
    wigner_binomial_bigint(j258 + 1, dj8 + 1) *
    wigner_binomial_bigint(dj8, (dj5 + dj8 - dj2) / 2) *
    wigner_binomial_bigint(j369 + 1, dj9 + 1) *
    wigner_binomial_bigint(dj9, (dj6 + dj9 - dj3) / 2)
  wigner_expr_from_bigint(sumres) *
  @symelem.sqrt(wigner_rational_expr(BigInt::from_int(1), res_den))
}

///|
pub fn dot_rot_grad_ynm(
  j : @symcore.Expr,
  p : @symcore.Expr,
  l : @symcore.Expr,
  m : @symcore.Expr,
  theta : @symcore.Expr,
  phi : @symcore.Expr,
) -> @symcore.Expr raise PhysicsError {
  let dj = wigner_doubled_int(j)
  let dp = wigner_doubled_int(p)
  let dl = wigner_doubled_int(l)
  let dm = wigner_doubled_int(m)
  if dj % 2 != 0 || dp % 2 != 0 || dl % 2 != 0 || dm % 2 != 0 {
    return @symcore.function("dot_rot_grad_Ynm", [j, p, l, m, theta, phi])
  }
  let ji = dj / 2
  let pi = dp / 2
  let li = dl / 2
  let mi = dm / 2
  let mut acc = @symcore.int(0)
  let lower = (li - ji).abs()
  let upper = li + ji
  for k in lower..<(upper + 1) {
    let k_expr = @symcore.int(k)
    let alpha = @symelem.sqrt(
        expr_div(
          (@symcore.int(2) * l + @symcore.int(1)) *
          (@symcore.int(2) * j + @symcore.int(1)) *
          (@symcore.int(2) * k_expr + @symcore.int(1)),
          @symcore.int(4) * pi_expr(),
        ),
      ) *
      (try! wigner_3j(
        j,
        l,
        k_expr,
        @symcore.int(0),
        @symcore.int(0),
        @symcore.int(0),
      )) *
      (try! wigner_3j(j, l, k_expr, p, m, @symcore.int(-1) * (m + p)))
    let coeff = alpha *
      rational_expr(1, 2) *
      (
        (k_expr ^ @symcore.int(2)) -
        (j ^ @symcore.int(2)) -
        (l ^ @symcore.int(2)) +
        k_expr -
        j -
        l
      )
    acc = acc +
      wigner_phase_expr(mi + pi) *
      @symspec.ynm(k_expr, m + p, theta, phi) *
      coeff
  }
  acc
}

///|
pub fn wigner_d_small(
  j_tot : @symcore.Expr,
  beta : @symcore.Expr,
) -> ExplicitMatrix raise PhysicsError {
  let dJ = wigner_doubled_int(j_tot)
  guard dJ >= 0 else { raise PhysicsError::ValueError("J must be nonnegative") }
  let size = dJ + 1
  let half_beta = beta * rational_expr(1, 2)
  let cos_half = @symelem.cos(half_beta)
  let sin_half = @symelem.sin(half_beta)
  let rows : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<size {
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<size {
      let sigmamax = wigner_int_min(i, j)
      let sigmamin = wigner_int_max(0, i + j - dJ)
      let numer = wigner_binomial_bigint(dJ, j)
      let denom = wigner_binomial_bigint(dJ, i)
      let dij = @symelem.sqrt(wigner_rational_expr(numer, denom))
      let mut terms = @symcore.int(0)
      for s in sigmamin..<(sigmamax + 1) {
        let phase = wigner_phase_expr(i - s)
        let coeff = wigner_expr_from_bigint(
          wigner_binomial_bigint(dJ - j, i - s) * wigner_binomial_bigint(j, s),
        )
        let cos_exp = 2 * s + dJ - i - j
        let sin_exp = i + j - 2 * s
        terms = terms +
          phase *
          coeff *
          (cos_half ^ @symcore.int(cos_exp)) *
          (sin_half ^ @symcore.int(sin_exp))
      }
      row.push(dij * terms)
    }
    rows.push(row)
  }
  explicit_matrix_from_rows(rows)
}

///|
pub fn wigner_d(
  j_tot : @symcore.Expr,
  alpha : @symcore.Expr,
  beta : @symcore.Expr,
  gamma : @symcore.Expr,
) -> ExplicitMatrix raise PhysicsError {
  let d_small = try! wigner_d_small(j_tot, beta)
  let dJ = wigner_doubled_int(j_tot)
  let size = dJ + 1
  let rows : Array[Array[@symcore.Expr]] = Array::new()
  for i in 0..<size {
    let mi = wigner_expr_from_doubled_int(dJ - 2 * i)
    let row : Array[@symcore.Expr] = Array::new()
    for j in 0..<size {
      let mj = wigner_expr_from_doubled_int(dJ - 2 * j)
      row.push(
        @symelem.exp(i_expr() * mi * alpha) *
        d_small.rows[i][j] *
        @symelem.exp(i_expr() * mj * gamma),
      )
    }
    rows.push(row)
  }
  explicit_matrix_from_rows(rows)
}
