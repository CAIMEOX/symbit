///|
/// Sparse domain-matrix compatibility front doors.
///
/// Current Limits:
/// - this file is a wrapper layer around sparse `DomainMatrix` storage, not a
///   separate sparse engine.
/// - some conversions normalize through `DomainMatrix` before returning sparse
///   output.

///|
/// Sparse domain-matrix wrapper used by matrix-related polynomial APIs.
///
/// - Does: Exposes sparse matrix entry points over `FieldElem` values.
/// - Input: Built from the constructors in this file.
/// - Returns: An `SDM`.
/// - Limits: Semantics follow the sparse compatibility layer rather than a full
///   standalone sparse-matrix hierarchy.
pub struct SDM {
  dm : DomainMatrix
}

///|
/// Build a sparse matrix from `(row, col, value)` entries.
///
/// - Does: Creates a sparse matrix of the requested shape and domain.
/// - Input: Row count, column count, sparse entries, and domain.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the sparse data is invalid for the shape.
pub fn sdm_from_entries(
  rows : Int,
  cols : Int,
  entries : Array[(Int, Int, FieldElem)],
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: domain_matrix_from_sparse(rows, cols, entries, domain) }
}

///|
/// Build a sparse matrix from dense rows.
///
/// - Does: Converts dense row data into sparse storage.
/// - Input: `Array[Array[FieldElem]]` and a `Domain`.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the rows cannot form a valid dense matrix.
pub fn sdm_from_dense(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: domain_matrix_from_dense(rows, domain).to_sparse() }
}

///|
/// Build a sparse matrix from dictionary-of-dictionaries storage.
///
/// - Does: Creates an `SDM` from sparse keyed rows and an explicit shape.
/// - Input: `DomainMatrixDOD`, shape, and domain.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the sparse data is invalid for the shape.
pub fn SDM::new(
  dod : DomainMatrixDOD,
  shape : (Int, Int),
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::from_dod(dod, shape, domain).to_sparse() }
}

///|
/// Build a sparse matrix from dense rows and an explicit shape.
///
/// - Does: Validates the shape and converts the rows into sparse storage.
/// - Input: Dense rows, shape, and domain.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError::DomainMismatch` when row sizes do not match the
///   requested shape.
pub fn SDM::from_list(
  rows : Array[Array[FieldElem]],
  shape : (Int, Int),
  domain : Domain,
) -> SDM raise PolyError {
  let (nrows, ncols) = shape
  if rows.length() != nrows {
    raise PolyError::DomainMismatch
  }
  for row in rows {
    if row.length() != ncols {
      raise PolyError::DomainMismatch
    }
  }
  SDM::{ dm: DomainMatrix::from_list(rows, domain).to_sparse() }
}

///|
/// Build a sparse matrix from a dense-domain matrix.
///
/// - Does: Converts a `DDM` into sparse storage.
/// - Input: A `DDM`.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` only if the dense view cannot be converted.
pub fn SDM::from_ddm(other : DDM) -> SDM raise PolyError {
  SDM::{ dm: other.to_domain_matrix().to_sparse() }
}

///|

///|
/// Public API `SDM.from_list_flat`.
///
/// - Does: Provides the `SDM.from_list_flat` operation for sparse domain-matrix compatibility.
/// - Input: parameters `elements : Array[FieldElem]`, `shape : (Int, Int)`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::from_list_flat(
  elements : Array[FieldElem],
  shape : (Int, Int),
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::from_list_flat(elements, shape, domain).to_sparse() }
}

///|

///|
/// Public API `SDM.from_dod`.
///
/// - Does: Provides the `SDM.from_dod` operation for sparse domain-matrix compatibility.
/// - Input: parameters `dod : DomainMatrixDOD`, `shape : (Int, Int)`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::from_dod(
  dod : DomainMatrixDOD,
  shape : (Int, Int),
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::from_dod(dod, shape, domain).to_sparse() }
}

///|

///|
/// Public API `SDM.from_dok`.
///
/// - Does: Provides the `SDM.from_dok` operation for sparse domain-matrix compatibility.
/// - Input: parameters `dok : DomainMatrixDOK`, `shape : (Int, Int)`, `domain :
/// Domain`, using the package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::from_dok(
  dok : DomainMatrixDOK,
  shape : (Int, Int),
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::from_dok(dok, shape, domain).to_sparse() }
}

