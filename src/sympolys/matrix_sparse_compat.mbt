///|
fn sdm_nonzero_columns(
  rref : SDM,
  pivots : Array[Int],
) -> Map[Int, Array[Int]] raise PolyError {
  let pivot_set : Map[Int, Bool] = Map::new()
  for pivot in pivots {
    pivot_set[pivot] = true
  }
  let out : Map[Int, Array[Int]] = Map::new()
  let dod = rref.to_dod()
  for row_index, row in dod {
    for col, value in row {
      if pivot_set.get(col) is Some(_) || fe_is_zero(value) {
        continue
      }
      match out.get(col) {
        Some(rows) => rows.push(row_index)
        None => out[col] = [row_index]
      }
    }
  }
  out
}

///|
/// Functional wrapper for SymPy `polys.matrices.sdm.sdm_irref`.
pub fn sdm_irref(
  a : SDM,
) -> (SDM, Array[Int], Map[Int, Array[Int]]) raise PolyError {
  let (rref, pivots) = a.rref()
  (rref, pivots, sdm_nonzero_columns(rref, pivots))
}

///|
fn sorted_sparse_cols(row : Map[Int, FieldElem]) -> Array[Int] {
  let cols : Array[Int] = Array::new()
  for col, _ in row {
    cols.push(col)
  }
  cols.sort()
  cols
}

///|
fn clone_sparse_row(row : Map[Int, FieldElem]) -> Map[Int, FieldElem] {
  let out : Map[Int, FieldElem] = Map::new()
  for col, value in row {
    out[col] = value
  }
  out
}

///|
fn sparse_row_addmul(
  acc : Map[Int, FieldElem],
  col : Int,
  value : FieldElem,
) -> Unit raise PolyError {
  match acc.get(col) {
    Some(prev) => {
      let next = fe_add(prev, value)
      if fe_is_zero(next) {
        ignore(acc.remove(col))
      } else {
        acc[col] = next
      }
    }
    None => if !fe_is_zero(value) { acc[col] = value }
  }
}

///|
fn sparse_row_lead(row : Map[Int, FieldElem]) -> Int {
  let cols = sorted_sparse_cols(row)
  if cols.is_empty() {
    abort("sparse_row_lead: empty row")
  }
  cols[0]
}

///|
fn sparse_row_scale_exquo(
  row : Map[Int, FieldElem],
  scale : FieldElem,
  divisor : FieldElem?,
  domain : Domain,
) -> Unit raise PolyError {
  let cols = sorted_sparse_cols(row)
  for col in cols {
    let mut value = fe_mul(row[col], scale)
    match divisor {
      Some(prev) => value = fe_exact_div_in_domain(value, prev, domain)
      None => ()
    }
    if fe_is_zero(value) {
      ignore(row.remove(col))
    } else {
      row[col] = value
    }
  }
}

///|
fn sparse_rref_row_order(rows : DomainMatrixDOD) -> Array[Map[Int, FieldElem]] {
  let indexed : Array[(Int, Map[Int, FieldElem])] = Array::new()
  for row_index, row in rows {
    indexed.push((row_index, clone_sparse_row(row)))
  }
  indexed.sort_by(fn(lhs, rhs) { lhs.0.compare(rhs.0) })
  let out : Array[Map[Int, FieldElem]] = Array::new()
  for item in indexed {
    out.push(item.1)
  }
  out
}

///|
fn sorted_sparse_index_keys(values : Map[Int, Int]) -> Array[Int] {
  let cols : Array[Int] = Array::new()
  for col, _ in values {
    cols.push(col)
  }
  cols.sort()
  cols
}

