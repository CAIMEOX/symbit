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
pub fn DDM::from_list(
  rows : Array[Array[FieldElem]],
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  let (nrows, ncols) = shape
  if rows.length() != nrows {
    raise PolyError::DomainMismatch
  }
  for row in rows {
    if row.length() != ncols {
      raise PolyError::DomainMismatch
    }
  }
  DDM::{ dm: DomainMatrix::from_list(rows, domain) }
}

///|
pub fn DDM::from_ddm(other : DDM) -> DDM raise PolyError {
  other.copy()
}

///|
pub fn DDM::from_list_flat(
  elements : Array[FieldElem],
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::from_list_flat(elements, shape, domain) }
}

///|
pub fn DDM::from_dod(
  dod : DomainMatrixDOD,
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  let dm = DomainMatrix::from_dod(dod, shape, domain)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
pub fn DDM::from_dok(
  dok : DomainMatrixDOK,
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  let dm = DomainMatrix::from_dok(dok, shape, domain)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
pub fn DDM::zeros(rows : Int, cols : Int, domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::zeros(rows, cols, domain) }
}

///|
pub fn DDM::ones(rows : Int, cols : Int, domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::ones(rows, cols, domain) }
}

///|
pub fn DDM::eye(n : Int, domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::eye(n, domain) }
}

///|
pub fn DDM::diag(
  values : Array[FieldElem],
  domain : Domain,
  rows? : Int? = None,
  cols? : Int? = None,
) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::diag(values, domain, rows=rows, cols=cols) }
}

///|
pub fn DDM::shape(self : DDM) -> (Int, Int) {
  self.dm.shape()
}

///|
pub fn DDM::copy(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.copy() }
}

///|
pub fn DDM::domain(self : DDM) -> Domain {
  self.dm.domain
}

///|
pub fn DDM::convert_to(self : DDM, domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: self.dm.convert_to(domain) }
}

///|
pub fn DDM::to_list(self : DDM) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.to_dense()
}

///|
pub fn DDM::to_list_flat(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.to_list_flat()
}

///|
pub fn DDM::flat(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.flat()
}

///|
pub fn DDM::flatiter(self : DDM) -> Iter[FieldElem] raise PolyError {
  self.flat().iter()
}

///|
pub fn DDM::to_flat_nz(
  self : DDM,
) -> (Array[FieldElem], DomainMatrixFlatNZData) raise PolyError {
  self.dm.to_flat_nz()
}

///|
pub fn DDM::from_flat_nz(
  self : DDM,
  elements : Array[FieldElem],
  data : DomainMatrixFlatNZData,
  domain : Domain,
) -> DDM raise PolyError {
  let dm = self.dm.from_flat_nz(elements, data, domain)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
pub fn DDM::iter_values(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.iter_values()
}

///|
pub fn DDM::iter_items(self : DDM) -> Array[(Int, Int, FieldElem)] raise PolyError {
  self.dm.iter_items()
}

///|
pub fn DDM::to_dod(self : DDM) -> DomainMatrixDOD raise PolyError {
  self.dm.to_dod()
}

///|
pub fn DDM::to_dok(self : DDM) -> DomainMatrixDOK raise PolyError {
  self.dm.to_dok()
}

///|
pub fn DDM::applyfunc(
  self : DDM,
  func : FieldElemMapper,
  domain? : Domain? = None,
) -> DDM raise PolyError {
  let dm = self.dm.applyfunc(func, domain=domain)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
pub fn DDM::to_domain_matrix(self : DDM) -> DomainMatrix {
  self.dm
}

///|
pub fn DDM::getitem(self : DDM, row : Int, col : Int) -> FieldElem raise PolyError {
  self.dm.getitem(row, col).element
}

///|
pub fn DDM::setitem(
  self : DDM,
  row : Int,
  col : Int,
  value : FieldElem,
) -> DDM raise PolyError {
  DDM::{ dm: self.dm.setitem(row, col, value) }
}

///|
pub fn DDM::extract_slice(
  self : DDM,
  row_start? : Int? = None,
  row_stop? : Int? = None,
  row_step? : Int = 1,
  col_start? : Int? = None,
  col_stop? : Int? = None,
  col_step? : Int = 1,
) -> DDM raise PolyError {
  DDM::{
    dm: self.dm.extract_slice(
      row_start=row_start,
      row_stop=row_stop,
      row_step=row_step,
      col_start=col_start,
      col_stop=col_stop,
      col_step=col_step,
    ),
  }
}

///|
pub fn DDM::to_ddm(self : DDM) -> DDM raise PolyError {
  self.copy()
}

///|
pub fn DDM::to_sdm(self : DDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.to_sparse() }
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
  DDM::{ dm: self.dm.neg() }
}

///|
pub fn DDM::mul(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  DDM::{ dm: self.dm.mul(scalar) }
}

///|
pub fn DDM::matmul(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.matmul(other.dm) }
}

///|
pub fn DDM::mul_elementwise(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.mul_elementwise(other.dm) }
}

///|
pub fn DDM::mul_scalar(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  self.mul(scalar)
}

///|
pub fn DDM::rmul(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  DDM::{ dm: self.dm.rmul(scalar) }
}