///|
/// Build a zero sparse matrix.
///
/// - Does: Creates a sparse zero matrix of the requested shape.
/// - Input: Row count, column count, and domain.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the matrix cannot be created.
pub fn SDM::zeros(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::zeros(rows, cols, domain).to_sparse() }
}

///|

///|
/// Public API `SDM.ones`.
///
/// - Does: Provides the `SDM.ones` operation for sparse domain-matrix compatibility.
/// - Input: parameters `rows : Int`, `cols : Int`, `domain : Domain`, using the package
/// representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::ones(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::ones(rows, cols, domain).to_sparse() }
}

///|
/// Build a sparse identity matrix.
///
/// - Does: Creates the square identity matrix in sparse storage.
/// - Input: Matrix size and domain.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the matrix cannot be created.
pub fn SDM::eye(n : Int, domain : Domain) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::eye(n, domain).to_sparse() }
}

///|

///|
/// Public API `SDM.diag`.
///
/// - Does: Provides the `SDM.diag` operation for sparse domain-matrix compatibility.
/// - Input: parameters `values : Array[FieldElem]`, `domain : Domain`, `rows : Int =
/// None`, `cols : Int = None`, using the package representation expected by the
/// signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::diag(
  values : Array[FieldElem],
  domain : Domain,
  rows? : Int? = None,
  cols? : Int? = None,
) -> SDM raise PolyError {
  SDM::{ dm: DomainMatrix::diag(values, domain, rows~, cols~).to_sparse() }
}

///|

///|
/// Public API `SDM.copy`.
///
/// - Does: Provides the `SDM.copy` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::copy(self : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.copy().to_sparse() }
}

///|
/// Return the sparse matrix shape.
///
/// - Does: Exposes the stored matrix dimensions.
/// - Input: An `SDM`.
/// - Returns: `(rows, cols)`.
/// - Limits: This reports the stored shape only.
pub fn SDM::shape(self : SDM) -> (Int, Int) {
  self.dm.shape()
}

///|
/// Return the coefficient domain.
///
/// - Does: Exposes the ground domain attached to the matrix entries.
/// - Input: An `SDM`.
/// - Returns: A `Domain`.
/// - Limits: This does not inspect or normalize the entries.
pub fn SDM::domain(self : SDM) -> Domain {
  self.dm.domain
}

///|
/// Convert entries into another coefficient domain.
///
/// - Does: Coerces every stored entry into the requested target domain.
/// - Input: An `SDM` and target `Domain`.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when an entry cannot be converted.
pub fn SDM::convert_to(self : SDM, domain : Domain) -> SDM raise PolyError {
  SDM::{ dm: self.dm.convert_to(domain).to_sparse() }
}

///|
/// Convert sparse storage to a dense matrix.
///
/// - Does: Expands the sparse entries into a `DDM`.
/// - Input: An `SDM`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the sparse storage cannot be expanded.
pub fn SDM::to_dense(self : SDM) -> DDM raise PolyError {
  let rows = self.dm.to_dense()
  DDM::{ dm: domain_matrix_from_dense(rows, self.dm.domain) }
}

///|

///|
/// Public API `SDM.to_ddm`.
///
/// - Does: Provides the `SDM.to_ddm` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_ddm(self : SDM) -> DDM raise PolyError {
  self.to_dense()
}

///|

///|
/// Public API `SDM.to_dfm`.
///
/// - Does: Provides the `SDM.to_dfm` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_dfm(self : SDM) -> DDM raise PolyError {
  self.to_ddm()
}

///|

///|
/// Public API `SDM.to_dfm_or_ddm`.
///
/// - Does: Provides the `SDM.to_dfm_or_ddm` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_dfm_or_ddm(self : SDM) -> DDM raise PolyError {
  self.to_ddm()
}

///|

///|
/// Public API `SDM.to_sdm`.
///
/// - Does: Provides the `SDM.to_sdm` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_sdm(self : SDM) -> SDM raise PolyError {
  self.copy()
}

///|
/// Return the underlying `DomainMatrix`.
///
/// - Does: Exposes the sparse `DomainMatrix` wrapper.
/// - Input: An `SDM`.
/// - Returns: A `DomainMatrix`.
/// - Limits: This is a structural view change only.
pub fn SDM::to_domain_matrix(self : SDM) -> DomainMatrix {
  self.dm
}

