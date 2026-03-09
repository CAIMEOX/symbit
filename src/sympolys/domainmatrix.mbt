///|
pub(all) enum DomainMatrixRep {
  Dense(Array[Array[FieldElem]])
  Sparse(Map[Int, Map[Int, FieldElem]])
}

///|
/// Matrix over a polys domain, aligned with SymPy `DomainMatrix` core shape.
pub struct DomainMatrix {
  rep : DomainMatrixRep
  rows : Int
  cols : Int
  domain : Domain
}

///|
fn make_dense(
  rows : Int,
  cols : Int,
  init : FieldElem,
) -> Array[Array[FieldElem]] {
  let out : Array[Array[FieldElem]] = Array::new()
  for _ in 0..<rows {
    out.push(Array::make(cols, init))
  }
  out
}

fn clone_dense_rows(rows : Array[Array[FieldElem]]) -> Array[Array[FieldElem]] {
  let out : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    let cloned : Array[FieldElem] = Array::new()
    for v in row {
      cloned.push(v)
    }
    out.push(cloned)
  }
  out
}

fn convert_matrix_elem(v : FieldElem, domain : Domain) -> FieldElem raise PolyError {
  let q = fe_expect_rational(v)
  fe_from_rational(q, domain)
}

fn all_indices_except(size : Int, skip : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in 0..<size {
    if i != skip {
      out.push(i)
    }
  }
  out
}

///|
/// Build a dense domain matrix from explicit entries.
pub fn domain_matrix_from_dense(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let nrows = rows.length()
  let ncols = if nrows == 0 { 0 } else { rows[0].length() }
  for row in rows {
    if row.length() != ncols {
      raise PolyError::DomainMismatch
    }
  }
  DomainMatrix::{
    rep: DomainMatrixRep::Dense(rows),
    rows: nrows,
    cols: ncols,
    domain,
  }
}

///|
/// Build a dense domain matrix from integer literals.
pub fn domain_matrix_from_ints(
  rows : Array[Array[Int]],
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let lifted : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    let out : Array[FieldElem] = Array::new()
    for v in row {
      out.push(fe_from_int(v, domain))
    }
    lifted.push(out)
  }
  domain_matrix_from_dense(lifted, domain)
}

///|
/// Build a sparse domain matrix from non-zero entries only.
pub fn domain_matrix_from_sparse(
  rows : Int,
  cols : Int,
  entries : Array[(Int, Int, FieldElem)],
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let sparse : Map[Int, Map[Int, FieldElem]] = Map::new()
  for entry in entries {
    let (r, c, v) = entry
    if r < 0 || r >= rows || c < 0 || c >= cols {
      raise PolyError::DomainMismatch
    }
    if fe_is_zero(v) {
      continue
    }
    match sparse.get(r) {
      Some(row_map) => row_map[c] = v
      None => {
        let row_map : Map[Int, FieldElem] = Map::new()
        row_map[c] = v
        sparse[r] = row_map
      }
    }
  }
  DomainMatrix::{ rep: DomainMatrixRep::Sparse(sparse), rows, cols, domain }
}

///|
/// Convert any representation to dense row-major storage.
pub fn DomainMatrix::to_dense(
  self : DomainMatrix,
) -> Array[Array[FieldElem]] raise PolyError {
  match self.rep {
    DomainMatrixRep::Dense(rows) => rows
    DomainMatrixRep::Sparse(entries) => {
      let zero = fe_from_int(0, self.domain)
      let rows : Array[Array[FieldElem]] = make_dense(
        self.rows,
        self.cols,
        zero,
      )
      for r, row_map in entries {
        for c, v in row_map {
          rows[r].set(c, v)
        }
      }
      rows
    }
  }
}

///|
/// Convert to sparse representation by dropping explicit zeros.
pub fn DomainMatrix::to_sparse(
  self : DomainMatrix,
) -> DomainMatrix raise PolyError {
  let dense = self.to_dense()
  let entries : Array[(Int, Int, FieldElem)] = Array::new()
  for i in 0..<self.rows {
    for j in 0..<self.cols {
      let v = dense[i][j]
      if !fe_is_zero(v) {
        entries.push((i, j, v))
      }
    }
  }
  domain_matrix_from_sparse(self.rows, self.cols, entries, self.domain)
}

