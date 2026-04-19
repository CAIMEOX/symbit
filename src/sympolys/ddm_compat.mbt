///|
/// Dense domain-matrix compatibility front doors.
///
/// Current Limits:
/// - this file is a wrapper layer around `DomainMatrix`, not a separate matrix
///   engine.
/// - some format-conversion entry points preserve only the public compatibility
///   behavior and may normalize back to dense storage.

///|
/// Dense domain-matrix wrapper used by matrix-related polynomial APIs.
///
/// - Does: Exposes a dense matrix view over `FieldElem` entries with
///   compatibility-oriented constructors and methods.
/// - Input: Built from `DomainMatrix`-backed constructors in this file.
/// - Returns: A `DDM`.
/// - Limits: Semantics follow the dense compatibility layer rather than a full
///   standalone matrix type hierarchy.
pub struct DDM {
  dm : DomainMatrix
}

///|
/// Build a dense domain matrix from explicit rows.
///
/// - Does: Creates a `DDM` from `FieldElem` rows in the given domain.
/// - Input: `Array[Array[FieldElem]]` and a `Domain`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the rows cannot form a valid dense matrix.
pub fn ddm_from_dense(
  rows : Array[Array[FieldElem]],
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: domain_matrix_from_dense(rows, domain) }
}

///|
/// Build a dense domain matrix from integer rows.
///
/// - Does: Lifts integer entries into the target domain and creates a `DDM`.
/// - Input: `Array[Array[Int]]` and a `Domain`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the target domain cannot represent the
///   lifted entries.
pub fn ddm_from_ints(
  rows : Array[Array[Int]],
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: domain_matrix_from_ints(rows, domain) }
}

///|
/// Build a dense matrix from row data and an explicit shape.
///
/// - Does: Validates the shape and constructs a `DDM`.
/// - Input: Dense rows, expected shape, and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError::DomainMismatch` when row sizes do not match the
///   requested shape.
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
/// Copy a dense domain matrix.
///
/// - Does: Returns a dense copy of another `DDM`.
/// - Input: A `DDM`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` only if the underlying copy operation fails.
pub fn DDM::from_ddm(other : DDM) -> DDM raise PolyError {
  other.copy()
}

///|
/// Compatibility alias returning a dense copy.
///
/// - Does: Preserves the `to_dfm` front door while returning a dense copy.
/// - Input: A `DDM`.
/// - Returns: A `DDM`.
/// - Limits: This compatibility layer does not distinguish DFM and DDM.
pub fn DDM::to_dfm(self : DDM) -> DDM raise PolyError {
  self.copy()
}

///|
/// Compatibility alias returning a dense copy.
///
/// - Does: Preserves the `to_dfm_or_ddm` front door while returning a dense
///   copy.
/// - Input: A `DDM`.
/// - Returns: A `DDM`.
/// - Limits: This compatibility layer does not distinguish DFM and DDM.
pub fn DDM::to_dfm_or_ddm(self : DDM) -> DDM raise PolyError {
  self.copy()
}

///|
/// Build a dense matrix from flat row-major storage.
///
/// - Does: Reconstructs a dense matrix with the requested shape.
/// - Input: Flat entries, shape, and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the flat data length does not match the
///   shape.
pub fn DDM::from_list_flat(
  elements : Array[FieldElem],
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::from_list_flat(elements, shape, domain) }
}

///|
/// Build a dense matrix from a dictionary-of-dictionaries sparse form.
///
/// - Does: Converts sparse keyed rows into a dense `DDM`.
/// - Input: `DomainMatrixDOD`, shape, and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the sparse data is invalid for the shape.
pub fn DDM::from_dod(
  dod : DomainMatrixDOD,
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  let dm = DomainMatrix::from_dod(dod, shape, domain)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
/// Build a dense matrix from a dictionary-of-keys sparse form.
///
/// - Does: Converts sparse keyed entries into a dense `DDM`.
/// - Input: `DomainMatrixDOK`, shape, and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the sparse data is invalid for the shape.
pub fn DDM::from_dok(
  dok : DomainMatrixDOK,
  shape : (Int, Int),
  domain : Domain,
) -> DDM raise PolyError {
  let dm = DomainMatrix::from_dok(dok, shape, domain)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
/// Build a zero matrix.
///
/// - Does: Creates a dense zero matrix of the requested shape.
/// - Input: Row count, column count, and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the requested matrix cannot be created.
pub fn DDM::zeros(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::zeros(rows, cols, domain) }
}

///|
/// Build an all-ones matrix.
///
/// - Does: Creates a dense matrix filled with the domain element `1`.
/// - Input: Row count, column count, and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the requested matrix cannot be created.
pub fn DDM::ones(
  rows : Int,
  cols : Int,
  domain : Domain,
) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::ones(rows, cols, domain) }
}

