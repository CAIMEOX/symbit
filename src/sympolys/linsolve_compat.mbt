///|
pub enum LinearSolveResult {
  NoSolution
  Unique(Array[FieldElem])
  Parametric(Array[Expr], Array[String])
}

///|
/// Build the sparse augmented matrix used by SymPy's matrix-based linsolve path.
pub fn sympy_dict_to_dm(
  eqs_coeffs : Array[Map[String, Expr]],
  eqs_rhs : Array[Expr],
  syms : Array[String],
) -> SDM raise PolyError {
  if eqs_coeffs.length() != eqs_rhs.length() {
    raise PolyError::DomainMismatch
  }
  let sym2index : Map[String, Int] = Map::new()
  for i in 0..<syms.length() {
    sym2index[syms[i]] = i
  }
  let expr_rows : Array[Array[(Int, Expr)]] = Array::new()
  let flat_exprs : Array[Expr] = Array::new()
  for i in 0..<eqs_coeffs.length() {
    let row_items : Array[(Int, Expr)] = Array::new()
    for sym, coeff in eqs_coeffs[i] {
      match sym2index.get(sym) {
        Some(col) => {
          row_items.push((col, coeff))
          flat_exprs.push(coeff)
        }
        None => raise PolyError::DomainMismatch
      }
    }
    let neg_rhs = int(0) - eqs_rhs[i]
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
fn expr_is_zero(expr : Expr) -> Bool {
  match expr {
    Expr::Number(q) => q.is_zero()
    _ => false
  }
}

///|
fn expr_has_floating_leaf(expr : Expr) -> Bool {
  match expr {
    Expr::Float(_) | Expr::ComplexFloat(_) => true
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) =>
      args.any(expr_has_floating_leaf)
    Expr::Pow(base, exp) =>
      expr_has_floating_leaf(base) || expr_has_floating_leaf(exp)
    _ => false
  }
}

///|
fn linsolve_numeric_prec_expr(expr : Expr) -> Int {
  match @symcore.number_symbol_kind(expr) {
    Some(
      @symcore.NumberSymbolKind::ImaginaryUnit
      | @symcore.NumberSymbolKind::Pi
      | @symcore.NumberSymbolKind::Exp1
      | @symcore.NumberSymbolKind::EulerGamma
      | @symcore.NumberSymbolKind::GoldenRatio
      | @symcore.NumberSymbolKind::Catalan
    ) => 80
    _ =>
      match expr {
        Expr::Float(f) => f.precision()
        Expr::ComplexFloat(z) => z.precision()
        Expr::Number(_) => 80
        Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) => {
          let mut best = 0
          for arg in args {
            let p = linsolve_numeric_prec_expr(arg)
            if p > best {
              best = p
            }
          }
          best
        }
        Expr::Pow(base, exp) => {
          let pb = linsolve_numeric_prec_expr(base)
          let pe = linsolve_numeric_prec_expr(exp)
          if pb > pe {
            pb
          } else {
            pe
          }
        }
        _ => 0
      }
  }
}

///|
fn linsolve_expr_to_complex(expr : Expr, prec : Int) -> @symcore.ComplexFloat? {
  match @symcore.evalf(expr, prec~) {
    Expr::Number(n) =>
      Some(
        @symcore.ComplexFloat::from_exact_parts(
          n,
          @symnum.BigRational::zero(),
          prec~,
        ),
      )
    Expr::Float(f) => Some(@symcore.ComplexFloat::from_real(f))
    Expr::ComplexFloat(z) => Some(z)
    _ => None
  }
}

///|
fn linsolve_complex_to_expr(value : @symcore.ComplexFloat) -> Expr {
  if @symnum.is_zero(value.to_mpc().imag) {
    @symcore.Expr::Float(value.real_part())
  } else {
    @symcore.Expr::ComplexFloat(value)
  }
}

///|
fn linsolve_complex_zero(value : @symcore.ComplexFloat, prec : Int) -> Bool {
  let tol_exp = if prec / 2 > 4 { -(prec / 2) } else { -4 }
  let tol = @symnum.from_man_exp(1N, tol_exp, prec~, rnd=@symnum.round_nearest)
  let abs = @symnum.mpc_abs(value.to_mpc(), prec, @symnum.round_nearest)
  @symnum.mpf_cmp(abs, tol) <= 0
}

///|
priv enum NumericExprLinsolveResult {
  Unsupported
  NoSolution
  Unique(Map[String, Expr])
}