///|

///|
/// Public API `SDM.to_list`.
///
/// - Does: Provides the `SDM.to_list` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[Array[FieldElem]]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_list(self : SDM) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.to_list()
}

///|

///|
/// Public API `SDM.to_list_flat`.
///
/// - Does: Provides the `SDM.to_list_flat` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_list_flat(self : SDM) -> Array[FieldElem] raise PolyError {
  self.dm.to_list_flat()
}

///|

///|
/// Public API `SDM.flat`.
///
/// - Does: Provides the `SDM.flat` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::flat(self : SDM) -> Array[FieldElem] raise PolyError {
  self.dm.flat()
}

///|

///|
/// Public API `SDM.to_flat_nz`.
///
/// - Does: Provides the `SDM.to_flat_nz` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `) -> (Array[FieldElem]`,
/// `DomainMatrixFlatNZData`, using the package representation expected by the
/// signature.
/// - Returns: a `(Array[FieldElem], DomainMatrixFlatNZData)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_flat_nz(
  self : SDM,
) -> (Array[FieldElem], DomainMatrixFlatNZData) raise PolyError {
  self.dm.to_flat_nz()
}

///|

///|
/// Public API `SDM.from_flat_nz`.
///
/// - Does: Provides the `SDM.from_flat_nz` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `elements : Array[FieldElem]`, `data :
/// DomainMatrixFlatNZData`, `domain : Domain`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::from_flat_nz(
  self : SDM,
  elements : Array[FieldElem],
  data : DomainMatrixFlatNZData,
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: self.dm.from_flat_nz(elements, data, domain).to_sparse() }
}

///|

///|
/// Public API `SDM.iter_values`.
///
/// - Does: Provides the `SDM.iter_values` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::iter_values(self : SDM) -> Array[FieldElem] raise PolyError {
  self.dm.iter_values()
}

///|

///|
/// Public API `SDM.iter_items`.
///
/// - Does: Provides the `SDM.iter_items` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `) -> Array[(Int, Int, FieldElem`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[(Int, Int, FieldElem)]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::iter_items(
  self : SDM,
) -> Array[(Int, Int, FieldElem)] raise PolyError {
  self.dm.iter_items()
}

///|

///|
/// Public API `SDM.to_dod`.
///
/// - Does: Provides the `SDM.to_dod` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DomainMatrixDOD` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_dod(self : SDM) -> DomainMatrixDOD raise PolyError {
  self.dm.to_dod()
}

///|

///|
/// Public API `SDM.to_dok`.
///
/// - Does: Provides the `SDM.to_dok` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DomainMatrixDOK` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_dok(self : SDM) -> DomainMatrixDOK raise PolyError {
  self.dm.to_dok()
}

///|

///|
/// Public API `SDM.to_sparse_entries`.
///
/// - Does: Provides the `SDM.to_sparse_entries` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `) -> Array[(Int, Int, FieldElem`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[(Int, Int, FieldElem)]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::to_sparse_entries(
  self : SDM,
) -> Array[(Int, Int, FieldElem)] raise PolyError {
  let rows = self.dm.to_dense()
  let entries : Array[(Int, Int, FieldElem)] = Array::new()
  for i in 0..<self.dm.rows {
    for j in 0..<self.dm.cols {
      let v = rows[i][j]
      if !fe_is_zero(v) {
        entries.push((i, j, v))
      }
    }
  }
  entries
}

///|

///|
/// Public API `SDM.getitem`.
///
/// - Does: Provides the `SDM.getitem` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `row : Int`, `col : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::getitem(
  self : SDM,
  row : Int,
  col : Int,
) -> FieldElem raise PolyError {
  self.dm.getitem(row, col).element
}

///|

///|
/// Public API `SDM.setitem`.
///
/// - Does: Provides the `SDM.setitem` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `row : Int`, `col : Int`, `value : FieldElem`,
/// using the package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::setitem(
  self : SDM,
  row : Int,
  col : Int,
  value : FieldElem,
) -> SDM raise PolyError {
  SDM::{ dm: self.dm.setitem(row, col, value).to_sparse() }
}

///|