///|
/// Build an identity matrix.
///
/// - Does: Creates the square identity matrix over the given domain.
/// - Input: Matrix size and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the requested matrix cannot be created.
pub fn DDM::eye(n : Int, domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::eye(n, domain) }
}

///|
/// Build a diagonal matrix.
///
/// - Does: Places the given values on the diagonal of a dense matrix.
/// - Input: Diagonal values, domain, and optional row/column counts.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the requested shape is incompatible.
pub fn DDM::diag(
  values : Array[FieldElem],
  domain : Domain,
  rows? : Int? = None,
  cols? : Int? = None,
) -> DDM raise PolyError {
  DDM::{ dm: DomainMatrix::diag(values, domain, rows~, cols~) }
}

///|
/// Return the matrix shape.
///
/// - Does: Exposes the dense matrix dimensions.
/// - Input: A `DDM`.
/// - Returns: `(rows, cols)`.
/// - Limits: This reports the stored shape only.
pub fn DDM::shape(self : DDM) -> (Int, Int) {
  self.dm.shape()
}

///|
/// Copy a dense domain matrix.
///
/// - Does: Returns a structural copy of the matrix.
/// - Input: A `DDM`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` only if the underlying copy operation fails.
pub fn DDM::copy(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.copy() }
}

///|

///|
/// Public API `DDM._check`.
///
/// - Does: Provides the `DDM._check` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `op : String`, `other : DDM`, `ashape : (Int,
/// Int)`, `bshape : (Int, Int)`, using the package representation expected by the
/// signature.
/// - Returns: a `Unit` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::_check(
  self : DDM,
  op : String,
  other : DDM,
  ashape : (Int, Int),
  bshape : (Int, Int),
) -> Unit raise PolyError {
  self.dm._check(op, other.dm, ashape, bshape, require_format=false)
}

///|
/// Return the coefficient domain.
///
/// - Does: Exposes the ground domain attached to the matrix entries.
/// - Input: A `DDM`.
/// - Returns: A `Domain`.
/// - Limits: This does not inspect or normalize the entries.
pub fn DDM::domain(self : DDM) -> Domain {
  self.dm.domain
}

///|
/// Convert entries into another coefficient domain.
///
/// - Does: Coerces every entry into the requested target domain.
/// - Input: A `DDM` and target `Domain`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when an entry cannot be converted.
pub fn DDM::convert_to(self : DDM, domain : Domain) -> DDM raise PolyError {
  DDM::{ dm: self.dm.convert_to(domain) }
}

///|
/// Return the dense row representation.
///
/// - Does: Exposes the stored matrix as dense rows.
/// - Input: A `DDM`.
/// - Returns: `Array[Array[FieldElem]]`.
/// - Limits: The returned data reflects the current dense normalization.
pub fn DDM::to_list(self : DDM) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.to_dense()
}

///|
/// Return flat row-major storage.
///
/// - Does: Flattens the dense matrix entries row by row.
/// - Input: A `DDM`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: Order is row-major and matches the stored shape.
pub fn DDM::to_list_flat(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.to_list_flat()
}

///|

///|
/// Public API `DDM.flat`.
///
/// - Does: Provides the `DDM.flat` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::flat(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.flat()
}

///|

///|
/// Public API `DDM.flatiter`.
///
/// - Does: Provides the `DDM.flatiter` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Iter[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::flatiter(self : DDM) -> Iter[FieldElem] raise PolyError {
  self.flat().iter()
}

