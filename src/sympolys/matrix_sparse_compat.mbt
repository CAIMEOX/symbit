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
  if a.shape().1 != ncols {
    raise PolyError::DomainMismatch
  }
  a.nullspace_from_rref(pivots~)
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