///|
/// Public API `SDM.extract_slice`.
///
/// - Does: Provides the `SDM.extract_slice` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `row_start : Int = None`, `row_stop : Int = None`,
/// `row_step : Int = 1`, `col_start : Int = None` and 2 more parameter(s), using the
/// package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::extract_slice(
  self : SDM,
  row_start? : Int? = None,
  row_stop? : Int? = None,
  row_step? : Int = 1,
  col_start? : Int? = None,
  col_stop? : Int? = None,
  col_step? : Int = 1,
) -> SDM raise PolyError {
  SDM::{
    dm: self.dm
    .extract_slice(
      row_start~,
      row_stop~,
      row_step~,
      col_start~,
      col_stop~,
      col_step~,
    )
    .to_sparse(),
  }
}

///|

///|
/// Public API `SDM.applyfunc`.
///
/// - Does: Provides the `SDM.applyfunc` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `func : FieldElemMapper`, `domain : Domain =
/// None`, using the package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::applyfunc(
  self : SDM,
  func : FieldElemMapper,
  domain? : Domain? = None,
) -> SDM raise PolyError {
  SDM::{ dm: self.dm.applyfunc(func, domain~).to_sparse() }
}

///|

///|
/// Public API `SDM.transpose`.
///
/// - Does: Provides the `SDM.transpose` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::transpose(self : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.transpose().to_sparse() }
}

///|

///|
/// Public API `SDM.add`.
///
/// - Does: Provides the `SDM.add` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `other : SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::add(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.add(other.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.sub`.
///
/// - Does: Provides the `SDM.sub` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `other : SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::sub(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.sub(other.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.neg`.
///
/// - Does: Provides the `SDM.neg` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::neg(self : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.neg().to_sparse() }
}

///|

///|
/// Public API `SDM.mul`.
///
/// - Does: Provides the `SDM.mul` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `scalar : FieldElem`, using the package
/// representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::mul(self : SDM, scalar : FieldElem) -> SDM raise PolyError {
  SDM::{ dm: self.dm.mul(scalar).to_sparse() }
}

///|

///|
/// Public API `SDM.matmul`.
///
/// - Does: Provides the `SDM.matmul` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `other : SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::matmul(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.matmul(other.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.mul_elementwise`.
///
/// - Does: Provides the `SDM.mul_elementwise` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `other : SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::mul_elementwise(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.mul_elementwise(other.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.rmul`.
///
/// - Does: Provides the `SDM.rmul` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `scalar : FieldElem`, using the package
/// representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::rmul(self : SDM, scalar : FieldElem) -> SDM raise PolyError {
  SDM::{ dm: self.dm.rmul(scalar).to_sparse() }
}

///|

///|
/// Public API `SDM.diagonal`.
///
/// - Does: Provides the `SDM.diagonal` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::diagonal(self : SDM) -> Array[FieldElem] raise PolyError {
  self.dm.diagonal()
}

///|

///|
/// Public API `SDM.extract`.
///
/// - Does: Provides the `SDM.extract` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `row_ids : Array[Int]`, `col_ids : Array[Int]`,
/// using the package representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::extract(
  self : SDM,
  row_ids : Array[Int],
  col_ids : Array[Int],
) -> SDM raise PolyError {
  SDM::{ dm: self.dm.extract(row_ids, col_ids).to_sparse() }
}

///|

///|
/// Public API `SDM.hstack`.
///
/// - Does: Provides the `SDM.hstack` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `other : SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::hstack(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.hstack(other.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.vstack`.
///
/// - Does: Provides the `SDM.vstack` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `other : SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::vstack(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.vstack(other.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.nnz`.
///
/// - Does: Provides the `SDM.nnz` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Int` value.
/// - Limits: Inputs must already satisfy the representation invariants expected by the
/// compatibility wrapper; no separate error channel is added.
pub fn SDM::nnz(self : SDM) -> Int {
  self.dm.nnz()
}

///|

///|
/// Public API `SDM.is_diagonal`.
///
/// - Does: Provides the `SDM.is_diagonal` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::is_diagonal(self : SDM) -> Bool raise PolyError {
  self.dm.is_diagonal()
}

///|

///|
/// Public API `SDM.is_upper`.
///
/// - Does: Provides the `SDM.is_upper` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::is_upper(self : SDM) -> Bool raise PolyError {
  self.dm.is_upper()
}

///|

///|
/// Public API `SDM.is_lower`.
///
/// - Does: Provides the `SDM.is_lower` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::is_lower(self : SDM) -> Bool raise PolyError {
  self.dm.is_lower()
}