///|
fn numeric_expr_linsolve(
  eqs_coeffs : Array[Map[String, Expr]],
  eqs_rhs : Array[Expr],
  syms : Array[String],
) -> NumericExprLinsolveResult {
  if eqs_coeffs.length() != eqs_rhs.length() ||
    eqs_coeffs.length() < syms.length() {
    return NumericExprLinsolveResult::Unsupported
  }
  let mut has_floating = false
  for row in eqs_coeffs {
    for _, coeff in row {
      if expr_has_floating_leaf(coeff) {
        has_floating = true
      }
    }
  }
  for rhs in eqs_rhs {
    if expr_has_floating_leaf(rhs) {
      has_floating = true
    }
  }
  if !has_floating {
    return NumericExprLinsolveResult::Unsupported
  }
  let mut prec = 80
  for row in eqs_coeffs {
    for _, coeff in row {
      let p = linsolve_numeric_prec_expr(coeff)
      if p > prec {
        prec = p
      }
    }
  }
  for rhs in eqs_rhs {
    let p = linsolve_numeric_prec_expr(rhs)
    if p > prec {
      prec = p
    }
  }
  let mat : Array[Array[@symcore.ComplexFloat]] = Array::new()
  for i in 0..<eqs_coeffs.length() {
    let row : Array[@symcore.ComplexFloat] = Array::new()
    for sym in syms {
      let expr = match eqs_coeffs[i].get(sym) {
        Some(coeff) => coeff
        None => int(0)
      }
      match linsolve_expr_to_complex(expr, prec) {
        Some(value) => row.push(value)
        None => return NumericExprLinsolveResult::Unsupported
      }
    }
    match linsolve_expr_to_complex(int(0) - eqs_rhs[i], prec) {
      Some(value) => row.push(value)
      None => return NumericExprLinsolveResult::Unsupported
    }
    mat.push(row)
  }
  let m = mat.length()
  let n = syms.length()
  let mut row = 0
  let pivots : Array[Int] = Array::new()
  for col in 0..<n {
    if row >= m {
      break
    }
    let mut pivot = row
    let mut pivot_measure = @symnum.mpc_abs(
      mat[row][col].to_mpc(),
      prec,
      @symnum.round_nearest,
    )
    for candidate in (row + 1)..<m {
      let measure = @symnum.mpc_abs(
        mat[candidate][col].to_mpc(),
        prec,
        @symnum.round_nearest,
      )
      if @symnum.mpf_cmp(measure, pivot_measure) > 0 {
        pivot = candidate
        pivot_measure = measure
      }
    }
    if linsolve_complex_zero(mat[pivot][col], prec) {
      continue
    }
    if pivot != row {
      let tmp = mat[row]
      mat[row] = mat[pivot]
      mat[pivot] = tmp
    }
    let pivot_inv = mat[row][col].reciprocal()
    for j in col..<=n {
      mat[row][j] = mat[row][j] * pivot_inv
    }
    for i in 0..<m {
      if i == row || linsolve_complex_zero(mat[i][col], prec) {
        continue
      }
      let factor = mat[i][col]
      for j in col..<=n {
        mat[i][j] = mat[i][j] + -(factor * mat[row][j])
      }
    }
    pivots.push(col)
    row += 1
  }
  for i in 0..<m {
    let mut all_zero = true
    for j in 0..<n {
      if !linsolve_complex_zero(mat[i][j], prec) {
        all_zero = false
        break
      }
    }
    if all_zero && !linsolve_complex_zero(mat[i][n], prec) {
      return NumericExprLinsolveResult::NoSolution
    }
  }
  if pivots.length() != n {
    return NumericExprLinsolveResult::Unsupported
  }
  let sol : Map[String, Expr] = Map::new()
  for i in 0..<n {
    sol[syms[pivots[i]]] = linsolve_complex_to_expr(mat[i][n])
  }
  NumericExprLinsolveResult::Unique(sol)
}

///|
fn expr_depends_on_syms(expr : Expr, symset : Map[String, Bool]) -> Bool {
  match expr {
    Expr::Symbol(name) => symset.get(name) is Some(_)
    Expr::Add(args) | Expr::Mul(args) =>
      args.any(child => expr_depends_on_syms(child, symset))
    Expr::Pow(base, exp) =>
      expr_depends_on_syms(base, symset) || expr_depends_on_syms(exp, symset)
    Expr::Function(_, args) =>
      args.any(child => expr_depends_on_syms(child, symset))
    _ => false
  }
}