///|
pub fn DomainMatrix::shape(self : DomainMatrix) -> (Int, Int) {
  (self.rows, self.cols)
}

///|
pub fn DomainMatrix::copy(self : DomainMatrix) -> DomainMatrix raise PolyError {
  domain_matrix_from_dense(clone_dense_rows(self.to_dense()), self.domain)
}

///|
pub fn domain_matrix_zeros(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let zero = fe_from_int(0, domain)
  let data : Array[Array[FieldElem]] = make_dense(rows, cols, zero)
  domain_matrix_from_dense(data, domain)
}

///|
pub fn domain_matrix_eye(
  n : Int,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let dense = domain_matrix_zeros(n, n, domain).to_dense()
  for i in 0..<n {
    dense[i].set(i, fe_from_int(1, domain))
  }
  domain_matrix_from_dense(dense, domain)
}

///|
pub fn domain_matrix_ones(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let one = fe_from_int(1, domain)
  let data : Array[Array[FieldElem]] = make_dense(rows, cols, one)
  domain_matrix_from_dense(data, domain)
}

///|
pub fn DomainMatrix::convert_to(
  self : DomainMatrix,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  if self.domain == domain {
    return self.copy()
  }
  let dense = self.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for row in dense {
    let out_row : Array[FieldElem] = Array::new()
    for v in row {
      out_row.push(convert_matrix_elem(v, domain))
    }
    out.push(out_row)
  }
  domain_matrix_from_dense(out, domain)
}

///|
pub fn DomainMatrix::to_field(self : DomainMatrix) -> DomainMatrix raise PolyError {
  self.convert_to(domain_get_field(self.domain))
}

///|
pub fn DomainMatrix::unify(
  self : DomainMatrix,
  other : DomainMatrix,
) -> (DomainMatrix, DomainMatrix) raise PolyError {
  let domain = domain_unify_pair(self.domain, other.domain)
  (self.convert_to(domain), other.convert_to(domain))
}

///|
pub fn DomainMatrix::clear_denoms(
  self : DomainMatrix,
  convert? : Bool = false,
) -> (DomainScalar, DomainMatrix) raise PolyError {
  let base = self.domain
  let ring = if domain_has_assoc_ring_pred(base) {
    domain_get_ring(base)
  } else {
    base
  }
  let dense = self.to_dense()
  let mut lcm_den = BigInt::from_int(1)
  for row in dense {
    for value in row {
      let q = fe_expect_rational(value)
      let den = q.denominator()
      let g = @symnum.gcd_bigint(lcm_den, den)
      lcm_den = lcm_den.mul(den.div(g))
    }
  }
  let scale_rat = @symnum.BigRational::from_bigint(lcm_den)
  let scale = fe_from_rational(scale_rat, base)
  let out_domain = if convert { ring } else { base }
  let out : Array[Array[FieldElem]] = Array::new()
  for row in dense {
    let out_row : Array[FieldElem] = Array::new()
    for value in row {
      let scaled = fe_mul(value, scale)
      out_row.push(if convert { convert_matrix_elem(scaled, out_domain) } else { scaled })
    }
    out.push(out_row)
  }
  (
    domain_scalar_new(fe_from_rational(scale_rat, ring), ring),
    domain_matrix_from_dense(out, out_domain),
  )
}

///|
fn ensure_same_shape(
  a : DomainMatrix,
  b : DomainMatrix,
) -> Unit raise PolyError {
  if a.rows != b.rows || a.cols != b.cols || a.domain.not_equal(b.domain) {
    raise PolyError::DomainMismatch
  }
}

///|
fn ensure_mul_shape(a : DomainMatrix, b : DomainMatrix) -> Unit raise PolyError {
  if a.cols != b.rows || a.domain.not_equal(b.domain) {
    raise PolyError::DomainMismatch
  }
}

