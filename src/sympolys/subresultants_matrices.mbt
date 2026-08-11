///|
fn subres_matrix_zero(domain : Domain) -> FieldElem raise PolyError {
  fe_from_int(0, domain)
}

///|
fn subres_matrix_one(domain : Domain) -> FieldElem raise PolyError {
  fe_from_int(1, domain)
}

///|
fn subres_matrix_new(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let zero = subres_matrix_zero(domain)
  Array::makei(rows, _ => Array::make(cols, zero))
}

///|
fn subres_coeff_degree(poly : Poly, degree : Int) -> FieldElem raise PolyError {
  let exps = Array::make(poly.gens.length(), 0)
  if !exps.is_empty() {
    exps.set(0, degree)
  }
  match poly.coeffs.get({ exps, }) {
    Some(c) => c
    None => subres_matrix_zero(poly.domain)
  }
}

///|
fn subres_coeffs_high(poly : Poly) -> Array[FieldElem] raise PolyError {
  let d = degree(poly)
  if d < 0 {
    return []
  }
  let out : Array[FieldElem] = []
  for k in 0..<=d {
    out.push(subres_coeff_degree(poly, d - k))
  }
  out
}

///|
fn subres_coeffs_low(
  poly : Poly,
  upto : Int,
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = []
  for k in 0..<=upto {
    out.push(subres_coeff_degree(poly, k))
  }
  out
}

///|
fn subres_ensure_matrix_pair(p : Poly, q : Poly) -> Unit raise PolyError {
  ensure_univar_pair(p, q)
  if Eq::not_equal(p.domain, q.domain) || p.gens != q.gens {
    raise DomainMismatch
  }
}

///|
fn subres_empty_matrix(domain : Domain) -> DomainMatrix raise PolyError {
  DomainMatrix::zeros(0, 0, domain)
}

///|
fn subres_single_zero_matrix(domain : Domain) -> DomainMatrix raise PolyError {
  DomainMatrix::zeros(1, 1, domain)
}

///|
fn subres_rotate_right(row : Array[FieldElem], k : Int) -> Array[FieldElem] {
  if row.is_empty() {
    return []
  }
  let n = row.length()
  let shift = (k % n + n) % n
  let out : Array[FieldElem] = []
  for i in 0..<n {
    out.push(row[(i - shift + n) % n])
  }
  out
}

///|
/// Return the backward identity matrix.
///
/// - Does: Mirrors SymPy `backward_eye` with ones on the anti-diagonal.
/// - Input: Matrix size `n` and optional coefficient domain.
/// - Returns: A square `DomainMatrix`.
/// - Limits: Negative sizes raise `PolyError::BadExponent`.
pub fn backward_eye(
  n : Int,
  domain? : Domain = ZZ,
) -> DomainMatrix raise PolyError {
  if n < 0 {
    raise BadExponent
  }
  let rows = subres_matrix_new(n, n, domain)
  let one = subres_matrix_one(domain)
  for i in 0..<n {
    rows[i].set(n - 1 - i, one)
  }
  DomainMatrix::from_list(rows, domain)
}

///|
/// Build a Sylvester matrix for two univariate polynomials.
///
/// - Does: Mirrors SymPy `sylvester(f, g, x, method)`.
/// - Input: Two compatible univariate `Poly` values and `method` `1` or `2`.
/// - Returns: A `DomainMatrix`.
/// - Limits: Supports exact `Poly` inputs already in the same domain and gens.
pub fn sylvester(
  f : Poly,
  g : Poly,
  kind? : Int = 1,
) -> DomainMatrix raise PolyError {
  subres_ensure_matrix_pair(f, g)
  let m = degree(f)
  let n = degree(g)
  if (m == n && n < 0) ||
    (m == n && n == 0) ||
    (m == 0 && n < 0) ||
    (m < 0 && n == 0) {
    return subres_empty_matrix(f.domain)
  }
  if (m >= 1 && n < 0) || (m < 0 && n >= 1) {
    return subres_single_zero_matrix(f.domain)
  }
  let fp = subres_coeffs_high(f)
  let gp = subres_coeffs_high(g)
  if kind <= 1 {
    let dim = m + n
    let rows = subres_matrix_new(dim, dim, f.domain)
    for i in 0..<n {
      for j in 0..<fp.length() {
        rows[i].set(i + j, fp[j])
      }
    }
    for i in n..<dim {
      for j in 0..<gp.length() {
        rows[i].set(i - n + j, gp[j])
      }
    }
    return DomainMatrix::from_list(rows, f.domain)
  }
  let mx = if m > n { m } else { n }
  let dim = 2 * mx
  let rows = subres_matrix_new(dim, dim, f.domain)
  let fp_pad : Array[FieldElem] = []
  let gp_pad : Array[FieldElem] = []
  for _ in 0..<(mx + 1 - fp.length()) {
    fp_pad.push(subres_matrix_zero(f.domain))
  }
  for c in fp {
    fp_pad.push(c)
  }
  for _ in 0..<(mx + 1 - gp.length()) {
    gp_pad.push(subres_matrix_zero(f.domain))
  }
  for c in gp {
    gp_pad.push(c)
  }
  for i in 0..<mx {
    for j in 0..<fp_pad.length() {
      rows[2 * i].set(i + j, fp_pad[j])
    }
    for j in 0..<gp_pad.length() {
      rows[2 * i + 1].set(i + j, gp_pad[j])
    }
  }
  DomainMatrix::from_list(rows, f.domain)
}

