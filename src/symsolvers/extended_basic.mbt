///|
fn solver_symbol_name(symbol : Expr) -> String raise SolverError {
  match symbol {
    Expr::Symbol(name) => name
    _ => raise SolverError::ValueError("expected Symbol in solver API")
  }
}

///|
fn solver_symbol_names(symbols : Array[Expr]) -> Array[String] raise SolverError {
  let out : Array[String] = []
  for symbol in symbols {
    let name = solver_symbol_name(symbol)
    if out.contains(name) {
      raise SolverError::ValueError("duplicate symbol " + name)
    }
    out.push(name)
  }
  out
}

///|
fn solver_expr_in_list(items : Array[Expr], target : Expr) -> Bool {
  items.any(item => @symcore.compare_expr(item, target) == 0)
}

///|
fn solver_sorted_unique_symbols(items : Array[Expr]) -> Array[Expr] raise SolverError {
  let out : Array[Expr] = []
  for item in items {
    guard item is Expr::Symbol(_) else {
      raise SolverError::ValueError("expected Symbol in solver API")
    }
    if !solver_expr_in_list(out, item) {
      out.push(item)
    }
  }
  @symcore.sort_exprs_in_place(out)
  out
}

///|
fn solver_normalize_equation(expr : Expr) -> Expr {
  match @symcore.relational_parts(expr) {
    Some((@symcore.RelOp::Eq, lhs, rhs)) =>
      @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])])
    _ => expr
  }
}

///|
fn solver_depends_on_any(expr : Expr, symbols : Array[Expr]) -> Bool {
  let free = @symcore.free_symbols(expr)
  for symbol in symbols {
    if solver_expr_in_list(free, symbol) {
      return true
    }
  }
  false
}

///|
fn solver_depends_only_on(expr : Expr, symbols : Array[Expr]) -> Bool {
  let free = @symcore.free_symbols(expr)
  if free.is_empty() {
    return false
  }
  for symbol in free {
    if !solver_expr_in_list(symbols, symbol) {
      return false
    }
  }
  true
}

///|
fn solver_mul_all(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    @symcore.int(1)
  } else if args.length() == 1 {
    args[0]
  } else {
    @symcore.mul(args)
  }
}

///|
fn solver_add_all(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    @symcore.int(0)
  } else if args.length() == 1 {
    args[0]
  } else {
    @symcore.add(args)
  }
}

///|
pub let allhints : Array[String] = [
  "factorable",
  "nth_algebraic",
  "separable",
  "1st_exact",
  "1st_linear",
  "Bernoulli",
  "1st_rational_riccati",
  "Riccati_special_minus2",
  "1st_homogeneous_coeff_best",
  "1st_homogeneous_coeff_subs_indep_div_dep",
  "1st_homogeneous_coeff_subs_dep_div_indep",
  "almost_linear",
  "linear_coefficients",
  "separable_reduced",
  "1st_power_series",
  "lie_group",
  "nth_linear_constant_coeff_homogeneous",
  "nth_linear_euler_eq_homogeneous",
  "nth_linear_constant_coeff_undetermined_coefficients",
  "nth_linear_euler_eq_nonhomogeneous_undetermined_coefficients",
  "nth_linear_constant_coeff_variation_of_parameters",
  "nth_linear_euler_eq_nonhomogeneous_variation_of_parameters",
  "Liouville",
  "2nd_linear_airy",
  "2nd_linear_bessel",
  "2nd_hypergeometric",
  "2nd_hypergeometric_Integral",
  "nth_order_reducible",
  "2nd_power_series_ordinary",
  "2nd_power_series_regular",
  "nth_algebraic_Integral",
  "separable_Integral",
  "1st_exact_Integral",
  "1st_linear_Integral",
  "Bernoulli_Integral",
  "1st_homogeneous_coeff_subs_indep_div_dep_Integral",
  "1st_homogeneous_coeff_subs_dep_div_indep_Integral",
  "almost_linear_Integral",
  "linear_coefficients_Integral",
  "separable_reduced_Integral",
  "nth_linear_constant_coeff_variation_of_parameters_Integral",
  "nth_linear_euler_eq_nonhomogeneous_variation_of_parameters_Integral",
  "Liouville_Integral",
  "2nd_nonlinear_autonomous_conserved",
  "2nd_nonlinear_autonomous_conserved_Integral",
]

///|
fn solver_constantsimp_inner(
  expr : Expr,
  constants : Array[Expr],
  replacement : Expr,
) -> Expr {
  if !solver_depends_on_any(expr, constants) {
    return expr
  }
  if solver_depends_only_on(expr, constants) {
    return replacement
  }
  match expr {
    Expr::Add(args) => {
      let rebuilt : Array[Expr] = []
      let mut collapsed = false
      for arg in args {
        if solver_depends_only_on(arg, constants) {
          collapsed = true
        } else {
          rebuilt.push(solver_constantsimp_inner(arg, constants, replacement))
        }
      }
      if collapsed {
        rebuilt.push(replacement)
      }
      solver_add_all(rebuilt)
    }
    Expr::Mul(args) => {
      let rebuilt : Array[Expr] = []
      let mut collapsed = false
      for arg in args {
        if solver_depends_only_on(arg, constants) {
          collapsed = true
        } else {
          rebuilt.push(solver_constantsimp_inner(arg, constants, replacement))
        }
      }
      if collapsed {
        rebuilt.push(replacement)
      }
      solver_mul_all(rebuilt)
    }
    Expr::Pow(base, exp) =>
      if solver_depends_only_on(base, constants) && !solver_depends_on_any(exp, constants) {
        replacement
      } else {
        @symcore.pow(
          solver_constantsimp_inner(base, constants, replacement),
          solver_constantsimp_inner(exp, constants, replacement),
        )
      }
    _ => expr
  }
}

///|
pub fn constantsimp(expr : Expr, constants : Array[Expr]) -> Expr raise SolverError {
  let normalized = solver_sorted_unique_symbols(constants)
  if normalized.is_empty() {
    return expr
  }
  solver_constantsimp_inner(expr, normalized, normalized[0])
}

///|
fn solver_exact_nonnegative_int(expr : Expr) -> Int? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) =>
      if den.compare(1N) == 0 && num.compare(0N) >= 0 {
        Some(num.to_int())
      } else {
        None
      }
    None => None
  }
}

///|
fn solver_derivative_vars(deriv_args : Array[Expr]) -> Array[Expr] {
  let out : Array[Expr] = []
  let mut i = 0
  while i + 1 < deriv_args.length() {
    let wrt = deriv_args[i]
    let count = solver_exact_nonnegative_int(deriv_args[i + 1]).unwrap_or(1)
    for _ in 0..<count {
      out.push(wrt)
    }
    i += 2
  }
  out
}

///|
fn solver_is_same_undefined_application(lhs : Expr, rhs : Expr) -> Bool {
  if @symcore.compare_expr(lhs, rhs) == 0 {
    return true
  }
  match (@symcore.undefined_application_parts(lhs), @symcore.undefined_application_parts(rhs)) {
    (Some((lname, largs)), Some((rname, rargs))) =>
      lname == rname && solver_expr_arrays_equal(largs, rargs)
    _ => false
  }
}

///|
fn solver_is_same_target(lhs : Expr, rhs : Expr) -> Bool {
  if solver_is_same_undefined_application(lhs, rhs) {
    return true
  }
  match (@symcore.derivative_parts(lhs), @symcore.derivative_parts(rhs)) {
    (Some((linner, largs)), Some((rinner, rargs))) =>
      solver_is_same_undefined_application(linner, rinner) &&
      solver_expr_arrays_equal(solver_derivative_vars(largs), solver_derivative_vars(rargs))
    _ => @symcore.compare_expr(lhs, rhs) == 0
  }
}