///|

///|
/// Public API `DDM.to_flat_nz`.
///
/// - Does: Provides the `DDM.to_flat_nz` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `) -> (Array[FieldElem]`,
/// `DomainMatrixFlatNZData`, using the package representation expected by the
/// signature.
/// - Returns: a `(Array[FieldElem], DomainMatrixFlatNZData)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::to_flat_nz(
  self : DDM,
) -> (Array[FieldElem], DomainMatrixFlatNZData) raise PolyError {
  self.dm.to_flat_nz()
}

///|

///|
/// Public API `DDM.from_flat_nz`.
///
/// - Does: Provides the `DDM.from_flat_nz` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `elements : Array[FieldElem]`, `data :
/// DomainMatrixFlatNZData`, `domain : Domain`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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

///|
/// Public API `DDM.iter_values`.
///
/// - Does: Provides the `DDM.iter_values` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::iter_values(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.iter_values()
}

///|

///|
/// Public API `DDM.iter_items`.
///
/// - Does: Provides the `DDM.iter_items` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `) -> Array[(Int, Int, FieldElem`, using the
/// package representation expected by the signature.
/// - Returns: a `Array[(Int, Int, FieldElem)]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::iter_items(
  self : DDM,
) -> Array[(Int, Int, FieldElem)] raise PolyError {
  self.dm.iter_items()
}

///|

///|
/// Public API `DDM.to_dod`.
///
/// - Does: Provides the `DDM.to_dod` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DomainMatrixDOD` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::to_dod(self : DDM) -> DomainMatrixDOD raise PolyError {
  self.dm.to_dod()
}

///|

///|
/// Public API `DDM.to_dok`.
///
/// - Does: Provides the `DDM.to_dok` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DomainMatrixDOK` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::to_dok(self : DDM) -> DomainMatrixDOK raise PolyError {
  self.dm.to_dok()
}

///|

///|
/// Public API `DDM.applyfunc`.
///
/// - Does: Provides the `DDM.applyfunc` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `func : FieldElemMapper`, `domain : Domain =
/// None`, using the package representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::applyfunc(
  self : DDM,
  func : FieldElemMapper,
  domain? : Domain? = None,
) -> DDM raise PolyError {
  let dm = self.dm.applyfunc(func, domain~)
  DDM::{ dm: domain_matrix_from_dense(dm.to_dense(), dm.domain) }
}

///|
/// Convert to the package `DomainMatrix` wrapper.
///
/// - Does: Exposes the underlying `DomainMatrix`.
/// - Input: A `DDM`.
/// - Returns: A `DomainMatrix`.
/// - Limits: This is a structural view change only.
pub fn DDM::to_domain_matrix(self : DDM) -> DomainMatrix {
  self.dm
}

///|

///|
/// Public API `DDM.getitem`.
///
/// - Does: Provides the `DDM.getitem` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `row : Int`, `col : Int`, using the package
/// representation expected by the signature.
/// - Returns: a `FieldElem` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::getitem(
  self : DDM,
  row : Int,
  col : Int,
) -> FieldElem raise PolyError {
  self.dm.getitem(row, col).element
}

///|

///|
/// Public API `DDM.setitem`.
///
/// - Does: Provides the `DDM.setitem` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `row : Int`, `col : Int`, `value : FieldElem`,
/// using the package representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::setitem(
  self : DDM,
  row : Int,
  col : Int,
  value : FieldElem,
) -> DDM raise PolyError {
  DDM::{ dm: self.dm.setitem(row, col, value) }
}

///|

///|
/// Public API `DDM.extract_slice`.
///
/// - Does: Provides the `DDM.extract_slice` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `row_start : Int = None`, `row_stop : Int = None`,
/// `row_step : Int = 1`, `col_start : Int = None` and 2 more parameter(s), using the
/// package representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
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
      row_start~,
      row_stop~,
      row_step~,
      col_start~,
      col_stop~,
      col_step~,
    ),
  }
}

///|

