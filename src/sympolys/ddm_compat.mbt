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