///|
fn solver_order_to_expr(
  order : (@bigint.BigInt, @bigint.BigInt),
) -> Expr {
  Expr::Number(@symnum.BigRational::new(order.0, order.1) catch {
    _ => @symnum.BigRational::zero()
  })
}

///|
fn solver_order_add(
  lhs : (@bigint.BigInt, @bigint.BigInt),
  rhs : (@bigint.BigInt, @bigint.BigInt),
) -> (@bigint.BigInt, @bigint.BigInt) {
  let num = lhs.0 * rhs.1 + rhs.0 * lhs.1
  let den = lhs.1 * rhs.1
  let value = @symnum.BigRational::new(num, den) catch {
    _ => return (0N, 1N)
  }
  (value.numerator(), value.denominator())
}

///|
fn solver_order_mul(
  lhs : (@bigint.BigInt, @bigint.BigInt),
  rhs : (@bigint.BigInt, @bigint.BigInt),
) -> (@bigint.BigInt, @bigint.BigInt) {
  let value = @symnum.BigRational::new(lhs.0 * rhs.0, lhs.1 * rhs.1) catch {
    _ => return (0N, 1N)
  }
  (value.numerator(), value.denominator())
}

///|
fn solver_order_eq(
  lhs : (@bigint.BigInt, @bigint.BigInt),
  rhs : (@bigint.BigInt, @bigint.BigInt),
) -> Bool {
  lhs.0 * rhs.1 == rhs.0 * lhs.1
}