///|
pub fn DomainMatrix::add(
  self : DomainMatrix,
  other : DomainMatrix,
) -> DomainMatrix raise PolyError {
  ensure_same_shape(self, other)
  let a = self.to_dense()
  let b = other.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for i in 0..<self.rows {
    let row : Array[FieldElem] = Array::new()
    for j in 0..<self.cols {
      row.push(fe_add(a[i][j], b[i][j]))
    }
    out.push(row)
  }
  domain_matrix_from_dense(out, self.domain)
}

///|
pub fn DomainMatrix::sub(
  self : DomainMatrix,
  other : DomainMatrix,
) -> DomainMatrix raise PolyError {
  ensure_same_shape(self, other)
  let a = self.to_dense()
  let b = other.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for i in 0..<self.rows {
    let row : Array[FieldElem] = Array::new()
    for j in 0..<self.cols {
      row.push(fe_sub(a[i][j], b[i][j]))
    }
    out.push(row)
  }
  domain_matrix_from_dense(out, self.domain)
}

///|
pub fn DomainMatrix::mul(
  self : DomainMatrix,
  other : DomainMatrix,
) -> DomainMatrix raise PolyError {
  ensure_mul_shape(self, other)
  let a = self.to_dense()
  let b = other.to_dense()
  let zero = fe_from_int(0, self.domain)
  let out : Array[Array[FieldElem]] = make_dense(self.rows, other.cols, zero)
  for i in 0..<self.rows {
    for j in 0..<other.cols {
      let mut acc = fe_from_int(0, self.domain)
      for k in 0..<self.cols {
        acc = fe_add(acc, fe_mul(a[i][k], b[k][j]))
      }
      out[i].set(j, acc)
    }
  }
  domain_matrix_from_dense(out, self.domain)
}

///|
pub fn DomainMatrix::transpose(
  self : DomainMatrix,
) -> DomainMatrix raise PolyError {
  let a = self.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for j in 0..<self.cols {
    let row : Array[FieldElem] = Array::new()
    for i in 0..<self.rows {
      row.push(a[i][j])
    }
    out.push(row)
  }
  domain_matrix_from_dense(out, self.domain)
}

///|
pub fn DomainMatrix::extract(
  self : DomainMatrix,
  row_ids : Array[Int],
  col_ids : Array[Int],
) -> DomainMatrix raise PolyError {
  let dense = self.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for r in row_ids {
    if r < 0 || r >= self.rows {
      raise PolyError::DomainMismatch
    }
    let row : Array[FieldElem] = Array::new()
    for c in col_ids {
      if c < 0 || c >= self.cols {
        raise PolyError::DomainMismatch
      }
      row.push(dense[r][c])
    }
    out.push(row)
  }
  domain_matrix_from_dense(out, self.domain)
}

fn domain_matrix_minor(
  matrix : DomainMatrix,
  skip_row : Int,
  skip_col : Int,
) -> DomainMatrix raise PolyError {
  matrix.extract(
    all_indices_except(matrix.rows, skip_row),
    all_indices_except(matrix.cols, skip_col),
  )
}

///|
fn swap_rows_in_place(data : Array[Array[FieldElem]], i : Int, j : Int) -> Unit {
  let tmp = data[i]
  data.set(i, data[j])
  data.set(j, tmp)
}

///|
fn fe_exact_div_in_domain(
  a : FieldElem,
  b : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_zero(b) {
    raise PolyError::DivisionByZero
  }
  match domain {
    Domain::ZZ => {
      let ar = fe_expect_rational(a)
      let br = fe_expect_rational(b)
      let num = ar.numerator()
      let den = br.numerator()
      if den.is_zero() || !num.mod(den).is_zero() {
        raise PolyError::ExactQuotientFailed
      }
      fe_from_int(num.div(den).to_int(), Domain::ZZ)
    }
    _ => fe_mul(a, fe_inv(b))
  }
}

