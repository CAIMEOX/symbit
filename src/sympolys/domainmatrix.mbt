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

fn all_indices(start : Int, stop : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in start..<stop {
    out.push(i)
  }
  out
}

fn restore_rep_like(
  dm : DomainMatrix,
  like : DomainMatrix,
) -> DomainMatrix raise PolyError {
  match like.rep {
    DomainMatrixRep::Dense(_) => dm
    DomainMatrixRep::Sparse(_) => dm.to_sparse()
  }
}

fn domain_matrix_scale(
  dm : DomainMatrix,
  scalar : FieldElem,
) -> DomainMatrix raise PolyError {
  let dense = dm.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for row in dense {
    let out_row : Array[FieldElem] = Array::new()
    for value in row {
      out_row.push(fe_mul(value, scalar))
    }
    out.push(out_row)
  }
  domain_matrix_from_dense(out, dm.domain)
}

fn domain_matrix_div_scalar(
  dm : DomainMatrix,
  scalar : FieldElem,
) -> DomainMatrix raise PolyError {
  domain_matrix_scale(dm, fe_inv(scalar))
}

fn canonical_unit_in_domain(
  value : FieldElem,
  domain : Domain,
) -> FieldElem raise PolyError {
  if fe_is_negative(value) {
    fe_from_int(-1, domain)
  } else {
    fe_from_int(1, domain)
  }
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
pub fn DomainMatrix::clear_denoms_rowwise(
  self : DomainMatrix,
  convert? : Bool = false,
) -> (DomainMatrix, DomainMatrix) raise PolyError {
  let base = self.domain
  let ring = if domain_has_assoc_ring_pred(base) {
    domain_get_ring(base)
  } else {
    base
  }
  let dense = self.to_dense()
  let diagonal : Array[FieldElem] = Array::new()
  let out_rows : Array[Array[FieldElem]] = Array::new()
  let out_domain = if convert { ring } else { base }
  for row in dense {
    let mut lcm_den = BigInt::from_int(1)
    for value in row {
      let q = fe_expect_rational(value)
      let den = q.denominator()
      let g = @symnum.gcd_bigint(lcm_den, den)
      lcm_den = lcm_den.mul(den.div(g))
    }
    let scale_rat = @symnum.BigRational::from_bigint(lcm_den)
    let scale = fe_from_rational(scale_rat, base)
    diagonal.push(fe_from_rational(scale_rat, ring))
    let out_row : Array[FieldElem] = Array::new()
    for value in row {
      let scaled = fe_mul(value, scale)
      out_row.push(if convert { convert_matrix_elem(scaled, out_domain) } else { scaled })
    }
    out_rows.push(out_row)
  }
  let zero = fe_from_int(0, ring)
  let den_rows = make_dense(self.rows, self.rows, zero)
  for i in 0..<diagonal.length() {
    den_rows[i].set(i, diagonal[i])
  }
  (
    domain_matrix_from_dense(den_rows, ring),
    domain_matrix_from_dense(out_rows, out_domain),
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

///|
pub fn DomainMatrix::hstack(
  self : DomainMatrix,
  other : DomainMatrix,
) -> DomainMatrix raise PolyError {
  if self.rows != other.rows || self.domain.not_equal(other.domain) {
    raise PolyError::DomainMismatch
  }
  let left = self.to_dense()
  let right = other.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for i in 0..<self.rows {
    let row : Array[FieldElem] = Array::new()
    for value in left[i] {
      row.push(value)
    }
    for value in right[i] {
      row.push(value)
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

fn dense_lu_in_place(
  rows : Array[Array[FieldElem]],
  _domain : Domain,
) -> Array[(Int, Int)] raise PolyError {
  let m = rows.length()
  if m == 0 {
    return []
  }
  let n = rows[0].length()
  let swaps : Array[(Int, Int)] = Array::new()
  let limit = if m < n { m } else { n }
  for i in 0..<limit {
    if fe_is_zero(rows[i][i]) {
      let mut ip = i + 1
      while ip < m && fe_is_zero(rows[ip][i]) {
        ip += 1
      }
      if ip == m {
        continue
      }
      swaps.push((i, ip))
      swap_rows_in_place(rows, i, ip)
    }
    for j in (i + 1)..<m {
      let lji = fe_mul(rows[j][i], fe_inv(rows[i][i]))
      rows[j].set(i, lji)
      for k in (i + 1)..<n {
        rows[j].set(k, fe_sub(rows[j][k], fe_mul(lji, rows[i][k])))
      }
    }
  }
  swaps
}

fn dense_lu_split(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> (Array[Array[FieldElem]], Array[Array[FieldElem]], Array[(Int, Int)]) raise PolyError {
  let m = rows.length()
  if m == 0 {
    return ([], [], [])
  }
  let n = rows[0].length()
  let lu = clone_dense_rows(rows)
  let swaps = dense_lu_in_place(lu, domain)
  let zero = fe_from_int(0, domain)
  let one = fe_from_int(1, domain)
  let l = make_dense(m, m, zero)
  let u = clone_dense_rows(lu)
  let minmn = if m < n { m } else { n }
  for i in 0..<m {
    l[i].set(i, one)
    let upto = if i < minmn { i } else { minmn }
    for j in 0..<upto {
      l[i].set(j, lu[i][j])
      u[i].set(j, zero)
    }
  }
  (l, u, swaps)
}

fn dense_lu_solve(
  l : Array[Array[FieldElem]],
  u : Array[Array[FieldElem]],
  swaps : Array[(Int, Int)],
  rhs : Array[Array[FieldElem]],
  domain : Domain,
) -> Array[Array[FieldElem]] raise PolyError {
  let m = u.length()
  if m == 0 {
    return []
  }
  let n = u[0].length()
  let m2 = rhs.length()
  if m != m2 || rhs.is_empty() {
    raise PolyError::DomainMismatch
  }
  if m < n {
    raise PolyError::DomainMismatch
  }
  let o = rhs[0].length()
  let b = clone_dense_rows(rhs)
  for swap in swaps {
    let (i1, i2) = swap
    swap_rows_in_place(b, i1, i2)
  }
  let zero = fe_from_int(0, domain)
  let y = make_dense(m, o, zero)
  for k in 0..<o {
    for i in 0..<m {
      let mut rhsik = b[i][k]
      for j in 0..<i {
        rhsik = fe_sub(rhsik, fe_mul(l[i][j], y[j][k]))
      }
      y[i].set(k, rhsik)
    }
  }
  for i in n..<m {
    for j in 0..<o {
      if !fe_is_zero(y[i][j]) {
        raise PolyError::ExactQuotientFailed
      }
    }
  }
  let x = make_dense(n, o, zero)
  for k in 0..<o {
    for ii in 0..<n {
      let i = n - 1 - ii
      if fe_is_zero(u[i][i]) {
        raise PolyError::ExactQuotientFailed
      }
      let mut rhsik = y[i][k]
      for j in (i + 1)..<n {
        rhsik = fe_sub(rhsik, fe_mul(u[i][j], x[j][k]))
      }
      x[i].set(k, fe_mul(rhsik, fe_inv(u[i][i])))
    }
  }
  x
}

fn dense_fflu_phase1(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> (Array[Array[FieldElem]], Array[Int]) raise PolyError {
  let lu = clone_dense_rows(rows)
  let row_count = lu.length()
  if row_count == 0 {
    return (lu, [])
  }
  let col_count = lu[0].length()
  let perm : Array[Int] = Array::new()
  for i in 0..<row_count {
    perm.push(i)
  }
  let mut rank = 0
  let limit = if row_count < col_count { row_count } else { col_count }
  for j in 0..<limit {
    let mut all_zero = true
    for i in 0..<row_count {
      if !fe_is_zero(lu[i][j]) {
        all_zero = false
        break
      }
    }
    if all_zero {
      continue
    }
    let mut pivot_row = -1
    for i in rank..<row_count {
      if !fe_is_zero(lu[i][j]) {
        pivot_row = i
        break
      }
    }
    if pivot_row == -1 {
      continue
    }
    if pivot_row != rank {
      swap_rows_in_place(lu, rank, pivot_row)
      let tmp = perm[rank]
      perm.set(rank, perm[pivot_row])
      perm.set(pivot_row, tmp)
    }
    let pivot = lu[rank][j]
    for i in (rank + 1)..<row_count {
      let multiplier = lu[i][j]
      let denominator = if rank > 0 { lu[rank - 1][rank - 1] } else { fe_from_int(1, domain) }
      for k in (j + 1)..<col_count {
        let num = fe_sub(fe_mul(pivot, lu[i][k]), fe_mul(lu[rank][k], multiplier))
        lu[i].set(k, fe_exact_div_in_domain(num, denominator, domain))
      }
      lu[i].set(j, multiplier)
    }
    rank += 1
  }
  (lu, perm)
}

fn dense_dot_cols(
  rows : Array[Array[FieldElem]],
  left : Int,
  right : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  let mut total = fe_from_int(0, domain)
  for row in rows {
    total = fe_add(total, fe_mul(row[left], row[right]))
  }
  total
}

fn tail_slice(row : Array[FieldElem], start : Int) -> Array[FieldElem] {
  let out : Array[FieldElem] = Array::new()
  for i in start..<row.length() {
    out.push(row[i])
  }
  out
}

fn dense_berk(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let m = rows.length()
  if m == 0 {
    return [fe_from_int(1, domain)]
  }
  let n = rows[0].length()
  if m != n {
    raise PolyError::DomainMismatch
  }
  if n == 1 {
    return [fe_from_int(1, domain), fe_neg(rows[0][0])]
  }

  let a = rows[0][0]
  let r : Array[Array[FieldElem]] = [tail_slice(rows[0], 1)]
  let c : Array[Array[FieldElem]] = Array::new()
  let a_minor : Array[Array[FieldElem]] = Array::new()
  for i in 1..<n {
    c.push([rows[i][0]])
    a_minor.push(tail_slice(rows[i], 1))
  }

  let q = dense_berk(a_minor, domain)
  let zero = fe_from_int(0, domain)
  let t = make_dense(n + 1, n, zero)
  for i in 0..<n {
    t[i].set(i, fe_from_int(1, domain))
    t[i + 1].set(i, fe_neg(a))
  }

  let mut cur_c = c
  for i in 2..=n {
    let an_c = if i == 2 {
      cur_c
    } else {
      domain_matrix_from_dense(a_minor, domain).mul(domain_matrix_from_dense(cur_c, domain)).to_dense()
    }
    let ran_c = domain_matrix_from_dense(r, domain).mul(domain_matrix_from_dense(an_c, domain)).to_dense()
    for j in 0..<(n + 1 - i) {
      t[i + j].set(j, fe_neg(ran_c[0][0]))
    }
    cur_c = an_c
  }

  let q_col : Array[Array[FieldElem]] = Array::new()
  for coeff in q {
    q_col.push([coeff])
  }
  let out = domain_matrix_from_dense(t, domain).mul(domain_matrix_from_dense(q_col, domain)).to_dense()
  let coeffs : Array[FieldElem] = Array::new()
  for row in out {
    coeffs.push(row[0])
  }
  coeffs
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

fn dense_rref_den(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> (Array[Array[FieldElem]], FieldElem, Array[Int]) raise PolyError {
  let data = clone_dense_rows(rows)
  let m = data.length()
  if m == 0 {
    return (data, fe_from_int(1, domain), [])
  }
  let n = data[0].length()
  let mut d : Option[FieldElem] = None
  let pivots : Array[Int] = Array::new()
  let no_pivots : Array[Int] = Array::new()
  let zero = fe_from_int(0, domain)
  let mut i = 0
  for j in 0..<n {
    if i >= m {
      break
    }
    let mut aij = data[i][j]
    if fe_is_zero(aij) {
      let mut ip = i + 1
      while ip < m && fe_is_zero(data[ip][j]) {
        ip += 1
      }
      if ip == m {
        no_pivots.push(j)
        continue
      }
      swap_rows_in_place(data, i, ip)
      aij = data[i][j]
    }

    if !pivots.is_empty() {
      let mut pivot_val = fe_mul(aij, data[0][pivots[0]])
      match d {
        Some(prev) => pivot_val = fe_exact_div_in_domain(pivot_val, prev, domain)
        None => ()
      }
      for ip in 0..<pivots.length() {
        data[ip].set(pivots[ip], pivot_val)
      }
    }

    for jnp in no_pivots {
      for ip in 0..<i {
        let mut value = data[ip][jnp]
        if fe_is_zero(value) {
          continue
        }
        value = fe_mul(value, aij)
        match d {
          Some(prev) => value = fe_exact_div_in_domain(value, prev, domain)
          None => ()
        }
        data[ip].set(jnp, value)
      }
    }

    for jp in 0..<m {
      if jp == i {
        continue
      }
      for kp in (j + 1)..<n {
        let mut value = fe_sub(fe_mul(aij, data[jp][kp]), fe_mul(data[jp][j], data[i][kp]))
        match d {
          Some(prev) => value = fe_exact_div_in_domain(value, prev, domain)
          None => ()
        }
        data[jp].set(kp, value)
      }
      data[jp].set(j, zero)
    }

    pivots.push(j)
    i += 1
    if i >= m {
      break
    }
    d = if fe_is_one(aij) { None } else { Some(aij) }
  }

  let denom = if pivots.is_empty() {
    fe_from_int(1, domain)
  } else {
    data[0][pivots[0]]
  }
  (data, denom, pivots)
}

fn normalize_rref_method(rref_method : String) -> String raise PolyError {
  match rref_method {
    "" | "auto" => "auto"
    "FF" | "GJ" | "CD" => rref_method
    "FF_dense" => "FF"
    "GJ_dense" => "GJ"
    "CD_dense" => "CD"
    _ => raise PolyError::DomainMismatch
  }
}

fn choose_rref_method(
  dm : DomainMatrix,
  rref_method : String,
) -> String raise PolyError {
  let normalized = normalize_rref_method(rref_method)
  if normalized != "auto" {
    return normalized
  }
  if !domain_is_exact_pred(dm.domain) {
    return "GJ"
  }
  if domain_is_field_pred(dm.domain) {
    return "GJ"
  }
  "FF"
}

fn infer_rref_pivots(
  rows : Array[Array[FieldElem]],
  cols : Int,
) -> Array[Int] {
  let pivots : Array[Int] = Array::new()
  let mut last_pivot = -1
  for row in rows {
    for j in (last_pivot + 1)..<cols {
      if !fe_is_zero(row[j]) {
        last_pivot = j
        pivots.push(j)
        break
      }
    }
  }
  pivots
}

fn nullspace_from_rref_with_nonpivots(
  dm : DomainMatrix,
  pivots? : Array[Int] = [],
) -> (DomainMatrix, Array[Int]) raise PolyError {
  let actual_pivots = if pivots.is_empty() {
    infer_rref_pivots(dm.to_dense(), dm.cols)
  } else {
    pivots
  }
  if actual_pivots.is_empty() {
    return (domain_matrix_eye(dm.cols, dm.domain), all_indices(0, dm.cols))
  }
  if actual_pivots.length() == dm.cols {
    return (domain_matrix_zeros(0, dm.cols, dm.domain), [])
  }
  let rows = dm.to_dense()
  let pivot_set : Map[Int, Bool] = {}
  for p in actual_pivots {
    pivot_set[p] = true
  }
  let nonpivots : Array[Int] = Array::new()
  for j in 0..<dm.cols {
    if pivot_set.get(j) is None {
      nonpivots.push(j)
    }
  }
  let pivot_val = rows[0][actual_pivots[0]]
  let zero = fe_from_int(0, dm.domain)
  let basis : Array[Array[FieldElem]] = Array::new()
  for free_col in nonpivots {
    let vec : Array[FieldElem] = Array::make(dm.cols, zero)
    vec.set(free_col, pivot_val)
    for i in 0..<actual_pivots.length() {
      vec.set(actual_pivots[i], fe_neg(rows[i][free_col]))
    }
    basis.push(vec)
  }
  (domain_matrix_from_dense(basis, dm.domain), nonpivots)
}

fn particular_from_rref(
  dm : DomainMatrix,
  pivots? : Array[Int] = [],
) -> DomainMatrix raise PolyError {
  if dm.cols == 0 {
    return domain_matrix_zeros(1, 0, dm.domain)
  }
  let actual_pivots = if pivots.is_empty() {
    infer_rref_pivots(dm.to_dense(), dm.cols)
  } else {
    pivots
  }
  let rows = dm.to_dense()
  let sol : Array[FieldElem] = Array::make(dm.cols - 1, fe_from_int(0, dm.domain))
  let rhs_col = dm.cols - 1
  for i in 0..<actual_pivots.length() {
    let pivot_col = actual_pivots[i]
    if pivot_col >= rhs_col {
      continue
    }
    let rhs = rows[i][rhs_col]
    if fe_is_zero(rhs) {
      continue
    }
    sol.set(pivot_col, fe_exact_div_in_domain(rhs, rows[i][pivot_col], dm.domain))
  }
  domain_matrix_from_dense([sol], dm.domain)
}

///|
pub fn DomainMatrix::rref_den(
  self : DomainMatrix,
  rref_method? : String = "auto",
  keep_domain? : Bool = true,
) -> (DomainMatrix, FieldElem, Array[Int]) raise PolyError {
  let chosen = choose_rref_method(self, rref_method)
  match chosen {
    "FF" => {
      let (rows, den, pivots) = dense_rref_den(self.to_dense(), self.domain)
      let dm = domain_matrix_from_dense(rows, self.domain)
      (restore_rep_like(dm, self), den, pivots)
    }
    "GJ" => {
      let field_dm = if domain_is_field_pred(self.domain) {
        self.copy()
      } else {
        self.to_field()
      }
      let (rref_f, pivots) = field_dm.rref()
      if keep_domain && field_dm.domain != self.domain {
        let (_, cleared) = rref_f.clear_denoms(convert=true)
        let den = if pivots.is_empty() {
          fe_from_int(1, cleared.domain)
        } else {
          cleared.to_dense()[0][pivots[0]]
        }
        (restore_rep_like(cleared, self), den, pivots)
      } else {
        let out = restore_rep_like(rref_f, self)
        (out, fe_from_int(1, out.domain), pivots)
      }
    }
    "CD" => {
      let (_, cleared) = self.clear_denoms_rowwise(convert=true)
      let (rref_r, den, pivots) = cleared.rref_den(rref_method="FF", keep_domain=false)
      if keep_domain && rref_r.domain != self.domain {
        let converted = rref_r.convert_to(self.domain)
        let den_in_self = convert_matrix_elem(den, self.domain)
        let normalized = domain_matrix_div_scalar(converted, den_in_self)
        let out = restore_rep_like(normalized, self)
        (out, fe_from_int(1, self.domain), pivots)
      } else {
        (restore_rep_like(rref_r, self), den, pivots)
      }
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn DomainMatrix::rank(self : DomainMatrix) -> Int raise PolyError {
  if domain_is_field_pred(self.domain) {
    self.rref().1.length()
  } else {
    self.rref_den().2.length()
  }
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
pub fn DomainMatrix::nullspace(
  self : DomainMatrix,
  divide_last? : Bool = false,
) -> DomainMatrix raise PolyError {
  if divide_last && !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  if divide_last {
    let (rref, pivots) = self.rref()
    return rref.nullspace_from_rref(pivots=pivots)
  }
  let (rref_den, den, pivots) = self.rref_den()
  let unit = canonical_unit_in_domain(den, rref_den.domain)
  let canonical = if fe_is_one(unit) {
    rref_den
  } else {
    domain_matrix_scale(rref_den, unit)
  }
  canonical.nullspace_from_rref(pivots=pivots)
}

///|
pub fn DomainMatrix::nullspace_from_rref(
  self : DomainMatrix,
  pivots? : Array[Int] = [],
) -> DomainMatrix raise PolyError {
  nullspace_from_rref_with_nonpivots(self, pivots~).0
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
pub fn DomainMatrix::solve_den_rref(
  self : DomainMatrix,
  rhs : DomainMatrix,
) -> (DomainMatrix, FieldElem) raise PolyError {
  let (a, b) = self.unify(rhs)
  if a.rows != b.rows {
    raise PolyError::DomainMismatch
  }
  if a.rows < a.cols {
    raise PolyError::DomainMismatch
  }
  let aug = a.hstack(b)
  let (aug_rref, den, pivots) = aug.rref_den()
  if pivots.length() != a.cols {
    raise PolyError::ExactQuotientFailed
  }
  if !pivots.is_empty() && pivots[pivots.length() - 1] >= a.cols {
    raise PolyError::ExactQuotientFailed
  }
  let num = aug_rref.extract(all_indices(0, a.cols), all_indices(a.cols, aug.cols))
  (num, den)
}

///|
pub fn DomainMatrix::inv_den(
  self : DomainMatrix,
  solve_method? : String = "",
) -> (DomainMatrix, FieldElem) raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  let identity = domain_matrix_eye(self.rows, self.domain)
  self.solve_den(identity, solve_method=solve_method)
}

///|
pub fn DomainMatrix::solve_den(
  self : DomainMatrix,
  rhs : DomainMatrix,
  solve_method? : String = "",
) -> (DomainMatrix, FieldElem) raise PolyError {
  let chosen_method = if solve_method == "" { "rref" } else { solve_method }
  match chosen_method {
    "rref" => self.solve_den_rref(rhs)
    "charpoly" => {
      let (a, b) = self.unify(rhs)
      if a.rows != b.rows || a.rows != a.cols {
        raise PolyError::DomainMismatch
      }
      let (num_inv, den) = a.adj_det()
      if fe_is_zero(den) {
        raise PolyError::ExactQuotientFailed
      }
      (num_inv.mul(b), den)
    }
    _ => raise PolyError::DomainMismatch
  }
}

///|
pub fn DomainMatrix::lu(
  self : DomainMatrix,
) -> (DomainMatrix, DomainMatrix, Array[(Int, Int)]) raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let (l_rows, u_rows, swaps) = dense_lu_split(self.to_dense(), self.domain)
  let l = restore_rep_like(domain_matrix_from_dense(l_rows, self.domain), self)
  let u = restore_rep_like(domain_matrix_from_dense(u_rows, self.domain), self)
  (l, u, swaps)
}

///|
pub fn DomainMatrix::qr(
  self : DomainMatrix,
) -> (DomainMatrix, DomainMatrix) raise PolyError {
  if !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let row_count = self.rows
  let col_count = self.cols
  let q_rows = clone_dense_rows(self.to_dense())
  let zero = fe_from_int(0, self.domain)
  let rank_bound = if row_count < col_count { row_count } else { col_count }
  let r_rows = make_dense(rank_bound, col_count, zero)
  for j in 0..<col_count {
    let bound = if j < row_count { j } else { row_count }
    for i in 0..<bound {
      let dot_ii = dense_dot_cols(q_rows, i, i, self.domain)
      if !fe_is_zero(dot_ii) {
        let rij = fe_mul(dense_dot_cols(q_rows, i, j, self.domain), fe_inv(dot_ii))
        r_rows[i].set(j, rij)
        for k in 0..<row_count {
          q_rows[k].set(j, fe_sub(q_rows[k][j], fe_mul(rij, q_rows[k][i])))
        }
      }
    }
    if j < row_count {
      let dot_jj = dense_dot_cols(q_rows, j, j, self.domain)
      if !fe_is_zero(dot_jj) {
        r_rows[j].set(j, fe_from_int(1, self.domain))
      }
    }
  }
  let q = restore_rep_like(
    domain_matrix_from_dense(q_rows, self.domain).extract(
      all_indices(0, row_count),
      all_indices(0, rank_bound),
    ),
    self,
  )
  let r = restore_rep_like(domain_matrix_from_dense(r_rows, self.domain), self)
  (q, r)
}

///|
pub fn DomainMatrix::lu_solve(
  self : DomainMatrix,
  rhs : DomainMatrix,
) -> DomainMatrix raise PolyError {
  let (a, b) = self.unify(rhs)
  if a.rows != b.rows {
    raise PolyError::DomainMismatch
  }
  if !domain_is_field_pred(a.domain) {
    raise PolyError::DomainNotField
  }
  let (l, u, swaps) = a.lu()
  let sol_rows = dense_lu_solve(l.to_dense(), u.to_dense(), swaps, b.to_dense(), a.domain)
  restore_rep_like(domain_matrix_from_dense(sol_rows, a.domain), self)
}

///|
pub fn DomainMatrix::fflu(
  self : DomainMatrix,
) -> (DomainMatrix, DomainMatrix, DomainMatrix, DomainMatrix) raise PolyError {
  let row_count = self.rows
  let col_count = self.cols
  let (u_rows, perm) = dense_fflu_phase1(self.to_dense(), self.domain)
  let zero = fe_from_int(0, self.domain)
  let one = fe_from_int(1, self.domain)

  let p_rows = make_dense(row_count, row_count, zero)
  for i in 0..<perm.length() {
    p_rows[i].set(perm[i], one)
  }

  let l_rows = make_dense(row_count, row_count, zero)
  let u = clone_dense_rows(u_rows)
  let mut i = 0
  let mut j = 0
  while i < row_count && j < col_count {
    if !fe_is_zero(u[i][j]) {
      l_rows[i].set(i, u[i][j])
      for k in (i + 1)..<row_count {
        l_rows[k].set(i, u[k][j])
        u[k].set(j, zero)
      }
      i += 1
    }
    j += 1
  }
  for k in i..<row_count {
    l_rows[k].set(k, one)
  }

  let d_rows = make_dense(row_count, row_count, zero)
  if row_count >= 1 {
    d_rows[0].set(0, l_rows[0][0])
  }
  let mut di = one
  for idx in 1..<row_count {
    di = fe_mul(l_rows[idx - 1][idx - 1], l_rows[idx][idx])
    d_rows[idx].set(idx, di)
  }

  let p = restore_rep_like(domain_matrix_from_dense(p_rows, self.domain), self)
  let l = restore_rep_like(domain_matrix_from_dense(l_rows, self.domain), self)
  let d = restore_rep_like(domain_matrix_from_dense(d_rows, self.domain), self)
  let u_dm = restore_rep_like(domain_matrix_from_dense(u, self.domain), self)
  (p, l, d, u_dm)
}

///|
pub fn DomainMatrix::charpoly(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  dense_berk(self.to_dense(), self.domain)
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