///|
fn solver_homogeneous_order_inner(
  expr : Expr,
  symbols : Array[Expr],
) -> (@bigint.BigInt, @bigint.BigInt)? {
  if !solver_depends_on_any(expr, symbols) {
    return Some((0N, 1N))
  }
  if solver_expr_in_list(symbols, expr) {
    return Some((1N, 1N))
  }
  match expr {
    Expr::Number(_) | Expr::Float(_) | Expr::ComplexFloat(_) | Expr::Boolean(_)
    | Expr::NumberSymbol(_) => Some((0N, 1N))
    Expr::Add(args) => {
      if args.is_empty() {
        return Some((0N, 1N))
      }
      let first = match solver_homogeneous_order_inner(args[0], symbols) {
        Some(value) => value
        None => return None
      }
      for i in 1..<args.length() {
        match solver_homogeneous_order_inner(args[i], symbols) {
          Some(value) if solver_order_eq(first, value) => ()
          _ => return None
        }
      }
      Some(first)
    }
    Expr::Mul(args) => {
      let mut acc = (0N, 1N)
      for arg in args {
        match solver_homogeneous_order_inner(arg, symbols) {
          Some(value) => acc = solver_order_add(acc, value)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match (solver_homogeneous_order_inner(base, symbols), @symcore.exact_numeric_expr_num_den(exp)) {
        (Some(value), Some(ratio)) => Some(solver_order_mul(value, ratio))
        _ => None
      }
    _ => None
  }
}

///|
pub fn homogeneous_order(eq : Expr, symbols : Array[Expr]) -> Expr? raise SolverError {
  let syms = solver_sorted_unique_symbols(symbols)
  solver_homogeneous_order_inner(solver_normalize_equation(eq), syms).map(
    solver_order_to_expr,
  )
}

///|
pub fn ode_order(expr : Expr, func : Expr) -> Int {
  let normalized = solver_normalize_equation(expr)
  match @symcore.derivative_parts(normalized) {
    Some((inner, deriv_args)) => {
      let total = solver_derivative_vars(deriv_args).length()
      if solver_is_same_undefined_application(inner, func) {
        return total
      }
      let mut nested = 0
      for arg in @symcore.args(inner) {
        let order = ode_order(arg, func)
        if order > nested {
          nested = order
        }
      }
      let promoted = total + nested
      let mut child_best = 0
      for arg in @symcore.args(normalized) {
        let order = ode_order(arg, func)
        if order > child_best {
          child_best = order
        }
      }
      if promoted > child_best { promoted } else { child_best }
    }
    None => {
      let mut best = 0
      for arg in @symcore.args(normalized) {
        let order = ode_order(arg, func)
        if order > best {
          best = order
        }
      }
      best
    }
  }
}

///|
fn solver_linear_factor_coeff(term : Expr, target : Expr) -> Expr? {
  if solver_is_same_target(term, target) {
    return Some(@symcore.int(1))
  }
  match term {
    Expr::Mul(args) => {
      let factors : Array[Expr] = []
      let mut seen = false
      for arg in args {
        if solver_is_same_target(arg, target) {
          if seen {
            return None
          }
          seen = true
        } else if @symcore.has(arg, target) {
          return None
        } else {
          factors.push(arg)
        }
      }
      if seen {
        Some(solver_mul_all(factors))
      } else if @symcore.has(term, target) {
        None
      } else {
        Some(@symcore.int(0))
      }
    }
    _ =>
      if @symcore.has(term, target) {
        None
      } else {
        Some(@symcore.int(0))
      }
  }
}

///|
fn solver_extract_linear_targets(
  expr : Expr,
  targets : Array[Expr],
) -> (Array[Expr], Expr)? {
  let terms = match solver_normalize_equation(expr) {
    Expr::Add(args) => args
    other => [other]
  }
  let coeffs : Array[Expr] = Array::make(targets.length(), @symcore.int(0))
  let mut constant = @symcore.int(0)
  for term in terms {
    let mut matched = -1
    let mut matched_coeff = @symcore.int(0)
    let mut bad_match = false
    for i in 0..<targets.length() {
      match solver_linear_factor_coeff(term, targets[i]) {
        Some(coeff) if !@symcore.is_zero(coeff) => {
          if matched >= 0 {
            return None
          }
          matched = i
          matched_coeff = coeff
        }
        Some(_) => ()
        None => bad_match = true
      }
    }
    if matched >= 0 {
      coeffs[matched] = canonical_expr(@symcore.add([coeffs[matched], matched_coeff]))
    } else if bad_match {
      return None
    } else {
      constant = canonical_expr(@symcore.add([constant, term]))
    }
  }
  Some((coeffs, constant))
}

///|
fn solver_assumption_value(
  expr : Expr,
  key : String,
  env : Map[String, @symassume.SymbolFacts],
) -> Bool? {
  let tri = match key {
    "zero" => Some(@symassume.is_zero(expr, env~))
    "nonzero" => Some(@symassume.is_nonzero(expr, env~))
    "integer" => Some(@symassume.is_integer(expr, env~))
    "rational" => Some(@symassume.is_rational(expr, env~))
    "real" => Some(@symassume.is_real(expr, env~))
    "positive" => Some(@symassume.is_positive(expr, env~))
    "nonnegative" => Some(@symassume.is_nonnegative(expr, env~))
    "negative" => Some(@symassume.is_positive(@symcore.mul([@symcore.int(-1), expr]), env~))
    "nonpositive" =>
      Some(
        @symassume.is_nonnegative(
          @symcore.mul([@symcore.int(-1), expr]),
          env~,
        ),
      )
    _ => None
  }
  match tri {
    Some(value) => @symassume.tri_to_bool_option(value)
    None =>
      match key {
        "complex" =>
          if @symcore.is_infinite(expr) || @symcore.is_nan(expr) {
            None
          } else {
            match @symcore.expr_form(expr) {
              @symcore.ExprForm::Number(_)
              | @symcore.ExprForm::Float(_)
              | @symcore.ExprForm::ComplexFloat(_) => Some(true)
              @symcore.ExprForm::NumberSymbol(kind) =>
                Some(
                  match kind {
                    @symcore.NumberSymbolKind::Infinity
                    | @symcore.NumberSymbolKind::NegativeInfinity
                    | @symcore.NumberSymbolKind::ComplexInfinity
                    | @symcore.NumberSymbolKind::NaN => false
                    _ => true
                  },
                )
              _ =>
                match @symassume.tri_to_bool_option(@symassume.is_real(expr, env~)) {
                  Some(true) => Some(true)
                  _ => None
                }
            }
          }
        "finite" =>
          if @symcore.is_nan(expr) {
            None
          } else if @symcore.is_infinite(expr) {
            Some(false)
          } else {
            match @symcore.expr_form(expr) {
              @symcore.ExprForm::Number(_)
              | @symcore.ExprForm::Float(_)
              | @symcore.ExprForm::ComplexFloat(_) => Some(true)
              @symcore.ExprForm::NumberSymbol(kind) =>
                Some(
                  match kind {
                    @symcore.NumberSymbolKind::Infinity
                    | @symcore.NumberSymbolKind::NegativeInfinity
                    | @symcore.NumberSymbolKind::ComplexInfinity
                    | @symcore.NumberSymbolKind::NaN => false
                    _ => true
                  },
                )
              _ => None
            }
          }
        "infinite" =>
          if @symcore.is_nan(expr) {
            None
          } else if @symcore.is_infinite(expr) {
            Some(true)
          } else {
            match solver_assumption_value(expr, "finite", env) {
              Some(true) => Some(false)
              _ => None
            }
          }
        _ => None
      }
  }
}

///|
fn solver_supported_assumptions() -> Array[String] {
  [
    "zero",
    "nonzero",
    "integer",
    "rational",
    "real",
    "positive",
    "nonnegative",
    "negative",
    "nonpositive",
    "complex",
    "finite",
    "infinite",
  ]
}

///|
fn solver_assumptions_from_expr(
  expr : Expr,
  env : Map[String, @symassume.SymbolFacts],
) -> Map[String, Bool?] {
  let out : Map[String, Bool?] = {}
  for key in solver_supported_assumptions() {
    match solver_assumption_value(expr, key, env) {
      Some(value) => out[key] = Some(value)
      None => ()
    }
  }
  out
}

///|
pub fn failing_assumptions(
  expr : Expr,
  assumptions : Map[String, Bool?],
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> Map[String, Bool?] {
  let failed : Map[String, Bool?] = {}
  for key, desired in assumptions {
    match desired {
      None => ()
      Some(value) =>
        match solver_assumption_value(expr, key, env) {
          Some(actual) if actual == value => ()
          Some(actual) => failed[key] = Some(actual)
          None => failed[key] = None
        }
    }
  }
  failed
}

///|
pub fn check_assumptions(
  expr : Expr,
  against? : Expr? = None,
  assumptions? : Map[String, Bool?] = {},
  env? : Map[String, @symassume.SymbolFacts] = {},
) -> Bool? raise SolverError {
  let checks = match against {
    Some(other) => {
      guard assumptions.is_empty() else {
        raise SolverError::ValueError("expecting against or assume, not both")
      }
      solver_assumptions_from_expr(other, env)
    }
    None => assumptions
  }
  let mut unknown = false
  for key, desired in checks {
    match desired {
      None => ()
      Some(value) =>
        match solver_assumption_value(expr, key, env) {
          Some(actual) =>
            if actual != value {
              return Some(false)
            }
          None => unknown = true
        }
    }
  }
  if unknown {
    None
  } else {
    Some(true)
  }
}

///|
fn solver_collect_term_pair(
  acc : Array[(Expr, Expr)],
  basis : Expr,
  coeff : Expr,
) -> Unit {
  for i in 0..<acc.length() {
    let (existing_basis, existing_coeff) = acc[i]
    if @symcore.compare_expr(existing_basis, basis) == 0 {
      acc[i] = (existing_basis, canonical_expr(@symcore.add([existing_coeff, coeff])))
      return
    }
  }
  acc.push((basis, canonical_expr(coeff)))
}

///|
fn solver_split_coeff_basis(term : Expr, basis_symbols : Array[Expr]) -> (Expr, Expr) {
  if !solver_depends_on_any(term, basis_symbols) {
    return (term, @symcore.int(1))
  }
  match term {
    Expr::Mul(args) => {
      let coeff_factors : Array[Expr] = []
      let basis_factors : Array[Expr] = []
      for arg in args {
        if solver_depends_on_any(arg, basis_symbols) {
          basis_factors.push(arg)
        } else {
          coeff_factors.push(arg)
        }
      }
      (solver_mul_all(coeff_factors), solver_mul_all(basis_factors))
    }
    _ => (@symcore.int(1), term)
  }
}

///|
fn solver_maps_from_tuple_set(
  set : Set,
  symbols : Array[Expr],
) -> Array[Map[String, Expr]] raise SolverError {
  let names = solver_symbol_names(symbols)
  match set {
    @symsets.Set::EmptySet => []
    @symsets.Set::FiniteSet(items) => {
      let out : Array[Map[String, Expr]] = []
      for item in items {
        match @symcore.tuple_items(item) {
          Some(values) => {
            let mapping : Map[String, Expr] = {}
            for i in 0..<names.length() {
              mapping[names[i]] = values.get(i).unwrap_or(symbols[i])
            }
            out.push(mapping)
          }
          None => ()
        }
      }
      out
    }
    _ => []
  }
}

///|
pub fn solve_undetermined_coeffs(
  equ : Expr,
  coeffs : Array[Expr],
  syms? : Array[Expr] = [],
  dict? : Bool = false,
) -> SolveResult? raise SolverError {
  guard !coeffs.is_empty() else {
    raise SolverError::ValueError("must provide symbols for coeffs")
  }
  let coeff_symbols = solver_sorted_unique_symbols(coeffs)
  let normalized0 = solver_normalize_equation(equ)
  let normalized = @symsimplify.numer_expand(normalized0)
  let live_coeffs : Array[Expr] = []
  for coeff in coeff_symbols {
    if @symcore.has(normalized, coeff) {
      live_coeffs.push(coeff)
    }
  }
  if live_coeffs.is_empty() {
    return Some(SolveResult::Dicts([]))
  }
  let basis_symbols = if syms.is_empty() {
    let out : Array[Expr] = []
    for symbol in solver_sorted_unique_symbols(@symcore.free_symbols(normalized)) {
      if !solver_expr_in_list(live_coeffs, symbol) {
        out.push(symbol)
      }
    }
    out
  } else {
    solver_sorted_unique_symbols(syms)
  }
  let pairs : Array[(Expr, Expr)] = []
  let terms = match normalized {
    Expr::Add(args) => args
    other => [other]
  }
  for term in terms {
    let (coeff, basis) = solver_split_coeff_basis(term, basis_symbols)
    if solver_depends_on_any(basis, live_coeffs) {
      return None
    }
    solver_collect_term_pair(pairs, basis, coeff)
  }
  let coeff_equations : Array[Expr] = []
  for pair in pairs {
    let coeff = pair.1
    if !@symcore.is_zero(coeff) {
      coeff_equations.push(solver_normalize_equation(coeff))
    }
  }
  if coeff_equations.is_empty() {
    return Some(SolveResult::Dicts([]))
  }
  let mappings = solver_maps_from_tuple_set(nonlinsolve(coeff_equations, live_coeffs), live_coeffs)
  if mappings.is_empty() {
    return Some(SolveResult::Dicts([]))
  }
  if dict {
    return Some(SolveResult::Dicts(mappings))
  }
  if mappings.length() == 1 {
    Some(SolveResult::Dict(mappings[0]))
  } else {
    Some(SolveResult::Dicts(mappings))
  }
}

///|
fn solver_infer_function(expr : Expr, arity : Int) -> Expr? {
  for node in @symcore.preorder(expr) {
    match @symcore.undefined_application_parts(node) {
      Some((_, args)) if args.length() == arity => return Some(node)
      _ => ()
    }
  }
  None
}

///|
fn solver_rewrite_solution_nodes(
  expr : Expr,
  func : Expr,
  rhs : Expr,
) -> Expr {
  if solver_is_same_undefined_application(expr, func) {
    return rhs
  }
  match expr {
    Expr::Derivative(inner, deriv_args) =>
      if solver_is_same_undefined_application(inner, func) {
        @symcalculus.derivative_expr(rhs, solver_derivative_vars(deriv_args))
      } else {
        Expr::Derivative(
          solver_rewrite_solution_nodes(inner, func, rhs),
          deriv_args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs)),
        )
      }
    Expr::Apply(head, args) =>
      match @symcore.function_head_name(head) {
        Some("Derivative") if args.length() >= 2 &&
          solver_is_same_undefined_application(args[0], func) =>
          @symcalculus.derivative_expr(
            rhs,
            solver_derivative_vars(@symcore.canonical_derivative_args(args[1:])),
          )
        _ =>
          @symcore.apply(
            solver_rewrite_solution_nodes(head, func, rhs),
            args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs)),
          ).unwrap_or(
            Expr::Apply(
              solver_rewrite_solution_nodes(head, func, rhs),
              args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs)),
            ),
          )
      }
    Expr::Add(args) =>
      @symcore.add(args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs)))
    Expr::Mul(args) =>
      @symcore.mul(args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs)))
    Expr::Pow(base, exp) =>
      @symcore.pow(
        solver_rewrite_solution_nodes(base, func, rhs),
        solver_rewrite_solution_nodes(exp, func, rhs),
      )
    Expr::Mod(lhs, rhs0) =>
      @symcore.mod_expr(
        solver_rewrite_solution_nodes(lhs, func, rhs),
        solver_rewrite_solution_nodes(rhs0, func, rhs),
      )
    Expr::Tuple(items) =>
      Expr::Tuple(items.map(item => solver_rewrite_solution_nodes(item, func, rhs)))
    Expr::Dict(items) =>
      Expr::Dict(
        items.map(entry => (
          solver_rewrite_solution_nodes(entry.0, func, rhs),
          solver_rewrite_solution_nodes(entry.1, func, rhs),
        )),
      )
    Expr::Relational(op, lhs, rhs0) =>
      Expr::Relational(
        op,
        solver_rewrite_solution_nodes(lhs, func, rhs),
        solver_rewrite_solution_nodes(rhs0, func, rhs),
      )
    Expr::Subs(inner, variable, value) =>
      Expr::Subs(
        solver_rewrite_solution_nodes(inner, func, rhs),
        solver_rewrite_solution_nodes(variable, func, rhs),
        solver_rewrite_solution_nodes(value, func, rhs),
      )
    Expr::Lambda(vars, body) =>
      Expr::Lambda(
        solver_rewrite_solution_nodes(vars, func, rhs),
        solver_rewrite_solution_nodes(body, func, rhs),
      )
    _ => expr
  }
}