///|
/// Public API `DDM.to_ddm`.
///
/// - Does: Provides the `DDM.to_ddm` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::to_ddm(self : DDM) -> DDM raise PolyError {
  self.copy()
}

///|

///|
/// Public API `DDM.to_sdm`.
///
/// - Does: Provides the `DDM.to_sdm` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `SDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::to_sdm(self : DDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.to_sparse() }
}

///|
/// Return a transposed dense matrix.
///
/// - Does: Swaps rows and columns.
/// - Input: A `DDM`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` only if the underlying transpose fails.
pub fn DDM::transpose(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.transpose() }
}

///|
/// Add two dense matrices.
///
/// - Does: Computes matrix addition entrywise.
/// - Input: Two `DDM` values with compatible shape and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the shapes or domains are incompatible.
pub fn DDM::add(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.add(other.dm) }
}

///|
/// Subtract one dense matrix from another.
///
/// - Does: Computes `self - other` entrywise.
/// - Input: Two `DDM` values with compatible shape and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the shapes or domains are incompatible.
pub fn DDM::sub(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.sub(other.dm) }
}

///|
/// Negate a dense matrix.
///
/// - Does: Negates every entry.
/// - Input: A `DDM`.
/// - Returns: A `DDM`.
/// - Limits: This keeps the same shape and domain.
pub fn DDM::neg(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.neg() }
}

///|
/// Multiply a dense matrix by a scalar.
///
/// - Does: Scales every entry by `scalar`.
/// - Input: A `DDM` and `FieldElem`.
/// - Returns: A `DDM`.
/// - Limits: The scalar must already belong to the matrix domain.
pub fn DDM::mul(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  DDM::{ dm: self.dm.mul(scalar) }
}

///|
/// Multiply two dense matrices.
///
/// - Does: Computes matrix multiplication.
/// - Input: Two `DDM` values with compatible inner dimension and domain.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the dimensions or domains are
///   incompatible.
pub fn DDM::matmul(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.matmul(other.dm) }
}

///|

///|
/// Public API `DDM.mul_elementwise`.
///
/// - Does: Provides the `DDM.mul_elementwise` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `other : DDM`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::mul_elementwise(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.mul_elementwise(other.dm) }
}

///|

///|
/// Public API `DDM.mul_scalar`.
///
/// - Does: Provides the `DDM.mul_scalar` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `scalar : FieldElem`, using the package
/// representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::mul_scalar(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  self.mul(scalar)
}

///|

///|
/// Public API `DDM.rmul`.
///
/// - Does: Provides the `DDM.rmul` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `scalar : FieldElem`, using the package
/// representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::rmul(self : DDM, scalar : FieldElem) -> DDM raise PolyError {
  DDM::{ dm: self.dm.rmul(scalar) }
}

///|
/// Return the main diagonal.
///
/// - Does: Extracts the entries `a[i, i]`.
/// - Input: A `DDM`.
/// - Returns: `Array[FieldElem]`.
/// - Limits: The length is limited by the smaller matrix dimension.
pub fn DDM::diagonal(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.diagonal()
}

///|
/// Extract a submatrix by explicit row and column ids.
///
/// - Does: Builds the matrix slice selected by the provided index arrays.
/// - Input: A `DDM`, row ids, and column ids.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when an index is invalid.
pub fn DDM::extract(
  self : DDM,
  row_ids : Array[Int],
  col_ids : Array[Int],
) -> DDM raise PolyError {
  DDM::{ dm: self.dm.extract(row_ids, col_ids) }
}

///|

///|
/// Public API `DDM.hstack`.
///
/// - Does: Provides the `DDM.hstack` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `other : DDM`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::hstack(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.hstack(other.dm) }
}

///|

///|
/// Public API `DDM.vstack`.
///
/// - Does: Provides the `DDM.vstack` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `other : DDM`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::vstack(self : DDM, other : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.vstack(other.dm) }
}

///|

///|
/// Public API `DDM.nnz`.
///
/// - Does: Provides the `DDM.nnz` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Int` value.
/// - Limits: Inputs must already satisfy the representation invariants expected by the
/// compatibility wrapper; no separate error channel is added.
pub fn DDM::nnz(self : DDM) -> Int {
  self.dm.nnz()
}

