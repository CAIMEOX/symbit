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
  let a = self.to_dense()
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
  let data = self.to_dense()
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