///|
fn sdm_rref_den(a : SDM) -> (SDM, FieldElem, Array[Int]) raise PolyError {
  let domain = a.domain()
  let shape = a.shape()
  let rows = a.to_dod()
  let one = fe_from_int(1, domain)
  if rows.is_empty() {
    return (a.copy(), one, [])
  }
  if rows.length() == 1 {
    let rows_in_order = sparse_rref_row_order(rows)
    let row = clone_sparse_row(rows_in_order[0])
    let pivot_col = sparse_row_lead(row)
    let pivot = row[pivot_col]
    let dod : DomainMatrixDOD = Map::new()
    dod[0] = row
    return (SDM::new(dod, shape, domain), pivot, [pivot_col])
  }

  let col_to_row_reduced : Map[Int, Int] = Map::new()
  let col_to_row_unreduced : Map[Int, Int] = Map::new()
  let rref_rows : Array[Map[Int, FieldElem]] = Array::new()
  let mut denom : FieldElem? = None
  let mut divisor : FieldElem? = None

  let work_rows = sparse_rref_row_order(rows)
  work_rows.sort_by(fn(lhs, rhs) {
    sparse_row_lead(lhs).compare(sparse_row_lead(rhs))
  })

  for input_row in work_rows {
    let ai : Map[Int, FieldElem] = Map::new()
    for col, value in input_row {
      if col_to_row_reduced.get(col) is None {
        ai[col] = value
      }
    }

    let ai_cancel : Map[Int, FieldElem] = Map::new()
    let ai_cols = sorted_sparse_cols(ai)
    for col in ai_cols {
      match col_to_row_unreduced.get(col) {
        Some(row_index) => {
          let aij = ai[col]
          ignore(ai.remove(col))
          let aj = rref_rows[row_index]
          for k, ajk in aj {
            sparse_row_addmul(ai_cancel, k, fe_mul(aij, ajk))
          }
        }
        None => ()
      }
    }

    let d = match denom {
      Some(value) => value
      None => one
    }
    let ai_nz = sorted_sparse_cols(ai)
    let ai_cancel_nz = sorted_sparse_cols(ai_cancel)
    let ai_nz_set : Map[Int, Bool] = Map::new()
    let ai_cancel_set : Map[Int, Bool] = Map::new()
    for col in ai_nz {
      ai_nz_set[col] = true
    }
    for col in ai_cancel_nz {
      ai_cancel_set[col] = true
    }
    for col in ai_cancel_nz {
      if ai_nz_set.get(col) is None {
        ai[col] = fe_neg(ai_cancel[col])
      }
    }
    for col in ai_nz {
      if ai_cancel_set.get(col) is None {
        ai[col] = fe_mul(ai[col], d)
      }
    }
    for col in ai_nz {
      if ai_cancel_set.get(col) is Some(_) {
        let value = fe_sub(fe_mul(ai[col], d), ai_cancel[col])
        if fe_is_zero(value) {
          ignore(ai.remove(col))
        } else {
          ai[col] = value
        }
      }
    }

    if ai.is_empty() {
      continue
    }

    let pivot_col = sparse_row_lead(ai)
    let pivot = ai[pivot_col]
    ignore(ai.remove(pivot_col))

    let unreduced_cols = sorted_sparse_index_keys(col_to_row_unreduced)
    for old_pivot in unreduced_cols {
      let row_index = col_to_row_unreduced[old_pivot]
      let ak = rref_rows[row_index]
      if ak.get(pivot_col) is None {
        sparse_row_scale_exquo(ak, pivot, divisor, domain)
        continue
      }

      let akj = ak[pivot_col]
      ignore(ak.remove(pivot_col))
      let ai_keys = sorted_sparse_cols(ai)
      let ak_keys = sorted_sparse_cols(ak)
      let ai_key_set : Map[Int, Bool] = Map::new()
      let ak_key_set : Map[Int, Bool] = Map::new()
      for col in ai_keys {
        ai_key_set[col] = true
      }
      for col in ak_keys {
        ak_key_set[col] = true
      }

      for col in ai_keys {
        if ak_key_set.get(col) is None {
          let mut value = fe_neg(fe_mul(akj, ai[col]))
          match divisor {
            Some(prev) => value = fe_exact_div_in_domain(value, prev, domain)
            None => ()
          }
          if !fe_is_zero(value) {
            ak[col] = value
          }
        }
      }

      for col in ak_keys {
        if ai_key_set.get(col) is None {
          let mut value = fe_mul(pivot, ak[col])
          match divisor {
            Some(prev) => value = fe_exact_div_in_domain(value, prev, domain)
            None => ()
          }
          if fe_is_zero(value) {
            ignore(ak.remove(col))
          } else {
            ak[col] = value
          }
        }
      }

      for col in ak_keys {
        if ai_key_set.get(col) is Some(_) {
          let mut value = fe_sub(fe_mul(pivot, ak[col]), fe_mul(akj, ai[col]))
          if fe_is_zero(value) {
            ignore(ak.remove(col))
            continue
          }
          match divisor {
            Some(prev) => value = fe_exact_div_in_domain(value, prev, domain)
            None => ()
          }
          if fe_is_zero(value) {
            ignore(ak.remove(col))
          } else {
            ak[col] = value
          }
        }
      }

      if ak.is_empty() {
        ignore(col_to_row_unreduced.remove(old_pivot))
        col_to_row_reduced[old_pivot] = row_index
      }
    }

    let row_index = rref_rows.length()
    rref_rows.push(ai)
    if ai.is_empty() {
      col_to_row_reduced[pivot_col] = row_index
    } else {
      col_to_row_unreduced[pivot_col] = row_index
    }

    if !fe_is_one(pivot) {
      denom = match denom {
        Some(value) => Some(fe_mul(value, pivot))
        None => Some(pivot)
      }
    }
    match divisor {
      Some(prev) =>
        denom = Some(
          fe_exact_div_in_domain(
            match denom {
              Some(value) => value
              None => one
            },
            prev,
            domain,
          ),
        )
      None => ()
    }
    divisor = denom
  }

  let final_denom = match denom {
    Some(value) => value
    None => one
  }
  let row_to_col : Map[Int, Int] = Map::new()
  for col, row_index in col_to_row_reduced {
    row_to_col[row_index] = col
  }
  for col, row_index in col_to_row_unreduced {
    row_to_col[row_index] = col
  }
  let ordered : Array[(Int, Map[Int, FieldElem])] = Array::new()
  for i in 0..<rref_rows.length() {
    ordered.push((row_to_col[i], clone_sparse_row(rref_rows[i])))
  }
  ordered.sort_by(fn(lhs, rhs) { lhs.0.compare(rhs.0) })
  let pivots : Array[Int] = Array::new()
  let dod : DomainMatrixDOD = Map::new()
  for i in 0..<ordered.length() {
    let pivot_col = ordered[i].0
    let row = ordered[i].1
    row[pivot_col] = final_denom
    pivots.push(pivot_col)
    if !row.is_empty() {
      dod[i] = row
    }
  }
  (SDM::new(dod, shape, domain), final_denom, pivots)
}

