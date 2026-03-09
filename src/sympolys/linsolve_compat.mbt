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
fn expr_is_zero(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(q) => q.is_zero()
    _ => false
  }
}

///|
fn expr_depends_on_syms(
  expr : @symcore.Expr,
  symset : Map[String, Bool],
) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => symset.get(name) is Some(_)
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(child => expr_depends_on_syms(child, symset))
    @symcore.Expr::Pow(base, exp) =>
      expr_depends_on_syms(base, symset) || expr_depends_on_syms(exp, symset)
    @symcore.Expr::Function(_, args) =>
      args.any(child => expr_depends_on_syms(child, symset))
    _ => false
  }
}

///|
fn add_linear_coeff(
  terms : Map[String, @symcore.Expr],
  sym : String,
  coeff : @symcore.Expr,
) -> Unit {
  if expr_is_zero(coeff) {
    return
  }
  match terms.get(sym) {
    Some(current) => {
      let updated = current + coeff
      if expr_is_zero(updated) {
        ignore(terms.remove(sym))
      } else {
        terms[sym] = updated
      }
    }
    None => terms[sym] = coeff
  }
}

///|
fn scale_linear_terms(
  terms : Map[String, @symcore.Expr],
  scale : @symcore.Expr,
) -> Map[String, @symcore.Expr] {
  let out : Map[String, @symcore.Expr] = Map::new()
  if expr_is_zero(scale) {
    return out
  }
  for sym, coeff in terms {
    let value = scale * coeff
    if !expr_is_zero(value) {
      out[sym] = value
    }
  }
  out
}

