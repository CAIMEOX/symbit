///|
pub enum SolveInput {
  Expr(Expr)
  Exprs(Array[Expr])
  Matrix(Matrix)
}

///|
pub enum SolveResult {
  List(Array[Expr])
  Dict(Map[String, Expr])
  Dicts(Array[Map[String, Expr]])
}

///|
pub let complexes : Set = @symsets.complexes()

///|
pub fn solve_expr_input(expr : Expr) -> SolveInput {
  SolveInput::Expr(expr)
}

///|
pub fn solve_exprs_input(exprs : Array[Expr]) -> SolveInput {
  SolveInput::Exprs(exprs)
}

///|
pub fn solve_matrix_input(matrix : Matrix) -> SolveInput {
  SolveInput::Matrix(matrix)
}

///|
fn sorted_unique_symbols(items : Array[Expr]) -> Array[Expr] raise SolverError {
  let out : Array[Expr] = []
  for item in items {
    guard item is Expr::Symbol(_) else {
      raise SolverError::ValueError("expected Symbol in solver API")
    }
    if !out.any(existing => @symcore.compare_expr(existing, item) == 0) {
      out.push(item)
    }
  }
  @symcore.sort_exprs_in_place(out)
  out
}

///|
fn normalize_equation(expr : Expr) -> Expr {
  match @symcore.relational_parts(expr) {
    Some((@symcore.RelOp::Eq, lhs, rhs)) =>
      @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])])
    _ => expr
  }
}

///|
fn normalize_equations(exprs : Array[Expr]) -> Array[Expr] {
  exprs.map(normalize_equation)
}

///|
fn infer_symbol(expr : Expr, symbol : Expr?) -> Expr raise SolverError {
  match symbol {
    Some(sym) => {
      ignore(symbol_name(sym))
      sym
    }
    None => {
      let syms = sorted_unique_symbols(@symcore.free_symbols(expr))
      if syms.length() != 1 {
        raise SolverError::ValueError(
          "symbol must be provided when the equation is not univariate",
        )
      }
      syms[0]
    }
  }
}

///|
fn solve_result_to_tuple_set(
  mappings : Array[Map[String, Expr]],
  symbols : Array[Expr],
) -> Set raise SolverError {
  let names = symbol_names(symbols)
  let tuples : Array[Expr] = []
  for mapping in mappings {
    let items : Array[Expr] = []
    for i in 0..<names.length() {
      items.push(mapping.get(names[i]).unwrap_or(symbols[i]))
    }
    tuples.push(Expr::Tuple(items))
  }
  @symsets.finite_set(tuples)
}

///|
fn finite_set_items(set : Set) -> Array[Expr]? {
  match set {
    @symsets.Set::FiniteSet(items) => Some(items)
    @symsets.Set::EmptySet => Some([])
    _ => None
  }
}

///|
fn input_equations(input : SolveInput) -> Array[Expr] {
  match input {
    SolveInput::Expr(expr) => [expr]
    SolveInput::Exprs(exprs) => exprs
    SolveInput::Matrix(matrix) => {
      let out : Array[Expr] = []
      for row in matrix.to_list() {
        for item in row {
          out.push(item)
        }
      }
      out
    }
  }
}

///|
fn expr_is_zeroish(expr : Expr) -> Bool? {
  check_zero_expr(normalize_equation(expr))
}

///|
fn negate_expr(expr : Expr) -> Expr {
  @symcore.mul([@symcore.int(-1), expr])
}

///|
fn expr_in_list(items : Array[Expr], target : Expr) -> Bool {
  items.any(item => @symcore.compare_expr(item, target) == 0)
}

///|
fn filtered_symbols(
  source : Array[Expr],
  symbols : Array[Expr],
  exclude : Array[Expr],
) -> Array[Expr] raise SolverError {
  let source_syms = sorted_unique_symbols(source)
  let requested = if symbols.is_empty() {
    source_syms
  } else {
    let asked = sorted_unique_symbols(symbols)
    let out : Array[Expr] = []
    for symbol in asked {
      if expr_in_list(source_syms, symbol) {
        out.push(symbol)
      }
    }
    out
  }
  let excluded = sorted_unique_symbols(exclude)
  let out : Array[Expr] = []
  for symbol in requested {
    if !expr_in_list(excluded, symbol) {
      out.push(symbol)
    }
  }
  out
}