///|
fn solver_extract_ode_linear(
  expr : Expr,
  func : Expr,
) -> (Expr, Expr, Expr, Expr)? {
  let (_, args) = match @symcore.undefined_application_parts(func) {
    Some(parts) => parts
    None => return None
  }
  guard args.length() == 1 else {
    return None
  }
  let wrt = args[0]
  let dfunc = @symcalculus.diff(func, wrt)
  match solver_extract_linear_targets(solver_normalize_equation(expr), [dfunc, func]) {
    Some((coeffs, constant)) if !@symcore.is_zero(coeffs[0]) =>
      Some((wrt, coeffs[0], coeffs[1], constant))
    _ => None
  }
}

///|
fn solver_infer_ode_function(eq : Expr, func : Expr?) -> Expr raise SolverError {
  match func {
    Some(value) => value
    None =>
      match solver_infer_function(solver_normalize_equation(eq), 1) {
        Some(value) => value
        None => raise SolverError::ValueError("unable to infer ODE function")
      }
  }
}

///|
fn solver_first_order_canonical_system(
  eqs : Array[Expr],
  funcs : Array[Expr],
  t : Expr,
) -> Array[Expr] raise SolverError {
  guard !eqs.is_empty() else {
    raise SolverError::ValueError("canonical_odes expects at least one equation")
  }
  guard eqs.length() == funcs.length() else {
    raise SolverError::ValueError("equation and function counts must match")
  }
  let derivative_targets = funcs.map(func => @symcalculus.diff(func, t))
  let coeff_rows : Array[Array[Expr]] = []
  let rhs_rows : Array[Array[Expr]] = []
  for eq in eqs {
    match solver_extract_linear_targets(solver_normalize_equation(eq), derivative_targets) {
      Some((coeffs, constant)) => {
        coeff_rows.push(coeffs)
        rhs_rows.push([canonical_expr(@symcore.mul([@symcore.int(-1), constant]))])
      }
      None =>
        raise SolverError::ValueError(
          "canonical_odes currently expects a first-order linear system",
        )
    }
  }
  let coeff_matrix = @symmatrices.matrix(coeff_rows) catch {
    err => raise wrap_matrix_error("canonical_odes", err)
  }
  let rhs_matrix = @symmatrices.matrix(rhs_rows) catch {
    err => raise wrap_matrix_error("canonical_odes", err)
  }
  let solved = coeff_matrix.solve(rhs_matrix) catch {
    err => raise wrap_matrix_error("canonical_odes", err)
  }
  let rows = solved.to_list()
  let out : Array[Expr] = []
  for i in 0..<funcs.length() {
    out.push(
      Expr::Relational(
        @symcore.RelOp::Eq,
        derivative_targets[i],
        rows[i][0],
      ),
    )
  }
  out
}

///|
pub fn canonical_odes(
  eqs : Array[Expr],
  funcs : Array[Expr],
  t : Expr,
) -> Array[Array[Expr]] raise SolverError {
  [solver_first_order_canonical_system(eqs, funcs, t)]
}

