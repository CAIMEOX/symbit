///|
fn zz_ddm_to_bigint_rows(ddm : DDM) -> Array[Array[BigInt]] raise PolyError {
  match ddm.domain() {
    Domain::ZZ => ()
    _ => raise PolyError::DomainMismatch
  }
  let rows = ddm.to_list()
  let out : Array[Array[BigInt]] = Array::new()
  for row in rows {
    let out_row : Array[BigInt] = Array::new()
    for v in row {
      let q = fe_expect_rational(v)
      if !q.denominator().equal_int(1) {
        raise PolyError::DomainMismatch
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
      out_row.push(fe_from_rational(@symnum.BigRational::from_bigint(v), Domain::ZZ))
    }
    out.push(out_row)
  }
  ddm_from_dense(out, Domain::ZZ)
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
  if x.op_lt(BigInt::from_int(0)) {
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
  if old_r.op_lt(zero) {
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
  if r.op_lt(zero) {
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
        if pivot == -1 || av.op_lt(best) {
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
    if a[i][j].op_lt(zero) {
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
/// Compute a row-style Hermite normal form for integer matrices.
pub fn DDM::hermite_normal_form(self : DDM) -> DDM raise PolyError {
  let rows = zz_ddm_to_bigint_rows(self)
  bigint_rows_to_zz_ddm(hnf_bigint(rows))
}
