///|
fn zz_ddm_to_bigint_rows(ddm : DDM) -> Array[Array[BigInt]] raise PolyError {
  match ddm.domain() {
    ZZ => ()
    _ => raise DomainMismatch
  }
  let rows = ddm.to_list()
  let out : Array[Array[BigInt]] = Array::new()
  for row in rows {
    let out_row : Array[BigInt] = Array::new()
    for v in row {
      let q = fe_expect_rational(v)
      if !q.denominator().equal_int(1) {
        raise DomainMismatch
      }
      out_row.push(q.numerator())
    }
    out.push(out_row)
  }
  out
}

///|
fn bigint_rows_to_zz_ddm(rows : Array[Array[BigInt]]) -> DDM raise PolyError {
  let out : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    let out_row : Array[FieldElem] = Array::new()
    for v in row {
      out_row.push(fe_from_rational(@symnum.BigRational::from_bigint(v), ZZ))
    }
    out.push(out_row)
  }
  ddm_from_dense(out, ZZ)
}

///|
fn clone_bigint_rows(rows : Array[Array[BigInt]]) -> Array[Array[BigInt]] {
  let out : Array[Array[BigInt]] = Array::new()
  for row in rows {
    let out_row : Array[BigInt] = Array::new()
    for value in row {
      out_row.push(value)
    }
    out.push(out_row)
  }
  out
}

///|
fn bigint_eye(n : Int) -> Array[Array[BigInt]] {
  let zero = BigInt::from_int(0)
  let one = BigInt::from_int(1)
  let out : Array[Array[BigInt]] = Array::new()
  for i in 0..<n {
    let row : Array[BigInt] = Array::new()
    for j in 0..<n {
      row.push(if i == j { one } else { zero })
    }
    out.push(row)
  }
  out
}

///|
fn bigint_matmul(
  left : Array[Array[BigInt]],
  right : Array[Array[BigInt]],
) -> Array[Array[BigInt]] {
  if left.is_empty() {
    return []
  }
  let rows = left.length()
  let inner = left[0].length()
  let cols = if right.is_empty() { 0 } else { right[0].length() }
  let zero = BigInt::from_int(0)
  let out : Array[Array[BigInt]] = Array::new()
  for i in 0..<rows {
    let row : Array[BigInt] = Array::new()
    for j in 0..<cols {
      let mut acc = zero
      for k in 0..<inner {
        acc = acc.add(left[i][k].mul(right[k][j]))
      }
      row.push(acc)
    }
    out.push(row)
  }
  out
}

///|
fn add_rows_bigint(
  matrix : Array[Array[BigInt]],
  i : Int,
  j : Int,
  a : BigInt,
  b : BigInt,
  c : BigInt,
  d : BigInt,
) -> Unit {
  let row_i = matrix[i]
  let row_j = matrix[j]
  matrix.set(i, row_linear_comb(row_i, a, row_j, b))
  matrix.set(j, row_linear_comb(row_i, c, row_j, d))
}

///|
fn add_columns_bigint(
  matrix : Array[Array[BigInt]],
  i : Int,
  j : Int,
  a : BigInt,
  b : BigInt,
  c : BigInt,
  d : BigInt,
) -> Unit {
  for k in 0..<matrix.length() {
    let e = matrix[k][i]
    let other = matrix[k][j]
    matrix[k].set(i, a.mul(e).add(b.mul(other)))
    matrix[k].set(j, c.mul(e).add(d.mul(other)))
  }
}

///|
fn swap_rows_bigint(matrix : Array[Array[BigInt]], i : Int, j : Int) -> Unit {
  if i == j {
    return
  }
  let tmp = matrix[i]
  matrix.set(i, matrix[j])
  matrix.set(j, tmp)
}

///|
fn swap_columns_bigint(matrix : Array[Array[BigInt]], i : Int, j : Int) -> Unit {
  if i == j {
    return
  }
  for row in matrix {
    let tmp = row[i]
    row.set(i, row[j])
    row.set(j, tmp)
  }
}