///|
fn sparse_dotvec(
  left : Map[Int, FieldElem],
  right : Map[Int, FieldElem],
  domain : Domain,
) -> FieldElem raise PolyError {
  let mut total = fe_from_int(0, domain)
  let cols = sorted_sparse_cols(left)
  for col in cols {
    match right.get(col) {
      Some(value) => total = fe_add(total, fe_mul(left[col], value))
      None => ()
    }
  }
  total
}

///|
fn sparse_matvecmul(
  matrix : DomainMatrixDOD,
  vec : Map[Int, FieldElem],
  domain : Domain,
) -> Map[Int, FieldElem] raise PolyError {
  let out : Map[Int, FieldElem] = Map::new()
  for row, values in matrix {
    let total = sparse_dotvec(values, vec, domain)
    if !fe_is_zero(total) {
      out[row] = total
    }
  }
  out
}

///|
fn sparse_berk_map(
  matrix : DomainMatrixDOD,
  n : Int,
  domain : Domain,
) -> Map[Int, FieldElem] raise PolyError {
  let zero = fe_from_int(0, domain)
  let one = fe_from_int(1, domain)

  if n == 0 {
    let out : Map[Int, FieldElem] = Map::new()
    out[0] = one
    return out
  }
  if n == 1 {
    let out : Map[Int, FieldElem] = Map::new()
    out[0] = one
    let a00 = match matrix.get(0) {
      Some(row) =>
        match row.get(0) {
          Some(value) => value
          None => zero
        }
      None => zero
    }
    if !fe_is_zero(a00) {
      out[1] = fe_neg(a00)
    }
    return out
  }

  let mut a = zero
  let r : Map[Int, FieldElem] = Map::new()
  let c : Map[Int, FieldElem] = Map::new()
  let minor : DomainMatrixDOD = Map::new()
  for i, row in matrix {
    for j, value in row {
      if i > 0 && j > 0 {
        match minor.get(i - 1) {
          Some(existing) => existing[j - 1] = value
          None => {
            let new_row : Map[Int, FieldElem] = Map::new()
            new_row[j - 1] = value
            minor[i - 1] = new_row
          }
        }
      } else if i > 0 {
        c[i - 1] = value
      } else if j > 0 {
        r[j - 1] = value
      } else {
        a = value
      }
    }
  }

  let mut an_c = c
  let rc = sparse_dotvec(r, c, domain)
  let tvals : Array[FieldElem] = [one, fe_neg(a), fe_neg(rc)]
  for _ in 3..<=n {
    an_c = sparse_matvecmul(minor, an_c, domain)
    if an_c.is_empty() {
      break
    }
    let ran_c = sparse_dotvec(r, an_c, domain)
    tvals.push(fe_neg(ran_c))
  }
  while !tvals.is_empty() && fe_is_zero(tvals[tvals.length() - 1]) {
    ignore(tvals.pop())
  }

  let q = sparse_berk_map(minor, n - 1, domain)
  let reversed : Array[FieldElem] = Array::new()
  for i in 0..<tvals.length() {
    reversed.push(tvals[tvals.length() - 1 - i])
  }

  let q_keys : Array[Int] = Array::new()
  for key, _ in q {
    q_keys.push(key)
  }
  q_keys.sort()
  if q_keys.is_empty() {
    return Map::new()
  }
  let min_q = q_keys[0]
  let max_q = q_keys[q_keys.length() - 1]
  let limit = if max_q + reversed.length() < n + 1 {
    max_q + reversed.length()
  } else {
    n + 1
  }
  let out : Map[Int, FieldElem] = Map::new()
  for i in min_q..<limit {
    let row : Map[Int, FieldElem] = Map::new()
    let start = i - reversed.length() + 1
    for offset in 0..<reversed.length() {
      row[start + offset] = reversed[offset]
    }
    let total = sparse_dotvec(row, q, domain)
    if !fe_is_zero(total) {
      out[i] = total
    }
  }
  out
}