///|
/// Determinant with Bareiss elimination for exact rings/fields.
pub fn DomainMatrix::det(self : DomainMatrix) -> FieldElem raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  if self.rows == 0 {
    return fe_from_int(1, self.domain)
  }
  let n = self.rows
  let a = clone_dense_rows(self.to_dense())
  let mut sign = 1
  let mut denom = fe_from_int(1, self.domain)
  for k in 0..<(n - 1) {
    let mut pivot = k
    while pivot < n && fe_is_zero(a[pivot][k]) {
      pivot = pivot + 1
    }
    if pivot == n {
      return fe_from_int(0, self.domain)
    }
    if pivot != k {
      swap_rows_in_place(a, pivot, k)
      sign = -sign
    }
    let akk = a[k][k]
    for i in (k + 1)..<n {
      for j in (k + 1)..<n {
        let num = fe_sub(fe_mul(a[i][j], akk), fe_mul(a[i][k], a[k][j]))
        let value = if k == 0 {
          num
        } else {
          fe_exact_div_in_domain(num, denom, self.domain)
        }
        a[i].set(j, value)
      }
      a[i].set(k, fe_from_int(0, self.domain))
    }
    denom = akk
  }
  let det = a[n - 1][n - 1]
  if sign < 0 {
    fe_neg(det)
  } else {
    det
  }
}

///|
/// Reduced row-echelon form over fields.
pub fn DomainMatrix::rref(
  self : DomainMatrix,
) -> (DomainMatrix, Array[Int]) raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let data = clone_dense_rows(self.to_dense())
  let mut lead = 0
  let pivots : Array[Int] = Array::new()
  for r in 0..<self.rows {
    if lead >= self.cols {
      break
    }
    let mut i = r
    while i < self.rows && fe_is_zero(data[i][lead]) {
      i = i + 1
    }
    while i == self.rows {
      lead = lead + 1
      if lead >= self.cols {
        return (domain_matrix_from_dense(data, self.domain), pivots)
      }
      i = r
      while i < self.rows && fe_is_zero(data[i][lead]) {
        i = i + 1
      }
    }
    if i != r {
      swap_rows_in_place(data, i, r)
    }
    let pivot = data[r][lead]
    let inv = fe_inv(pivot)
    for j in 0..<self.cols {
      data[r].set(j, fe_mul(data[r][j], inv))
    }
    for i2 in 0..<self.rows {
      if i2 == r {
        continue
      }
      let factor = data[i2][lead]
      if fe_is_zero(factor) {
        continue
      }
      for j in 0..<self.cols {
        data[i2].set(j, fe_sub(data[i2][j], fe_mul(factor, data[r][j])))
      }
    }
    pivots.push(lead)
    lead = lead + 1
  }
  (domain_matrix_from_dense(data, self.domain), pivots)
}

///|
pub fn DomainMatrix::rank(self : DomainMatrix) -> Int raise PolyError {
  self.rref().1.length()
}

///|
pub fn DomainMatrix::columnspace(self : DomainMatrix) -> DomainMatrix raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let pivots = self.rref().1
  let rows : Array[Int] = Array::new()
  for i in 0..<self.rows {
    rows.push(i)
  }
  self.extract(rows, pivots)
}

///|
pub fn DomainMatrix::rowspace(self : DomainMatrix) -> DomainMatrix raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let pivots = self.rref().1
  let rows : Array[Int] = Array::new()
  for i in 0..<pivots.length() {
    rows.push(i)
  }
  let cols : Array[Int] = Array::new()
  for j in 0..<self.cols {
    cols.push(j)
  }
  self.extract(rows, cols)
}

///|
pub fn DomainMatrix::nullspace(self : DomainMatrix) -> DomainMatrix raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let (rref, pivots) = self.rref()
  let rows = rref.to_dense()
  let pivot_set : Map[Int, Bool] = {}
  for p in pivots {
    pivot_set[p] = true
  }
  let free_cols : Array[Int] = Array::new()
  for j in 0..<self.cols {
    if pivot_set.get(j) is None {
      free_cols.push(j)
    }
  }
  if free_cols.is_empty() {
    return domain_matrix_zeros(0, self.cols, self.domain)
  }
  let one = fe_from_int(1, self.domain)
  let zero = fe_from_int(0, self.domain)
  let basis : Array[Array[FieldElem]] = Array::new()
  for free in free_cols {
    let vec : Array[FieldElem] = Array::make(self.cols, zero)
    vec.set(free, one)
    for i in 0..<pivots.length() {
      let p = pivots[i]
      vec.set(p, fe_neg(rows[i][free]))
    }
    basis.push(vec)
  }
  domain_matrix_from_dense(basis, self.domain)
}