///|
fn smith_bigint_zero_shape(
  rows : Int,
  cols : Int,
) -> (Array[BigInt], Array[Array[BigInt]], Array[Array[BigInt]]) {
  ([], bigint_eye(rows), bigint_eye(cols))
}

///|
fn smith_bigint_decomp(
  rows : Array[Array[BigInt]],
  full : Bool,
) -> (Array[BigInt], Array[Array[BigInt]], Array[Array[BigInt]]) {
  let row_count = rows.length()
  let col_count = if row_count == 0 { 0 } else { rows[0].length() }
  if row_count == 0 || col_count == 0 {
    return smith_bigint_zero_shape(row_count, col_count)
  }

  let zero = BigInt::from_int(0)
  let one = BigInt::from_int(1)
  let matrix = clone_bigint_rows(rows)
  let mut s = bigint_eye(row_count)
  let mut t = bigint_eye(col_count)

  fn clear_column(
    matrix : Array[Array[BigInt]],
    s : Array[Array[BigInt]]?,
  ) -> Unit {
    let mut pivot = matrix[0][0]
    for j in 1..<matrix.length() {
      if matrix[j][0].equal(zero) {
        continue
      }
      if matrix[j][0].mod(pivot).equal(zero) {
        let d = matrix[j][0].div(pivot)
        add_rows_bigint(matrix, 0, j, one, zero, d.neg(), one)
        match s {
          Some(ss) => add_rows_bigint(ss, 0, j, one, zero, d.neg(), one)
          None => ()
        }
      } else {
        let (g, a, b) = xgcd(pivot, matrix[j][0])
        let d0 = matrix[j][0].div(g)
        let dj = pivot.div(g)
        add_rows_bigint(matrix, 0, j, a, b, d0, dj.neg())
        match s {
          Some(ss) => add_rows_bigint(ss, 0, j, a, b, d0, dj.neg())
          None => ()
        }
        pivot = g
      }
    }
  }

  fn clear_row(
    matrix : Array[Array[BigInt]],
    t : Array[Array[BigInt]]?,
  ) -> Unit {
    let mut pivot = matrix[0][0]
    for j in 1..<matrix[0].length() {
      if matrix[0][j].equal(zero) {
        continue
      }
      if matrix[0][j].mod(pivot).equal(zero) {
        let d = matrix[0][j].div(pivot)
        add_columns_bigint(matrix, 0, j, one, zero, d.neg(), one)
        match t {
          Some(tt) => add_columns_bigint(tt, 0, j, one, zero, d.neg(), one)
          None => ()
        }
      } else {
        let (g, a, b) = xgcd(pivot, matrix[0][j])
        let d0 = matrix[0][j].div(g)
        let dj = pivot.div(g)
        add_columns_bigint(matrix, 0, j, a, b, d0, dj.neg())
        match t {
          Some(tt) => add_columns_bigint(tt, 0, j, a, b, d0, dj.neg())
          None => ()
        }
        pivot = g
      }
    }
  }

  let mut pivot_row = -1
  for i in 0..<row_count {
    if !matrix[i][0].equal(zero) {
      pivot_row = i
      break
    }
  }
  if pivot_row >= 0 && pivot_row != 0 {
    swap_rows_bigint(matrix, 0, pivot_row)
    if full {
      swap_rows_bigint(s, 0, pivot_row)
    }
  } else {
    let mut pivot_col = -1
    for j in 0..<col_count {
      if !matrix[0][j].equal(zero) {
        pivot_col = j
        break
      }
    }
    if pivot_col >= 0 && pivot_col != 0 {
      swap_columns_bigint(matrix, 0, pivot_col)
      if full {
        swap_columns_bigint(t, 0, pivot_col)
      }
    }
  }

  while true {
    let mut has_row = false
    for i in 1..<col_count {
      if !matrix[0][i].equal(zero) {
        has_row = true
        break
      }
    }
    let mut has_col = false
    for i in 1..<row_count {
      if !matrix[i][0].equal(zero) {
        has_col = true
        break
      }
    }
    if !has_row && !has_col {
      break
    }
    if full {
      clear_column(matrix, Some(s))
      clear_row(matrix, Some(t))
    } else {
      clear_column(matrix, None)
      clear_row(matrix, None)
    }
  }

  if !matrix[0][0].equal(zero) && matrix[0][0] < zero {
    matrix[0][0] = matrix[0][0].neg()
    if full {
      let scaled : Array[BigInt] = Array::new()
      for value in s[0] {
        scaled.push(value.neg())
      }
      s.set(0, scaled)
    }
  }

  let mut invs : Array[BigInt] = Array::new()
  if row_count > 1 && col_count > 1 {
    let lower_right : Array[Array[BigInt]] = Array::new()
    for i in 1..<row_count {
      let row : Array[BigInt] = Array::new()
      for j in 1..<col_count {
        row.push(matrix[i][j])
      }
      lower_right.push(row)
    }
    let (sub_invs, s_small, t_small) = smith_bigint_decomp(lower_right, full)
    invs = sub_invs
    if full {
      let s2 = bigint_eye(row_count)
      let t2 = bigint_eye(col_count)
      for i in 1..<row_count {
        for j in 1..<row_count {
          s2[i].set(j, s_small[i - 1][j - 1])
        }
      }
      for i in 1..<col_count {
        for j in 1..<col_count {
          t2[i].set(j, t_small[i - 1][j - 1])
        }
      }
      s = bigint_matmul(s2, s)
      t = bigint_matmul(t, t2)
    }
  }

  let result : Array[BigInt] = Array::new()
  if !matrix[0][0].equal(zero) {
    result.push(matrix[0][0])
    for inv in invs {
      result.push(inv)
    }
    for i in 0..<(result.length() - 1) {
      let a = result[i]
      let b = result[i + 1]
      if b.equal(zero) || b.mod(a).equal(zero) {
        break
      }
      let (d, x, y) = xgcd(a, b)
      let alpha = a.div(d)
      let beta = b.div(d)
      if full {
        add_rows_bigint(s, i, i + 1, one, zero, x, one)
        add_columns_bigint(t, i, i + 1, one, y, zero, one)
        add_rows_bigint(s, i, i + 1, one, alpha.neg(), zero, one)
        add_columns_bigint(t, i, i + 1, one, zero, beta.neg(), one)
        add_rows_bigint(s, i, i + 1, zero, one, one.neg(), zero)
      }
      result.set(i, d)
      result.set(i + 1, b.mul(alpha))
    }
  } else {
    if full {
      if row_count > 1 {
        let rotated : Array[Array[BigInt]] = Array::new()
        for i in 1..<row_count {
          rotated.push(s[i])
        }
        rotated.push(s[0])
        s = rotated
      }
      if col_count > 1 {
        let rotated_t : Array[Array[BigInt]] = Array::new()
        for row in t {
          let rotated_row : Array[BigInt] = Array::new()
          for j in 1..<col_count {
            rotated_row.push(row[j])
          }
          rotated_row.push(row[0])
          rotated_t.push(rotated_row)
        }
        t = rotated_t
      }
    }
    for inv in invs {
      result.push(inv)
    }
    result.push(zero)
  }

  (result, s, t)
}