///|
fn linsolve_sdm_nonzero_columns(
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
fn linsolve_symset(syms : Array[String]) -> Map[String, Bool] {
  let out : Map[String, Bool] = Map::new()
  for sym in syms {
    out[sym] = true
  }
  out
}

///|
fn lin_eq2dict_impl(
  expr : @symcore.Expr,
  symset : Map[String, Bool],
) -> (@symcore.Expr, Map[String, @symcore.Expr]) raise PolyError {
  match expr {
    @symcore.Expr::Symbol(name) =>
      if symset.get(name) is Some(_) {
        let terms : Map[String, @symcore.Expr] = Map::new()
        terms[name] = @symcore.int(1)
        (@symcore.int(0), terms)
      } else {
        (expr, {})
      }
    @symcore.Expr::Add(args) => {
      let coeff_terms : Map[String, @symcore.Expr] = Map::new()
      let const_terms : Array[@symcore.Expr] = Array::new()
      for arg in args {
        let (const_part, terms_part) = lin_eq2dict_impl(arg, symset)
        const_terms.push(const_part)
        for sym, coeff in terms_part {
          add_linear_coeff(coeff_terms, sym, coeff)
        }
      }
      (@symcore.add(const_terms), coeff_terms)
    }
    @symcore.Expr::Mul(args) => {
      let coeff_factors : Array[@symcore.Expr] = Array::new()
      let mut linear_const = @symcore.int(1)
      let mut linear_terms : Map[String, @symcore.Expr]? = None
      for arg in args {
        let (const_part, terms_part) = lin_eq2dict_impl(arg, symset)
        if terms_part.is_empty() {
          coeff_factors.push(const_part)
          continue
        }
        match linear_terms {
          Some(_) => raise PolyError::NonPolynomial
          None => {
            linear_const = const_part
            linear_terms = Some(terms_part)
          }
        }
      }
      let coeff = @symcore.mul(coeff_factors)
      match linear_terms {
        None => (coeff, {})
        Some(terms) => (coeff * linear_const, scale_linear_terms(terms, coeff))
      }
    }
    @symcore.Expr::Pow(base, exp) =>
      match exp {
        @symcore.Expr::Number(n) if n.is_zero() => (@symcore.int(1), {})
        @symcore.Expr::Number(n) if n.is_one() => lin_eq2dict_impl(base, symset)
        _ =>
          if !expr_depends_on_syms(expr, symset) {
            (expr, {})
          } else {
            raise PolyError::NonPolynomial
          }
      }
    _ =>
      if !expr_depends_on_syms(expr, symset) {
        (expr, {})
      } else {
        raise PolyError::NonPolynomial
      }
  }
}

///|
/// Return the symbol-independent term and the nonzero linear coefficients.
pub fn _lin_eq2dict(
  expr : @symcore.Expr,
  syms : Array[String],
) -> (@symcore.Expr, Map[String, @symcore.Expr]) raise PolyError {
  lin_eq2dict_impl(expr, linsolve_symset(syms))
}

///|
/// Convert Expr/Eq equations into coefficient dicts plus symbol-free terms.
pub fn _linear_eq_to_dict(
  eqs : Array[@symcore.Expr],
  syms : Array[String],
) -> (Array[Map[String, @symcore.Expr]], Array[@symcore.Expr]) raise PolyError {
  let symset = linsolve_symset(syms)
  let coeffs : Array[Map[String, @symcore.Expr]] = Array::new()
  let ind : Array[@symcore.Expr] = Array::new()
  for eq in eqs {
    match eq {
      @symcore.Expr::Function("Eq", args) if args.length() == 2 => {
        let (lhs_const, lhs_terms) = lin_eq2dict_impl(args[0], symset)
        let (rhs_const, rhs_terms) = lin_eq2dict_impl(args[1], symset)
        let merged : Map[String, @symcore.Expr] = Map::new()
        for sym, coeff in lhs_terms {
          add_linear_coeff(merged, sym, coeff)
        }
        for sym, coeff in rhs_terms {
          add_linear_coeff(merged, sym, @symcore.int(0) - coeff)
        }
        coeffs.push(merged)
        ind.push(lhs_const - rhs_const)
      }
      @symcore.Expr::Function("Eq", _) => raise PolyError::NonPolynomial
      _ => {
        let (const_part, terms_part) = lin_eq2dict_impl(eq, symset)
        coeffs.push(terms_part)
        ind.push(const_part)
      }
    }
  }
  (coeffs, ind)
}

///|
/// Solve Expr/Eq systems using the same sparse-domain path as SymPy `_linsolve`.
pub fn _linsolve(
  eqs : Array[@symcore.Expr],
  syms : Array[String],
) -> Map[String, @symcore.Expr]? raise PolyError {
  let nsyms = syms.length()
  let (eqsdict, const_terms) = _linear_eq_to_dict(eqs, syms)
  let aaug = sympy_dict_to_dm(eqsdict, const_terms, syms)
  let (arref, pivots, nzcols) = if
    domain_is_real_field_pred(aaug.domain()) ||
    domain_is_complex_field_pred(aaug.domain()) {
    let (dense_rref, dense_pivots) = aaug.to_dense().rref()
    let sparse_rref = dense_rref.to_sdm()
    (
      sparse_rref,
      dense_pivots,
      linsolve_sdm_nonzero_columns(sparse_rref, dense_pivots),
    )
  } else {
    sdm_irref(aaug)
  }

  if !pivots.is_empty() && pivots[pivots.length() - 1] == nsyms {
    return None
  }

  let particular = sdm_particular_from_rref(arref, nsyms + 1, pivots)
  let one = fe_from_int(1, arref.domain())
  let (nullspace, nonpivots) = sdm_nullspace_from_rref(
    arref,
    one,
    nsyms,
    pivots,
    nzcols,
  )

  let sol : Map[String, @symcore.Expr] = Map::new()
  let p_rows = particular.to_dense().to_list()
  if !p_rows.is_empty() {
    let p = p_rows[0]
    for i in 0..<nsyms {
      if !fe_is_zero(p[i]) {
        add_linear_coeff(sol, syms[i], fe_to_expr_const(p[i]))
      }
    }
  }

  let basis_rows = nullspace.to_dense().to_list()
  for i in 0..<nonpivots.length() {
    let free_sym = @symcore.symbol(syms[nonpivots[i]])
    let row = basis_rows[i]
    for j in 0..<nsyms {
      if !fe_is_zero(row[j]) {
        add_linear_coeff(sol, syms[j], free_sym * fe_to_expr_const(row[j]))
      }
    }
  }

  for sym in syms {
    if sol.get(sym) is None {
      sol[sym] = @symcore.int(0)
    }
  }

  Some(sol)
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
