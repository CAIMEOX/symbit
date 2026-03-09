///|
pub enum LinearSolveResult {
  NoSolution
  Unique(Array[FieldElem])
  Parametric(Array[@symcore.Expr], Array[String])
}

///|
/// Build the sparse augmented matrix used by SymPy's matrix-based linsolve path.
pub fn sympy_dict_to_dm(
  eqs_coeffs : Array[Map[String, @symcore.Expr]],
  eqs_rhs : Array[@symcore.Expr],
  syms : Array[String],
) -> SDM raise PolyError {
  if eqs_coeffs.length() != eqs_rhs.length() {
    raise PolyError::DomainMismatch
  }
  let sym2index : Map[String, Int] = Map::new()
  for i in 0..<syms.length() {
    sym2index[syms[i]] = i
  }
  let expr_rows : Array[Array[(Int, @symcore.Expr)]] = Array::new()
  let flat_exprs : Array[@symcore.Expr] = Array::new()
  for i in 0..<eqs_coeffs.length() {
    let row_items : Array[(Int, @symcore.Expr)] = Array::new()
    for sym, coeff in eqs_coeffs[i] {
      match sym2index.get(sym) {
        Some(col) => {
          row_items.push((col, coeff))
          flat_exprs.push(coeff)
        }
        None => raise PolyError::DomainMismatch
      }
    }
    let neg_rhs = @symcore.int(0) - eqs_rhs[i]
    row_items.push((syms.length(), neg_rhs))
    flat_exprs.push(neg_rhs)
    expr_rows.push(row_items)
  }
  let (domain, values) = DomainMatrix::get_domain(flat_exprs, field=true)
  let value_rows : Array[Array[(Int, FieldElem)]] = Array::new()
  let mut offset = 0
  for row_items in expr_rows {
    let converted : Array[(Int, FieldElem)] = Array::new()
    for item in row_items {
      converted.push((item.0, values[offset]))
      offset += 1
    }
    value_rows.push(converted)
  }
  let dod : DomainMatrixDOD = Map::new()
  let mut next_row = 0
  for row_items in value_rows {
    let row : Map[Int, FieldElem] = Map::new()
    for item in row_items {
      if !fe_is_zero(item.1) {
        row[item.0] = item.1
      }
    }
    if row.is_empty() {
      continue
    }
    dod[next_row] = row
    next_row += 1
  }
  SDM::from_dod(dod, (eqs_coeffs.length(), syms.length() + 1), domain)
}

///|
fn lift_matrix_to_field(dm : DomainMatrix) -> DomainMatrix raise PolyError {
  if domain_is_field_pred(dm.domain) {
    return dm
  }
  let field = domain_get_field(dm.domain)
  let rows = dm.to_dense()
  let out : Array[Array[FieldElem]] = Array::new()
  for row in rows {
    let out_row : Array[FieldElem] = Array::new()
    for v in row {
      let q = fe_expect_rational(v)
      out_row.push(fe_from_rational(q, field))
    }
    out.push(out_row)
  }
  domain_matrix_from_dense(out, field)
}

///|
fn lift_vector_to_field(
  rhs : Array[FieldElem],
  domain : Domain,
) -> Array[FieldElem] raise PolyError {
  if domain_is_field_pred(domain) {
    return rhs
  }
  let field = domain_get_field(domain)
  let out : Array[FieldElem] = Array::new()
  for v in rhs {
    let q = fe_expect_rational(v)
    out.push(fe_from_rational(q, field))
  }
  out
}

///|
///|
/// Solve linear system `A * x = b` using RREF.
pub fn linear_solve(
  a : DDM,
  b : Array[FieldElem],
) -> LinearSolveResult raise PolyError {
  let (m, n) = a.shape()
  if b.length() != m {
    raise PolyError::DomainMismatch
  }
  let af = lift_matrix_to_field(a.to_domain_matrix())
  let bf = lift_vector_to_field(b, a.domain())
  let a_rows = af.to_dense()
  let aug_rows : Array[Array[FieldElem]] = Array::new()
  for i in 0..<m {
    let row = a_rows[i].copy()
    row.push(bf[i])
    aug_rows.push(row)
  }
  let aug = domain_matrix_from_dense(aug_rows, af.domain)
  let (rref_aug, pivots) = aug.rref()
  let rows = rref_aug.to_dense()

  // Detect inconsistency: 0 ... 0 | c (c != 0)
  for i in 0..<m {
    let mut all_zero = true
    for j in 0..<n {
      if !fe_is_zero(rows[i][j]) {
        all_zero = false
        break
      }
    }
    if all_zero && !fe_is_zero(rows[i][n]) {
      return LinearSolveResult::NoSolution
    }
  }

  let pivot_set : Map[Int, Bool] = {}
  for p in pivots {
    if p < n {
      pivot_set[p] = true
    }
  }
  let free_vars : Array[Int] = Array::new()
  for j in 0..<n {
    if pivot_set.get(j) is None {
      free_vars.push(j)
    }
  }

  if free_vars.is_empty() {
    let sol : Array[FieldElem] = Array::make(n, fe_from_int(0, af.domain))
    for i in 0..<pivots.length() {
      let p = pivots[i]
      if p < n {
        sol.set(p, rows[i][n])
      }
    }
    return LinearSolveResult::Unique(sol)
  }

  // Parametric solution with t0, t1, ... free symbols.
  let params = free_vars.map(i => "t\{i}")
  let free_exprs : Map[Int, @symcore.Expr] = {}
  for i in 0..<free_vars.length() {
    free_exprs[free_vars[i]] = @symcore.symbol(params[i])
  }
  let exprs : Array[@symcore.Expr] = Array::make(n, @symcore.int(0))
  for j in 0..<n {
    match free_exprs.get(j) {
      Some(v) => exprs.set(j, v)
      None => ()
    }
  }

  for i in 0..<pivots.length() {
    let p = pivots[i]
    if p >= n {
      continue
    }
    let mut rhs = fe_to_expr_const(rows[i][n])
    for fv in free_vars {
      let coeff = rows[i][fv]
      if fe_is_zero(coeff) {
        continue
      }
      rhs = rhs - (fe_to_expr_const(coeff) * exprs[fv])
    }
    exprs.set(p, rhs)
  }

  LinearSolveResult::Parametric(exprs, params)
}