///|
fn bigint_invariants_to_zz_elems(
  invs : Array[BigInt],
) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for value in invs {
    out.push(fe_from_rational(@symnum.BigRational::from_bigint(value), ZZ))
  }
  out
}

///|
fn smith_diag_from_invariants(
  invs : Array[BigInt],
  rows : Int,
  cols : Int,
) -> DDM raise PolyError {
  DDM::diag(
    bigint_invariants_to_zz_elems(invs),
    ZZ,
    rows=Some(rows),
    cols=Some(cols),
  )
}

///|
fn smith_adjust_invariants_for_det_sign(
  ddm : DDM,
  invs : Array[BigInt],
) -> Array[BigInt] raise PolyError {
  let (rows, cols) = ddm.shape()
  if rows != cols || invs.is_empty() {
    return invs
  }
  if !fe_is_negative(ddm.det()) {
    return invs
  }
  let out = invs.copy()
  for i in 0..<out.length() {
    let idx = out.length() - 1 - i
    if !out[idx].equal_int(0) {
      out[idx] = out[idx].neg()
      break
    }
  }
  out
}

///|
fn smith_adjust_left_transform_for_det_sign(
  ddm : DDM,
  invs : Array[BigInt],
  left : Array[Array[BigInt]],
) -> Array[Array[BigInt]] raise PolyError {
  let (rows, cols) = ddm.shape()
  if rows != cols || invs.is_empty() {
    return left
  }
  if !fe_is_negative(ddm.det()) {
    return left
  }
  let adjusted = clone_bigint_rows(left)
  for i in 0..<invs.length() {
    let idx = invs.length() - 1 - i
    if !invs[idx].equal_int(0) {
      let row : Array[BigInt] = Array::new()
      for value in adjusted[idx] {
        row.push(value.neg())
      }
      adjusted.set(idx, row)
      break
    }
  }
  adjusted
}