///|

///|
/// Public API `DDM.is_diagonal`.
///
/// - Does: Provides the `DDM.is_diagonal` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::is_diagonal(self : DDM) -> Bool raise PolyError {
  self.dm.is_diagonal()
}

///|

///|
/// Public API `DDM.is_upper`.
///
/// - Does: Provides the `DDM.is_upper` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::is_upper(self : DDM) -> Bool raise PolyError {
  self.dm.is_upper()
}

///|

///|
/// Public API `DDM.is_lower`.
///
/// - Does: Provides the `DDM.is_lower` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::is_lower(self : DDM) -> Bool raise PolyError {
  self.dm.is_lower()
}

///|

///|
/// Public API `DDM.is_zero_matrix`.
///
/// - Does: Provides the `DDM.is_zero_matrix` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Bool` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::is_zero_matrix(self : DDM) -> Bool raise PolyError {
  self.dm.is_zero_matrix()
}

///|
/// Compute the determinant.
///
/// - Does: Returns the determinant in the matrix domain.
/// - Input: A square `DDM`.
/// - Returns: A `FieldElem`.
/// - Limits: Raises `PolyError` when the determinant path cannot proceed.
pub fn DDM::det(self : DDM) -> FieldElem raise PolyError {
  self.dm.det()
}

///|
/// Compute reduced row echelon form.
///
/// - Does: Returns the RREF matrix together with pivot columns.
/// - Input: A `DDM`.
/// - Returns: `(DDM, Array[Int])`.
/// - Limits: Raises `PolyError` when the underlying elimination fails.
pub fn DDM::rref(self : DDM) -> (DDM, Array[Int]) raise PolyError {
  let (r, pivots) = self.dm.rref()
  (DDM::{ dm: r }, pivots)
}

///|
/// Compute denominator-cleared reduced row echelon form.
///
/// - Does: Returns the numerator matrix, common denominator, and pivot columns.
/// - Input: A `DDM` plus optional method flags.
/// - Returns: `(DDM, FieldElem, Array[Int])`.
/// - Limits: Raises `PolyError` when the elimination path fails.
pub fn DDM::rref_den(
  self : DDM,
  rref_method? : String = "auto",
  keep_domain? : Bool = true,
) -> (DDM, FieldElem, Array[Int]) raise PolyError {
  let (r, den, pivots) = self.dm.rref_den(rref_method~, keep_domain~)
  (DDM::{ dm: r }, den, pivots)
}

///|
/// Compute the rank.
///
/// - Does: Returns the rank of the matrix.
/// - Input: A `DDM`.
/// - Returns: An `Int`.
/// - Limits: Raises `PolyError` when the rank path fails.
pub fn DDM::rank(self : DDM) -> Int raise PolyError {
  self.dm.rank()
}

///|
/// Clear common denominators from all entries.
///
/// - Does: Returns a common denominator together with the numerator matrix.
/// - Input: A `DDM` and optional `convert` flag.
/// - Returns: `(DomainScalar, DDM)`.
/// - Limits: Raises `PolyError` when denominator clearing fails.
pub fn DDM::clear_denoms(
  self : DDM,
  convert? : Bool = false,
) -> (DomainScalar, DDM) raise PolyError {
  let (den, num) = self.dm.clear_denoms(convert~)
  (den, DDM::{ dm: num })
}

///|

///|
/// Public API `DDM.clear_denoms_rowwise`.
///
/// - Does: Provides the `DDM.clear_denoms_rowwise` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `convert : Bool = false`, `) -> (DDM`, `DDM`,
/// using the package representation expected by the signature.
/// - Returns: a `(DDM, DDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::clear_denoms_rowwise(
  self : DDM,
  convert? : Bool = false,
) -> (DDM, DDM) raise PolyError {
  let (den, num) = self.dm.clear_denoms_rowwise(convert~)
  (DDM::{ dm: den }, DDM::{ dm: num })
}