///|

///|
/// Public API `SDM.is_zero_matrix`.
///
/// - Does: Provides the `SDM.is_zero_matrix` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::is_zero_matrix(self : SDM) -> Bool raise PolyError {
  self.dm.is_zero_matrix()
}

///|

///|
/// Public API `SDM.det`.
///
/// - Does: Provides the `SDM.det` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::det(self : SDM) -> FieldElem raise PolyError {
  self.dm.det()
}

///|
/// Compute reduced row echelon form.
///
/// - Does: Returns the sparse RREF matrix together with pivot columns.
/// - Input: An `SDM`.
/// - Returns: `(SDM, Array[Int])`.
/// - Limits: Raises `PolyError` when the underlying elimination fails.
pub fn SDM::rref(self : SDM) -> (SDM, Array[Int]) raise PolyError {
  let (r, pivots) = self.dm.rref()
  (SDM::{ dm: r.to_sparse() }, pivots)
}

///|
/// Compute denominator-cleared reduced row echelon form.
///
/// - Does: Returns the numerator matrix, common denominator, and pivot columns.
/// - Input: An `SDM` plus optional method flags.
/// - Returns: `(SDM, FieldElem, Array[Int])`.
/// - Limits: Raises `PolyError` when the elimination path fails.
pub fn SDM::rref_den(
  self : SDM,
  rref_method? : String = "auto",
  keep_domain? : Bool = true,
) -> (SDM, FieldElem, Array[Int]) raise PolyError {
  let (r, den, pivots) = self.dm.rref_den(rref_method~, keep_domain~)
  (SDM::{ dm: r.to_sparse() }, den, pivots)
}

///|

///|
/// Public API `SDM.nullspace_from_rref`.
///
/// - Does: Provides the `SDM.nullspace_from_rref` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `pivots : Array[Int] = []`, `) -> (SDM`,
/// `Array[Int]`, using the package representation expected by the signature.
/// - Returns: a `(SDM, Array[Int])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::nullspace_from_rref(
  self : SDM,
  pivots? : Array[Int] = [],
) -> (SDM, Array[Int]) raise PolyError {
  let (basis, nonpivots) = nullspace_from_rref_with_nonpivots(self.dm, pivots~)
  (SDM::{ dm: basis.to_sparse() }, nonpivots)
}

///|
/// Compute a basis of the nullspace.
///
/// - Does: Returns nullspace vectors as sparse rows.
/// - Input: An `SDM` and optional `divide_last` flag.
/// - Returns: `Array[Array[FieldElem]]`.
/// - Limits: Raises `PolyError` when the underlying RREF-based path fails.
pub fn SDM::nullspace(
  self : SDM,
  divide_last? : Bool = false,
) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.nullspace(divide_last~).to_dense()
}

///|
/// Compute an LU factorization.
///
/// - Does: Returns sparse `L`, `U`, and row-swap data.
/// - Input: An `SDM`.
/// - Returns: `(SDM, SDM, Array[(Int, Int)])`.
/// - Limits: Raises `PolyError` when the factorization fails.
pub fn SDM::lu(self : SDM) -> (SDM, SDM, Array[(Int, Int)]) raise PolyError {
  let (l, u, swaps) = self.dm.lu()
  (SDM::{ dm: l.to_sparse() }, SDM::{ dm: u.to_sparse() }, swaps)
}

///|

///|
/// Public API `SDM.qr`.
///
/// - Does: Provides the `SDM.qr` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM) -> (SDM`, `SDM`, using the package representation
/// expected by the signature.
/// - Returns: a `(SDM, SDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::qr(self : SDM) -> (SDM, SDM) raise PolyError {
  let (q, r) = self.dm.qr()
  (SDM::{ dm: q.to_sparse() }, SDM::{ dm: r.to_sparse() })
}

///|
/// Solve a linear system via LU factorization.
///
/// - Does: Solves `self * X = rhs`.
/// - Input: Coefficient `SDM` and right-hand-side `SDM`.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the exact solve path fails.
pub fn SDM::lu_solve(self : SDM, rhs : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.lu_solve(rhs.dm).to_sparse() }
}

///|