///|
fn row_linear_comb(
  row_a : Array[BigInt],
  a_mul : BigInt,
  row_b : Array[BigInt],
  b_mul : BigInt,
) -> Array[BigInt] {
  let out : Array[BigInt] = Array::new()
  for i in 0..<row_a.length() {
    out.push(a_mul.mul(row_a[i]).add(b_mul.mul(row_b[i])))
  }
  out
}

///|
fn abs_bigint(x : BigInt) -> BigInt {
  if x < BigInt::from_int(0) {
    x.neg()
  } else {
    x
  }
}

///|
fn xgcd(a0 : BigInt, b0 : BigInt) -> (BigInt, BigInt, BigInt) {
  let zero = BigInt::from_int(0)
  let mut old_r = a0
  let mut r = b0
  let mut old_s = BigInt::from_int(1)
  let mut s = BigInt::from_int(0)
  let mut old_t = BigInt::from_int(0)
  let mut t = BigInt::from_int(1)
  while !r.equal(zero) {
    let q = old_r.div(r)
    let nr = old_r.sub(q.mul(r))
    old_r = r
    r = nr
    let ns = old_s.sub(q.mul(s))
    old_s = s
    s = ns
    let nt = old_t.sub(q.mul(t))
    old_t = t
    t = nt
  }
  if old_r < zero {
    (old_r.neg(), old_s.neg(), old_t.neg())
  } else {
    (old_r, old_s, old_t)
  }
}

///|
fn divmod_euclid(a : BigInt, b : BigInt) -> (BigInt, BigInt) {
  let zero = BigInt::from_int(0)
  let mut q = a.div(b)
  let mut r = a.mod(b)
  if r < zero {
    q = q.sub(BigInt::from_int(1))
    r = r.add(b)
  }
  (q, r)
}