///|
fn negative_power_denominator_base(expr : Expr) -> Expr? {
  match expr {
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) =>
          if num.compare(0N) < 0 && den.compare(1N) == 0 {
            Some(base)
          } else {
            None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn collect_denominator_factors(expr : Expr) -> Array[Expr] {
  let out : Array[Expr] = []
  for node in @symcore.preorder(expr) {
    match negative_power_denominator_base(node) {
      Some(base) =>
        if !out.any(item => @symcore.compare_expr(item, base) == 0) {
          out.push(base)
        }
      None => ()
    }
  }
  out
}

///|
fn linear_solution_from_matrix(num : Expr, symbol : Expr) -> (Expr, Expr)? {
  let res : Result[(Matrix, Matrix), SolverError] = try? linear_eq_to_matrix(
    [num],
    [symbol],
  )
  match res {
    Ok((lhs, rhs)) => {
      let coeff = lhs.getitem(0, 0) catch { _ => return None }
      if @symcore.is_zero(coeff) {
        return None
      }
      let rhs_value = rhs.getitem(0, 0) catch { _ => return None }
      Some(
        (
          symbol,
          canonical_expr(
            @symcore.mul([rhs_value, @symcore.pow(coeff, @symcore.int(-1))]),
          ),
        ),
      )
    }
    Err(_) => None
  }
}

///|
fn symbolic_condition_set(expr : Expr, symbol : Expr, base : Set) -> Set {
  let text = @symprint.to_string(expr) + " = 0"
  @symsets.condition_set(symbol, @symlogic.bool_symbol(text), base~)
}

///|
fn canonical_expr(expr : Expr) -> Expr {
  let normalized = @sympolys.domain_normal_expr(@sympolys.Domain::EX, expr) catch {
    _ => expr
  }
  @symsimplify.simplify(normalized)
}

///|
fn expr_in_domain(domain : Set, expr : Expr) -> Bool {
  match domain {
    @symsets.Set::Complexes => true
    _ =>
      match @symsets.contains(domain, expr) {
        @symsets.SetBool::True => true
        @symsets.SetBool::False => false
        @symsets.SetBool::Unknown =>
          match domain {
            @symsets.Set::Reals =>
              @symassume.tri_to_bool_option(@symassume.is_real(expr)).unwrap_or(
                false,
              )
            @symsets.Set::Rationals =>
              @symassume.tri_to_bool_option(@symassume.is_rational(expr)).unwrap_or(
                false,
              )
            @symsets.Set::Integers =>
              @symassume.tri_to_bool_option(@symassume.is_integer(expr)).unwrap_or(
                false,
              )
            _ => false
          }
      }
  }
}

///|
fn solve_univariate_polynomial(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set raise SolverError {
  let name = symbol_name(symbol)
  let poly = @sympolys.Poly::from_expr_defaults(normalize_equation(expr), gens=[
    name,
  ]) catch {
    err => raise wrap_poly_error("solveset", err)
  }
  let roots = @sympolys.roots(poly) catch {
    err => raise wrap_poly_error("solveset", err)
  }
  let filtered : Array[Expr] = []
  for root in roots {
    let normalized = canonical_expr(root)
    if expr_in_domain(domain, normalized) {
      filtered.push(normalized)
    }
  }
  @symsets.finite_set(filtered)
}

///|
fn merge_assignments(
  base : Map[String, Expr],
  extra : Map[String, Expr],
) -> Map[String, Expr] {
  let out : Map[String, Expr] = {}
  for key, value in base {
    out[key] = value
  }
  for key, value in extra {
    out[key] = value
  }
  out
}

///|
fn env_with_assignment(
  base : Map[String, Expr],
  name : String,
  value : Expr,
) -> Map[String, Expr] {
  let out = merge_assignments(base, {})
  out[name] = value
  out
}

///|
fn substitute_equations(
  equations : Array[Expr],
  env : Map[String, Expr],
) -> Array[Expr] {
  equations.map(eq => normalize_equation(@symcore.subst(eq, env)))
}

///|
fn drop_symbol(symbols : Array[Expr], target : Expr) -> Array[Expr] {
  let out : Array[Expr] = []
  for symbol in symbols {
    if @symcore.compare_expr(symbol, target) != 0 {
      out.push(symbol)
    }
  }
  out
}

///|
fn all_zero_equations(equations : Array[Expr]) -> Bool {
  for eq in equations {
    if expr_is_zeroish(eq) != Some(true) {
      return false
    }
  }
  true
}

///|
fn choose_univariate_basis_equation(
  basis : Array[@sympolys.Poly],
  symbols : Array[Expr],
) -> (Expr, Expr)? raise SolverError {
  for poly in basis {
    let expr = poly.to_expr()
    let frees = filtered_symbols(@symcore.free_symbols(expr), [], [])
    if frees.length() == 1 {
      let symbol = frees[0]
      if expr_in_list(symbols, symbol) {
        return Some((symbol, expr))
      }
    }
  }
  None
}

///|
fn choose_univariate_equation(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> (Expr, Expr)? raise SolverError {
  for eq in equations {
    let frees = filtered_symbols(@symcore.free_symbols(eq), [], [])
    if frees.length() == 1 {
      let symbol = frees[0]
      if expr_in_list(symbols, symbol) {
        return Some((symbol, eq))
      }
    }
  }
  None
}

///|
fn recursive_polynomial_solutions(
  equations : Array[Expr],
  symbols : Array[Expr],
  assignment : Map[String, Expr],
) -> Array[Map[String, Expr]] raise SolverError {
  let normalized = substitute_equations(equations, assignment)
  let live_eqs : Array[Expr] = []
  for eq in normalized {
    match expr_is_zeroish(eq) {
      Some(true) => ()
      Some(false) | None => live_eqs.push(eq)
    }
  }
  if live_eqs.is_empty() {
    return [assignment]
  }
  if symbols.is_empty() {
    return []
  }
  let names = symbol_names(symbols)
  let linear_try : Result[Map[String, Expr]?, @sympolys.PolyError] = try? @sympolys._linsolve(
    live_eqs, names,
  )
  match linear_try {
    Ok(Some(sol)) => return [merge_assignments(assignment, sol)]
    Ok(None) => return []
    Err(_) => ()
  }
  match choose_univariate_equation(live_eqs, symbols) {
    Some((symbol, expr)) => {
      let set = solveset(expr, symbol=Some(symbol), domain=@symsets.complexes())
      let roots = finite_set_items(set).unwrap_or([])
      let out : Array[Map[String, Expr]] = []
      let name = symbol_name(symbol)
      for root in roots {
        let next_assignment = env_with_assignment(assignment, name, root)
        let tail = recursive_polynomial_solutions(
          live_eqs,
          drop_symbol(symbols, symbol),
          next_assignment,
        )
        for sol in tail {
          out.push(sol)
        }
      }
      return out
    }
    None => ()
  }
  let basis = @sympolys.groebner_expr(
    live_eqs,
    gens=names,
    order=@sympolys.TermOrder::Lex,
  ) catch {
    err => raise wrap_poly_error("nonlinsolve", err)
  }
  match choose_univariate_basis_equation(basis, symbols) {
    Some((symbol, expr)) => {
      let set = solveset(expr, symbol=Some(symbol), domain=@symsets.complexes())
      let roots = finite_set_items(set).unwrap_or([])
      let out : Array[Map[String, Expr]] = []
      let name = symbol_name(symbol)
      for root in roots {
        let next_assignment = env_with_assignment(assignment, name, root)
        let tail = recursive_polynomial_solutions(
          live_eqs,
          drop_symbol(symbols, symbol),
          next_assignment,
        )
        for sol in tail {
          out.push(sol)
        }
      }
      out
    }
    None => if all_zero_equations(live_eqs) { [assignment] } else { [] }
  }
}

///|
fn tuple_array_from_set(set : Set) -> Array[Expr] {
  match set {
    @symsets.Set::FiniteSet(items) => items
    _ => []
  }
}

///|
pub fn solve_linear(
  lhs : Expr,
  rhs? : Expr = @symcore.int(0),
  symbols? : Array[Expr] = [],
  exclude? : Array[Expr] = [],
) -> (Expr, Expr) raise SolverError {
  let eq = normalize_equation(@symcore.add([lhs, negate_expr(rhs)]))
  let num = @sympolys.domain_numer_expr(@sympolys.Domain::EX, eq) catch {
    _ => eq
  }
  let den = @sympolys.domain_denom_expr(@sympolys.Domain::EX, eq) catch {
    _ => @symcore.int(1)
  }
  if @symcore.is_zero(num) {
    return (@symcore.int(0), @symcore.int(1))
  }
  let candidates = filtered_symbols(
    @symcore.free_symbols(num),
    symbols,
    exclude,
  )
  if candidates.is_empty() {
    return (@symcore.int(0), @symcore.int(1))
  }
  let dens = collect_denominator_factors(eq)
  for symbol in candidates {
    match linear_solution_from_matrix(num, symbol) {
      Some(solution) => {
        let (_, value) = solution
        let mut safe = true
        for factor in dens {
          if checksol(factor, symbol, value) == Some(true) {
            safe = false
            break
          }
        }
        if safe {
          return solution
        } else {
          return (@symcore.int(0), @symcore.int(0))
        }
      }
      None => ()
    }
  }
  if num is Expr::Symbol(_) {
    (@symcore.int(0), @symcore.int(0))
  } else {
    (num, den)
  }
}

///|
pub fn solveset(
  expr : Expr,
  symbol? : Expr? = None,
  domain? : Set = @symsets.complexes(),
) -> Set raise SolverError {
  let sym = infer_symbol(expr, symbol)
  let normalized = normalize_equation(expr)
  let free = filtered_symbols(@symcore.free_symbols(normalized), [], [])
  if !expr_in_list(free, sym) {
    return match expr_is_zeroish(normalized) {
      Some(true) => domain
      _ => @symsets.empty_set()
    }
  }
  let linear = solve_linear(normalized, symbols=[sym], exclude=[])
  if @symcore.compare_expr(linear.0, sym) == 0 {
    let value = linear.1
    if expr_in_domain(domain, value) {
      return @symsets.finite_set([value])
    } else {
      return @symsets.empty_set()
    }
  }
  let poly_try : Result[Set, SolverError] = try? solve_univariate_polynomial(
    normalized, sym, domain,
  )
  match poly_try {
    Ok(set) => set
    Err(_) => symbolic_condition_set(normalized, sym, domain)
  }
}

///|
pub fn nonlinsolve(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> Set raise SolverError {
  let syms = sorted_unique_symbols(symbols)
  let names = symbol_names(syms)
  let normalized = normalize_equations(equations)
  let linear_try : Result[Map[String, Expr]?, @sympolys.PolyError] = try? @sympolys._linsolve(
    normalized, names,
  )
  match linear_try {
    Ok(solution) => return tuple_solution_set(solution, syms, names)
    Err(_) => ()
  }
  let solved = recursive_polynomial_solutions(normalized, syms, {})
  solve_result_to_tuple_set(solved, syms)
}

///|
pub fn solve_poly_system(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> Array[Expr] raise SolverError {
  tuple_array_from_set(nonlinsolve(equations, symbols))
}

///|
pub fn solve_triangulated(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> Array[Expr] raise SolverError {
  solve_poly_system(equations, symbols)
}

///|
pub fn substitution(
  system : Array[Expr],
  symbols : Array[Expr],
) -> Set raise SolverError {
  if system.is_empty() || symbols.is_empty() {
    @symsets.empty_set()
  } else {
    nonlinsolve(system, symbols)
  }
}

///|
fn solve_finite_set_items(set : Set) -> Array[Expr] raise SolverError {
  finite_set_items(set).unwrap_or_else(() => {
    raise SolverError::ValueError("solve expects a finite solution set")
  })
}

///|
pub fn solve(
  input : SolveInput,
  symbols? : Array[Expr] = [],
) -> SolveResult raise SolverError {
  let equations = input_equations(input)
  let normalized = normalize_equations(equations)
  if normalized.is_empty() {
    return SolveResult::List([])
  }
  let requested = if symbols.is_empty() {
    let free : Array[Expr] = []
    for eq in normalized {
      for item in @symcore.free_symbols(eq) {
        free.push(item)
      }
    }
    filtered_symbols(free, [], [])
  } else {
    sorted_unique_symbols(symbols)
  }
  if normalized.length() == 1 && requested.length() == 1 {
    return SolveResult::List(
      solve_finite_set_items(
        solveset(normalized[0], symbol=Some(requested[0]), domain=complexes),
      ),
    )
  }
  if requested.length() == 1 {
    let mut acc : Set? = None
    for eq in normalized {
      let next = solveset(eq, symbol=Some(requested[0]), domain=complexes)
      acc = match acc {
        None => Some(next)
        Some(existing) => Some(@symsets.intersection([existing, next]))
      }
    }
    return SolveResult::List(
      solve_finite_set_items(acc.unwrap_or(@symsets.empty_set())),
    )
  }
  let solutions = nonlinsolve(normalized, requested)
  let names = symbol_names(requested)
  match solutions {
    @symsets.Set::FiniteSet(items) => {
      let dicts : Array[Map[String, Expr]] = []
      for item in items {
        match @symcore.tuple_items(item) {
          Some(values) => {
            let mapping : Map[String, Expr] = {}
            for i in 0..<names.length() {
              mapping[names[i]] = values.get(i).unwrap_or(requested[i])
            }
            dicts.push(mapping)
          }
          None => ()
        }
      }
      if dicts.length() == 1 {
        SolveResult::Dict(dicts[0])
      } else {
        SolveResult::Dicts(dicts)
      }
    }
    _ => SolveResult::Dicts([])
  }
}

///|
fn expr_to_mpf(expr : Expr, prec : Int) -> @symnum.Mpf {
  let evaled = @symcore.evalf(expr, prec~)
  match evaled {
    Expr::Float(value) => value.to_mpf()
    Expr::ComplexFloat(value) => {
      let imag = value.imag_part().to_mpf()
      if @symnum.is_zero(imag) {
        value.real_part().to_mpf()
      } else {
        @symnum.fnan
      }
    }
    Expr::Number(value) => {
      let approx = @symcore.Float::from_exact(value, prec~) catch {
        _ => @symcore.Float::from_mpf(@symnum.fnan, prec~)
      }
      approx.to_mpf()
    }
    _ => @symnum.fnan
  }
}

///|
pub fn nsolve(
  expr : Expr,
  symbol : Expr,
  x0 : Expr,
  x1? : Expr? = None,
  prec? : Int = 80,
  solver? : String = "auto",
) -> Expr raise SolverError {
  let name = symbol_name(symbol)
  let base = normalize_equation(expr)
  let guess0 = expr_to_mpf(x0, prec)
  let guess1 = x1.map(value => expr_to_mpf(value, prec))
  let f = fn(value : @symnum.Mpf) {
    let env : Map[String, Expr] = {}
    env[name] = Expr::Float(@symcore.Float::from_mpf(value, prec~))
    expr_to_mpf(@symcore.subst(base, env), prec)
  }
  let root = match guess1 {
    Some(other) =>
      @symnum.findroot(f, guess0, x1=other, solver~, prec~) catch {
        err => raise SolverError::ValueError("nsolve: " + err.to_string())
      }
    None =>
      @symnum.findroot(f, guess0, solver~, prec~) catch {
        err => raise SolverError::ValueError("nsolve: " + err.to_string())
      }
  }
  Expr::Float(@symcore.Float::from_mpf(root, prec~))
}