///|
/// Evaluate the sign/value determinant used by subresultant PRS algorithms.
///
/// - Does: Mirrors SymPy `correct_sign` by deleting the same Sylvester-matrix
///   rows and columns before taking the determinant.
/// - Input: Original degrees, the first Sylvester matrix, row deletion count,
///   and column deletion count.
/// - Returns: A determinant in the matrix domain.
/// - Limits: Invalid dimensions or deletion counts raise `PolyError`.
pub fn correct_sign(
  deg_f : Int,
  deg_g : Int,
  s1 : DomainMatrix,
  rdel : Int,
  cdel : Int,
) -> FieldElem raise PolyError {
  if deg_f < 0 || deg_g < 0 || rdel < 0 || cdel < 0 {
    raise BadExponent
  }
  let dim = deg_f + deg_g
  if s1.rows != dim || s1.cols != dim || rdel > deg_f || rdel > deg_g {
    raise DomainMismatch
  }
  let row_ids : Array[Int] = []
  for i in 0..<(deg_g - rdel) {
    row_ids.push(i)
  }
  for i in deg_g..<(dim - rdel) {
    row_ids.push(i)
  }
  let row_count = row_ids.length()
  if cdel == 0 {
    let col_ids : Array[Int] = []
    for i in 0..<row_count {
      col_ids.push(i)
    }
    return s1.extract(row_ids, col_ids).det()
  }
  if row_count == 0 {
    raise DomainMismatch
  }
  let replacement_col = row_count + cdel - 1
  if replacement_col >= s1.cols {
    raise DomainMismatch
  }
  let col_ids : Array[Int] = []
  for i in 0..<(row_count - 1) {
    col_ids.push(i)
  }
  col_ids.push(replacement_col)
  s1.extract(row_ids, col_ids).det()
}

///|
/// Create the small matrix used by Van Vleck-style subresultant steps.
///
/// - Does: Mirrors SymPy `create_ma` by stacking right rotations of `row1`
///   followed by `row2`.
/// - Input: Dividend/divisor degrees, two coefficient rows, column count, and
///   optional domain.
/// - Returns: A `DomainMatrix`.
/// - Limits: Reversed degree order or row/column mismatches raise `PolyError`.
pub fn create_ma(
  deg_f : Int,
  deg_g : Int,
  row1 : Array[FieldElem],
  row2 : Array[FieldElem],
  col_num : Int,
  domain? : Domain = ZZ,
) -> DomainMatrix raise PolyError {
  if col_num < 0 {
    raise BadExponent
  }
  if deg_g - deg_f >= 1 || row1.length() != col_num || row2.length() != col_num {
    raise DomainMismatch
  }
  let row_count = deg_f - deg_g + 2
  if row_count < 0 {
    raise DomainMismatch
  }
  let rows = subres_matrix_new(row_count, col_num, domain)
  for i in 0..<(deg_f - deg_g + 1) {
    rows.set(i, subres_rotate_right(row1, i))
  }
  rows.set(row_count - 1, row2.copy())
  DomainMatrix::from_list(rows, domain)
}

///|
fn bezout_coeff_matrix(
  p : Poly,
  q : Poly,
  mx : Int,
) -> Array[Array[FieldElem]] raise PolyError {
  let coeffs = subres_matrix_new(mx, mx, p.domain)
  let pp = subres_coeffs_low(p, mx)
  let qq = subres_coeffs_low(q, mx)
  for i in 0..<=mx {
    for j in 0..<=mx {
      let pc = pp[i]
      let qc = qq[j]
      if fe_is_zero(pc) || fe_is_zero(qc) || i == j {
        continue
      }
      let factor = fe_mul(pc, qc)
      if i > j {
        let d = i - j
        for k in 0..<d {
          let x_exp = i - 1 - k
          let y_exp = j + k
          coeffs[x_exp].set(y_exp, fe_add(coeffs[x_exp][y_exp], factor))
        }
      } else {
        let d = j - i
        let neg_factor = fe_neg(factor)
        for k in 0..<d {
          let x_exp = j - 1 - k
          let y_exp = i + k
          coeffs[x_exp].set(y_exp, fe_add(coeffs[x_exp][y_exp], neg_factor))
        }
      }
    }
  }
  coeffs
}

///|
/// Build the Bezout matrix for two univariate polynomials.
///
/// - Does: Mirrors SymPy `bezout(p, q, x, method)` for `method="bz"` and
///   `method="prs"`.
/// - Input: Two compatible univariate `Poly` values and a method string.
/// - Returns: A `DomainMatrix`.
/// - Limits: Supports exact `Poly` inputs already in the same domain and gens.
pub fn bezout(
  p : Poly,
  q : Poly,
  kind? : String = "bz",
) -> DomainMatrix raise PolyError {
  subres_ensure_matrix_pair(p, q)
  let m = degree(p)
  let n = degree(q)
  if (m == n && n < 0) ||
    (m == n && n == 0) ||
    (m == 0 && n < 0) ||
    (m < 0 && n == 0) {
    return subres_empty_matrix(p.domain)
  }
  if (m >= 1 && n < 0) || (m < 0 && n >= 1) {
    return subres_single_zero_matrix(p.domain)
  }
  let mx = if m > n { m } else { n }
  let coeffs = bezout_coeff_matrix(p, q, mx)
  let rows = subres_matrix_new(mx, mx, p.domain)
  for i in 0..<mx {
    for j in 0..<mx {
      if kind == "prs" {
        rows[mx - 1 - i].set(mx - 1 - j, coeffs[i][j])
      } else {
        rows[i].set(j, coeffs[i][j])
      }
    }
  }
  DomainMatrix::from_list(rows, p.domain)
}