///|
pub fn linear_ode_to_matrix(
  eqs : Array[Expr],
  funcs : Array[Expr],
  t : Expr,
  order : Int,
) -> (Array[@symmatrices.Matrix], @symmatrices.Matrix) raise SolverError {
  guard order == 1 else {
    raise SolverError::ValueError("linear_ode_to_matrix currently supports only first-order systems")
  }
  let systems = canonical_odes(eqs, funcs, t)
  let system = systems[0]
  let derivative_targets = funcs.map(func => @symcalculus.diff(func, t))
  let targets : Array[Expr] = []
  for item in derivative_targets {
    targets.push(item)
  }
  for item in funcs {
    targets.push(item)
  }
  let a1_rows : Array[Array[Expr]] = []
  let a0_rows : Array[Array[Expr]] = []
  let b_rows : Array[Array[Expr]] = []
  for eq in system {
    match solver_extract_linear_targets(solver_normalize_equation(eq), targets) {
      Some((coeffs, constant)) => {
        let row1 : Array[Expr] = []
        let row0 : Array[Expr] = []
        for i in 0..<funcs.length() {
          row1.push(coeffs[i])
          row0.push(canonical_expr(@symcore.mul([@symcore.int(-1), coeffs[funcs.length() + i]])))
        }
        a1_rows.push(row1)
        a0_rows.push(row0)
        b_rows.push([canonical_expr(@symcore.mul([@symcore.int(-1), constant]))])
      }
      None =>
        raise SolverError::ValueError(
          "linear_ode_to_matrix currently expects a first-order linear system",
        )
    }
  }
  (
    [
      @symmatrices.matrix(a1_rows) catch {
        err => raise wrap_matrix_error("linear_ode_to_matrix", err)
      },
      @symmatrices.matrix(a0_rows) catch {
        err => raise wrap_matrix_error("linear_ode_to_matrix", err)
      },
    ],
    @symmatrices.matrix(b_rows) catch {
      err => raise wrap_matrix_error("linear_ode_to_matrix", err)
    },
  )
}

///|
fn solver_factorial_int(n : Int) -> Int {
  let mut acc = 1
  for i in 2..=n {
    acc *= i
  }
  acc
}

///|
fn solver_expr_equal(lhs : Expr, rhs : Expr) -> Bool {
  @symcore.compare_expr(lhs, rhs) == 0
}

///|
fn solver_build_matrix(
  rows : Array[Array[Expr]],
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  @symmatrices.matrix(rows) catch {
    err => raise wrap_matrix_error(context, err)
  }
}

///|
fn solver_matrix_normalize_entries(
  matrix : @symmatrices.Matrix,
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  let rows = matrix.to_list()
  let normalized : Array[Array[Expr]] = []
  for row in rows {
    let next : Array[Expr] = []
    for value in row {
      next.push(@symsimplify.numer_expand(canonical_expr(value)))
    }
    normalized.push(next)
  }
  solver_build_matrix(normalized, context)
}

///|
fn solver_matrix_subst_symbol(
  matrix : @symmatrices.Matrix,
  name : String,
  value : Expr,
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  let env : Map[String, Expr] = {}
  env[name] = value
  let rows = matrix.to_list()
  let substituted : Array[Array[Expr]] = []
  for row in rows {
    let next : Array[Expr] = []
    for item in row {
      next.push(canonical_expr(@symcore.subst(item, env)))
    }
    substituted.push(next)
  }
  solver_build_matrix(substituted, context)
}

///|
fn solver_jordan_blocks(
  jordan : @symmatrices.Matrix,
) -> Array[(Expr, Int)] {
  let rows = jordan.to_list()
  let out : Array[(Expr, Int)] = []
  let mut i = 0
  while i < jordan.rows {
    let lambda = rows[i][i]
    let mut size = 1
    while i + size < jordan.rows &&
      solver_expr_equal(rows[i + size - 1][i + size], @symcore.int(1)) &&
      solver_expr_equal(rows[i + size][i + size], lambda) {
      size += 1
    }
    out.push((lambda, size))
    i += size
  }
  out
}

///|
fn solver_jordan_block_exponential(
  eigenvalue : Expr,
  size : Int,
  variable : Expr,
  negative : Bool,
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  let sign = if negative { @symcore.int(-1) } else { @symcore.int(1) }
  let exp_term = @symcore.function(
    "exp",
    [canonical_expr(@symcore.mul([sign, eigenvalue, variable]))],
  )
  let rows : Array[Array[Expr]] = []
  for i in 0..<size {
    let row : Array[Expr] = []
    for j in 0..<size {
      if j < i {
        row.push(@symcore.int(0))
      } else {
        let shift = j - i
        let nilpotent_term = if shift == 0 {
          @symcore.int(1)
        } else {
          let factorial = solver_factorial_int(shift)
          let coeff = @symcore.rational_from_ints(1, factorial) catch {
            _ => @symcore.int(0)
          }
          canonical_expr(@symcore.mul([coeff, variable ^ @symcore.int(shift)]))
        }
        row.push(@symsimplify.numer_expand(canonical_expr(@symcore.mul([exp_term, nilpotent_term]))))
      }
    }
    rows.push(row)
  }
  solver_build_matrix(rows, context)
}

///|
fn solver_matrix_exponential(
  matrix : @symmatrices.Matrix,
  variable : Expr,
  context : String,
  negative? : Bool = false,
) -> @symmatrices.Matrix raise SolverError {
  let (p, j) = matrix.jordan_form() catch {
    err => raise wrap_matrix_error(context, err)
  }
  let blocks : Array[@symmatrices.Matrix] = []
  for block in solver_jordan_blocks(j) {
    blocks.push(
      solver_jordan_block_exponential(block.0, block.1, variable, negative, context),
    )
  }
  let exp_j = if blocks.length() == 1 {
    blocks[0]
  } else {
    @symmatrices.block_diag(blocks) catch {
      err => raise wrap_matrix_error(context, err)
    }
  }
  let p_inv = p.inv() catch {
    err => raise wrap_matrix_error(context, err)
  }
  solver_matrix_normalize_entries((p * exp_j) * p_inv, context)
}

///|
fn solver_constant_vector(
  size : Int,
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  let rows : Array[Array[Expr]] = []
  for i in 0..<size {
    rows.push([Expr::Symbol("C\{i + 1}")])
  }
  solver_build_matrix(rows, context)
}

///|
fn solver_integrate_column_matrix(
  matrix : @symmatrices.Matrix,
  variable : Expr,
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  let rows = matrix.to_list()
  let integrated : Array[Array[Expr]] = []
  for row in rows {
    integrated.push([canonical_expr(@symintegrals.integrate(row[0], limits=[variable]))])
  }
  solver_build_matrix(integrated, context)
}

///|
pub fn linodesolve(
  a : @symmatrices.Matrix,
  t : Expr,
  rhs? : @symmatrices.Matrix? = None,
  antiderivative? : @symmatrices.Matrix? = None,
  type_hint? : String = "auto",
  doit? : Bool = false,
  tau? : Expr? = None,
) -> @symmatrices.Matrix raise SolverError {
  ignore(antiderivative)
  ignore(type_hint)
  ignore(doit)
  guard a.rows == a.cols else {
    raise SolverError::ShapeError("linodesolve expects a square coefficient matrix")
  }
  let b_rows = match rhs {
    Some(value) => {
      guard value.rows == a.rows && value.cols == 1 else {
        raise SolverError::ShapeError("linodesolve expects a column rhs matrix with matching rows")
      }
      value.to_list()
    }
    None => Array::make(a.rows, [@symcore.int(0)])
  }
  let t_name = match t {
    Expr::Symbol(name) => name
    _ => raise SolverError::ValueError("linodesolve expects Symbol as the independent variable")
  }
  let tau_var = match tau {
    Some(value) =>
      match value {
        Expr::Symbol(_) => value
        _ => raise SolverError::ValueError("linodesolve expects Symbol as tau")
      }
    None => Expr::Symbol("_tau")
  }
  let tau_name = match tau_var {
    Expr::Symbol(name) => name
    _ => "_tau"
  }
  let exp_pos = solver_matrix_exponential(a, t, "linodesolve")
  let constants = solver_constant_vector(a.rows, "linodesolve")
  let forcing = solver_build_matrix(b_rows, "linodesolve")
  let particular = if forcing.is_zero_matrix() {
    solver_build_matrix(Array::make(a.rows, [@symcore.int(0)]), "linodesolve")
  } else {
    let forcing_tau = if tau_name == t_name {
      forcing
    } else {
      solver_matrix_subst_symbol(forcing, t_name, tau_var, "linodesolve")
    }
    let exp_neg_tau = solver_matrix_exponential(a, tau_var, "linodesolve", negative=true)
    solver_integrate_column_matrix(exp_neg_tau * forcing_tau, tau_var, "linodesolve")
  }
  solver_matrix_normalize_entries(exp_pos * (constants + particular), "linodesolve")
}

