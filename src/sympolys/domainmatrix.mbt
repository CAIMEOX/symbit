///|
pub(all) enum DomainMatrixRep {
  Dense(Array[Array[FieldElem]])
  Sparse(Map[Int, Map[Int, FieldElem]])
}

///|
/// DOD/DOK helpers exposed by the matrix compatibility layer.
pub type DomainMatrixDOD = Map[Int, Map[Int, FieldElem]]

///|
pub type DomainMatrixDOK = Map[(Int, Int), FieldElem]

///|
/// Layout token used by `to_flat_nz`/`from_flat_nz`.
pub enum DomainMatrixFlatNZData {
  Dense(Int, Int)
  Sparse(Int, Int, Array[(Int, Int)])
}

///|
pub type FieldElemMapper = (FieldElem) -> FieldElem raise PolyError

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

fn clone_dod(dod : DomainMatrixDOD) -> DomainMatrixDOD {
  let out : DomainMatrixDOD = Map::new()
  for r, row in dod {
    let row_copy : Map[Int, FieldElem] = Map::new()
    for c, value in row {
      row_copy[c] = value
    }
    out[r] = row_copy
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

fn normalize_matrix_index(index : Int, size : Int) -> Int raise PolyError {
  let normalized = if index < 0 { size + index } else { index }
  if normalized < 0 || normalized >= size {
    raise PolyError::DomainMismatch
  }
  normalized
}

fn normalize_slice_bound_positive(bound : Int, size : Int) -> Int {
  let shifted = if bound < 0 { size + bound } else { bound }
  if shifted < 0 {
    return 0
  }
  if shifted > size {
    return size
  }
  shifted
}

fn normalize_slice_bound_negative(bound : Int, size : Int) -> Int {
  let shifted = if bound < 0 { size + bound } else { bound }
  if shifted < -1 {
    return -1
  }
  if shifted >= size {
    return size - 1
  }
  shifted
}

fn slice_index_range(
  size : Int,
  start? : Int? = None,
  stop? : Int? = None,
  step? : Int = 1,
) -> Array[Int] raise PolyError {
  if step == 0 {
    raise PolyError::DomainMismatch
  }
  let out : Array[Int] = Array::new()
  if step > 0 {
    let start_idx = match start {
      Some(v) => normalize_slice_bound_positive(v, size)
      None => 0
    }
    let stop_idx = match stop {
      Some(v) => normalize_slice_bound_positive(v, size)
      None => size
    }
    let mut i = start_idx
    while i < stop_idx {
      out.push(i)
      i += step
    }
  } else {
    let start_idx = match start {
      Some(v) => normalize_slice_bound_negative(v, size)
      None => size - 1
    }
    let stop_idx = match stop {
      Some(v) => normalize_slice_bound_negative(v, size)
      None => -1
    }
    let mut i = start_idx
    while i > stop_idx {
      out.push(i)
      i += step
    }
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

fn domain_matrix_matmul(
  left : DomainMatrix,
  right : DomainMatrix,
) -> DomainMatrix raise PolyError {
  ensure_mul_shape(left, right)
  let a = left.to_dense()
  let b = right.to_dense()
  let zero = fe_from_int(0, left.domain)
  let out : Array[Array[FieldElem]] = make_dense(left.rows, right.cols, zero)
  for i in 0..<left.rows {
    for j in 0..<right.cols {
      let mut acc = fe_from_int(0, left.domain)
      for k in 0..<left.cols {
        acc = fe_add(acc, fe_mul(a[i][k], b[k][j]))
      }
      out[i].set(j, acc)
    }
  }
  domain_matrix_from_dense(out, left.domain)
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

fn bigint_abs(x : BigInt) -> BigInt {
  if x.op_lt(BigInt::from_int(0)) {
    x.neg()
  } else {
    x
  }
}

fn field_elem_pow_nonnegative(
  base : FieldElem,
  n : Int,
  domain : Domain,
) -> FieldElem raise PolyError {
  if n < 0 {
    raise PolyError::BadExponent
  }
  let mut acc = fe_from_int(1, domain)
  let mut cur = base
  let mut exp = n
  while exp > 0 {
    if exp % 2 == 1 {
      acc = fe_mul(acc, cur)
    }
    exp = exp / 2
    if exp > 0 {
      cur = fe_mul(cur, cur)
    }
  }
  acc
}

fn field_elems_content(
  values : Array[FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let mut numer_gcd = BigInt::from_int(0)
  let mut denom_lcm = BigInt::from_int(1)
  for value in values {
    let q = fe_expect_rational(value)
    let numer = bigint_abs(q.numerator())
    if numer.is_zero() {
      continue
    }
    numer_gcd = if numer_gcd.is_zero() {
      numer
    } else {
      @symnum.gcd_bigint(numer_gcd, numer)
    }
    let denom = q.denominator()
    let g = @symnum.gcd_bigint(denom_lcm, denom)
    denom_lcm = denom_lcm.mul(denom.div(g))
  }
  if numer_gcd.is_zero() {
    return fe_from_int(0, domain)
  }
  fe_from_rational(try! @symnum.BigRational::new(numer_gcd, denom_lcm), domain)
}

fn dense_matrix_nonzero_entries(
  rows : Array[Array[FieldElem]],
) -> Array[(Int, Int, FieldElem)] {
  let out : Array[(Int, Int, FieldElem)] = Array::new()
  for i in 0..<rows.length() {
    for j in 0..<rows[i].length() {
      let value = rows[i][j]
      if !fe_is_zero(value) {
        out.push((i, j, value))
      }
    }
  }
  out
}

fn dense_matrix_is_diagonal(rows : Array[Array[FieldElem]]) -> Bool {
  for i in 0..<rows.length() {
    for j in 0..<rows[i].length() {
      if i != j && !fe_is_zero(rows[i][j]) {
        return false
      }
    }
  }
  true
}

fn dense_matrix_is_upper(rows : Array[Array[FieldElem]]) -> Bool {
  for i in 0..<rows.length() {
    for j in 0..<rows[i].length() {
      if i > j && !fe_is_zero(rows[i][j]) {
        return false
      }
    }
  }
  true
}

fn dense_matrix_is_lower(rows : Array[Array[FieldElem]]) -> Bool {
  for i in 0..<rows.length() {
    for j in 0..<rows[i].length() {
      if i < j && !fe_is_zero(rows[i][j]) {
        return false
      }
    }
  }
  true
}

fn dense_matrix_is_zero(rows : Array[Array[FieldElem]]) -> Bool {
  for row in rows {
    for value in row {
      if !fe_is_zero(value) {
        return false
      }
    }
  }
  true
}

fn matrix_adjacency_from_dense(
  rows : Array[Array[FieldElem]],
) -> (Array[Array[Int]], Array[Array[Int]]) {
  let n = rows.length()
  let adj : Array[Array[Int]] = Array::new()
  let rev : Array[Array[Int]] = Array::new()
  for _ in 0..<n {
    adj.push([])
    rev.push([])
  }
  for i in 0..<n {
    for j in 0..<rows[i].length() {
      if !fe_is_zero(rows[i][j]) {
        adj[i].push(j)
        rev[j].push(i)
      }
    }
  }
  (adj, rev)
}

fn dfs_postorder(
  node : Int,
  adj : Array[Array[Int]],
  seen : Array[Bool],
  order : Array[Int],
) -> Unit {
  if seen[node] {
    return
  }
  seen.set(node, true)
  for next in adj[node] {
    if !seen[next] {
      dfs_postorder(next, adj, seen, order)
    }
  }
  order.push(node)
}

fn dfs_collect_component(
  node : Int,
  adj : Array[Array[Int]],
  seen : Array[Bool],
  component : Array[Int],
) -> Unit {
  if seen[node] {
    return
  }
  seen.set(node, true)
  component.push(node)
  for next in adj[node] {
    if !seen[next] {
      dfs_collect_component(next, adj, seen, component)
    }
  }
}

fn collect_charpoly_factors(
  factors : Array[(Array[FieldElem], Int)],
) -> Array[(Array[FieldElem], Int)] {
  let keys : Array[String] = Array::new()
  let out : Array[(Array[FieldElem], Int)] = Array::new()
  for factor_pair in factors {
    let key = factor_pair.0.map(fe_to_string).join(",")
    let mut found = -1
    for i in 0..<keys.length() {
      if keys[i] == key {
        found = i
        break
      }
    }
    if found >= 0 {
      let prev = out[found]
      out.set(found, (prev.0, prev.1 + factor_pair.1))
    } else {
      keys.push(key)
      out.push(factor_pair)
    }
  }
  out
}

fn poly_from_dense_desc(
  coeffs : Array[FieldElem],
  gen : String,
  domain : Domain,
) -> Poly raise PolyError {
  let map : Map[Monomial, FieldElem] = Map::new()
  let degree = coeffs.length() - 1
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    if fe_is_zero(coeff) {
      continue
    }
    let mono = monomial_one(1)
    mono.exps.set(0, degree - i)
    add_term(map, mono, coeff, domain)
  }
  Poly::{ coeffs: map, gens: [gen], domain, order: TermOrder::Lex }
}

fn poly_to_dense_desc(poly : Poly) -> Array[FieldElem] raise PolyError {
  let degree = poly.degree(0)
  let coeffs : Array[FieldElem] = Array::make(degree + 1, fe_from_int(0, poly.domain))
  for mono, coeff in poly.coeffs {
    coeffs[degree - mono.exps[0]] = coeff
  }
  coeffs
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
pub fn DomainMatrix::from_list(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> DomainMatrix raise PolyError {
  domain_matrix_from_dense(rows, domain)
}

///|
/// Build a dense domain matrix from a flat row-major list of entries.
pub fn DomainMatrix::from_list_flat(
  elements : Array[FieldElem],
  shape : (Int, Int),
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let (rows, cols) = shape
  if rows < 0 || cols < 0 || elements.length() != rows * cols {
    raise PolyError::DomainMismatch
  }
  let dense : Array[Array[FieldElem]] = Array::new()
  for i in 0..<rows {
    let row : Array[FieldElem] = Array::new()
    for j in 0..<cols {
      row.push(elements[i * cols + j])
    }
    dense.push(row)
  }
  domain_matrix_from_dense(dense, domain)
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
/// Build a sparse domain matrix from dictionary-of-dictionaries form.
pub fn DomainMatrix::from_dod(
  dod : DomainMatrixDOD,
  shape : (Int, Int),
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let (rows, cols) = shape
  let entries : Array[(Int, Int, FieldElem)] = Array::new()
  for r, row in dod {
    for c, value in row {
      entries.push((r, c, value))
    }
  }
  domain_matrix_from_sparse(rows, cols, entries, domain)
}

///|
/// Build a sparse domain matrix from dictionary-of-keys form.
pub fn DomainMatrix::from_dok(
  dok : DomainMatrixDOK,
  shape : (Int, Int),
  domain : Domain,
) -> DomainMatrix raise PolyError {
  let (rows, cols) = shape
  let entries : Array[(Int, Int, FieldElem)] = Array::new()
  for key, value in dok {
    entries.push((key.0, key.1, value))
  }
  domain_matrix_from_sparse(rows, cols, entries, domain)
}

///|
pub fn DomainMatrix::zeros(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  domain_matrix_zeros(rows, cols, domain)
}

///|
pub fn DomainMatrix::ones(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  domain_matrix_ones(rows, cols, domain)
}

///|
pub fn DomainMatrix::eye(n : Int, domain : Domain) -> DomainMatrix raise PolyError {
  domain_matrix_eye(n, domain)
}

///|
pub fn DomainMatrix::diag(
  values : Array[FieldElem],
  domain : Domain,
  rows? : Int? = None,
  cols? : Int? = None,
) -> DomainMatrix raise PolyError {
  let rows = match rows {
    Some(v) => v
    None => values.length()
  }
  let cols = match cols {
    Some(v) => v
    None => values.length()
  }
  if rows < 0 || cols < 0 {
    raise PolyError::DomainMismatch
  }
  let zero = fe_from_int(0, domain)
  let dense = make_dense(rows, cols, zero)
  let mut limit = rows
  if cols < limit {
    limit = cols
  }
  if values.length() < limit {
    limit = values.length()
  }
  for i in 0..<limit {
    dense[i].set(i, values[i])
  }
  domain_matrix_from_dense(dense, domain)
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
pub fn DomainMatrix::unify_eq(self : DomainMatrix, other : DomainMatrix) -> Bool raise PolyError {
  if self.shape() != other.shape() {
    return false
  }
  let (a, b) = if self.domain == other.domain {
    (self, other)
  } else {
    self.unify(other)
  }
  let left = a.to_dense()
  let right = b.to_dense()
  for i in 0..<a.rows {
    for j in 0..<a.cols {
      if !fe_is_zero(fe_sub(left[i][j], right[i][j])) {
        return false
      }
    }
  }
  true
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
  scalar : FieldElem,
) -> DomainMatrix raise PolyError {
  self.scalarmul(scalar)
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
    let row_idx = normalize_matrix_index(r, self.rows)
    let row : Array[FieldElem] = Array::new()
    for c in col_ids {
      let col_idx = normalize_matrix_index(c, self.cols)
      row.push(dense[row_idx][col_idx])
    }
    out.push(row)
  }
  domain_matrix_from_dense(out, self.domain)
}

///|
pub fn DomainMatrix::extract_slice(
  self : DomainMatrix,
  row_start? : Int? = None,
  row_stop? : Int? = None,
  row_step? : Int = 1,
  col_start? : Int? = None,
  col_stop? : Int? = None,
  col_step? : Int = 1,
) -> DomainMatrix raise PolyError {
  let rows = slice_index_range(self.rows, start=row_start, stop=row_stop, step=row_step)
  let cols = slice_index_range(self.cols, start=col_start, stop=col_stop, step=col_step)
  self.extract(rows, cols)
}

///|
pub fn DomainMatrix::getitem(
  self : DomainMatrix,
  row : Int,
  col : Int,
) -> DomainScalar raise PolyError {
  let dense = self.to_dense()
  let row_idx = normalize_matrix_index(row, self.rows)
  let col_idx = normalize_matrix_index(col, self.cols)
  domain_scalar_new(dense[row_idx][col_idx], self.domain)
}

///|
pub fn DomainMatrix::setitem(
  self : DomainMatrix,
  row : Int,
  col : Int,
  value : FieldElem,
) -> DomainMatrix raise PolyError {
  let _ = fe_add(value, fe_from_int(0, self.domain))
  let row_idx = normalize_matrix_index(row, self.rows)
  let col_idx = normalize_matrix_index(col, self.cols)
  let dense = clone_dense_rows(self.to_dense())
  dense[row_idx].set(col_idx, value)
  restore_rep_like(domain_matrix_from_dense(dense, self.domain), self)
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

///|
pub fn DomainMatrix::vstack(
  self : DomainMatrix,
  other : DomainMatrix,
) -> DomainMatrix raise PolyError {
  let (top, bottom) = self.unify(other)
  if top.cols != bottom.cols {
    raise PolyError::DomainMismatch
  }
  let out = clone_dense_rows(top.to_dense())
  for row in bottom.to_dense() {
    out.push(row)
  }
  restore_rep_like(domain_matrix_from_dense(out, top.domain), self)
}

///|
pub fn DomainMatrix::neg(self : DomainMatrix) -> DomainMatrix raise PolyError {
  restore_rep_like(domain_matrix_scale(self, fe_from_int(-1, self.domain)), self)
}

///|
pub fn DomainMatrix::matmul(
  self : DomainMatrix,
  other : DomainMatrix,
) -> DomainMatrix raise PolyError {
  restore_rep_like(domain_matrix_matmul(self, other), self)
}

///|
pub fn DomainMatrix::mul_elementwise(
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
      row.push(fe_mul(a[i][j], b[i][j]))
    }
    out.push(row)
  }
  restore_rep_like(domain_matrix_from_dense(out, self.domain), self)
}

///|
pub fn DomainMatrix::scalarmul(
  self : DomainMatrix,
  scalar : FieldElem,
) -> DomainMatrix raise PolyError {
  restore_rep_like(domain_matrix_scale(self, scalar), self)
}

///|
pub fn DomainMatrix::rscalarmul(
  self : DomainMatrix,
  scalar : FieldElem,
) -> DomainMatrix raise PolyError {
  self.scalarmul(scalar)
}

///|
pub fn DomainMatrix::rmul(
  self : DomainMatrix,
  scalar : FieldElem,
) -> DomainMatrix raise PolyError {
  self.scalarmul(scalar)
}

///|
pub fn DomainMatrix::diagonal(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  let dense = self.to_dense()
  let limit = if self.rows < self.cols { self.rows } else { self.cols }
  let out : Array[FieldElem] = Array::new()
  for i in 0..<limit {
    out.push(dense[i][i])
  }
  out
}

///|
pub fn DomainMatrix::nnz(self : DomainMatrix) -> Int raise PolyError {
  dense_matrix_nonzero_entries(self.to_dense()).length()
}

///|
pub fn DomainMatrix::iter_values(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for entry in dense_matrix_nonzero_entries(self.to_dense()) {
    out.push(entry.2)
  }
  out
}

///|
pub fn DomainMatrix::iter_items(self : DomainMatrix) -> Array[(Int, Int, FieldElem)] raise PolyError {
  dense_matrix_nonzero_entries(self.to_dense())
}

///|
pub fn DomainMatrix::to_list(self : DomainMatrix) -> Array[Array[FieldElem]] raise PolyError {
  self.to_dense()
}

///|
pub fn DomainMatrix::to_list_flat(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for row in self.to_dense() {
    for value in row {
      out.push(value)
    }
  }
  out
}

///|
pub fn DomainMatrix::flat(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  self.to_list_flat()
}

///|
pub fn DomainMatrix::to_flat_nz(
  self : DomainMatrix,
) -> (Array[FieldElem], DomainMatrixFlatNZData) raise PolyError {
  match self.rep {
    DomainMatrixRep::Dense(_) =>
      (self.to_list_flat(), DomainMatrixFlatNZData::Dense(self.rows, self.cols))
    DomainMatrixRep::Sparse(_) => {
      let elements : Array[FieldElem] = Array::new()
      let positions : Array[(Int, Int)] = Array::new()
      for entry in dense_matrix_nonzero_entries(self.to_dense()) {
        elements.push(entry.2)
        positions.push((entry.0, entry.1))
      }
      (elements, DomainMatrixFlatNZData::Sparse(self.rows, self.cols, positions))
    }
  }
}

///|
pub fn DomainMatrix::from_flat_nz(
  self : DomainMatrix,
  elements : Array[FieldElem],
  data : DomainMatrixFlatNZData,
  domain : Domain,
) -> DomainMatrix raise PolyError {
  match data {
    DomainMatrixFlatNZData::Dense(rows, cols) => {
      if rows != self.rows || cols != self.cols {
        raise PolyError::DomainMismatch
      }
      DomainMatrix::from_list_flat(elements, (rows, cols), domain)
    }
    DomainMatrixFlatNZData::Sparse(rows, cols, positions) => {
      if rows != self.rows || cols != self.cols {
        raise PolyError::DomainMismatch
      }
      if elements.length() != positions.length() {
        raise PolyError::DomainMismatch
      }
      let entries : Array[(Int, Int, FieldElem)] = Array::new()
      for i in 0..<elements.length() {
        let pos = positions[i]
        entries.push((pos.0, pos.1, elements[i]))
      }
      domain_matrix_from_sparse(rows, cols, entries, domain)
    }
  }
}

///|
pub fn DomainMatrix::to_dod(self : DomainMatrix) -> DomainMatrixDOD raise PolyError {
  let dod : DomainMatrixDOD = Map::new()
  for entry in dense_matrix_nonzero_entries(self.to_dense()) {
    match dod.get(entry.0) {
      Some(row) => row[entry.1] = entry.2
      None => {
        let row : Map[Int, FieldElem] = Map::new()
        row[entry.1] = entry.2
        dod[entry.0] = row
      }
    }
  }
  dod
}

///|
pub fn DomainMatrix::from_dod_like(
  self : DomainMatrix,
  dod : DomainMatrixDOD,
  domain? : Domain? = None,
) -> DomainMatrix raise PolyError {
  let out_domain = match domain {
    Some(v) => v
    None => self.domain
  }
  restore_rep_like(DomainMatrix::from_dod(clone_dod(dod), self.shape(), out_domain), self)
}

///|
pub fn DomainMatrix::to_dok(self : DomainMatrix) -> DomainMatrixDOK raise PolyError {
  let dok : DomainMatrixDOK = Map::new()
  for entry in dense_matrix_nonzero_entries(self.to_dense()) {
    dok[(entry.0, entry.1)] = entry.2
  }
  dok
}

///|
pub fn DomainMatrix::to_ddm(self : DomainMatrix) -> DDM raise PolyError {
  DDM::{ dm: self.copy() }
}

///|
pub fn DomainMatrix::to_sdm(self : DomainMatrix) -> SDM raise PolyError {
  SDM::{ dm: self.to_sparse() }
}

///|
pub fn DomainMatrix::content(self : DomainMatrix) -> FieldElem raise PolyError {
  field_elems_content(self.iter_values(), self.domain)
}

///|
pub fn DomainMatrix::primitive(self : DomainMatrix) -> (FieldElem, DomainMatrix) raise PolyError {
  let content = self.content()
  if fe_is_zero(content) {
    return (content, self.copy())
  }
  let dense = self.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for row in dense {
    let out_row : Array[FieldElem] = Array::new()
    for value in row {
      if fe_is_zero(value) {
        out_row.push(value)
      } else {
        out_row.push(fe_exact_div_in_domain(value, content, self.domain))
      }
    }
    out.push(out_row)
  }
  (content, restore_rep_like(domain_matrix_from_dense(out, self.domain), self))
}

///|
pub fn DomainMatrix::cancel_denom(
  self : DomainMatrix,
  denom : FieldElem,
) -> (DomainMatrix, FieldElem) raise PolyError {
  if fe_is_zero(denom) {
    raise PolyError::DivisionByZero
  }
  let unit = canonical_unit_in_domain(denom, self.domain)
  let canon_matrix = if fe_is_one(unit) {
    self.copy()
  } else {
    self.scalarmul(unit)
  }
  let canon_denom = fe_mul(unit, denom)
  if fe_is_one(canon_denom) {
    return (canon_matrix, canon_denom)
  }
  let values = canon_matrix.iter_values()
  values.push(canon_denom)
  let common = field_elems_content(values, self.domain)
  if fe_is_one(common) {
    return (canon_matrix, canon_denom)
  }
  let (content, prim) = canon_matrix.primitive()
  if fe_is_one(content) {
    return (canon_matrix, canon_denom)
  }
  let reduced_common = field_elems_content([content, canon_denom], self.domain)
  if fe_is_one(reduced_common) {
    return (canon_matrix, canon_denom)
  }
  (
    prim.scalarmul(fe_exact_div_in_domain(content, reduced_common, self.domain)),
    fe_exact_div_in_domain(canon_denom, reduced_common, self.domain),
  )
}

///|
pub fn DomainMatrix::cancel_denom_elementwise(
  self : DomainMatrix,
  denom : FieldElem,
) -> (DomainMatrix, DomainMatrix) raise PolyError {
  if fe_is_zero(denom) {
    raise PolyError::DivisionByZero
  }
  let unit = canonical_unit_in_domain(denom, self.domain)
  let canon_matrix = if fe_is_one(unit) {
    self.copy()
  } else {
    self.scalarmul(unit)
  }
  let canon_denom = fe_mul(unit, denom)
  if fe_is_one(canon_denom) {
    return (
      canon_matrix,
      restore_rep_like(domain_matrix_ones(self.rows, self.cols, self.domain), self),
    )
  }
  let num_rows : Array[Array[FieldElem]] = Array::new()
  let den_rows : Array[Array[FieldElem]] = Array::new()
  for row in canon_matrix.to_dense() {
    let out_num : Array[FieldElem] = Array::new()
    let out_den : Array[FieldElem] = Array::new()
    for value in row {
      if fe_is_zero(value) {
        out_num.push(value)
        out_den.push(fe_from_int(1, self.domain))
      } else {
        let common = field_elems_content([value, canon_denom], self.domain)
        out_num.push(fe_exact_div_in_domain(value, common, self.domain))
        out_den.push(fe_exact_div_in_domain(canon_denom, common, self.domain))
      }
    }
    num_rows.push(out_num)
    den_rows.push(out_den)
  }
  (
    restore_rep_like(domain_matrix_from_dense(num_rows, self.domain), self),
    restore_rep_like(domain_matrix_from_dense(den_rows, self.domain), self),
  )
}

///|
pub fn DomainMatrix::pow(self : DomainMatrix, n : Int) -> DomainMatrix raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  if n < 0 {
    raise PolyError::BadExponent
  }
  let mut acc = domain_matrix_eye(self.rows, self.domain)
  let mut base = self.copy()
  let mut exp = n
  while exp > 0 {
    if exp % 2 == 1 {
      acc = acc.matmul(base)
    }
    exp = exp / 2
    if exp > 0 {
      base = base.matmul(base)
    }
  }
  restore_rep_like(acc, self)
}

///|
pub fn DomainMatrix::is_square(self : DomainMatrix) -> Bool {
  self.rows == self.cols
}

///|
pub fn DomainMatrix::applyfunc(
  self : DomainMatrix,
  func : FieldElemMapper,
  domain? : Domain? = None,
) -> DomainMatrix raise PolyError {
  let out_domain = match domain {
    Some(v) => v
    None => self.domain
  }
  match self.rep {
    DomainMatrixRep::Dense(rows) => {
      let out : Array[Array[FieldElem]] = Array::new()
      for row in rows {
        let out_row : Array[FieldElem] = Array::new()
        for value in row {
          out_row.push(func(value))
        }
        out.push(out_row)
      }
      domain_matrix_from_dense(out, out_domain)
    }
    DomainMatrixRep::Sparse(entries) => {
      let sparse : Map[Int, Map[Int, FieldElem]] = Map::new()
      for r, row in entries {
        for c, value in row {
          let mapped = func(value)
          if fe_is_zero(mapped) {
            continue
          }
          match sparse.get(r) {
            Some(row_out) => row_out[c] = mapped
            None => {
              let row_out : Map[Int, FieldElem] = Map::new()
              row_out[c] = mapped
              sparse[r] = row_out
            }
          }
        }
      }
      DomainMatrix::{
        rep: DomainMatrixRep::Sparse(sparse),
        rows: self.rows,
        cols: self.cols,
        domain: out_domain,
      }
    }
  }
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
      domain_matrix_from_dense(a_minor, domain).matmul(domain_matrix_from_dense(cur_c, domain)).to_dense()
    }
    let ran_c = domain_matrix_from_dense(r, domain).matmul(domain_matrix_from_dense(an_c, domain)).to_dense()
    for j in 0..<(n + 1 - i) {
      t[i + j].set(j, fe_neg(ran_c[0][0]))
    }
    cur_c = an_c
  }

  let q_col : Array[Array[FieldElem]] = Array::new()
  for coeff in q {
    q_col.push([coeff])
  }
  let out = domain_matrix_from_dense(t, domain).matmul(domain_matrix_from_dense(q_col, domain)).to_dense()
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
pub fn DomainMatrix::particular(
  self : DomainMatrix,
  pivots? : Array[Int] = [],
) -> DomainMatrix raise PolyError {
  particular_from_rref(self, pivots~)
}

///|
pub fn DomainMatrix::_solve(
  self : DomainMatrix,
  rhs : DomainMatrix,
) -> (DomainMatrix, DomainMatrix) raise PolyError {
  if self.rows != rhs.rows || rhs.cols != 1 {
    raise PolyError::DomainMismatch
  }
  if self.domain.not_equal(rhs.domain) || !domain_is_field_pred(self.domain) {
    raise PolyError::DomainNotField
  }
  let aug = self.hstack(rhs)
  let (rref_aug, pivots) = aug.rref()
  let particular = rref_aug.particular(pivots=pivots)
  let left_rref = rref_aug.extract(all_indices(0, rref_aug.rows), all_indices(0, self.cols))
  let left_pivots : Array[Int] = Array::new()
  for pivot in pivots {
    if pivot < self.cols {
      left_pivots.push(pivot)
    }
  }
  let nullspace = left_rref.nullspace_from_rref(pivots=left_pivots)
  (particular, nullspace)
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
    "charpoly" => self.solve_den_charpoly(rhs)
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
pub fn DomainMatrix::charpoly_factor_list(
  self : DomainMatrix,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  let irreducible : Array[(Array[FieldElem], Int)] = Array::new()
  for block in self.charpoly_factor_blocks() {
    let poly = poly_from_dense_desc(block.0, "lambda", self.domain)
    let (_, factors) = poly.factor_list()
    for factor_pair in factors {
      irreducible.push((poly_to_dense_desc(factor_pair.0), block.1 * factor_pair.1))
    }
  }
  collect_charpoly_factors(irreducible)
}

///|
pub fn DomainMatrix::charpoly_berk(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  self.charpoly()
}

///|
pub fn DomainMatrix::charpoly_base(self : DomainMatrix) -> Array[FieldElem] raise PolyError {
  if self.rows == 0 {
    return [fe_from_int(1, self.domain)]
  }
  let dm = if self.nnz() * 2 < self.rows * self.cols {
    self.to_sparse()
  } else {
    self.copy()
  }
  if domain_is_field_pred(dm.domain) && domain_has_assoc_ring_pred(dm.domain) {
    let (den, cleared) = dm.clear_denoms(convert=true)
    let cp_ring = cleared.charpoly_berk()
    let den_field = convert_matrix_elem(den.element, dm.domain)
    let out : Array[FieldElem] = Array::new()
    for i in 0..<cp_ring.length() {
      let coeff = convert_matrix_elem(cp_ring[i], dm.domain)
      let scale = field_elem_pow_nonnegative(den_field, i, dm.domain)
      out.push(fe_mul(coeff, fe_inv(scale)))
    }
    return out
  }
  dm.charpoly_berk()
}

///|
pub fn DomainMatrix::eval_poly(
  self : DomainMatrix,
  p : Array[FieldElem],
) -> DomainMatrix raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  if p.is_empty() {
    return restore_rep_like(domain_matrix_zeros(self.rows, self.cols, self.domain), self)
  }
  let ident = domain_matrix_eye(self.rows, self.domain)
  let mut acc = ident.scalarmul(p[0])
  for i in 1..<p.length() {
    acc = self.matmul(acc).add(ident.scalarmul(p[i]))
  }
  restore_rep_like(acc, self)
}

///|
pub fn DomainMatrix::eval_poly_mul(
  self : DomainMatrix,
  p : Array[FieldElem],
  rhs : DomainMatrix,
) -> DomainMatrix raise PolyError {
  let (a, b) = self.unify(rhs)
  if a.rows != a.cols || b.rows != a.cols {
    raise PolyError::DomainMismatch
  }
  if p.is_empty() {
    return restore_rep_like(domain_matrix_zeros(b.rows, b.cols, b.domain), rhs)
  }
  let mut acc = b.scalarmul(convert_matrix_elem(p[0], b.domain))
  for i in 1..<p.length() {
    acc = a.matmul(acc).add(b.scalarmul(convert_matrix_elem(p[i], b.domain)))
  }
  restore_rep_like(acc, rhs)
}

///|
pub fn DomainMatrix::adj_poly_det(
  self : DomainMatrix,
  cp? : Array[FieldElem] = [],
) -> (Array[FieldElem], FieldElem) raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  let charpoly = if cp.is_empty() { self.charpoly() } else { cp }
  let det = if charpoly.length() % 2 == 1 {
    charpoly[charpoly.length() - 1]
  } else {
    fe_neg(charpoly[charpoly.length() - 1])
  }
  let adj_poly : Array[FieldElem] = Array::new()
  for i in 0..<(charpoly.length() - 1) {
    let coeff = charpoly[i]
    adj_poly.push(if charpoly.length() % 2 == 1 { fe_neg(coeff) } else { coeff })
  }
  (adj_poly, det)
}

///|
pub fn DomainMatrix::solve_den_charpoly(
  self : DomainMatrix,
  rhs : DomainMatrix,
  cp? : Array[FieldElem] = [],
  check? : Bool = true,
) -> (DomainMatrix, FieldElem) raise PolyError {
  let (a, b) = self.unify(rhs)
  if a.rows != a.cols || b.rows != a.rows {
    raise PolyError::DomainMismatch
  }
  let (adj_poly, det) = a.adj_poly_det(cp=cp)
  if check && fe_is_zero(det) {
    raise PolyError::ExactQuotientFailed
  }
  (a.eval_poly_mul(adj_poly, b), det)
}

///|
pub fn DomainMatrix::scc(self : DomainMatrix) -> Array[Array[Int]] raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  if self.rows == 0 {
    return []
  }
  let (adj, rev) = matrix_adjacency_from_dense(self.to_dense())
  let seen = Array::make(self.rows, false)
  let order : Array[Int] = Array::new()
  for node in 0..<self.rows {
    if !seen[node] {
      dfs_postorder(node, adj, seen, order)
    }
  }
  let seen_rev = Array::make(self.rows, false)
  let comps : Array[Array[Int]] = Array::new()
  for idx in 0..<order.length() {
    let node = order[order.length() - 1 - idx]
    if seen_rev[node] {
      continue
    }
    let comp : Array[Int] = Array::new()
    dfs_collect_component(node, rev, seen_rev, comp)
    comp.sort()
    comps.push(comp)
  }
  let out : Array[Array[Int]] = Array::new()
  for i in 0..<comps.length() {
    out.push(comps[comps.length() - 1 - i])
  }
  out
}

///|
pub fn DomainMatrix::charpoly_factor_blocks(
  self : DomainMatrix,
) -> Array[(Array[FieldElem], Int)] raise PolyError {
  if self.rows != self.cols {
    raise PolyError::DomainMismatch
  }
  let factors : Array[(Array[FieldElem], Int)] = Array::new()
  for indices in self.scc() {
    factors.push((self.extract(indices, indices).charpoly_base(), 1))
  }
  collect_charpoly_factors(factors)
}

///|
pub fn DomainMatrix::lll(
  self : DomainMatrix,
  delta? : @symnum.BigRational,
) -> DomainMatrix raise PolyError {
  let reduced = match delta {
    Some(d) => self.to_ddm().lll(delta=d)
    None => self.to_ddm().lll()
  }
  restore_rep_like(reduced.to_domain_matrix(), self)
}

///|
pub fn DomainMatrix::lll_transform(
  self : DomainMatrix,
  delta? : @symnum.BigRational,
) -> (DomainMatrix, DomainMatrix) raise PolyError {
  let (reduced, transform) = match delta {
    Some(d) => self.to_ddm().lll_transform(delta=d)
    None => self.to_ddm().lll_transform()
  }
  (
    restore_rep_like(reduced.to_domain_matrix(), self),
    restore_rep_like(transform.to_domain_matrix(), self),
  )
}

///|
pub fn DomainMatrix::is_diagonal(self : DomainMatrix) -> Bool raise PolyError {
  dense_matrix_is_diagonal(self.to_dense())
}

///|
pub fn DomainMatrix::is_upper(self : DomainMatrix) -> Bool raise PolyError {
  dense_matrix_is_upper(self.to_dense())
}

///|
pub fn DomainMatrix::is_lower(self : DomainMatrix) -> Bool raise PolyError {
  dense_matrix_is_lower(self.to_dense())
}

///|
pub fn DomainMatrix::is_zero_matrix(self : DomainMatrix) -> Bool raise PolyError {
  dense_matrix_is_zero(self.to_dense())
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