///|
/// Public API `SDM.fflu`.
///
/// - Does: Provides the `SDM.fflu` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM) -> (SDM`, `SDM`, `SDM`, `SDM`, using the package
/// representation expected by the signature.
/// - Returns: a `(SDM, SDM, SDM, SDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::fflu(self : SDM) -> (SDM, SDM, SDM, SDM) raise PolyError {
  let (p, l, d, u) = self.dm.fflu()
  (
    SDM::{ dm: p.to_sparse() },
    SDM::{ dm: l.to_sparse() },
    SDM::{ dm: d.to_sparse() },
    SDM::{ dm: u.to_sparse() },
  )
}

///|
/// Compute the characteristic polynomial coefficients.
///
/// - Does: Returns the characteristic polynomial in dense coefficient form.
/// - Input: A square `SDM`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: Raises `PolyError` when the characteristic-polynomial path fails.
pub fn SDM::charpoly(self : SDM) -> Array[FieldElem] raise PolyError {
  self.dm.charpoly()
}

///|
/// Compute a sparse inverse.
///
/// - Does: Returns the exact inverse matrix when it exists.
/// - Input: A square `SDM`.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` for non-square or singular inputs.
pub fn SDM::inv(self : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.inv().to_sparse() }
}

///|

///|
/// Public API `SDM.particular`.
///
/// - Does: Provides the `SDM.particular` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `pivots : Array[Int] = []`, using the package
/// representation expected by the signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::particular(
  self : SDM,
  pivots? : Array[Int] = [],
) -> SDM raise PolyError {
  SDM::{ dm: particular_from_rref(self.dm, pivots~).to_sparse() }
}

///|

///|
/// Public API `SDM.scc`.
///
/// - Does: Provides the `SDM.scc` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[Array[Int]]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::scc(self : SDM) -> Array[Array[Int]] raise PolyError {
  self.dm.scc()
}

///|
/// Run LLL reduction on sparse rows.
///
/// - Does: Computes an LLL-reduced basis through the sparse compatibility
///   layer.
/// - Input: An `SDM` and optional Lovasz parameter `delta`.
/// - Returns: An `SDM`.
/// - Limits: Raises `PolyError` when the input domain is unsupported.
pub fn SDM::lll(
  self : SDM,
  delta? : @symnum.BigRational,
) -> SDM raise PolyError {
  let reduced = match delta {
    Some(d) => self.to_dense().lll(delta=d)
    None => self.to_dense().lll()
  }
  SDM::{ dm: reduced.to_domain_matrix().to_sparse() }
}

///|

///|
/// Public API `SDM.lll_transform`.
///
/// - Does: Provides the `SDM.lll_transform` operation for sparse domain-matrix compatibility.
/// - Input: parameters `self : SDM`, `delta : @symnum.BigRational`, `) -> (SDM`, `SDM`,
/// using the package representation expected by the signature.
/// - Returns: a `(SDM, SDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn SDM::lll_transform(
  self : SDM,
  delta? : @symnum.BigRational,
) -> (SDM, SDM) raise PolyError {
  let (reduced, transform) = match delta {
    Some(d) => self.to_dense().lll_transform(delta=d)
    None => self.to_dense().lll_transform()
  }
  (
    SDM::{ dm: reduced.to_domain_matrix().to_sparse() },
    SDM::{ dm: transform.to_domain_matrix().to_sparse() },
  )
}

///|
/// Return a stable string form for diagnostics.
///
/// - Does: Formats the sparse matrix through its dense view for tests and
/// - Input: An `SDM`.
/// - Returns: A `String`.
/// - Limits: The output is intended for diagnostics, not general
///   serialization.
pub fn SDM::to_string(self : SDM) -> String raise PolyError {
  let entries = self.to_sparse_entries()
  let by_row : Map[Int, Array[(Int, FieldElem)]] = Map([])
  for e in entries {
    let (r, c, v) = e
    match by_row.get(r) {
      Some(row) => row.push((c, v))
      None => by_row[r] = [(c, v)]
    }
  }
  let row_ids : Array[Int] = Array::new()
  for r, _ in by_row {
    row_ids.push(r)
  }
  row_ids.sort()
  let row_parts : Array[String] = Array::new()
  for r in row_ids {
    let cells = by_row[r]
    cells.sort_by((a, b) => a.0 - b.0)
    let cell_text = cells.map(p => "\{p.0}: \{p.1.to_string()}").join(", ")
    row_parts.push("\{r}: {\{cell_text}}")
  }
  let body = row_parts.join(", ")
  "{\{body}}"
}