///|
fn hnf_bigint(rows : Array[Array[BigInt]]) -> Array[Array[BigInt]] {
  if rows.is_empty() {
    return rows
  }
  let m = rows.length()
  let n = rows[0].length()
  let a = rows.copy()
  let zero = BigInt::from_int(0)
  let mut i = 0
  for j in 0..<n {
    if i >= m {
      break
    }
    let mut pivot = -1
    let mut best = BigInt::from_int(0)
    for r in i..<m {
      let v = a[r][j]
      if !v.equal(zero) {
        let av = abs_bigint(v)
        if pivot == -1 || av < best {
          pivot = r
          best = av
        }
      }
    }
    if pivot < 0 {
      continue
    }
    if pivot != i {
      let tmp = a[i]
      a.set(i, a[pivot])
      a.set(pivot, tmp)
    }
    for k in 0..<m {
      if k == i {
        continue
      }
      let aki = a[k][j]
      if aki.equal(zero) {
        continue
      }
      let aii = a[i][j]
      let (g, s, t) = xgcd(aii, aki)
      let row_i = a[i]
      let row_k = a[k]
      let k_mul_i = aki.neg().div(g)
      let k_mul_k = aii.div(g)
      let new_i = row_linear_comb(row_i, s, row_k, t)
      let new_k = row_linear_comb(row_i, k_mul_i, row_k, k_mul_k)
      a.set(i, new_i)
      a.set(k, new_k)
    }
    if a[i][j] < zero {
      let row = a[i]
      let neg_row : Array[BigInt] = Array::new()
      for v in row {
        neg_row.push(v.neg())
      }
      a.set(i, neg_row)
    }
    let pivot_val = a[i][j]
    for k in 0..<i {
      let v = a[k][j]
      if v.equal(zero) {
        continue
      }
      let (q, _) = divmod_euclid(v, pivot_val)
      if q.equal(zero) {
        continue
      }
      let row_k = a[k]
      let row_i = a[i]
      let new_k : Array[BigInt] = Array::new()
      for c in 0..<n {
        new_k.push(row_k[c].sub(q.mul(row_i[c])))
      }
      a.set(k, new_k)
    }
    i = i + 1
  }
  a
}

///|
/// Integer normal-form compatibility front doors.
///
/// Current Limits:
/// - these front doors currently target `ZZ`-backed dense matrices.
/// - they expose the stable compatibility surface, not every internal helper in
///   the Smith/Hermite implementation.

///|
/// Compute the Hermite normal form of an integer matrix.
///
/// - Does: Returns the row-style Hermite normal form through the dense
///   compatibility layer.
/// - Input: A `DDM` over `ZZ`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError::DomainMismatch` when the matrix is not over
///   `ZZ`.
pub fn DDM::hermite_normal_form(self : DDM) -> DDM raise PolyError {
  let rows = zz_ddm_to_bigint_rows(self)
  bigint_rows_to_zz_ddm(hnf_bigint(rows))
}

///|
/// Return invariant factors of an integer matrix.
///
/// - Does: Computes the invariant factors used by Smith normal form.
/// - Input: A `DDM` over `ZZ`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: Raises `PolyError::DomainMismatch` when the matrix is not over
///   `ZZ`.
pub fn DDM::invariant_factors(self : DDM) -> Array[FieldElem] raise PolyError {
  let rows = zz_ddm_to_bigint_rows(self)
  let (invs, _, _) = smith_bigint_decomp(rows, false)
  bigint_invariants_to_zz_elems(
    smith_adjust_invariants_for_det_sign(self, invs),
  )
}

///|
/// Compute the Smith normal form of an integer matrix.
///
/// - Does: Returns the diagonal Smith normal form matrix.
/// - Input: A `DDM` over `ZZ`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError::DomainMismatch` when the matrix is not over
///   `ZZ`.
pub fn DDM::smith_normal_form(self : DDM) -> DDM raise PolyError {
  let rows = zz_ddm_to_bigint_rows(self)
  let (invs, _, _) = smith_bigint_decomp(rows, false)
  let (row_count, col_count) = self.shape()
  smith_diag_from_invariants(
    smith_adjust_invariants_for_det_sign(self, invs),
    row_count,
    col_count,
  )
}

///|
/// Check whether a matrix is already in Smith normal form.
///
/// - Does: Verifies diagonal shape and divisibility conditions.
/// - Input: A `DDM` over `ZZ`.
/// - Returns: A `Bool`.
/// - Limits: Raises `PolyError::DomainMismatch` when the matrix is not over
///   `ZZ`.
pub fn DDM::is_smith_normal_form(self : DDM) -> Bool raise PolyError {
  let rows = zz_ddm_to_bigint_rows(self)
  if rows.is_empty() {
    return true
  }
  let zero = BigInt::from_int(0)
  let row_count = rows.length()
  let col_count = rows[0].length()
  for i in 0..<row_count {
    for j in 0..<col_count {
      if i != j && !rows[i][j].equal(zero) {
        return false
      }
    }
  }
  let upper = if row_count < col_count { row_count } else { col_count }
  for i in 1..<upper {
    let prev = rows[i - 1][i - 1]
    let cur = rows[i][i]
    if prev.equal(zero) {
      if !cur.equal(zero) {
        return false
      }
    } else if !cur.equal(zero) && !cur.mod(prev).equal(zero) {
      return false
    }
  }
  true
}

