///|
priv struct RatForm {
  offset : @symnum.BigRational
  coeffs : Map[Int, @symnum.BigRational]
}

///|
priv struct VarLabel {
  dual : Bool
  idx : Int
}

///|
priv struct VarTransform {
  offset : @symnum.BigRational
  coeffs : Map[Int, @symnum.BigRational]
}

///|
fn rat_zero() -> @symnum.BigRational {
  @symnum.BigRational::zero()
}

///|
fn rat_one() -> @symnum.BigRational {
  @symnum.BigRational::one()
}

///|
fn rat_from_int(value : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(value)
}

///|
fn rat_from_expr(
  expr : Expr,
  context : String,
) -> @symnum.BigRational raise SolverError {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) =>
      @symnum.BigRational::new(num, den) catch {
        _ => raise ValueError(context + ": invalid rational")
      }
    None => raise ValueError(context + ": expected exact numeric value")
  }
}

///|
fn rat_to_expr(value : @symnum.BigRational) -> Expr {
  Number(value)
}

///|
fn rat_neg(value : @symnum.BigRational) -> @symnum.BigRational {
  value.neg_r()
}

///|
fn rat_sub(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> @symnum.BigRational {
  lhs.add_r(rhs.neg_r())
}

///|
fn rat_div(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
  context : String,
) -> @symnum.BigRational raise SolverError {
  lhs.div_r(rhs) catch {
    _ => raise ValueError(context + ": division by zero")
  }
}

///|
fn rat_is_negative(value : @symnum.BigRational) -> Bool {
  value.compare(rat_zero()) < 0
}

///|
fn rat_is_positive(value : @symnum.BigRational) -> Bool {
  value.compare(rat_zero()) > 0
}

///|
fn rat_min(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> @symnum.BigRational {
  if lhs.compare(rhs) <= 0 {
    lhs
  } else {
    rhs
  }
}

///|
fn rat_max(
  lhs : @symnum.BigRational,
  rhs : @symnum.BigRational,
) -> @symnum.BigRational {
  if lhs.compare(rhs) >= 0 {
    lhs
  } else {
    rhs
  }
}

///|
fn label_lt(a : VarLabel, b : VarLabel) -> Bool {
  if a.dual != b.dual {
    !a.dual && b.dual
  } else {
    a.idx < b.idx
  }
}

///|
fn add_sparse_coeff(
  coeffs : Map[Int, @symnum.BigRational],
  idx : Int,
  value : @symnum.BigRational,
) -> Unit {
  if value.is_zero() {
    return
  }
  match coeffs.get(idx) {
    Some(existing) => {
      let next = existing.add_r(value)
      if next.is_zero() {
        coeffs.remove(idx)
      } else {
        coeffs[idx] = next
      }
    }
    None => coeffs[idx] = value
  }
}

///|
fn sparse_count(coeffs : Map[Int, @symnum.BigRational]) -> Int {
  let mut count = 0
  for _, value in coeffs {
    if !value.is_zero() {
      count += 1
    }
  }
  count
}

///|
fn sparse_first(
  coeffs : Map[Int, @symnum.BigRational],
) -> (Int, @symnum.BigRational)? {
  for idx, value in coeffs {
    if !value.is_zero() {
      return Some((idx, value))
    }
  }
  None
}

///|
fn dense_row_from_sparse(
  coeffs : Map[Int, @symnum.BigRational],
  width : Int,
) -> Array[@symnum.BigRational] {
  let row = Array::makei(width, _ => rat_zero())
  for idx, value in coeffs {
    row[idx] = value
  }
  row
}

///|
fn linear_form_from_expr(
  expr : Expr,
  names : Array[String],
  context : String,
) -> RatForm raise SolverError {
  let (coeff_maps, const_terms) = @sympolys._linear_eq_to_dict([expr], names) catch {
    err => raise wrap_poly_error(context, err)
  }
  let coeffs : Map[Int, @symnum.BigRational] = Map([])
  for i in 0..<names.length() {
    match coeff_maps[0].get(names[i]) {
      Some(value) => add_sparse_coeff(coeffs, i, rat_from_expr(value, context))
      None => ()
    }
  }
  { offset: rat_from_expr(const_terms[0], context), coeffs }
}

///|
fn bool_constraint_value(expr : Expr) -> Bool? {
  match expr {
    Boolean(value) => Some(value)
    _ => @symcore.bool_value(expr)
  }
}

///|
fn constraint_forms(
  constraint : Expr,
  names : Array[String],
  context : String,
) -> Array[RatForm] raise SolverError {
  match bool_constraint_value(constraint) {
    Some(true) => return []
    Some(false) => raise InfeasibleLPError("Inconsistent/False constraint")
    None => ()
  }
  match @symcore.relational_parts(constraint) {
    Some((Le, lhs, rhs)) =>
      [
        linear_form_from_expr(
          @symcore.add([lhs, negate_expr(rhs)]),
          names,
          context,
        ),
      ]
    Some((Ge, lhs, rhs)) =>
      [
        linear_form_from_expr(
          @symcore.add([rhs, negate_expr(lhs)]),
          names,
          context,
        ),
      ]
    Some((Eq, lhs, rhs)) =>
      [
        linear_form_from_expr(
          @symcore.add([lhs, negate_expr(rhs)]),
          names,
          context,
        ),
        linear_form_from_expr(
          @symcore.add([rhs, negate_expr(lhs)]),
          names,
          context,
        ),
      ]
    Some(_) =>
      raise ValueError(
        context + ": only Eq, <= and >= constraints are supported",
      )
    None =>
      raise ValueError(context + ": expected a relational linear constraint")
  }
}

///|
fn matrix_row_rationals(
  matrix : Matrix,
  row : Int,
  context : String,
) -> Array[@symnum.BigRational] raise SolverError {
  let out : Array[@symnum.BigRational] = []
  let items = matrix.row(row) catch {
    err => raise wrap_matrix_error(context, err)
  }
  for item in items {
    out.push(rat_from_expr(item, context))
  }
  out
}

///|
fn pivot_tableau(
  matrix : Array[Array[@symnum.BigRational]],
  i : Int,
  j : Int,
) -> Array[Array[@symnum.BigRational]] raise SolverError {
  let rows = matrix.length()
  let cols = matrix[0].length()
  let pivot = matrix[i][j]
  if pivot.is_zero() {
    raise ValueError("simplex: zero pivot")
  }
  let out : Array[Array[@symnum.BigRational]] = Array::new()
  for _ in 0..<rows {
    let row : Array[@symnum.BigRational] = Array::makei(cols, _ => rat_zero())
    out.push(row)
  }
  for r in 0..<rows {
    for c in 0..<cols {
      out[r][c] = rat_sub(
        matrix[r][c],
        rat_div(matrix[r][j].mul_r(matrix[i][c]), pivot, "simplex pivot"),
      )
    }
  }
  for c in 0..<cols {
    out[i][c] = rat_div(matrix[i][c], pivot, "simplex pivot row")
  }
  for r in 0..<rows {
    out[r][j] = rat_neg(rat_div(matrix[r][j], pivot, "simplex pivot col"))
  }
  out[i][j] = rat_div(rat_one(), pivot, "simplex pivot inverse")
  out
}

///|
fn choose_pivot_row(
  a : Array[Array[@symnum.BigRational]],
  b : Array[@symnum.BigRational],
  candidate_rows : Array[Int],
  pivot_col : Int,
  y : Array[VarLabel],
) -> Int raise SolverError {
  let mut best = candidate_rows[0]
  let mut best_ratio = rat_div(b[best], a[best][pivot_col], "simplex ratio")
  for idx in 1..<candidate_rows.length() {
    let row = candidate_rows[idx]
    let ratio = rat_div(b[row], a[row][pivot_col], "simplex ratio")
    let cmp = ratio.compare(best_ratio)
    if cmp < 0 || (cmp == 0 && label_lt(y[row], y[best])) {
      best = row
      best_ratio = ratio
    }
  }
  best
}

///|
fn row_prefix(
  row : Array[@symnum.BigRational],
  width : Int,
) -> Array[@symnum.BigRational] {
  let out : Array[@symnum.BigRational] = []
  for i in 0..<width {
    out.push(row[i])
  }
  out
}

///|
fn tableau_coeffs(
  tableau : Array[Array[@symnum.BigRational]],
  width : Int,
) -> Array[Array[@symnum.BigRational]] {
  let out : Array[Array[@symnum.BigRational]] = []
  for row in tableau {
    out.push(row_prefix(row, width))
  }
  out
}

///|
fn tableau_rhs(
  tableau : Array[Array[@symnum.BigRational]],
  rhs_col : Int,
) -> Array[@symnum.BigRational] {
  let out : Array[@symnum.BigRational] = []
  for row in tableau {
    out.push(row[rhs_col])
  }
  out
}

///|
fn simplex_nonnegative_min(
  a_input : Array[Array[@symnum.BigRational]],
  b_input : Array[@symnum.BigRational],
  c_input : Array[@symnum.BigRational],
  d_input : @symnum.BigRational,
) -> (@symnum.BigRational, Array[@symnum.BigRational]) raise SolverError {
  let m = a_input.length()
  let n = c_input.length()
  let tableau : Array[Array[@symnum.BigRational]] = []
  for i in 0..<m {
    let row = a_input[i].copy()
    row.push(b_input[i])
    tableau.push(row)
  }
  let last = c_input.copy()
  last.push(d_input)
  tableau.push(last)

  let xlabels : Array[VarLabel] = []
  for j in 0..<n {
    xlabels.push({ dual: false, idx: j })
  }
  let ylabels : Array[VarLabel] = []
  for i in 0..<m {
    ylabels.push({ dual: true, idx: i })
  }

  while true {
    let mut k = -1
    for i in 0..<m {
      if rat_is_negative(tableau[i][n]) {
        k = i
        break
      }
    }
    if k < 0 {
      break
    }
    let candidate_cols : Array[Int] = []
    for j in 0..<n {
      if rat_is_negative(tableau[k][j]) {
        candidate_cols.push(j)
      }
    }
    if candidate_cols.is_empty() {
      raise InfeasibleLPError("The constraint set is empty!")
    }
    let mut c = candidate_cols[0]
    for idx in 1..<candidate_cols.length() {
      let cand = candidate_cols[idx]
      if label_lt(xlabels[cand], xlabels[c]) {
        c = cand
      }
    }
    let candidate_rows : Array[Int] = []
    for i in 0..<m {
      if rat_is_positive(tableau[i][c]) &&
        tableau[i][n].compare(rat_zero()) >= 0 {
        candidate_rows.push(i)
      }
    }
    candidate_rows.push(k)
    let r = choose_pivot_row(
      tableau_coeffs(tableau, n),
      tableau_rhs(tableau, n),
      candidate_rows,
      c,
      ylabels,
    )
    let next = pivot_tableau(tableau, r, c)
    for i in 0..<tableau.length() {
      tableau[i] = next[i]
    }
    let tmp = xlabels[c]
    xlabels[c] = ylabels[r]
    ylabels[r] = tmp
  }

  while true {
    let candidate_cols : Array[Int] = []
    for j in 0..<n {
      if rat_is_negative(tableau[m][j]) {
        candidate_cols.push(j)
      }
    }
    if candidate_cols.is_empty() {
      break
    }
    let mut c = candidate_cols[0]
    for idx in 1..<candidate_cols.length() {
      let cand = candidate_cols[idx]
      if label_lt(xlabels[cand], xlabels[c]) {
        c = cand
      }
    }
    let candidate_rows : Array[Int] = []
    for i in 0..<m {
      if rat_is_positive(tableau[i][c]) {
        candidate_rows.push(i)
      }
    }
    if candidate_rows.is_empty() {
      raise UnboundedLPError(
        "Objective function can assume arbitrarily large values!",
      )
    }
    let r = choose_pivot_row(
      tableau_coeffs(tableau, n),
      tableau_rhs(tableau, n),
      candidate_rows,
      c,
      ylabels,
    )
    let next = pivot_tableau(tableau, r, c)
    for i in 0..<tableau.length() {
      tableau[i] = next[i]
    }
    let tmp = xlabels[c]
    xlabels[c] = ylabels[r]
    ylabels[r] = tmp
  }

  let solution = Array::makei(n, _ => rat_zero())
  for i in 0..<m {
    if !ylabels[i].dual {
      solution[ylabels[i].idx] = tableau[i][n]
    }
  }
  (rat_neg(tableau[m][n]), solution)
}

///|
fn normalize_bounds(
  bounds : Array[(Expr?, Expr?)]?,
  count : Int,
  default_nonnegative : Bool,
  context : String,
) -> Array[(@symnum.BigRational?, @symnum.BigRational?)] raise SolverError {
  let out : Array[(@symnum.BigRational?, @symnum.BigRational?)] = []
  if bounds is None {
    for _ in 0..<count {
      out.push(
        if default_nonnegative {
          (Some(rat_zero()), None)
        } else {
          (None, None)
        },
      )
    }
    return out
  }
  let items = bounds.unwrap()
  if items.length() != count {
    raise ShapeError(context + ": bounds length mismatch")
  }
  for item in items {
    let lower = item.0.map(value => rat_from_expr(value, context))
    let upper = item.1.map(value => rat_from_expr(value, context))
    out.push((lower, upper))
  }
  out
}

///|
fn update_lower_bound(
  current : @symnum.BigRational?,
  next : @symnum.BigRational,
) -> @symnum.BigRational {
  match current {
    Some(value) => rat_max(value, next)
    None => next
  }
}

///|
fn update_upper_bound(
  current : @symnum.BigRational?,
  next : @symnum.BigRational,
) -> @symnum.BigRational {
  match current {
    Some(value) => rat_min(value, next)
    None => next
  }
}

///|
fn build_var_transforms(
  bounds : Array[(@symnum.BigRational?, @symnum.BigRational?)],
) -> (Array[VarTransform], Int, Array[RatForm]) raise SolverError {
  let transforms : Array[VarTransform] = []
  let extra_constraints : Array[RatForm] = []
  let mut next_var = 0
  for i in 0..<bounds.length() {
    let (lower, upper) = bounds[i]
    match (lower, upper) {
      (Some(lo), Some(hi)) if lo.compare(hi) > 0 =>
        raise InfeasibleLPError("inconsistent bounds")
      _ => ()
    }
    match (lower, upper) {
      (Some(lo), None) =>
        if lo.is_zero() {
          let coeffs : Map[Int, @symnum.BigRational] = Map([])
          coeffs[next_var] = rat_one()
          transforms.push({ offset: rat_zero(), coeffs })
          next_var += 1
        } else {
          let coeffs : Map[Int, @symnum.BigRational] = Map([])
          coeffs[next_var] = rat_one()
          transforms.push({ offset: lo, coeffs })
          next_var += 1
        }
      (None, Some(hi)) => {
        let coeffs : Map[Int, @symnum.BigRational] = Map([])
        coeffs[next_var] = rat_from_int(-1)
        transforms.push({ offset: hi, coeffs })
        next_var += 1
      }
      (Some(lo), Some(hi)) => {
        let coeffs : Map[Int, @symnum.BigRational] = Map([])
        coeffs[next_var] = rat_one()
        transforms.push({ offset: lo, coeffs })
        let ub_coeffs : Map[Int, @symnum.BigRational] = Map([])
        ub_coeffs[next_var] = rat_one()
        extra_constraints.push({ offset: rat_sub(lo, hi), coeffs: ub_coeffs })
        next_var += 1
      }
      (None, None) => {
        let coeffs : Map[Int, @symnum.BigRational] = Map([])
        coeffs[next_var] = rat_one()
        coeffs[next_var + 1] = rat_from_int(-1)
        transforms.push({ offset: rat_zero(), coeffs })
        next_var += 2
      }
    }
  }
  (transforms, next_var, extra_constraints)
}

///|
fn substitute_form(form : RatForm, transforms : Array[VarTransform]) -> RatForm {
  let coeffs : Map[Int, @symnum.BigRational] = Map([])
  let mut offset = form.offset
  for idx, value in form.coeffs {
    let tr = transforms[idx]
    offset = offset.add_r(value.mul_r(tr.offset))
    for z_idx, z_coeff in tr.coeffs {
      add_sparse_coeff(coeffs, z_idx, value.mul_r(z_coeff))
    }
  }
  { offset, coeffs }
}

///|
fn optimize_forms(
  objective : RatForm,
  constraints : Array[RatForm],
  bounds : Array[(@symnum.BigRational?, @symnum.BigRational?)],
) -> (@symnum.BigRational, Array[@symnum.BigRational], Array[VarTransform]) raise SolverError {
  let (transforms, z_count, extra_constraints) = build_var_transforms(bounds)
  let objective_z = substitute_form(objective, transforms)
  let rows : Array[RatForm] = []
  for item in constraints {
    rows.push(substitute_form(item, transforms))
  }
  for item in extra_constraints {
    rows.push(item)
  }
  let a : Array[Array[@symnum.BigRational]] = []
  let b : Array[@symnum.BigRational] = []
  for row in rows {
    a.push(dense_row_from_sparse(row.coeffs, z_count))
    b.push(rat_neg(row.offset))
  }
  let c = dense_row_from_sparse(objective_z.coeffs, z_count)
  let (value, solution) = simplex_nonnegative_min(
    a,
    b,
    c,
    rat_neg(objective_z.offset),
  )
  (value, solution, transforms)
}

///|
fn recover_original_values(
  solution : Array[@symnum.BigRational],
  transforms : Array[VarTransform],
) -> Array[@symnum.BigRational] {
  let out : Array[@symnum.BigRational] = []
  for tr in transforms {
    let mut value = tr.offset
    for idx, coeff in tr.coeffs {
      value = value.add_r(coeff.mul_r(solution[idx]))
    }
    out.push(value)
  }
  out
}

///|
fn objective_form_from_array(
  coeffs : Array[Expr],
  context : String,
) -> RatForm raise SolverError {
  let map : Map[Int, @symnum.BigRational] = Map([])
  for i in 0..<coeffs.length() {
    add_sparse_coeff(map, i, rat_from_expr(coeffs[i], context))
  }
  { offset: rat_zero(), coeffs: map }
}

///|
fn forms_from_matrix_rows(
  matrix : Matrix,
  rhs : Array[Expr],
  context : String,
) -> Array[RatForm] raise SolverError {
  if matrix.rows != rhs.length() {
    raise ShapeError(context + ": rhs length mismatch")
  }
  let out : Array[RatForm] = []
  for i in 0..<matrix.rows {
    let coeffs = matrix_row_rationals(matrix, i, context)
    let map : Map[Int, @symnum.BigRational] = Map([])
    for j in 0..<coeffs.length() {
      add_sparse_coeff(map, j, coeffs[j])
    }
    out.push({ offset: rat_neg(rat_from_expr(rhs[i], context)), coeffs: map })
  }
  out
}

///|
fn negate_form(form : RatForm) -> RatForm {
  let coeffs : Map[Int, @symnum.BigRational] = Map([])
  for idx, value in form.coeffs {
    coeffs[idx] = value.neg_r()
  }
  { offset: form.offset.neg_r(), coeffs }
}

///|
/// Solve a linear program in matrix form.
///
/// `c` is the objective vector, `a/b` encode inequality rows, `a_eq/b_eq`
/// encode equality rows, and `bounds` stores per-variable lower/upper bounds.
/// The result is `(optimal_value, primal_solution_vector)`.
pub fn linprog(
  c : Array[Expr],
  a? : Matrix? = None,
  b? : Array[Expr]? = None,
  a_eq? : Matrix? = None,
  b_eq? : Array[Expr]? = None,
  bounds? : Array[(Expr?, Expr?)]? = None,
) -> (Expr, Array[Expr]) raise SolverError {
  let objective = objective_form_from_array(c, "linprog")
  let constraints : Array[RatForm] = []
  let var_count = c.length()
  match (a, b) {
    (Some(matrix), Some(rhs)) => {
      if matrix.cols != var_count {
        raise ShapeError("linprog: A and c dimension mismatch")
      }
      for row in forms_from_matrix_rows(matrix, rhs, "linprog") {
        constraints.push(row)
      }
    }
    (None, None) => ()
    _ => raise ShapeError("linprog: A and b must both be given")
  }
  match (a_eq, b_eq) {
    (Some(matrix), Some(rhs)) => {
      if matrix.cols != var_count {
        raise ShapeError("linprog: A_eq and c dimension mismatch")
      }
      let rows = forms_from_matrix_rows(matrix, rhs, "linprog")
      for row in rows {
        constraints.push(row)
        constraints.push(negate_form(row))
      }
    }
    (None, None) => ()
    _ => raise ShapeError("linprog: A_eq and b_eq must both be given")
  }
  let normalized_bounds = normalize_bounds(bounds, var_count, true, "linprog")
  let (value, solution, transforms) = optimize_forms(
    objective, constraints, normalized_bounds,
  )
  let original = recover_original_values(solution, transforms)
  (rat_to_expr(value), original.map(rat_to_expr))
}

///|
fn extract_bound_from_form(
  form : RatForm,
  bounds : Array[(@symnum.BigRational?, @symnum.BigRational?)],
) -> Bool raise SolverError {
  let count = sparse_count(form.coeffs)
  if count == 0 {
    return form.offset.compare(rat_zero()) <= 0
  }
  if count != 1 {
    return false
  }
  match sparse_first(form.coeffs) {
    Some((idx, coeff)) => {
      let value = rat_div(rat_neg(form.offset), coeff, "lp bound")
      let current = bounds[idx]
      if rat_is_positive(coeff) {
        bounds[idx] = (current.0, Some(update_upper_bound(current.1, value)))
      } else {
        bounds[idx] = (Some(update_lower_bound(current.0, value)), current.1)
      }
      true
    }
    None => false
  }
}

///|
fn collect_lp_symbols(
  objective : Expr,
  constraints : Array[Expr],
) -> Array[Expr] raise SolverError {
  let items : Array[Expr] = @symcore.free_symbols(objective)
  for constraint in constraints {
    for symbol in @symcore.free_symbols(constraint) {
      items.push(symbol)
    }
  }
  sorted_unique_symbols(items)
}

///|
fn objective_linear_form(
  objective : Expr,
  names : Array[String],
) -> RatForm raise SolverError {
  linear_form_from_expr(objective, names, "lp objective")
}

///|
fn lp_extreme(
  objective : Expr,
  constraints : Array[Expr],
  maximize : Bool,
) -> (Expr, Map[String, Expr]) raise SolverError {
  let symbols = collect_lp_symbols(objective, constraints)
  let names = symbol_names(symbols)
  let objective_form = objective_linear_form(objective, names)
  let bounds = Array::makei(symbols.length(), _ => (None, None))
  let rows : Array[RatForm] = []
  for constraint in constraints {
    let forms = constraint_forms(constraint, names, "lp constraint")
    for form in forms {
      let used_as_bound = extract_bound_from_form(form, bounds) catch {
        err => raise err
      }
      if !used_as_bound {
        rows.push(form)
      }
    }
  }
  for i in 0..<bounds.length() {
    match bounds[i] {
      (Some(lo), Some(hi)) if lo.compare(hi) > 0 =>
        raise InfeasibleLPError("Inconsistent/False constraint")
      _ => ()
    }
  }
  let target = if maximize {
    negate_form(objective_form)
  } else {
    objective_form
  }
  let (value, solution, transforms) = optimize_forms(target, rows, bounds)
  let primal = recover_original_values(solution, transforms)
  let out : Map[String, Expr] = Map([])
  for i in 0..<names.length() {
    out[names[i]] = rat_to_expr(primal[i])
  }
  let final_value = if maximize { rat_neg(value) } else { value }
  (rat_to_expr(final_value), out)
}

///|
/// Minimize a linear objective given symbolic inequality constraints.
///
/// Constraints are given in the public `lpmin/lpmax` front-door style, such as
/// `x >= 0` or `x + y <= 2`. The result is the optimal value together with a
/// map from symbol names to primal values.
pub fn lpmin(
  objective : Expr,
  constraints : Array[Expr],
) -> (Expr, Map[String, Expr]) raise SolverError {
  lp_extreme(objective, constraints, false)
}

///|
/// Maximize a linear objective given symbolic inequality constraints.
///
/// This is the maximization counterpart of [`lpmin`](#lpmin).
pub fn lpmax(
  objective : Expr,
  constraints : Array[Expr],
) -> (Expr, Map[String, Expr]) raise SolverError {
  lp_extreme(objective, constraints, true)
}