///|
/// Compute the adjugate and determinant together.
///
/// - Does: Returns `(adj(A), det(A))`.
/// - Input: A square `DDM`.
/// - Returns: `(DDM, FieldElem)`.
/// - Limits: Raises `PolyError` when the underlying exact path fails.
pub fn DDM::adj_det(self : DDM) -> (DDM, FieldElem) raise PolyError {
  let (adj, det) = self.dm.adj_det()
  (DDM::{ dm: adj }, det)
}

///|
/// Compute the adjugate matrix.
///
/// - Does: Returns `adj(A)`.
/// - Input: A square `DDM`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` when the underlying exact path fails.
pub fn DDM::adjugate(self : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.adjugate() }
}

///|
/// Compute a denominator-cleared inverse.
///
/// - Does: Returns `(num, den)` such that `A^-1 = num / den`.
/// - Input: A square `DDM` and optional solve-method tag.
/// - Returns: `(DDM, FieldElem)`.
/// - Limits: Raises `PolyError` when the inverse does not exist or the exact
///   solve path fails.
pub fn DDM::inv_den(
  self : DDM,
  solve_method? : String = "",
) -> (DDM, FieldElem) raise PolyError {
  let (num, den) = self.dm.inv_den(solve_method~)
  (DDM::{ dm: num }, den)
}

///|
/// Solve a linear system with denominator clearing.
///
/// - Does: Solves `self * X = rhs` and returns `(num, den)` such that
///   `X = num / den`.
/// - Input: Coefficient `DDM`, right-hand-side `DDM`, and optional solve-method
///   tag.
/// - Returns: `(DDM, FieldElem)`.
/// - Limits: Raises `PolyError` when the exact solve path fails.
pub fn DDM::solve_den(
  self : DDM,
  rhs : DDM,
  solve_method? : String = "",
) -> (DDM, FieldElem) raise PolyError {
  let (num, den) = self.dm.solve_den(rhs.dm, solve_method~)
  (DDM::{ dm: num }, den)
}

///|

///|
/// Public API `DDM.solve_den_rref`.
///
/// - Does: Provides the `DDM.solve_den_rref` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `rhs : DDM`, `) -> (DDM`, `FieldElem`, using the
/// package representation expected by the signature.
/// - Returns: a `(DDM, FieldElem)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::solve_den_rref(
  self : DDM,
  rhs : DDM,
) -> (DDM, FieldElem) raise PolyError {
  let (num, den) = self.dm.solve_den_rref(rhs.dm)
  (DDM::{ dm: num }, den)
}

///|

///|
/// Public API `DDM.lu`.
///
/// - Does: Provides the `DDM.lu` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM) -> (DDM`, `DDM`, `Array[(Int, Int)]`, using the
/// package representation expected by the signature.
/// - Returns: a `(DDM, DDM, Array[(Int, Int)])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::lu(self : DDM) -> (DDM, DDM, Array[(Int, Int)]) raise PolyError {
  let (l, u, swaps) = self.dm.lu()
  (DDM::{ dm: l }, DDM::{ dm: u }, swaps)
}

///|

///|
/// Public API `DDM.qr`.
///
/// - Does: Provides the `DDM.qr` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM) -> (DDM`, `DDM`, using the package representation
/// expected by the signature.
/// - Returns: a `(DDM, DDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::qr(self : DDM) -> (DDM, DDM) raise PolyError {
  let (q, r) = self.dm.qr()
  (DDM::{ dm: q }, DDM::{ dm: r })
}

///|

///|
/// Public API `DDM.lu_solve`.
///
/// - Does: Provides the `DDM.lu_solve` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `rhs : DDM`, using the package representation
/// expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::lu_solve(self : DDM, rhs : DDM) -> DDM raise PolyError {
  DDM::{ dm: self.dm.lu_solve(rhs.dm) }
}

///|

///|
/// Public API `DDM.fflu`.
///
/// - Does: Provides the `DDM.fflu` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM) -> (DDM`, `DDM`, `DDM`, `DDM`, using the package
/// representation expected by the signature.
/// - Returns: a `(DDM, DDM, DDM, DDM)` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::fflu(self : DDM) -> (DDM, DDM, DDM, DDM) raise PolyError {
  let (p, l, d, u) = self.dm.fflu()
  (DDM::{ dm: p }, DDM::{ dm: l }, DDM::{ dm: d }, DDM::{ dm: u })
}

