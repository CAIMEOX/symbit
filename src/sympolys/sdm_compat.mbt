///|
/// Sparse Domain Matrix (`SDM`) compatibility layer.
pub struct SDM {
  dm : DomainMatrix
}

///|
pub fn sdm_from_entries(
  rows : Int,
  cols : Int,
  entries : Array[(Int, Int, FieldElem)],
  domain : Domain,
) -> SDM raise PolyError {
  SDM::{ dm: domain_matrix_from_sparse(rows, cols, entries, domain) }
}

///|
pub fn sdm_from_dense(rows : Array[Array[FieldElem]], domain : Domain) -> SDM raise PolyError {
  SDM::{ dm: domain_matrix_from_dense(rows, domain).to_sparse() }
}

///|
pub fn SDM::shape(self : SDM) -> (Int, Int) {
  self.dm.shape()
}

///|
pub fn SDM::domain(self : SDM) -> Domain {
  self.dm.domain
}

///|
pub fn SDM::to_dense(self : SDM) -> DDM raise PolyError {
  let rows = self.dm.to_dense()
  DDM::{ dm: domain_matrix_from_dense(rows, self.dm.domain) }
}

///|
pub fn SDM::to_sparse_entries(self : SDM) -> Array[(Int, Int, FieldElem)] raise PolyError {
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
pub fn SDM::add(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.add(other.dm).to_sparse() }
}

///|
pub fn SDM::sub(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.sub(other.dm).to_sparse() }
}

///|
pub fn SDM::mul(self : SDM, other : SDM) -> SDM raise PolyError {
  SDM::{ dm: self.dm.mul(other.dm).to_sparse() }
}

///|
pub fn SDM::rref_den(
  self : SDM,
  rref_method? : String = "auto",
  keep_domain? : Bool = true,
) -> (SDM, FieldElem, Array[Int]) raise PolyError {
  let (r, den, pivots) = self.dm.rref_den(
    rref_method=rref_method,
    keep_domain=keep_domain,
  )
  (SDM::{ dm: r.to_sparse() }, den, pivots)
}

///|
pub fn SDM::nullspace_from_rref(
  self : SDM,
  pivots? : Array[Int] = [],
) -> (SDM, Array[Int]) raise PolyError {
  let (basis, nonpivots) = nullspace_from_rref_with_nonpivots(self.dm, pivots~)
  (SDM::{ dm: basis.to_sparse() }, nonpivots)
}

///|
pub fn SDM::particular(
  self : SDM,
  pivots? : Array[Int] = [],
) -> SDM raise PolyError {
  SDM::{ dm: particular_from_rref(self.dm, pivots~).to_sparse() }
}

///|
pub fn SDM::to_string(self : SDM) -> String raise PolyError {
  let entries = self.to_sparse_entries()
  let by_row : Map[Int, Array[(Int, FieldElem)]] = Map::new()
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
    let cell_text = cells.map(p => "\{p.0}: \{fe_to_string(p.1)}").join(", ")
    row_parts.push("\{r}: {\{cell_text}}")
  }
  let body = row_parts.join(", ")
  "{\{body}}"
}