///|
pub fn DomainMatrix::inv(self : DomainMatrix) -> DomainMatrix raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  let n = self.rows
  let one = fe_from_int(1, self.domain)
  let zero = fe_from_int(0, self.domain)
  let left = clone_dense_rows(self.to_dense())
  let aug_rows : Array[Array[FieldElem]] = Array::new()
  for i in 0..<n {
    let row = left[i].copy()
    for j in 0..<n {
      row.push(if i == j { one } else { zero })
    }
    aug_rows.push(row)
  }
  let aug = domain_matrix_from_dense(aug_rows, self.domain)
  let (rref_aug, pivots) = aug.rref()
  if pivots.length() < n {
    raise PolyError::ExactQuotientFailed
  }
  for i in 0..<n {
    if pivots[i] != i {
      raise PolyError::ExactQuotientFailed
    }
  }
  let rows = rref_aug.to_dense()
  let inv_rows : Array[Array[FieldElem]] = Array::new()
  for i in 0..<n {
    let row : Array[FieldElem] = Array::new()
    for j in 0..<n {
      let expected = if i == j { one } else { zero }
      if !fe_is_zero(fe_sub(rows[i][j], expected)) {
        raise PolyError::ExactQuotientFailed
      }
      row.push(rows[i][n + j])
    }
    inv_rows.push(row)
  }
  domain_matrix_from_dense(inv_rows, self.domain)
}

///|
pub fn DomainMatrix::adj_det(
  self : DomainMatrix,
) -> (DomainMatrix, FieldElem) raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  let det = self.det()
  if self.rows == 0 {
    return (domain_matrix_zeros(0, 0, self.domain), det)
  }
  if self.rows == 1 {
    return (domain_matrix_eye(1, self.domain), det)
  }
  let n = self.rows
  let out : Array[Array[FieldElem]] = Array::new()
  for i in 0..<n {
    let row : Array[FieldElem] = Array::new()
    for j in 0..<n {
      let minor = domain_matrix_minor(self, j, i)
      let mut cofactor = minor.det()
      if (i + j) % 2 == 1 {
        cofactor = fe_neg(cofactor)
      }
      row.push(cofactor)
    }
    out.push(row)
  }
  (domain_matrix_from_dense(out, self.domain), det)
}

///|
pub fn DomainMatrix::adjugate(self : DomainMatrix) -> DomainMatrix raise PolyError {
  self.adj_det().0
}

///|
pub fn DomainMatrix::inv_den(
  self : DomainMatrix,
  solve_method? : String = "",
) -> (DomainMatrix, FieldElem) raise PolyError {
  if solve_method != "" && solve_method != "rref" && solve_method != "charpoly" {
    raise PolyError::DomainMismatch
  }
  let (adj, det) = self.adj_det()
  if fe_is_zero(det) {
    raise PolyError::ExactQuotientFailed
  }
  (adj, det)
}

///|
pub fn DomainMatrix::solve_den(
  self : DomainMatrix,
  rhs : DomainMatrix,
  solve_method? : String = "",
) -> (DomainMatrix, FieldElem) raise PolyError {
  let (a, b) = self.unify(rhs)
  if a.rows != b.rows || a.rows != a.cols {
    raise PolyError::DomainMismatch
  }
  let (num_inv, den) = a.inv_den(solve_method=solve_method)
  (num_inv.mul(b), den)
}

///|
/// SymPy-like `Matrix([[...], ...])` textual form.
pub fn DomainMatrix::to_matrix_string(
  self : DomainMatrix,
) -> String raise PolyError {
  let rows = self.to_dense()
  let row_parts : Array[String] = Array::new()
  for row in rows {
    let values = row.map(v => fe_to_string(v)).join(", ")
    row_parts.push("[\{values}]")
  }
  let joined_rows = row_parts.join(", ")
  "Matrix([\{joined_rows}])"
}