///|
fn add_linear_coeff(
  terms : Map[String, Expr],
  sym : String,
  coeff : Expr,
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
  terms : Map[String, Expr],
  scale : Expr,
) -> Map[String, Expr] {
  let out : Map[String, Expr] = Map::new()
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
  expr : Expr,
  symset : Map[String, Bool],
) -> (Expr, Map[String, Expr]) raise PolyError {
  match expr {
    Expr::Symbol(name) =>
      if symset.get(name) is Some(_) {
        let terms : Map[String, Expr] = Map::new()
        terms[name] = int(1)
        (int(0), terms)
      } else {
        (expr, {})
      }
    Expr::Add(args) => {
      let coeff_terms : Map[String, Expr] = Map::new()
      let const_terms : Array[Expr] = Array::new()
      for arg in args {
        let (const_part, terms_part) = lin_eq2dict_impl(arg, symset)
        const_terms.push(const_part)
        for sym, coeff in terms_part {
          add_linear_coeff(coeff_terms, sym, coeff)
        }
      }
      (@symcore.add(const_terms), coeff_terms)
    }
    Expr::Mul(args) => {
      let coeff_factors : Array[Expr] = Array::new()
      let mut linear_const = int(1)
      let mut linear_terms : Map[String, Expr]? = None
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
    Expr::Pow(base, exp) =>
      match exp {
        Expr::Number(n) if n.is_zero() => (int(1), {})
        Expr::Number(n) if n.is_one() => lin_eq2dict_impl(base, symset)
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
fn _lin_eq2dict(
  expr : Expr,
  syms : Array[String],
) -> (Expr, Map[String, Expr]) raise PolyError {
  lin_eq2dict_impl(expr, linsolve_symset(syms))
}

///|
/// Convert Expr/Eq equations into coefficient dicts plus symbol-free terms.
pub fn _linear_eq_to_dict(
  eqs : Array[Expr],
  syms : Array[String],
) -> (Array[Map[String, Expr]], Array[Expr]) raise PolyError {
  let symset = linsolve_symset(syms)
  let coeffs : Array[Map[String, Expr]] = Array::new()
  let ind : Array[Expr] = Array::new()
  for eq in eqs {
    match @symcore.relational_parts(eq) {
      Some((@symcore.RelOp::Eq, lhs, rhs)) => {
        let (lhs_const, lhs_terms) = lin_eq2dict_impl(lhs, symset)
        let (rhs_const, rhs_terms) = lin_eq2dict_impl(rhs, symset)
        let merged : Map[String, Expr] = Map::new()
        for sym, coeff in lhs_terms {
          add_linear_coeff(merged, sym, coeff)
        }
        for sym, coeff in rhs_terms {
          add_linear_coeff(merged, sym, int(0) - coeff)
        }
        coeffs.push(merged)
        ind.push(lhs_const - rhs_const)
      }
      Some(_) => raise PolyError::NonPolynomial
      None => {
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
  eqs : Array[Expr],
  syms : Array[String],
) -> Map[String, Expr]? raise PolyError {
  let nsyms = syms.length()
  let (eqsdict, const_terms) = _linear_eq_to_dict(eqs, syms)
  match numeric_expr_linsolve(eqsdict, const_terms, syms) {
    NumericExprLinsolveResult::NoSolution => return None
    NumericExprLinsolveResult::Unique(sol) => return Some(sol)
    NumericExprLinsolveResult::Unsupported => ()
  }
  let aaug = sympy_dict_to_dm(eqsdict, const_terms, syms)
  let (arref, pivots, nzcols) = if domain_is_real_field_pred(aaug.domain()) ||
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
    arref, one, nsyms, pivots, nzcols,
  )

  let sol : Map[String, Expr] = Map::new()
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
    let free_sym = Expr::Symbol(syms[nonpivots[i]])
    let row = basis_rows[i]
    for j in 0..<nsyms {
      if !fe_is_zero(row[j]) {
        add_linear_coeff(sol, syms[j], free_sym * fe_to_expr_const(row[j]))
      }
    }
  }

  for sym in syms {
    if sol.get(sym) is None {
      sol[sym] = int(0)
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
  let free_exprs : Map[Int, Expr] = {}
  for i in 0..<free_vars.length() {
    free_exprs[free_vars[i]] = Expr::Symbol(params[i])
  }
  let exprs : Array[Expr] = Array::make(n, int(0))
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
      rhs = rhs - fe_to_expr_const(coeff) * exprs[fv]
    }
    exprs.set(p, rhs)
  }

  LinearSolveResult::Parametric(exprs, params)
}
