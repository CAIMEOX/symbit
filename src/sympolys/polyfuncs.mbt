///|
pub fn interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  gen : String,
  domain : Domain,
) -> Poly raise PolyError {
  let builder = PolyBuilder::new([gen], domain)
  let mut result = Poly::zero([gen], domain)
  for i in 0..<points.length() {
    let (xi, yi) = points[i]
    let mut basis = Poly::one([gen], domain)
    let mut denom = @symnum.BigRational::one()
    for j in 0..<points.length() {
      if i == j {
        continue
      }
      let (xj, _) = points[j]
      denom = denom.mul_r(xi.add_r(xj.neg_r()))
      let term_expr = @symcore.symbol(gen) - @symcore.number(xj)
      let term = builder.from_expr(term_expr)
      basis = basis.mul(term)
    }
    let denom_fe = ensure_coeff_domain(denom, domain)
    let denom_inv = fe_inv(denom_fe)
    basis = basis.scale_coeff(denom_inv)
    let yi_fe = ensure_coeff_domain(yi, domain)
    basis = basis.scale_coeff(yi_fe)
    result = result.add(basis)
  }
  result
}

///|
pub fn rational_interpolate(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  gen : String,
  domain : Domain,
) -> (Poly, Poly) raise PolyError {
  if points.is_empty() {
    raise PolyError::NonPolynomial
  }
  let n = points.length()
  let k = n - deg_num - 1
  if k < 0 {
    raise PolyError::NotImplemented("rational_interpolate: too few points")
  }
  let matrix = build_rational_matrix(points, deg_num, k)
  let coeffs = nullspace_vector(matrix)
  let den_start = deg_num + 1
  let den_end = den_start + k
  let mut den_deg = -1
  let mut idx = den_end
  while idx >= den_start {
    if !coeffs[idx].is_zero() {
      den_deg = idx - den_start
      break
    }
    idx = idx - 1
  }
  if den_deg < 0 {
    raise PolyError::NotImplemented("rational_interpolate: zero denominator")
  }
  let lead = coeffs[den_start + den_deg]
  let inv_lead = lead.reciprocal() catch {
    _ => raise PolyError::DivisionByZero
  }
  for i in 0..<coeffs.length() {
    coeffs.set(i, coeffs[i].mul_r(inv_lead))
  }
  let num_coeffs : Array[@symnum.BigRational] = Array::new()
  for i in 0..=deg_num {
    num_coeffs.push(coeffs[i])
  }
  let den_coeffs : Array[@symnum.BigRational] = Array::new()
  for i in 0..=den_deg {
    den_coeffs.push(coeffs[den_start + i])
  }
  let num = poly_from_coeffs(num_coeffs, gen, domain)
  let den = poly_from_coeffs(den_coeffs, gen, domain)
  (num, den)
}

///|
fn build_rational_matrix(
  points : Array[(@symnum.BigRational, @symnum.BigRational)],
  deg_num : Int,
  k : Int,
) -> Array[Array[@symnum.BigRational]] {
  let rows : Array[Array[@symnum.BigRational]] = Array::new()
  for i in 0..<points.length() {
    let (xi, yi) = points[i]
    let row : Array[@symnum.BigRational] = Array::new()
    let mut pow = @symnum.BigRational::one()
    for _ in 0..=deg_num {
      row.push(pow)
      pow = pow.mul_r(xi)
    }
    let mut pow_den = @symnum.BigRational::one()
    for _ in 0..=k {
      row.push(yi.neg_r().mul_r(pow_den))
      pow_den = pow_den.mul_r(xi)
    }
    rows.push(row)
  }
  rows
}

///|
fn nullspace_vector(
  matrix : Array[Array[@symnum.BigRational]],
) -> Array[@symnum.BigRational] raise PolyError {
  let rows = matrix.length()
  guard rows > 0 else { raise PolyError::NonPolynomial }
  let cols = matrix[0].length()
  let r = matrix
  let pivot_cols : Array[Int] = Array::new()
  let mut row = 0
  for col in 0..<cols {
    if row >= rows {
      break
    }
    let mut pivot = -1
    for i in row..<rows {
      if !r[i][col].is_zero() {
        pivot = i
        break
      }
    }
    if pivot == -1 {
      continue
    }
    if pivot != row {
      let tmp = r[row]
      r.set(row, r[pivot])
      r.set(pivot, tmp)
    }
    let pivot_val = r[row][col]
    for j in col..<cols {
      let v = r[row][j]
      r[row].set(j, v.div_r(pivot_val) catch {
        _ => raise PolyError::DivisionByZero
      })
    }
    for i in 0..<rows {
      if i == row {
        continue
      }
      let factor = r[i][col]
      if factor.is_zero() {
        continue
      }
      for j in col..<cols {
        let val = r[i][j]
        let sub = factor.mul_r(r[row][j])
        r[i].set(j, val.add_r(sub.neg_r()))
      }
    }
    pivot_cols.push(col)
    row += 1
  }
  let pivot_flags : Array[Bool] = Array::new()
  for _ in 0..<cols {
    pivot_flags.push(false)
  }
  for pc in pivot_cols {
    pivot_flags.set(pc, true)
  }
  let free_cols : Array[Int] = Array::new()
  for c in 0..<cols {
    if !pivot_flags[c] {
      free_cols.push(c)
    }
  }
  guard !free_cols.is_empty() else {
    raise PolyError::NotImplemented("rational_interpolate: no free column")
  }
  let free_col = free_cols[0]
  let sol : Array[@symnum.BigRational] = Array::new()
  for _ in 0..<cols {
    sol.push(@symnum.BigRational::zero())
  }
  sol.set(free_col, @symnum.BigRational::one())
  for i in 0..<pivot_cols.length() {
    let pc = pivot_cols[i]
    let coeff = r[i][free_col]
    sol.set(pc, coeff.neg_r())
  }
  sol
}

///|
fn poly_from_coeffs(
  coeffs : Array[@symnum.BigRational],
  gen : String,
  domain : Domain,
) -> Poly raise PolyError {
  let map : Map[Monomial, FieldElem] = Map::new()
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if coeff.is_zero() {
      continue
    }
    let mono = monomial_one(1)
    mono.exps.set(0, i)
    let fe = ensure_coeff_domain(coeff, domain)
    add_term(map, mono, fe, domain)
  }
  Poly::{ coeffs: map, gens: [gen], domain, order: TermOrder::Lex }
}