///|

///|
/// Public API `DDM._fflu`.
///
/// - Does: Provides the `DDM._fflu` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM) -> (DDM`, `Array[Int]`, using the package
/// representation expected by the signature.
/// - Returns: a `(DDM, Array[Int])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::_fflu(self : DDM) -> (DDM, Array[Int]) raise PolyError {
  let (lu_rows, perm) = dense_fflu_phase1(self.dm.to_dense(), self.dm.domain)
  (ddm_from_dense(lu_rows, self.dm.domain), perm)
}

///|

///|
/// Public API `DDM.charpoly`.
///
/// - Does: Provides the `DDM.charpoly` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[FieldElem]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::charpoly(self : DDM) -> Array[FieldElem] raise PolyError {
  self.dm.charpoly()
}

///|
/// Compute a dense inverse.
///
/// - Does: Returns the exact inverse matrix when it exists.
/// - Input: A square `DDM`.
/// - Returns: A `DDM`.
/// - Limits: Raises `PolyError` for non-square or singular inputs.
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
/// Compute a basis of the nullspace.
///
/// - Does: Returns nullspace vectors as dense rows.
/// - Input: A `DDM` and optional `divide_last` flag.
/// - Returns: `Array[Array[FieldElem]]`.
/// - Limits: Raises `PolyError` when the underlying RREF-based path fails.
pub fn DDM::nullspace(
  self : DDM,
  divide_last? : Bool = false,
) -> Array[Array[FieldElem]] raise PolyError {
  self.dm.nullspace(divide_last~).to_dense()
}

///|

///|
/// Public API `DDM.nullspace_from_rref`.
///
/// - Does: Provides the `DDM.nullspace_from_rref` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `pivots : Array[Int] = []`, `) -> (DDM`,
/// `Array[Int]`, using the package representation expected by the signature.
/// - Returns: a `(DDM, Array[Int])` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::nullspace_from_rref(
  self : DDM,
  pivots? : Array[Int] = [],
) -> (DDM, Array[Int]) raise PolyError {
  let (basis, nonpivots) = nullspace_from_rref_with_nonpivots(self.dm, pivots~)
  (DDM::{ dm: basis }, nonpivots)
}

///|

///|
/// Public API `DDM.particular`.
///
/// - Does: Provides the `DDM.particular` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, `pivots : Array[Int] = []`, using the package
/// representation expected by the signature.
/// - Returns: a `DDM` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::particular(
  self : DDM,
  pivots? : Array[Int] = [],
) -> DDM raise PolyError {
  DDM::{ dm: particular_from_rref(self.dm, pivots~) }
}

///|

///|
/// Public API `DDM.scc`.
///
/// - Does: Provides the `DDM.scc` operation for dense domain-matrix compatibility.
/// - Input: parameters `self : DDM`, using the package representation expected by the
/// signature.
/// - Returns: a `Array[Array[Int]]` value.
/// - Limits: Raises `PolyError` for invalid domains, shapes, or unsupported exact
/// operations; inputs must already satisfy the representation invariants expected by
/// this compatibility layer.
pub fn DDM::scc(self : DDM) -> Array[Array[Int]] raise PolyError {
  self.dm.scc()
}

///|
/// Return a stable string form for diagnostics.
///
/// - Does: Formats the dense rows as nested bracketed lists.
/// - Input: A `DDM`.
/// - Returns: A `String`.
/// - Limits: The output is intended for diagnostics and tests, not general
///   serialization.
pub fn DDM::to_string(self : DDM) -> String raise PolyError {
  let rows = self.to_list()
  let row_parts : Array[String] = Array::new()
  for row in rows {
    let row_text = row.map(v => v.to_string()).join(", ")
    row_parts.push("[\{row_text}]")
  }
  let matrix_text = row_parts.join(", ")
  "[\{matrix_text}]"
}