///|
pub fn infinitesimals(
  eq : Expr,
  func? : Expr? = None,
  order? : Int? = None,
  hint? : String = "default",
  match_env? : Map[String, Expr]? = None,
) -> Array[Map[String, Expr]] raise SolverError {
  ignore(hint)
  ignore(match_env)
  let f = solver_infer_ode_function(eq, func)
  let ode_ord = order.unwrap_or(ode_order(eq, f))
  guard ode_ord == 1 else {
    raise SolverError::ValueError("infinitesimals currently supports only first-order ODEs")
  }
  let (wrt, coeff_d, coeff_f, constant) = match solver_extract_ode_linear(eq, f) {
    Some(value) => value
    None =>
      raise SolverError::ValueError(
        "infinitesimals currently supports first-order linear ODEs",
      )
  }
  guard @symcore.is_zero(constant) else {
    raise SolverError::ValueError(
      "infinitesimals currently supports homogeneous first-order linear ODEs",
    )
  }
  let p = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      coeff_f,
      @symcore.pow(coeff_d, @symcore.int(-1)),
    ]),
  )
  let eta = @symcore.function(
    "exp",
    [canonical_expr(@symintegrals.integrate(p, limits=[wrt]))],
  )
  let sol : Map[String, Expr] = {}
  sol["xi"] = @symcore.int(0)
  sol["eta"] = eta
  [sol]
}

///|
pub fn checkinfsol(
  eq : Expr,
  infinitesimal_solutions : Array[Map[String, Expr]],
  func? : Expr? = None,
  order? : Int? = None,
) -> Array[(Bool, Expr)] raise SolverError {
  let f = solver_infer_ode_function(eq, func)
  let ode_ord = order.unwrap_or(ode_order(eq, f))
  guard ode_ord == 1 else {
    raise SolverError::ValueError("checkinfsol currently supports only first-order ODEs")
  }
  let (wrt, coeff_d, coeff_f, constant) = match solver_extract_ode_linear(eq, f) {
    Some(value) => value
    None =>
      raise SolverError::ValueError(
        "checkinfsol currently supports first-order linear ODEs",
      )
  }
  let y = Expr::Symbol("_y")
  let h = canonical_expr(
    @symcore.add([
      @symcore.mul([
        @symcore.int(-1),
        coeff_f,
        @symcore.pow(coeff_d, @symcore.int(-1)),
        y,
      ]),
      @symcore.mul([
        @symcore.int(-1),
        constant,
        @symcore.pow(coeff_d, @symcore.int(-1)),
      ]),
    ]),
  )
  let out : Array[(Bool, Expr)] = []
  for infinitesimal in infinitesimal_solutions {
    let xi = infinitesimal.get("xi").unwrap_or(@symcore.int(0))
    let eta = infinitesimal.get("eta").unwrap_or(@symcore.int(0))
    let residual = canonical_expr(
      @symcore.add([
        @symcalculus.diff(eta, wrt),
        @symcore.mul([
          canonical_expr(
            @symcore.add([
              @symcalculus.diff(eta, y),
              @symcore.mul([@symcore.int(-1), @symcalculus.diff(xi, wrt)]),
            ]),
          ),
          h,
        ]),
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(xi, y),
          h ^ @symcore.int(2),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          xi,
          @symcalculus.diff(h, wrt),
        ]),
        @symcore.mul([
          @symcore.int(-1),
          eta,
          @symcalculus.diff(h, y),
        ]),
      ]),
    )
    out.push((expr_is_zeroish(residual) == Some(true), residual))
  }
  out
}

///|
pub fn classify_ode(
  eq : Expr,
  func? : Expr? = None,
) -> Array[String] raise SolverError {
  let f = solver_infer_ode_function(eq, func)
  if ode_order(eq, f) != 1 {
    return []
  }
  match solver_extract_ode_linear(eq, f) {
    Some((_, _, coeff_func, constant)) => {
      let hints : Array[String] = []
      if @symcore.is_zero(constant) {
        hints.push("separable")
      }
      hints.push("1st_linear")
      if @symcore.is_zero(constant) && !@symcore.is_zero(coeff_func) {
        hints.push("Bernoulli")
      }
      hints
    }
    None => []
  }
}

///|
pub fn dsolve(
  eq : Expr,
  func? : Expr? = None,
  hint? : String = "default",
) -> Expr raise SolverError {
  let f = match func {
    Some(value) => value
    None =>
      match solver_infer_function(solver_normalize_equation(eq), 1) {
        Some(value) => value
        None => raise SolverError::ValueError("unable to infer ODE function")
      }
  }
  let (_, args) = match @symcore.undefined_application_parts(f) {
    Some(parts) => parts
    None => raise SolverError::ValueError("expected applied undefined function")
  }
  guard args.length() == 1 else {
    raise SolverError::ValueError("expected an ordinary single-variable function")
  }
  let recognized = classify_ode(eq, func=Some(f))
  guard hint == "default" || hint == "1st_linear" || recognized.contains(hint) else {
    raise SolverError::ValueError("unsupported ODE hint: " + hint)
  }
  let (wrt, coeff_d, coeff_f, constant) = match solver_extract_ode_linear(eq, f) {
    Some(value) => value
    None => raise SolverError::ValueError("ODE is not recognized by dsolve")
  }
  let p = canonical_expr(
    @symcore.mul([coeff_f, @symcore.pow(coeff_d, @symcore.int(-1))]),
  )
  let q = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      constant,
      @symcore.pow(coeff_d, @symcore.int(-1)),
    ]),
  )
  let integral_p = canonical_expr(@symintegrals.integrate(p, limits=[wrt]))
  let mu = @symcore.function("exp", [integral_p])
  let inv_mu = @symcore.function(
    "exp",
    [canonical_expr(@symcore.mul([@symcore.int(-1), integral_p]))],
  )
  let c1 = Expr::Symbol("C1")
  let rhs = if @symcore.is_zero(q) {
    canonical_expr(@symcore.mul([c1, inv_mu]))
  } else {
    let integral_q = canonical_expr(
      @symintegrals.integrate(canonical_expr(@symcore.mul([mu, q])), limits=[wrt]),
    )
    canonical_expr(
      @symcore.mul([
        inv_mu,
        @symcore.add([c1, integral_q]),
      ]),
    )
  }
  Expr::Relational(@symcore.RelOp::Eq, f, rhs)
}