///|
pub fn DDM::diagonal(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.diagonal()
}

///|
pub fn DDM::extract(
  self : DDM,
  row_ids : Array[Int],
  col_ids : Array[Int],
) -> DDM raise PolyError {
  DDM::{ dm: self.dm.extract(row_ids, col_ids) }
}

///|
pub fn DDM::hstack(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.hstack(other.dm) }
}

///|
pub fn DDM::vstack(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.vstack(other.dm) }
}

///|
pub fn DDM::nnz(self : DDM) -> Int raise PolyError {
  self.dm.nnz()
}

///|
pub fn DDM::is_diagonal(self : DDM) -> Bool raise PolyError {
  self.dm.is_diagonal()
}

///|
pub fn DDM::is_upper(self : DDM) -> Bool raise PolyError {
  self.dm.is_upper()
}

///|
pub fn DDM::is_lower(self : DDM) -> Bool raise PolyError {
  self.dm.is_lower()
}

///|
pub fn DDM::is_zero_matrix(self : DDM) -> Bool raise PolyError {
  self.dm.is_zero_matrix()
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
pub fn DDM::rref_den(
  self : DDM,
  rref_method? : String = "auto",
  keep_domain? : Bool = true,
) -> (DDM, FieldElem, Array[Int]) raise PolyError {
  let (r, den, pivots) = self.dm.rref_den(
    rref_method=rref_method,
    keep_domain=keep_domain,
  )
  (DDM::{ dm: r }, den, pivots)
}

///|
pub fn DDM::rank(self : DDM) -> Int raise PolyError {
  self.dm.rank()
}

///|
pub fn DDM::clear_denoms(
  self : DDM,
  convert? : Bool = false,
) -> (DomainScalar, DDM) raise PolyError {
  let (den, num) = self.dm.clear_denoms(convert~)
  (den, DDM::{ dm: num })
}

///|
pub fn DDM::clear_denoms_rowwise(
  self : DDM,
  convert? : Bool = false,
) -> (DDM, DDM) raise PolyError {
  let (den, num) = self.dm.clear_denoms_rowwise(convert~)
  (DDM::{ dm: den }, DDM::{ dm: num })
}

///|
pub fn DDM::adj_det(self : DDM) -> (DDM, FieldElem) raise PolyError {
  let (adj, det) = self.dm.adj_det()
  (DDM::{ dm: adj }, det)
}

///|
pub fn DDM::adjugate(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.adjugate() }
}

///|
pub fn DDM::inv_den(
  self : DDM,
  solve_method? : String = "",
) -> (DDM, FieldElem) raise PolyError {
  let (num, den) = self.dm.inv_den(solve_method=solve_method)
  (DDM::{ dm: num }, den)
}

///|
pub fn DDM::solve_den(
  self : DDM,
  rhs : DDM,
  solve_method? : String = "",
) -> (DDM, FieldElem) raise PolyError {
  let (num, den) = self.dm.solve_den(rhs.dm, solve_method=solve_method)
  (DDM::{ dm: num }, den)
}

///|
pub fn DDM::solve_den_rref(
  self : DDM,
  rhs : DDM,
) -> (DDM, FieldElem) raise PolyError {
  let (num, den) = self.dm.solve_den_rref(rhs.dm)
  (DDM::{ dm: num }, den)
}

///|
pub fn DDM::lu(self : DDM) -> (DDM, DDM, Array[(Int, Int)]) raise PolyError {
  let (l, u, swaps) = self.dm.lu()
  (DDM::{ dm: l }, DDM::{ dm: u }, swaps)
}

///|
pub fn DDM::qr(self : DDM) -> (DDM, DDM) raise PolyError {
  let (q, r) = self.dm.qr()
  (DDM::{ dm: q }, DDM::{ dm: r })
}

///|
pub fn DDM::lu_solve(self : DDM, rhs : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.lu_solve(rhs.dm) }
}

///|
pub fn DDM::fflu(self : DDM) -> (DDM, DDM, DDM, DDM) raise PolyError {
  let (p, l, d, u) = self.dm.fflu()
  (DDM::{ dm: p }, DDM::{ dm: l }, DDM::{ dm: d }, DDM::{ dm: u })
}

///|
pub fn DDM::charpoly(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.charpoly()
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
pub fn DDM::nullspace(
  self : DDM,
  divide_last? : Bool = false,
) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.nullspace(divide_last=divide_last).to_dense()
}

///|
pub fn DDM::nullspace_from_rref(
  self : DDM,
  pivots? : Array[Int] = [],
) -> (DDM, Array[Int]) raise PolyError {
  let (basis, nonpivots) = nullspace_from_rref_with_nonpivots(self.dm, pivots~)
  (DDM::{ dm: basis }, nonpivots)
}

///|
pub fn DDM::particular(
  self : DDM,
  pivots? : Array[Int] = [],
) -> DDM raise PolyError {
  DDM::{ dm: particular_from_rref(self.dm, pivots~) }
}

///|
pub fn DDM::scc(self : DDM) -> Array[Array[Int]] raise PolyError {
  self.dm.scc()
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