///|
/// Compute Smith normal form together with transforms.
///
/// - Does: Returns `(S, U, V)` such that `U * A * V = S`.
/// - Input: A `DDM` over `ZZ`.
/// - Returns: `(DDM, DDM, DDM)`.
/// - Limits: Raises `PolyError::DomainMismatch` when the matrix is not over
///   `ZZ`.
pub fn DDM::smith_normal_decomp(self : DDM) -> (DDM, DDM, DDM) raise PolyError {
  let rows = zz_ddm_to_bigint_rows(self)
  let (invs, s, t) = smith_bigint_decomp(rows, true)
  let (row_count, col_count) = self.shape()
  let adjusted_invs = smith_adjust_invariants_for_det_sign(self, invs)
  let adjusted_s = smith_adjust_left_transform_for_det_sign(self, invs, s)
  (
    smith_diag_from_invariants(adjusted_invs, row_count, col_count),
    bigint_rows_to_zz_ddm(adjusted_s),
    bigint_rows_to_zz_ddm(t),
  )
}

///|
/// Return invariant factors through the `DomainMatrix` front door.
///
/// - Does: Computes invariant factors after converting through `DDM`.
/// - Input: A `DomainMatrix`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: Shares the same integer-domain restrictions as
///   `DDM::invariant_factors`.
pub fn DomainMatrix::invariant_factors(
  self : DomainMatrix,
) -> Array[FieldElem] raise PolyError {
  self.to_ddm().invariant_factors()
}

///|
/// Compute Smith normal form through the `DomainMatrix` front door.
///
/// - Does: Returns the Smith normal form while preserving the outer matrix
///   representation.
/// - Input: A `DomainMatrix`.
/// - Returns: A `DomainMatrix`.
/// - Limits: Shares the same integer-domain restrictions as
///   `DDM::smith_normal_form`.
pub fn DomainMatrix::smith_normal_form(
  self : DomainMatrix,
) -> DomainMatrix raise PolyError {
  restore_rep_like(self.to_ddm().smith_normal_form().to_domain_matrix(), self)
}

///|
/// Check Smith normal form through the `DomainMatrix` front door.
///
/// - Does: Tests whether the matrix already satisfies Smith normal-form
///   conditions.
/// - Input: A `DomainMatrix`.
/// - Returns: A `Bool`.
/// - Limits: Shares the same integer-domain restrictions as
///   `DDM::is_smith_normal_form`.
pub fn DomainMatrix::is_smith_normal_form(
  self : DomainMatrix,
) -> Bool raise PolyError {
  self.to_ddm().is_smith_normal_form()
}

///|
/// Compute Smith normal form and transforms through `DomainMatrix`.
///
/// - Does: Returns `(S, U, V)` while preserving the outer representation of
///   each matrix.
/// - Input: A `DomainMatrix`.
/// - Returns: `(DomainMatrix, DomainMatrix, DomainMatrix)`.
/// - Limits: Shares the same integer-domain restrictions as
///   `DDM::smith_normal_decomp`.
pub fn DomainMatrix::smith_normal_decomp(
  self : DomainMatrix,
) -> (DomainMatrix, DomainMatrix, DomainMatrix) raise PolyError {
  let (smf, s, t) = self.to_ddm().smith_normal_decomp()
  (
    restore_rep_like(smf.to_domain_matrix(), self),
    restore_rep_like(s.to_domain_matrix(), self),
    restore_rep_like(t.to_domain_matrix(), self),
  )
}