///|
pub fn checkodesol(
  ode : Expr,
  sol : Expr,
  func? : Expr? = None,
) -> (Bool, Expr) raise SolverError {
  let f = match func {
    Some(value) => value
    None =>
      match sol {
        Expr::Relational(@symcore.RelOp::Eq, lhs, rhs) =>
          match solver_infer_function(lhs, 1) {
            Some(value) => value
            None =>
              match solver_infer_function(rhs, 1) {
                Some(value) => value
                None =>
                  match solver_infer_function(solver_normalize_equation(ode), 1) {
                    Some(value) => value
                    None =>
                      raise SolverError::ValueError(
                        "unable to infer ODE function",
                      )
                  }
              }
          }
        _ =>
          match solver_infer_function(solver_normalize_equation(ode), 1) {
            Some(value) => value
            None => raise SolverError::ValueError("unable to infer ODE function")
          }
      }
  }
  let rhs = match sol {
    Expr::Relational(@symcore.RelOp::Eq, lhs, value) =>
      if solver_is_same_undefined_application(lhs, f) {
        value
      } else if solver_is_same_undefined_application(value, f) {
        lhs
      } else {
        raise SolverError::ValueError("solution must solve for the target function")
      }
    _ => sol
  }
  match solver_extract_ode_linear(ode, f) {
    Some((wrt, coeff_d, coeff_f, constant)) => {
      let residual = canonical_expr(
        @symcore.add([
          @symcore.mul([coeff_d, @symcalculus.diff(rhs, wrt)]),
          @symcore.mul([coeff_f, rhs]),
          constant,
        ]),
      )
      return (expr_is_zeroish(residual) == Some(true), residual)
    }
    None => ()
  }
  let residual = canonical_expr(
    solver_rewrite_solution_nodes(solver_normalize_equation(ode), f, rhs),
  )
  (expr_is_zeroish(residual) == Some(true), residual)
}

///|
fn solver_expr_arrays_equal(xs : Array[Expr], ys : Array[Expr]) -> Bool {
  if xs.length() != ys.length() {
    return false
  }
  for item in xs {
    if !solver_expr_in_list(ys, item) {
      return false
    }
  }
  true
}

///|
fn solver_first_sep_vars(sep : Array[Expr]) -> Array[Expr] raise SolverError {
  guard !sep.is_empty() else {
    raise SolverError::ValueError("separation requires at least one factor")
  }
  match @symcore.application_parts(sep[0]) {
    Some((_, args)) => args
    None => raise SolverError::ValueError("separated terms must be applications")
  }
}

///|
fn solver_all_other_sep_vars(sep : Array[Expr]) -> Array[Expr] raise SolverError {
  let out : Array[Expr] = []
  for i in 1..<sep.length() {
    match @symcore.application_parts(sep[i]) {
      Some((_, args)) =>
        for arg in args {
          out.push(arg)
        }
      None => raise SolverError::ValueError("separated terms must be applications")
    }
  }
  out
}

///|
fn solver_simple_pde_separate(
  expr : Expr,
  dep_vars : Array[Expr],
  other_vars : Array[Expr],
) -> Array[Expr]? {
  let terms = match canonical_expr(expr) {
    Expr::Add(args) => args
    other => [other]
  }
  let lhs : Array[Expr] = []
  let rhs : Array[Expr] = []
  for term in terms {
    let dep = solver_depends_on_any(term, dep_vars)
    let other = solver_depends_on_any(term, other_vars)
    if dep && other {
      return None
    }
    if other {
      rhs.push(term)
    } else {
      lhs.push(term)
    }
  }
  guard !lhs.is_empty() && !rhs.is_empty() else {
    return None
  }
  Some([
    canonical_expr(solver_add_all(lhs)),
    canonical_expr(@symcore.mul([@symcore.int(-1), solver_add_all(rhs)])),
  ])
}

///|
pub fn pde_separate(
  eq : Expr,
  fun : Expr,
  sep : Array[Expr],
  strategy? : String = "mul",
) -> Array[Expr]? raise SolverError {
  guard strategy == "add" || strategy == "mul" else {
    raise SolverError::ValueError("unknown separation strategy: " + strategy)
  }
  let (_, orig_args) = match @symcore.undefined_application_parts(fun) {
    Some(parts) => parts
    None => raise SolverError::ValueError("expected applied undefined function")
  }
  let subs_args : Array[Expr] = []
  for item in sep {
    match @symcore.application_parts(item) {
      Some((_, args)) =>
        for arg in args {
          subs_args.push(arg)
        }
      None => raise SolverError::ValueError("separated terms must be applications")
    }
  }
  guard orig_args.length() == subs_args.length() else {
    raise SolverError::ValueError("variable counts do not match")
  }
  let unique_subs = solver_sorted_unique_symbols(subs_args)
  guard unique_subs.length() == subs_args.length() else {
    raise SolverError::ValueError("duplicate substitution arguments detected")
  }
  guard solver_expr_arrays_equal(orig_args, subs_args) else {
    raise SolverError::ValueError("arguments do not match")
  }
  if sep.length() == 2 {
    match solver_match_equal_derivative_pde(eq, fun) {
      Some((x, y)) => {
        let left = sep[0]
        let right = sep[1]
        let left_part = if strategy == "add" {
          canonical_expr(@symcalculus.diff(left, x))
        } else {
          canonical_expr(
            @symcore.mul([
              @symcalculus.diff(left, x),
              @symcore.pow(left, @symcore.int(-1)),
            ]),
          )
        }
        let right_part = if strategy == "add" {
          canonical_expr(@symcalculus.diff(right, y))
        } else {
          canonical_expr(
            @symcore.mul([
              @symcalculus.diff(right, y),
              @symcore.pow(right, @symcore.int(-1)),
            ]),
          )
        }
        return Some([left_part, right_part])
      }
      None => ()
    }
    match solver_extract_pde_linear_homogeneous(eq, fun) {
      Some((x, y, a, b, c)) if @symcore.is_zero(c) => {
        let left = sep[0]
        let right = sep[1]
        let left_part = if strategy == "add" {
          canonical_expr(@symcore.mul([a, @symcalculus.diff(left, x)]))
        } else {
          canonical_expr(
            @symcore.mul([
              a,
              @symcalculus.diff(left, x),
              @symcore.pow(left, @symcore.int(-1)),
            ]),
          )
        }
        let right_part = if strategy == "add" {
          canonical_expr(@symcore.mul([@symcore.int(-1), b, @symcalculus.diff(right, y)]))
        } else {
          canonical_expr(
            @symcore.mul([
              @symcore.int(-1),
              b,
              @symcalculus.diff(right, y),
              @symcore.pow(right, @symcore.int(-1)),
            ]),
          )
        }
        return Some([left_part, right_part])
      }
      _ => ()
    }
  }
  let replacement = if strategy == "add" { solver_add_all(sep) } else { solver_mul_all(sep) }
  let mut result = canonical_expr(
    solver_rewrite_solution_nodes(solver_normalize_equation(eq), fun, replacement),
  )
  if strategy == "mul" {
    let terms = match result {
      Expr::Add(args) => args
      other => [other]
    }
    let divided : Array[Expr] = []
    let inv = @symcore.pow(replacement, @symcore.int(-1))
    for term in terms {
      divided.push(canonical_expr(@symcore.mul([term, inv])))
    }
    result = canonical_expr(solver_add_all(divided))
  }
  solver_simple_pde_separate(
    result,
    solver_first_sep_vars(sep),
    solver_all_other_sep_vars(sep),
  )
}

///|
pub fn pde_separate_add(
  eq : Expr,
  fun : Expr,
  sep : Array[Expr],
) -> Array[Expr]? raise SolverError {
  pde_separate(eq, fun, sep, strategy="add")
}

///|
pub fn pde_separate_mul(
  eq : Expr,
  fun : Expr,
  sep : Array[Expr],
) -> Array[Expr]? raise SolverError {
  pde_separate(eq, fun, sep, strategy="mul")
}

