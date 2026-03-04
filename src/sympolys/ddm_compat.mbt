///|
/// Dense Domain Matrix (`DDM`) compatibility layer.
pub struct DDM {
  dm : DomainMatrix
}

///|
pub fn ddm_from_dense(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: domain_matrix_from_dense(rows, domain) }
}

///|
pub fn ddm_from_ints(rows : Array[Array[Int]], domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: domain_matrix_from_ints(rows, domain) }
}

///|
pub fn DDM::shape(self : DDM) -> (Int, Int) {
  self.dm.shape()
}

///|
pub fn DDM::domain(self : DDM) -> Domain {
  self.dm.domain
}

///|
pub fn DDM::to_list(self : DDM) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.to_dense()
}

///|
pub fn DDM::to_domain_matrix(self : DDM) -> DomainMatrix {
  self.dm
}

///|
pub fn DDM::transpose(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.transpose() }
}

///|
pub fn DDM::add(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.add(other.dm) }
}

///|
pub fn DDM::sub(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.sub(other.dm) }
}

///|
pub fn DDM::neg(self : DDM) -> DDM raise PolyError {
  let rows = self.dm.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    out.push(row.map(x => fe_neg(x)))
  }
  ddm_from_dense(out, self.dm.domain)
}

///|
pub fn DDM::mul(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.mul(other.dm) }
}

///|
pub fn DDM::mul_scalar(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  let rows = self.dm.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    out.push(row.map(x => fe_mul(x, scalar)))
  }
  ddm_from_dense(out, self.dm.domain)
}

///|
pub fn DDM::det(self : DDM) -> FieldElem raise PolyError {
  self.dm.det()
}

///|
pub fn DDM::rref(self : DDM) -> (DDM, Array[Int]) raise PolyError {
  let (r, pivots) = self.dm.rref()
  (DDM::{ dm: r }, pivots)
}

///|
pub fn DDM::rank(self : DDM) -> Int raise PolyError {
  let (_, pivots) = self.rref()
  pivots.length()
}

///|
pub fn DDM::inv(self : DDM) -> DDM raise PolyError {
  let (m, n) = self.shape()
  if m != n {
    raise PolyError::DomainMismatch
  }
  let one = fe_from_int(1, self.dm.domain)
  let zero = fe_from_int(0, self.dm.domain)
  let left = self.dm.to_dense()
  let aug_rows : Array[Array[FieldElem]] = Array::new()
  for i in 0..<m {
    let row = left[i].copy()
    for j in 0..<n {
      row.push(if i == j { one } else { zero })
    }
    aug_rows.push(row)
  }
  let aug = domain_matrix_from_dense(aug_rows, self.dm.domain)
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
  ddm_from_dense(inv_rows, self.dm.domain)
}

///|
pub fn DDM::nullspace(self : DDM) -> Array[Array[FieldElem]] raise PolyError {
  let (m, n) = self.shape()
  let (r, pivots) = self.rref()
  let rows = r.to_list()
  let pivot_set : Map[Int, Bool] = {}
  for p in pivots {
    pivot_set[p] = true
  }
  let free_cols : Array[Int] = Array::new()
  for j in 0..<n {
    if pivot_set.get(j) is None {
      free_cols.push(j)
    }
  }
  if free_cols.is_empty() {
    return []
  }
  let one = fe_from_int(1, self.dm.domain)
  let zero = fe_from_int(0, self.dm.domain)
  let basis : Array[Array[FieldElem]] = Array::new()
  for free in free_cols {
    let vec : Array[FieldElem] = Array::make(n, zero)
    vec.set(free, one)
    for i in 0..<pivots.length() {
      let p = pivots[i]
      if i < m {
        vec.set(p, fe_neg(rows[i][free]))
      }
    }
    basis.push(vec)
  }
  basis
}

///|
pub fn DDM::to_string(self : DDM) -> String raise PolyError {
  let rows = self.to_list()
  let row_parts : Array[String] = Array::new()
  for row in rows {
    let row_text = row.map(fe_to_string).join(", ")
    row_parts.push("[\{row_text}]")
  }
  let matrix_text = row_parts.join(", ")
  "[\{matrix_text}]"
}