///|
fn sparse_berk(
  matrix : DomainMatrixDOD,
  n : Int,
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  let coeffs : Array[FieldElem] = Array::make(n + 1, fe_from_int(0, domain))
  let pdict = sparse_berk_map(matrix, n, domain)
  for i, value in pdict {
    coeffs[i] = value
  }
  coeffs
}

///|
/// Build nullspace basis vectors from sparse RREF data.
pub fn sdm_nullspace_from_rref(
  a : SDM,
  one : FieldElem,
  ncols : Int,
  pivots : Array[Int],
  nonzero_cols : Map[Int, Array[Int]],
) -> (SDM, Array[Int]) raise PolyError {
  let _ = one
  let _ = nonzero_cols
  let (rows, cols) = a.shape()
  if cols < ncols {
    raise PolyError::DomainMismatch
  }
  let work = if cols == ncols {
    a
  } else {
    let row_ids : Array[Int] = Array::new()
    for i in 0..<rows {
      row_ids.push(i)
    }
    let col_ids : Array[Int] = Array::new()
    for j in 0..<ncols {
      col_ids.push(j)
    }
    a.extract(row_ids, col_ids)
  }
  let left_pivots : Array[Int] = Array::new()
  for pivot in pivots {
    if pivot < ncols {
      left_pivots.push(pivot)
    }
  }
  work.nullspace_from_rref(pivots=left_pivots)
}

///|
/// Extract a particular solution vector from sparse RREF data.
pub fn sdm_particular_from_rref(
  a : SDM,
  ncols : Int,
  pivots : Array[Int],
) -> SDM raise PolyError {
  if a.shape().1 != ncols {
    raise PolyError::DomainMismatch
  }
  a.particular(pivots~)
}