///|
fn solver_extract_pde_linear_homogeneous(
  eq : Expr,
  func : Expr,
) -> (Expr, Expr, Expr, Expr, Expr)? {
  let (_, args) = match @symcore.undefined_application_parts(func) {
    Some(parts) => parts
    None => return None
  }
  guard args.length() == 2 else {
    return None
  }
  let x = args[0]
  let y = args[1]
  let dx = @symcalculus.diff(func, x)
  let dy = @symcalculus.diff(func, y)
  match solver_extract_linear_targets(solver_normalize_equation(eq), [dx, dy, func]) {
    Some((coeffs, constant)) =>
      if @symcore.is_zero(coeffs[0]) && @symcore.is_zero(coeffs[1]) {
        None
      } else if solver_depends_on_any(coeffs[0], args) ||
        solver_depends_on_any(coeffs[1], args) ||
        solver_depends_on_any(coeffs[2], args) ||
        !@symcore.is_zero(constant) {
        None
      } else {
        Some((x, y, coeffs[0], coeffs[1], coeffs[2]))
      }
    _ => None
  }
}

///|
fn solver_match_equal_derivative_pde(eq : Expr, func : Expr) -> (Expr, Expr)? {
  let (_, args) = match @symcore.undefined_application_parts(func) {
    Some(parts) => parts
    None => return None
  }
  guard args.length() == 2 else {
    return None
  }
  let x = args[0]
  let y = args[1]
  let dx = @symcalculus.diff(func, x)
  let dy = @symcalculus.diff(func, y)
  match eq {
    Expr::Relational(@symcore.RelOp::Eq, lhs, rhs) =>
      if solver_is_same_target(lhs, dx) && solver_is_same_target(rhs, dy) {
        Some((x, y))
      } else if solver_is_same_target(lhs, dy) &&
        solver_is_same_target(rhs, dx) {
        Some((y, x))
      } else {
        None
      }
    _ => None
  }
}

///|
fn solver_pdsolve_equal_derivative(eq : Expr, func : Expr) -> Expr? {
  match solver_match_equal_derivative_pde(eq, func) {
    Some((x, y)) =>
      Some(
        Expr::Relational(
          @symcore.RelOp::Eq,
          func,
          @symcore.applied_undefined_function(
            "F",
            [canonical_expr(@symcore.mul([@symcore.int(-1), @symcore.add([x, y])]))],
          ),
        ),
      )
    None => None
  }
}

///|
fn solver_equal_derivative_rhs_residual(
  rhs : Expr,
  x : Expr,
  y : Expr,
) -> Expr? {
  match @symcore.undefined_application_parts(rhs) {
    Some((_, args)) if args.length() == 1 => {
      let arg = args[0]
      let dx = canonical_expr(@symcalculus.diff(arg, x))
      let dy = canonical_expr(@symcalculus.diff(arg, y))
      let difference = canonical_expr(
        @symcore.add([dx, @symcore.mul([@symcore.int(-1), dy])]),
      )
      if expr_is_zeroish(difference) == Some(true) {
        Some(@symcore.int(0))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
pub fn classify_pde(
  eq : Expr,
  func? : Expr? = None,
) -> Array[String] raise SolverError {
  let f = match func {
    Some(value) => value
    None =>
      match solver_infer_function(solver_normalize_equation(eq), 2) {
        Some(value) => value
        None => raise SolverError::ValueError("unable to infer PDE function")
      }
  }
  match solver_extract_pde_linear_homogeneous(eq, f) {
    Some(_) => ["1st_linear_constant_coeff_homogeneous"]
    None =>
      match solver_match_equal_derivative_pde(eq, f) {
        Some(_) => ["1st_linear_constant_coeff_homogeneous"]
        None => []
      }
  }
}

///|
pub fn pdsolve(
  eq : Expr,
  func? : Expr? = None,
  hint? : String = "default",
) -> Expr raise SolverError {
  let f = match func {
    Some(value) => value
    None =>
      match solver_infer_function(solver_normalize_equation(eq), 2) {
        Some(value) => value
        None => raise SolverError::ValueError("unable to infer PDE function")
      }
  }
  guard hint == "default" || hint == "1st_linear_constant_coeff_homogeneous" else {
    raise SolverError::ValueError("unsupported PDE hint: " + hint)
  }
  match solver_pdsolve_equal_derivative(eq, f) {
    Some(value) => return value
    None => ()
  }
  let (x, y, a, b, c) = match solver_extract_pde_linear_homogeneous(eq, f) {
    Some(value) => value
    None => raise SolverError::ValueError("PDE is not recognized by pdsolve")
  }
  let invariant = canonical_expr(
    @symcore.add([
      @symcore.mul([b, x]),
      @symcore.mul([@symcore.int(-1), a, y]),
    ]),
  )
  let arbitrary = @symcore.applied_undefined_function("F", [invariant])
  let rhs = if @symcore.is_zero(c) {
    arbitrary
  } else {
    let denom = canonical_expr(
      @symcore.add([a ^ @symcore.int(2), b ^ @symcore.int(2)]),
    )
    let exponent = canonical_expr(
      @symcore.mul([
        @symcore.int(-1),
        c,
        @symcore.add([@symcore.mul([a, x]), @symcore.mul([b, y])]),
        @symcore.pow(denom, @symcore.int(-1)),
      ]),
    )
    canonical_expr(@symcore.mul([arbitrary, @symcore.function("exp", [exponent])]))
  }
  Expr::Relational(@symcore.RelOp::Eq, f, rhs)
}

///|
pub fn checkpdesol(
  pde : Expr,
  sol : Expr,
  func? : Expr? = None,
) -> (Bool, Expr) raise SolverError {
  let f = match func {
    Some(value) => value
    None =>
      match sol {
        Expr::Relational(@symcore.RelOp::Eq, lhs, rhs) =>
          match solver_infer_function(lhs, 2) {
            Some(value) => value
            None =>
              match solver_infer_function(rhs, 2) {
                Some(value) => value
                None =>
                  match solver_infer_function(solver_normalize_equation(pde), 2) {
                    Some(value) => value
                    None =>
                      raise SolverError::ValueError(
                        "unable to infer PDE function",
                      )
                  }
              }
          }
        _ =>
          match solver_infer_function(solver_normalize_equation(pde), 2) {
            Some(value) => value
            None => raise SolverError::ValueError("unable to infer PDE function")
          }
      }
  }
  let rhs = match sol {
    Expr::Relational(@symcore.RelOp::Eq, lhs, value) =>
      if solver_is_same_undefined_application(lhs, f) {
        value
      } else if solver_is_same_undefined_application(value, f) {
        lhs
      } else {
        raise SolverError::ValueError("solution must solve for the target function")
      }
    _ => sol
  }
  match solver_match_equal_derivative_pde(pde, f) {
    Some((x, y)) => {
      let residual = match solver_equal_derivative_rhs_residual(rhs, x, y) {
        Some(value) => value
        None =>
          canonical_expr(
            @symcore.add([
              @symcalculus.diff(rhs, x),
              @symcore.mul([@symcore.int(-1), @symcalculus.diff(rhs, y)]),
            ]),
          )
      }
      return (expr_is_zeroish(residual) == Some(true), residual)
    }
    None => ()
  }
  match solver_extract_pde_linear_homogeneous(pde, f) {
    Some((x, y, a, b, c)) => {
      let residual = canonical_expr(
        @symcore.add([
          @symcore.mul([a, @symcalculus.diff(rhs, x)]),
          @symcore.mul([b, @symcalculus.diff(rhs, y)]),
          @symcore.mul([c, rhs]),
        ]),
      )
      return (expr_is_zeroish(residual) == Some(true), residual)
    }
    None => ()
  }
  let residual = canonical_expr(
    solver_rewrite_solution_nodes(solver_normalize_equation(pde), f, rhs),
  )
  (expr_is_zeroish(residual) == Some(true), residual)
}
