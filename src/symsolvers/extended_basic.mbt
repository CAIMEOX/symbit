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
fn solver_expand_mul_sequence(factors : Array[Expr]) -> Expr {
  let mut terms : Array[Expr] = [@symcore.int(1)]
  for factor in factors {
    match factor {
      Expr::Add(args) => {
        let next_terms : Array[Expr] = []
        for term in terms {
          for arg in args {
            next_terms.push(canonical_expr(@symcore.mul([term, arg])))
          }
        }
        terms = next_terms
      }
      _ =>
        for i in 0..<terms.length() {
          terms[i] = canonical_expr(@symcore.mul([terms[i], factor]))
        }
    }
  }
  solver_add_all(terms)
}

///|
fn solver_expand_expr(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => canonical_expr(@symcore.add(args.map(arg => solver_expand_expr(arg))))
    Expr::Mul(args) => solver_expand_mul_sequence(args.map(arg => solver_expand_expr(arg)))
    Expr::Pow(base, exp) => {
      let expanded_base = solver_expand_expr(base)
      let expanded_exp = solver_expand_expr(exp)
      match @symcore.exact_numeric_expr_num_den(expanded_exp) {
        Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) >= 0 && num.compare(8N) <= 0 => {
          let power = num.to_int()
          if power == 0 {
            @symcore.int(1)
          } else {
            let factors : Array[Expr] = Array::make(power, expanded_base)
            solver_expand_mul_sequence(factors)
          }
        }
        _ => canonical_expr(@symcore.pow(expanded_base, expanded_exp))
      }
    }
    Expr::Apply(head, args) =>
      @symcore.raw_apply(head, args.map(arg => solver_expand_expr(arg))).unwrap_or(
        Expr::Apply(head, args.map(arg => solver_expand_expr(arg))),
      )
    _ => expr
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
  root : Expr,
) -> Expr {
  let local_replacement = solver_constantsimp_replacement_for(expr, constants, replacement)
  if !solver_depends_on_any(expr, constants) {
    return expr
  }
  if solver_depends_only_on(expr, constants) &&
    solver_constantsimp_can_replace(expr, root, constants) {
    return local_replacement
  }
  if @symcore.application_has_name(expr, "exp", arity=1) {
    match @symcore.application_args(expr) {
      Some([Expr::Add(args)]) => {
        let absorbable : Array[Expr] = []
        let kept : Array[Expr] = []
        for arg in args {
          if solver_constantsimp_absorbable(arg, constants) {
            absorbable.push(arg)
          } else {
            kept.push(solver_constantsimp_inner(arg, constants, replacement, root))
          }
        }
        if !absorbable.is_empty() && !kept.is_empty() &&
          solver_constantsimp_can_replace(solver_add_all(absorbable), root, constants) {
          let absorbed = solver_add_all(absorbable)
          return solver_mul_all([
            solver_constantsimp_replacement_for(absorbed, constants, replacement),
            @symcore.function("exp", [solver_add_all(kept)]),
          ])
        }
      }
      _ => ()
    }
  }
  match expr {
    Expr::Add(args) => {
      let rebuilt : Array[Expr] = []
      let absorbed : Array[Expr] = []
      let mut collapsed = false
      for arg in args {
        if solver_constantsimp_absorbable(arg, constants) {
          collapsed = true
          absorbed.push(arg)
        } else {
          rebuilt.push(solver_constantsimp_inner(arg, constants, replacement, root))
        }
      }
      if collapsed &&
        solver_constantsimp_can_replace(solver_add_all(absorbed), root, constants) {
        rebuilt.push(
          solver_constantsimp_replacement_for(
            solver_add_all(absorbed),
            constants,
            replacement,
          ),
        )
        solver_add_all(rebuilt)
      } else {
        solver_add_all(args.map(arg => solver_constantsimp_inner(arg, constants, replacement, root)))
      }
    }
    Expr::Mul(args) => {
      let rebuilt : Array[Expr] = []
      let absorbed : Array[Expr] = []
      let mut collapsed = false
      for arg in args {
        if solver_constantsimp_absorbable(arg, constants) {
          collapsed = true
          absorbed.push(arg)
        } else {
          rebuilt.push(solver_constantsimp_inner(arg, constants, replacement, root))
        }
      }
      if collapsed &&
        solver_constantsimp_can_replace(solver_mul_all(absorbed), root, constants) {
        rebuilt.push(
          solver_constantsimp_replacement_for(
            solver_mul_all(absorbed),
            constants,
            replacement,
          ),
        )
        solver_mul_all(rebuilt)
      } else {
        solver_mul_all(args.map(arg => solver_constantsimp_inner(arg, constants, replacement, root)))
      }
    }
    Expr::Pow(base, exp) =>
      if solver_constantsimp_absorbable(base, constants) &&
        solver_constantsimp_absorbable(exp, constants) &&
        solver_constantsimp_can_replace(expr, root, constants) {
        replacement
      } else {
        @symcore.pow(
          solver_constantsimp_inner(base, constants, replacement, root),
          solver_constantsimp_inner(exp, constants, replacement, root),
        )
      }
    _ => @symcore.map_children(
      expr,
      child => solver_constantsimp_inner(child, constants, replacement, root),
    )
  }
}

///|
fn solver_constantsimp_absorbable(expr : Expr, constants : Array[Expr]) -> Bool {
  let free = @symcore.free_symbols(expr)
  if free.is_empty() {
    return true
  }
  for symbol in free {
    if !solver_expr_in_list(constants, symbol) {
      return false
    }
  }
  true
}

///|
fn solver_constantsimp_replacement_for(
  expr : Expr,
  constants : Array[Expr],
  fallback : Expr,
) -> Expr {
  let free = @symcore.free_symbols(expr)
  let mut best : Expr? = None
  for symbol in constants {
    if !solver_expr_in_list(free, symbol) {
      continue
    }
    let name = match symbol {
      Expr::Symbol(s) => s
      _ => continue
    }
    let take = match best {
      None => true
      Some(current) => {
        let current_name = match current {
          Expr::Symbol(s) => s
          _ => ""
        }
        if name.has_prefix("C") && !current_name.has_prefix("C") {
          true
        } else if name.has_prefix("C") == current_name.has_prefix("C") {
          name.compare(current_name) < 0
        } else {
          false
        }
      }
    }
    if take {
      best = Some(symbol)
    }
  }
  match best {
    Some(value) => value
    None => expr
  }
}

///|
fn solver_constantsimp_occurs(root : Expr, needle : Expr) -> Int {
  let mut total = 0
  if @symcore.compare_expr(root, needle) == 0 {
    total += 1
  }
  for child in @symcore.children(root) {
    total += solver_constantsimp_occurs(child, needle)
  }
  total
}

///|
fn solver_constantsimp_can_replace(
  expr : Expr,
  root : Expr,
  constants : Array[Expr],
) -> Bool {
  let free = @symcore.free_symbols(expr)
  if free.is_empty() {
    return false
  }
  for symbol in free {
    if !solver_expr_in_list(constants, symbol) {
      return false
    }
    if solver_constantsimp_occurs(root, symbol) != solver_constantsimp_occurs(expr, symbol) {
      return false
    }
  }
  true
}

///|
fn solver_constantsimp_direct_constant_term(expr : Expr, constants : Array[Expr]) -> Bool {
  @symcore.is_number_atom(expr) || solver_expr_in_list(constants, expr)
}

///|
fn solver_constantsimp_add_terms(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Add(args) => args
    _ => [expr]
  }
}

///|
fn solver_constantsimp_mul_terms(expr : Expr) -> Array[Expr] {
  match expr {
    Expr::Mul(args) => args
    _ => [expr]
  }
}

///|
fn solver_constantsimp_eq_addlike(expr : Expr) -> Bool {
  match expr {
    Expr::Add(_) | Expr::Symbol(_) => true
    _ => false
  }
}

///|
fn solver_constantsimp_eq_mullike(expr : Expr) -> Bool {
  match expr {
    Expr::Mul(_) | Expr::Symbol(_) => true
    _ => false
  }
}

///|
fn solver_constantsimp_postprocess_eq(expr : Expr, constants : Array[Expr]) -> Expr {
  match expr {
    Expr::Relational(@symcore.RelOp::Eq, lhs0, rhs0) => {
      let mut lhs = lhs0
      let mut rhs = rhs0
      if solver_expr_in_list(constants, lhs) {
        let tmp = lhs
        lhs = rhs
        rhs = tmp
      }
      if solver_expr_in_list(constants, rhs) && solver_constantsimp_eq_addlike(lhs) {
        let lhs_nonconst : Array[Expr] = []
        for term in solver_constantsimp_add_terms(lhs) {
          if !solver_constantsimp_direct_constant_term(term, constants) {
            lhs_nonconst.push(term)
          }
        }
        if !lhs_nonconst.is_empty() {
          Expr::Relational(@symcore.RelOp::Eq, solver_add_all(lhs_nonconst), constants[0])
        } else {
          expr
        }
      } else if solver_expr_in_list(constants, rhs) && solver_constantsimp_eq_mullike(lhs) {
        let lhs_nonconst : Array[Expr] = []
        for term in solver_constantsimp_mul_terms(lhs) {
          if !solver_constantsimp_direct_constant_term(term, constants) {
            lhs_nonconst.push(term)
          }
        }
        if !lhs_nonconst.is_empty() {
          Expr::Relational(@symcore.RelOp::Eq, solver_mul_all(lhs_nonconst), constants[0])
        } else {
          expr
        }
      } else {
        expr
      }
    }
    _ => expr
  }
}

///|
fn solver_constantsimp_negative_one_power_base(expr : Expr) -> Expr? {
  match expr {
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) if num.compare(-1N) == 0 && den.compare(1N) == 0 => Some(base)
        _ => None
      }
    _ => None
  }
}

///|
fn solver_constantsimp_inverse_sqrt_base(expr : Expr) -> Expr? {
  if @symcore.application_has_name(expr, "sqrt", arity=1) {
    match @symcore.application_args(expr) {
      Some([arg]) => solver_constantsimp_negative_one_power_base(arg)
      _ => None
    }
  } else {
    None
  }
}

///|
fn solver_constantsimp_radical_cleanup(expr : Expr) -> Expr {
  match expr {
    _ if @symcore.application_has_name(expr, "sqrt", arity=1) =>
      match @symcore.application_args(expr) {
        Some([arg]) =>
          @symcore.function(
            "sqrt",
            [@symsimplify.simplify(solver_constantsimp_radical_cleanup(arg), max_passes=2)],
          )
        _ => expr
      }
    Expr::Mul(args) => {
      let cleaned = args.map(arg => solver_constantsimp_radical_cleanup(arg))
      let used : Array[Bool] = Array::make(cleaned.length(), false)
      let rebuilt : Array[Expr] = []
      for i in 0..<cleaned.length() {
        if used[i] {
          continue
        }
        let mut paired = false
        for j in (i + 1)..<cleaned.length() {
          if used[j] {
            continue
          }
          match solver_constantsimp_inverse_sqrt_base(cleaned[j]) {
            Some(base) if @symcore.compare_expr(cleaned[i], base) == 0 => {
              used[i] = true
              used[j] = true
              rebuilt.push(@symcore.function("sqrt", [base]))
              paired = true
              break
            }
            _ => ()
          }
          match solver_constantsimp_inverse_sqrt_base(cleaned[i]) {
            Some(base) if @symcore.compare_expr(cleaned[j], base) == 0 => {
              used[i] = true
              used[j] = true
              rebuilt.push(@symcore.function("sqrt", [base]))
              paired = true
              break
            }
            _ => ()
          }
        }
        if !paired {
          used[i] = true
          rebuilt.push(cleaned[i])
        }
      }
      solver_mul_all(rebuilt)
    }
    Expr::Add(args) => solver_add_all(args.map(arg => solver_constantsimp_radical_cleanup(arg)))
    Expr::Pow(base, exp) =>
      @symcore.pow(
        solver_constantsimp_radical_cleanup(base),
        solver_constantsimp_radical_cleanup(exp),
      )
    _ => @symcore.map_children(
      expr,
      child => solver_constantsimp_radical_cleanup(child),
    )
  }
}

///|
pub fn constantsimp(expr : Expr, constants : Array[Expr]) -> Expr raise SolverError {
  let normalized = solver_sorted_unique_symbols(constants)
  if normalized.is_empty() {
    return expr
  }
  let mut replacement = normalized[0]
  let mut replacement_name = symbol_name(replacement)
  for item in normalized {
    let name = symbol_name(item)
    let prefer_item = if name.starts_with("C") && !replacement_name.starts_with("C") {
      true
    } else if name.starts_with("C") == replacement_name.starts_with("C") {
      name.compare(replacement_name) < 0
    } else {
      false
    }
    if prefer_item {
      replacement = item
      replacement_name = name
    }
  }
  solver_constantsimp_radical_cleanup(
    solver_constantsimp_postprocess_eq(
      solver_constantsimp_inner(expr, normalized, replacement, expr),
      normalized,
    ),
  )
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
fn solver_diff_by_vars(expr : Expr, vars : Array[Expr]) -> Expr {
  let mut out = expr
  for wrt in vars {
    out = @symcalculus.diff(out, wrt)
  }
  canonical_expr(out)
}

///|
fn solver_diff_n(expr : Expr, wrt : Expr, order : Int) -> Expr {
  let vars : Array[Expr] = []
  for _ in 0..<order {
    vars.push(wrt)
  }
  solver_diff_by_vars(expr, vars)
}

///|
fn solver_application_signature(expr : Expr) -> (String, Array[Expr])? {
  match @symcore.application_parts(expr) {
    Some((head, args)) =>
      match @symcore.function_head_name(head) {
        Some(name) => Some((name, args))
        None => None
      }
    None => None
  }
}

///|
fn solver_is_same_undefined_application(lhs : Expr, rhs : Expr) -> Bool {
  if @symcore.compare_expr(lhs, rhs) == 0 {
    return true
  }
  match (solver_application_signature(lhs), solver_application_signature(rhs)) {
    (Some((lname, largs)), Some((rname, rargs))) =>
      lname == rname && solver_expr_arrays_equal(largs, rargs)
    _ => false
  }
}

///|
fn solver_derivative_signature(expr : Expr) -> (Expr, Array[Expr])? {
  match @symcore.derivative_parts(expr) {
    Some((inner, args)) => {
      let vars = solver_derivative_vars(args)
      match solver_derivative_signature(inner) {
        Some((base, inner_vars)) => {
          let out = inner_vars.copy()
          for item in vars {
            out.push(item)
          }
          Some((base, out))
        }
        None =>
          match solver_application_signature(inner) {
            Some(_) => Some((inner, vars))
            None => None
          }
      }
    }
    None => None
  }
}

///|
fn solver_is_same_target(lhs : Expr, rhs : Expr) -> Bool {
  if solver_is_same_undefined_application(lhs, rhs) {
    return true
  }
  match (solver_derivative_signature(lhs), solver_derivative_signature(rhs)) {
    (Some((lbase, lvars)), Some((rbase, rvars))) =>
      solver_is_same_undefined_application(lbase, rbase) &&
      solver_expr_arrays_equal(lvars, rvars)
    _ => @symcore.compare_expr(lhs, rhs) == 0
  }
}

///|
fn solver_expr_has_target(expr : Expr, target : Expr) -> Bool {
  for node in @symcore.preorder(expr) {
    if solver_is_same_target(node, target) {
      return true
    }
  }
  false
}

///|
fn solver_replace_targets(
  expr : Expr,
  replacements : Array[(Expr, Expr)],
) -> Expr {
  for pair in replacements {
    if solver_is_same_target(expr, pair.0) {
      return pair.1
    }
  }
  @symcore.map_children(expr, child => solver_replace_targets(child, replacements))
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
  let mut best = 0
  match solver_derivative_signature(normalized) {
    Some((base, vars)) =>
      if solver_is_same_undefined_application(base, func) {
        best = vars.length()
      }
    None => ()
  }
  for arg in @symcore.args(normalized) {
    let current = ode_order(arg, func)
    if current > best {
      best = current
    }
  }
  best
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
        } else if solver_expr_has_target(arg, target) {
          return None
        } else {
          factors.push(arg)
        }
      }
      if seen {
        Some(solver_mul_all(factors))
      } else if solver_expr_has_target(term, target) {
        None
      } else {
        Some(@symcore.int(0))
      }
    }
    _ =>
      if solver_expr_has_target(term, target) {
        None
      } else {
        Some(@symcore.int(0))
      }
  }
}

///|
fn solver_zero_linear_coeffs(targets : Array[Expr]) -> Array[Expr] {
  Array::make(targets.length(), @symcore.int(0))
}

///|
fn solver_expr_has_any_target(expr : Expr, targets : Array[Expr]) -> Bool {
  targets.any(target => solver_expr_has_target(expr, target))
}

///|
fn solver_linear_scale_parts(
  parts : (Array[Expr], Expr),
  scale : Expr,
) -> (Array[Expr], Expr) {
  let coeffs : Array[Expr] = []
  for coeff in parts.0 {
    coeffs.push(canonical_expr(@symcore.mul([scale, coeff])))
  }
  (coeffs, canonical_expr(@symcore.mul([scale, parts.1])))
}

///|
fn solver_linear_add_parts(
  lhs : (Array[Expr], Expr),
  rhs : (Array[Expr], Expr),
) -> (Array[Expr], Expr) {
  let coeffs : Array[Expr] = []
  for i in 0..<lhs.0.length() {
    coeffs.push(canonical_expr(@symcore.add([lhs.0[i], rhs.0[i]])))
  }
  (coeffs, canonical_expr(@symcore.add([lhs.1, rhs.1])))
}

///|
fn solver_linear_decompose_targets(
  expr : Expr,
  targets : Array[Expr],
) -> (Array[Expr], Expr)? {
  let coeffs0 = solver_zero_linear_coeffs(targets)
  for i in 0..<targets.length() {
    if solver_is_same_target(expr, targets[i]) {
      coeffs0[i] = @symcore.int(1)
      return Some((coeffs0, @symcore.int(0)))
    }
  }
  if !solver_expr_has_any_target(expr, targets) {
    return Some((coeffs0, expr))
  }
  match expr {
    Expr::Add(args) => {
      let mut acc = (solver_zero_linear_coeffs(targets), @symcore.int(0))
      for arg in args {
        match solver_linear_decompose_targets(arg, targets) {
          Some(parts) => acc = solver_linear_add_parts(acc, parts)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let scale_factors : Array[Expr] = []
      let mut dependent : (Array[Expr], Expr)? = None
      for arg in args {
        if !solver_expr_has_any_target(arg, targets) {
          scale_factors.push(arg)
          continue
        }
        match solver_linear_decompose_targets(arg, targets) {
          Some(parts) => {
            let coeff_nonzero = parts.0.any(coeff => !@symcore.is_zero(coeff))
            if !coeff_nonzero {
              scale_factors.push(parts.1)
            } else if dependent is None {
              dependent = Some(parts)
            } else {
              return None
            }
          }
          None => return None
        }
      }
      let scale = solver_mul_all(scale_factors)
      match dependent {
        Some(parts) => Some(solver_linear_scale_parts(parts, scale))
        None => Some((solver_zero_linear_coeffs(targets), scale))
      }
    }
    _ => None
  }
}

///|
fn solver_extract_linear_targets(
  expr : Expr,
  targets : Array[Expr],
) -> (Array[Expr], Expr)? {
  match solver_linear_decompose_targets(solver_normalize_equation(expr), targets) {
    Some((coeffs, constant)) =>
      Some((
        coeffs.map(canonical_expr),
        canonical_expr(constant),
      ))
    None => None
  }
}

///|
fn solver_quadratic_factor_coeff(term : Expr, target : Expr) -> Expr? {
  match term {
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) if num.compare(2N) == 0 && den.compare(1N) == 0 &&
          solver_is_same_target(base, target) => Some(@symcore.int(1))
        _ =>
          if solver_expr_has_target(term, target) {
            None
          } else {
            Some(@symcore.int(0))
          }
      }
    Expr::Mul(args) => {
      let factors : Array[Expr] = []
      let mut seen = false
      for arg in args {
        match arg {
          Expr::Pow(base, exp) =>
            match @symcore.exact_numeric_expr_num_den(exp) {
              Some((num, den)) if num.compare(2N) == 0 && den.compare(1N) == 0 &&
                solver_is_same_target(base, target) =>
                if seen {
                  return None
                } else {
                  seen = true
                }
              _ =>
                if solver_expr_has_target(arg, target) {
                  return None
                } else {
                  factors.push(arg)
                }
            }
          _ =>
            if solver_expr_has_target(arg, target) {
              return None
            } else {
              factors.push(arg)
            }
        }
      }
      if seen {
        Some(solver_mul_all(factors))
      } else if solver_expr_has_target(term, target) {
        None
      } else {
        Some(@symcore.int(0))
      }
    }
    _ =>
      if solver_expr_has_target(term, target) {
        None
      } else {
        Some(@symcore.int(0))
      }
  }
}

///|
fn solver_extract_quadratic_target(
  expr : Expr,
  target : Expr,
) -> (Expr, Expr, Expr)? {
  let terms = match solver_normalize_equation(expr) {
    Expr::Add(args) => args
    other => [other]
  }
  let mut coeff_sq = @symcore.int(0)
  let mut coeff_lin = @symcore.int(0)
  let mut constant = @symcore.int(0)
  for term in terms {
    match solver_quadratic_factor_coeff(term, target) {
      Some(q) if !@symcore.is_zero(q) => {
        coeff_sq = canonical_expr(@symcore.add([coeff_sq, q]))
      }
      Some(_) | None =>
        match solver_linear_factor_coeff(term, target) {
          Some(l) if !@symcore.is_zero(l) =>
            coeff_lin = canonical_expr(@symcore.add([coeff_lin, l]))
          Some(_) => constant = canonical_expr(@symcore.add([constant, term]))
          None => return None
        }
    }
  }
  Some((coeff_sq, coeff_lin, constant))
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
  if solver_is_same_target(expr, func) {
    return rhs
  }
  match expr {
    Expr::Derivative(inner, deriv_args) => {
      let rewritten_inner = solver_rewrite_solution_nodes(inner, func, rhs)
      let rewritten_args = deriv_args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs))
      solver_diff_by_vars(rewritten_inner, solver_derivative_vars(rewritten_args))
    }
    Expr::Apply(head, args) =>
      match @symcore.function_head_name(head) {
        Some("Derivative") if args.length() >= 2 => {
          let rewritten_args = args.map(arg => solver_rewrite_solution_nodes(arg, func, rhs))
          solver_diff_by_vars(
            rewritten_args[0],
            solver_derivative_vars(@symcore.canonical_derivative_args(rewritten_args[1:])),
          )
        }
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
fn solver_eq_lhs_rhs(expr : Expr) -> (Expr, Expr) {
  match @symcore.relational_parts(expr) {
    Some((@symcore.RelOp::Eq, lhs, rhs)) => (lhs, rhs)
    _ => (expr, @symcore.int(0))
  }
}

///|
fn solver_checkodesol_residual(expr : Expr) -> (Bool, Expr) {
  let residual = canonical_expr(expr)
  (expr_is_zeroish(residual) == Some(true), residual)
}

///|
fn solver_checkodesol_solved_rhs(sol : Expr, f : Expr) -> Expr? {
  match sol {
    Expr::Relational(@symcore.RelOp::Eq, lhs, rhs) =>
      if solver_is_same_target(lhs, f) && !solver_expr_has_target(rhs, f) {
        Some(rhs)
      } else if solver_is_same_target(rhs, f) && !solver_expr_has_target(lhs, f) {
        Some(lhs)
      } else {
        None
      }
    _ => None
  }
}

///|
fn solver_checkodesol_rewrite_solution(sol : Expr, f : Expr) -> Expr {
  match sol {
    Expr::Relational(@symcore.RelOp::Eq, lhs, rhs) =>
      if solver_is_same_target(rhs, f) {
        Expr::Relational(@symcore.RelOp::Eq, rhs, lhs)
      } else {
        sol
      }
    _ => Expr::Relational(@symcore.RelOp::Eq, f, sol)
  }
}

///|
fn solver_checkodesol_solve_target(sol : Expr, target : Expr) -> Array[Expr] raise SolverError {
  solver_single_target_solutions(sol, target)
}

///|
fn solver_checkodesol_pass1(
  ode : Expr,
  sol : Expr,
  f : Expr,
) -> (Bool, Expr)? {
  match solver_checkodesol_solved_rhs(sol, f) {
    Some(rhs) => {
      let residual = solver_rewrite_solution_nodes(solver_normalize_equation(ode), f, rhs)
      Some(solver_checkodesol_residual(residual))
    }
    None => None
  }
}

///|
fn solver_checkodesol_pass2(
  ode : Expr,
  sol : Expr,
  _f : Expr,
  x : Expr,
  order : Int,
) -> (Bool, Expr) {
  let (lhs, rhs) = solver_eq_lhs_rhs(sol)
  let residual = canonical_expr(
    @symcore.add([
      solver_diff_n(lhs, x, order),
      @symcore.mul([@symcore.int(-1), solver_diff_n(rhs, x, order)]),
      @symcore.mul([@symcore.int(-1), solver_normalize_equation(ode)]),
    ]),
  )
  solver_checkodesol_residual(residual)
}

///|
fn solver_checkodesol_lookup(
  diffsols : Array[(Int, Expr)],
  order : Int,
) -> Expr? {
  for item in diffsols {
    if item.0 == order {
      return Some(item.1)
    }
  }
  None
}

///|
fn solver_checkodesol_pass3(
  ode : Expr,
  sol : Expr,
  f : Expr,
  x : Expr,
  order : Int,
) -> (Bool, Expr)? {
  let diffsols : Array[(Int, Expr)] = []
  match solver_checkodesol_solved_rhs(sol, f) {
    Some(rhs) => diffsols.push((0, rhs))
    None => ()
  }
  let sol_expr = solver_normalize_equation(sol)
  for i in 1..=order {
    if i == 1 {
      let ds = solver_diff_n(sol_expr, x, 1)
      let solved_try : Result[Array[Expr], SolverError] = try?
        solver_checkodesol_solve_target(ds, solver_ode_target(f, x, i))
      let solved = match solved_try {
        Ok(items) => items
        Err(_) => return None
      }
      guard !solved.is_empty() else {
        return None
      }
      diffsols.push((i, solved[0]))
    } else {
      let prev = diffsols[i - 1].1
      diffsols.push((i, solver_diff_n(prev, x, 1)))
    }
  }
  let (ode_lhs0, ode_rhs0) = solver_eq_lhs_rhs(ode)
  let mut ode_lhs = ode_lhs0
  let mut ode_rhs = ode_rhs0
  let mut i = order
  while i >= 0 {
    match solver_checkodesol_lookup(diffsols, i) {
      Some(rhs) => {
        let target = solver_ode_target(f, x, i)
        ode_lhs = solver_rewrite_solution_nodes(ode_lhs, target, rhs)
        ode_rhs = solver_rewrite_solution_nodes(ode_rhs, target, rhs)
      }
      None => ()
    }
    i -= 1
  }
  Some(
    solver_checkodesol_residual(
      @symcore.add([
        ode_lhs,
        @symcore.mul([@symcore.int(-1), ode_rhs]),
      ]),
    ),
  )
}

///|
fn solver_ode_target(
  func : Expr,
  wrt : Expr,
  order : Int,
) -> Expr {
  if order <= 0 {
    return func
  }
  let vars : Array[Expr] = []
  for _ in 0..<order {
    vars.push(wrt)
  }
  @symcore.raw_derivative(func, vars[:])
}

///|
fn solver_used_symbol_names(exprs : Array[Expr]) -> Array[String] {
  let names : Array[String] = []
  for expr in exprs {
    for symbol in @symcore.free_symbols(expr) {
      match symbol {
        Expr::Symbol(name) =>
          if !names.contains(name) {
            names.push(name)
          }
        _ => ()
      }
    }
  }
  names
}

///|
fn solver_temp_symbols(
  exprs : Array[Expr],
  count : Int,
  prefix : String,
) -> Array[Expr] {
  let used = solver_used_symbol_names(exprs)
  let out : Array[Expr] = []
  let mut i = 0
  while out.length() < count {
    let name = prefix + i.to_string()
    if !used.contains(name) {
      out.push(Expr::Symbol(name))
    }
    i += 1
  }
  out
}

///|
fn solver_symbolize_targets(
  eqs : Array[Expr],
  targets : Array[Expr],
  prefix : String,
) -> (Array[Expr], Array[Expr], Array[(Expr, Expr)]) {
  let symbols = solver_temp_symbols(eqs, targets.length(), prefix)
  let forward : Array[(Expr, Expr)] = []
  let backward : Array[(Expr, Expr)] = []
  for i in 0..<targets.length() {
    forward.push((targets[i], symbols[i]))
    backward.push((symbols[i], targets[i]))
  }
  (
    eqs.map(eq => solver_replace_targets(eq, forward)),
    symbols,
    backward,
  )
}

///|
fn solver_maps_from_result(
  result : SolveResult,
  symbols : Array[Expr],
) -> Array[Map[String, Expr]] raise SolverError {
  let names = solver_symbol_names(symbols)
  match result {
    SolveResult::List(items) => {
      guard names.length() == 1 else {
        raise SolverError::ValueError("expected a single symbolic target")
      }
      let out : Array[Map[String, Expr]] = []
      for item in items {
        let mapping : Map[String, Expr] = {}
        mapping[names[0]] = item
        out.push(mapping)
      }
      out
    }
    SolveResult::Dict(values) => [values]
    SolveResult::Dicts(items) => items
  }
}

///|
fn solver_func_orders(
  eqs : Array[Expr],
  funcs : Array[Expr],
) -> Array[Int] {
  let out : Array[Int] = []
  for func in funcs {
    let mut best = 0
    for eq in eqs {
      let current = ode_order(eq, func)
      if current > best {
        best = current
      }
    }
    out.push(best)
  }
  out
}

///|
fn solver_separate_mul_parts(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  let factors = match canonical_expr(expr) {
    Expr::Mul(args) => args
    other => [other]
  }
  let coeffs : Array[Expr] = []
  let xs : Array[Expr] = []
  let ys : Array[Expr] = []
  for factor in factors {
    let has_x = solver_lie_depends_on(factor, x)
    let has_y = solver_lie_depends_on(factor, y)
    if has_x && has_y {
      return None
    }
    if has_x {
      xs.push(factor)
    } else if has_y {
      ys.push(factor)
    } else {
      coeffs.push(factor)
    }
  }
  Some(SolverLieSeparated::{
    coeff: solver_mul_all(coeffs),
    x_part: solver_mul_all(xs),
    y_part: solver_mul_all(ys),
  })
}

///|
fn solver_separate_mul_parts_raw(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  let factors = match expr {
    Expr::Mul(args) => args
    other => [other]
  }
  let coeffs : Array[Expr] = []
  let xs : Array[Expr] = []
  let ys : Array[Expr] = []
  for factor in factors {
    let has_x = solver_lie_depends_on(factor, x)
    let has_y = solver_lie_depends_on(factor, y)
    if has_x && has_y {
      return None
    }
    if has_x {
      xs.push(factor)
    } else if has_y {
      ys.push(factor)
    } else {
      coeffs.push(factor)
    }
  }
  Some(SolverLieSeparated::{
    coeff: solver_mul_all(coeffs),
    x_part: solver_mul_all(xs),
    y_part: solver_mul_all(ys),
  })
}

///|
fn solver_single_target_solutions(
  eq : Expr,
  target : Expr,
) -> Array[Expr] raise SolverError {
  let normalized = solver_normalize_equation(eq)
  let expanded = canonical_expr(@symsimplify.fraction_expand(solver_expand_expr(normalized)))
  match solver_extract_linear_targets(normalized, [target]) {
    Some((coeffs, constant)) if !@symcore.is_zero(coeffs[0]) =>
      return [
        canonical_expr(
          @symcore.mul([
            @symcore.int(-1),
            constant,
            @symcore.pow(coeffs[0], @symcore.int(-1)),
          ]),
        ),
      ]
    _ => ()
  }
  match solver_extract_linear_targets(expanded, [target]) {
    Some((coeffs, constant)) if !@symcore.is_zero(coeffs[0]) =>
      return [
        canonical_expr(
          @symcore.mul([
            @symcore.int(-1),
            constant,
            @symcore.pow(coeffs[0], @symcore.int(-1)),
          ]),
        ),
      ]
    _ => ()
  }
  let (rewritten, symbols, backward) = solver_symbolize_targets(
    [expanded],
    [target],
    "__ode_sep_",
  )
  let symbol = symbols[0]
  let poly_name = solver_symbol_name(symbol)
  let poly_try : Result[Array[Expr], @sympolys.PolyError] = try? {
    let poly = @sympolys.Poly::from_expr_defaults(
      rewritten[0],
      gens=[poly_name],
      domain=@sympolys.Domain::EX,
    )
    let degree = poly.degree(0)
    if degree == 1 {
      @sympolys.roots_linear(poly)
    } else if degree == 2 {
      @sympolys.roots_quadratic(poly)
    } else {
      @sympolys.roots(poly)
    }
  }
  match poly_try {
    Ok(roots) if !roots.is_empty() => {
      let out : Array[Expr] = []
      for root in roots {
        out.push(solver_finalize_solution_expr(solver_replace_targets(root, backward)))
      }
      return out
    }
    _ => ()
  }
  match solver_extract_quadratic_target(expanded, target) {
    Some((a, b, constant)) if !@symcore.is_zero(a) => {
      let disc = canonical_expr(
        @symcore.add([
          b ^ @symcore.int(2),
          @symcore.mul([
            @symcore.int(-4),
            a,
            constant,
          ]),
        ]),
      )
      let sqrt_disc = solver_exact_root_simplify(
        canonical_expr(
          @symcore.pow(
            disc,
            @symcore.rational_from_ints(1, 2) catch {
              _ => @symcore.function("Rational", [@symcore.int(1), @symcore.int(2)])
            },
          ),
        ),
      )
      let denom = canonical_expr(@symcore.mul([@symcore.int(2), a]))
      let neg_b = canonical_expr(@symcore.mul([@symcore.int(-1), b]))
      return [
        solver_finalize_solution_expr(
          @symcore.mul([
            canonical_expr(
              @symcore.add([
                neg_b,
                @symcore.mul([@symcore.int(-1), sqrt_disc]),
              ]),
            ),
            denom ^ @symcore.int(-1),
          ]),
        ),
        solver_finalize_solution_expr(
          @symcore.mul([
            canonical_expr(@symcore.add([neg_b, sqrt_disc])),
            denom ^ @symcore.int(-1),
          ]),
        ),
      ]
    }
    _ => ()
  }
  let mappings = solver_maps_from_result(
    solve(solve_expr_input(rewritten[0]), symbols=symbols),
    symbols,
  )
  let out : Array[Expr] = []
  for mapping in mappings {
    let rhs = mapping.get(solver_symbol_name(symbol)).unwrap_or(symbol)
    out.push(solver_finalize_solution_expr(solver_replace_targets(rhs, backward)))
  }
  out
}

///|
fn solver_split_integer_coeff(term : Expr) -> (@bigint.BigInt, Expr)? {
  match term {
    Expr::Number(value) =>
      if value.is_integral() {
        Some((value.numerator(), @symcore.int(1)))
      } else {
        None
      }
    Expr::Mul(args) => {
      let mut coeff = 1N
      let factors : Array[Expr] = []
      for arg in args {
        match @symcore.exact_numeric_expr_num_den(arg) {
          Some((num, den)) if den.compare(1N) == 0 => coeff *= num
          Some(_) => return None
          None => factors.push(arg)
        }
      }
      Some((coeff, solver_mul_all(factors)))
    }
    _ => Some((1N, term))
  }
}

///|
fn solver_exact_sqrt_bigint(n : @bigint.BigInt) -> @bigint.BigInt? {
  let expr = Expr::Number(@symnum.BigRational::new(n, 1N) catch {
    _ => return None
  })
  let root_try : Result[Expr?, @sympolys.PolyError] = try?
    @sympolys.domain_exsqrt_expr(@sympolys.Domain::ZZ, expr)
  match root_try {
    Ok(Some(Expr::Number(value))) if value.is_integral() => Some(value.numerator())
    _ => None
  }
}

///|
fn solver_bigint_gcd(lhs : @bigint.BigInt, rhs : @bigint.BigInt) -> @bigint.BigInt {
  let mut a = if lhs.compare(0N) < 0 { -lhs } else { lhs }
  let mut b = if rhs.compare(0N) < 0 { -rhs } else { rhs }
  while b != 0N {
    let r = a % b
    a = b
    b = r
  }
  a
}

///|
fn solver_collect_square_term_factors(
  expr : Expr,
  counts : Map[String, Int],
  factors : Map[String, Expr],
) -> Unit {
  match expr {
    Expr::Mul(args) =>
      for arg in args {
        solver_collect_square_term_factors(arg, counts, factors)
      }
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) > 0 => {
          let power = num.to_int()
          match base {
            Expr::Mul(_) => {
              let (inner_counts, inner_factors) = solver_collect_square_term_map(base)
              for key, factor in inner_factors {
                factors[key] = factor
              }
              for key, count in inner_counts {
                counts[key] = counts.get(key).unwrap_or(0) + count * power
              }
            }
            _ => {
              let key = @symprint.debug_repr(base)
              factors[key] = base
              counts[key] = counts.get(key).unwrap_or(0) + power
            }
          }
        }
        _ => {
          let key = @symprint.debug_repr(expr)
          factors[key] = expr
          counts[key] = counts.get(key).unwrap_or(0) + 1
        }
      }
    Expr::Number(_) => ()
    _ => {
      let key = @symprint.debug_repr(expr)
      factors[key] = expr
      counts[key] = counts.get(key).unwrap_or(0) + 1
    }
  }
}

///|
fn solver_collect_square_term_map(expr : Expr) -> (Map[String, Int], Map[String, Expr]) {
  let counts : Map[String, Int] = {}
  let factors : Map[String, Expr] = {}
  solver_collect_square_term_factors(expr, counts, factors)
  (counts, factors)
}

///|
fn solver_remove_square_factor_once(
  factors : Array[Expr],
  target : Expr,
) -> Bool {
  for i in 0..<factors.length() {
    if @symcore.compare_expr(factors[i], target) == 0 {
      ignore(factors.remove(i))
      return true
    }
    match factors[i] {
      Expr::Pow(base, exp) if @symcore.compare_expr(base, target) == 0 =>
        match @symcore.exact_numeric_expr_num_den(exp) {
          Some((num, den)) if den.compare(1N) == 0 && num.compare(1N) > 0 => {
            let next_exp = Expr::Number(@symnum.BigRational::new(num - 1N, 1N) catch {
              _ => @symnum.BigRational::one()
            })
            factors[i] = canonical_expr(@symcore.pow(base, next_exp))
            return true
          }
          Some((num, den)) if den.compare(1N) == 0 && num.compare(1N) == 0 => {
            ignore(factors.remove(i))
            return true
          }
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn solver_remove_square_term_factors(
  expr : Expr,
  common_counts : Map[String, Int],
  factors_by_key : Map[String, Expr],
) -> Expr {
  let factors = match expr {
    Expr::Mul(args) => args.copy()
    other => [other]
  }
  for key, count in common_counts {
    let factor = factors_by_key.get(key).unwrap_or(@symcore.int(1))
    for _ in 0..<count {
      ignore(solver_remove_square_factor_once(factors, factor))
    }
  }
  solver_mul_all(factors)
}

///|
fn solver_extract_add_square_factor(base : Expr) -> (Expr, Expr)? {
  let terms = match base {
    Expr::Add(args) if !args.is_empty() => args
    _ => return None
  }
  let pieces : Array[(@bigint.BigInt, Expr)] = []
  let mut gcd : @bigint.BigInt? = None
  let mut common_counts : Map[String, Int]? = None
  let factor_exprs : Map[String, Expr] = {}
  for term in terms {
    match solver_split_integer_coeff(term) {
      Some((coeff, rest)) => {
        let abs_coeff = if coeff.compare(0N) < 0 { -coeff } else { coeff }
        if abs_coeff == 0N {
          continue
        }
        let (counts, exprs) = solver_collect_square_term_map(rest)
        for key, factor in exprs {
          factor_exprs[key] = factor
        }
        common_counts = Some(
          match common_counts {
            Some(current) => {
              let next : Map[String, Int] = {}
              for key, value in current {
                let min_count = counts.get(key).unwrap_or(0)
                if min_count < value { next[key] = min_count } else { next[key] = value }
              }
              next
            }
            None => counts
          },
        )
        gcd = Some(
          match gcd {
            Some(current) => solver_bigint_gcd(current, abs_coeff)
            None => abs_coeff
          },
        )
        pieces.push((coeff, rest))
      }
      None => return None
    }
  }
  let common = gcd.unwrap_or(0N)
  let square_counts : Map[String, Int] = {}
  for key, count in common_counts.unwrap_or({}) {
    let even_count = count / 2 * 2
    if even_count >= 2 {
      square_counts[key] = even_count
    }
  }
  let numeric_square = common.compare(1N) > 0 &&
    (solver_exact_sqrt_bigint(common) is Some(_))
  guard numeric_square || !square_counts.is_empty() else {
    return None
  }
  let sqrt_common = solver_exact_sqrt_bigint(common).unwrap_or(1N)
  let sqrt_factors : Array[Expr] = []
  if sqrt_common != 1N {
    sqrt_factors.push(
      Expr::Number(@symnum.BigRational::new(sqrt_common, 1N) catch {
        _ => @symnum.BigRational::one()
      }),
    )
  }
  let remove_counts : Map[String, Int] = {}
  for key, count in square_counts {
    let factor = factor_exprs.get(key).unwrap_or(@symcore.int(1))
    remove_counts[key] = count
    let out_exp = count / 2
    if out_exp == 1 {
      sqrt_factors.push(factor)
    } else {
      sqrt_factors.push(canonical_expr(@symcore.pow(factor, @symcore.int(out_exp))))
    }
  }
  let reduced_terms : Array[Expr] = []
  for piece in pieces {
    let coeff = piece.0 / common
    let rest = solver_remove_square_term_factors(piece.1, remove_counts, factor_exprs)
    reduced_terms.push(
      if coeff == 1N {
        rest
      } else if coeff == -1N {
        canonical_expr(@symcore.mul([@symcore.int(-1), rest]))
      } else {
        canonical_expr(
          @symcore.mul([
            Expr::Number(@symnum.BigRational::new(coeff, 1N) catch {
              _ => @symnum.BigRational::zero()
            }),
            rest,
          ]),
        )
      },
    )
  }
  Some((
    solver_mul_all(sqrt_factors),
    canonical_expr(@symcore.add(reduced_terms)),
  ))
}

///|
fn solver_extract_mul_square_factor(base : Expr) -> (Expr, Expr)? {
  let factors = match base {
    Expr::Mul(args) if !args.is_empty() => args
    _ => return None
  }
  let outside : Array[Expr] = []
  let inside : Array[Expr] = []
  let mut changed = false
  for factor in factors {
    match factor {
      Expr::Number(value) if value.is_integral() && value.numerator().compare(0N) > 0 => {
        match solver_exact_sqrt_bigint(value.numerator()) {
          Some(root) => {
            outside.push(
              Expr::Number(@symnum.BigRational::new(root, 1N) catch {
                _ => @symnum.BigRational::one()
              }),
            )
            changed = true
          }
          None => inside.push(factor)
        }
      }
      Expr::Pow(inner, exp) =>
        match @symcore.exact_numeric_expr_num_den(exp) {
          Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) > 0 => {
            let power = num.to_int()
            let outside_power = power / 2
            let inside_power = power % 2
            if outside_power > 0 {
              changed = true
              if outside_power == 1 {
                outside.push(inner)
              } else {
                outside.push(canonical_expr(@symcore.pow(inner, @symcore.int(outside_power))))
              }
            }
            if inside_power == 1 {
              inside.push(inner)
            }
          }
          _ => inside.push(factor)
        }
      _ => inside.push(factor)
    }
  }
  guard changed else {
    return None
  }
  Some((solver_mul_all(outside), solver_mul_all(inside)))
}

///|
fn solver_exact_root_simplify(expr : Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => solver_exact_root_simplify(child))
  match rewritten {
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) if num.compare(1N) == 0 && den.compare(2N) == 0 => {
          let expanded_base = solver_expand_expr(base)
          let sqrt_try : Result[Expr?, @sympolys.PolyError] = try?
            @sympolys.domain_exsqrt_expr(@sympolys.Domain::QQ, expanded_base)
          match sqrt_try {
            Ok(Some(root)) => canonical_expr(root)
            _ =>
              match solver_extract_mul_square_factor(expanded_base) {
                Some((factor, reduced)) =>
                  canonical_expr(
                    @symcore.mul([
                      factor,
                      solver_exact_root_simplify(
                        @symcore.pow(
                          reduced,
                          @symcore.rational_from_ints(1, 2) catch {
                            _ => @symcore.function("Rational", [@symcore.int(1), @symcore.int(2)])
                          },
                        ),
                      ),
                    ]),
                  )
                None =>
                  match solver_extract_add_square_factor(expanded_base) {
                Some((factor, reduced)) =>
                  canonical_expr(
                    @symcore.mul([
                      factor,
                      solver_exact_root_simplify(
                        @symcore.pow(
                          reduced,
                          @symcore.rational_from_ints(1, 2) catch {
                            _ => @symcore.function("Rational", [@symcore.int(1), @symcore.int(2)])
                          },
                        ),
                      ),
                    ]),
                  )
                    None => @symcore.function("sqrt", [expanded_base])
                  }
              }
          }
        }
        _ => rewritten
      }
    _ => rewritten
  }
}

///|
fn solver_add_term_key(term : Expr) -> (@symnum.BigRational, Expr) {
  match term {
    Expr::Number(value) => (value, @symcore.int(1))
    Expr::Mul(args) => {
      let mut coeff = @symnum.BigRational::one()
      let rest : Array[Expr] = []
      for arg in args {
        match @symcore.exact_numeric_expr_num_den(arg) {
          Some((num, den)) => {
            let value_res : Result[@symnum.BigRational, @symnum.RationalError] = try?
              @symnum.BigRational::new(num, den)
            match value_res {
              Ok(value) => coeff = coeff.mul_r(value)
              Err(_) => rest.push(arg)
            }
          }
          None => rest.push(arg)
        }
      }
      (coeff, solver_mul_all(rest))
    }
    _ => (@symnum.BigRational::one(), term)
  }
}

///|
fn solver_add_term_priority(term : Expr) -> Int {
  for node in @symcore.preorder(term) {
    if @symcore.undefined_application_parts(node) is Some(_) {
      return 0
    }
    match @symcore.application_parts(node) {
      Some((Expr::FunctionHead(_), _)) => return 0
      _ => ()
    }
  }
  1
}

///|
fn solver_sort_add_terms(expr : Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => solver_sort_add_terms(child))
  match rewritten {
    Expr::Add(args) => {
      let sorted = args.copy()
      sorted.sort_by((lhs, rhs) => {
        let lpriority = solver_add_term_priority(lhs)
        let rpriority = solver_add_term_priority(rhs)
        if lpriority != rpriority {
          lpriority - rpriority
        } else {
        let (lcoeff, lbase) = solver_add_term_key(lhs)
        let (rcoeff, rbase) = solver_add_term_key(rhs)
        let base_cmp = @symcore.compare_expr(lbase, rbase)
        if base_cmp != 0 {
          base_cmp
        } else {
          let coeff_cmp = rcoeff.compare(lcoeff)
          if coeff_cmp != 0 {
            coeff_cmp
          } else {
            @symcore.compare_expr(lhs, rhs)
          }
        }
        }
      })
      @symcore.raw_add(sorted)
    }
    _ => rewritten
  }
}

///|
fn solver_finalize_solution_expr(expr : Expr) -> Expr {
  let exact = solver_exact_root_simplify(canonical_expr(expr))
  let simplified = @symsimplify.simplify(exact, max_passes=2)
  solver_sort_add_terms(canonical_expr(solver_exact_root_simplify(simplified)))
}

///|
fn solver_separable_canonical_systems(
  eqs : Array[Expr],
  targets : Array[Expr],
) -> Array[Array[Expr]] raise SolverError {
  if eqs.is_empty() || targets.is_empty() {
    return []
  }
  let mut states : Array[(Array[(Expr, Expr)], Array[Expr])] = [([], eqs)]
  for _ in 0..<targets.length() {
    let next_states : Array[(Array[(Expr, Expr)], Array[Expr])] = []
    for state in states {
      let replacements = state.0
      let current_eqs = state.1.map(eq => canonical_expr(solver_replace_targets(eq, replacements)))
      let unresolved : Array[Expr] = []
      for target in targets {
        if !replacements.any(pair => @symcore.compare_expr(pair.0, target) == 0) {
          unresolved.push(target)
        }
      }
      if unresolved.is_empty() {
        next_states.push((replacements, current_eqs))
        continue
      }
      let mut expanded = false
      for i in 0..<current_eqs.length() {
        let hits : Array[Expr] = []
        for target in unresolved {
          if solver_expr_has_target(current_eqs[i], target) {
            hits.push(target)
          }
        }
        if hits.length() != 1 {
          continue
        }
        let target = hits[0]
        let sols = solver_single_target_solutions(current_eqs[i], target)
        if sols.is_empty() {
          continue
        }
        expanded = true
        for sol in sols {
          let next_replacements = replacements.copy()
          next_replacements.push((target, sol))
          let next_eqs : Array[Expr] = []
          for j in 0..<current_eqs.length() {
            if j != i {
              next_eqs.push(current_eqs[j])
            }
          }
          next_states.push((next_replacements, next_eqs))
        }
        break
      }
      if !expanded {
        return []
      }
    }
    if next_states.is_empty() {
      return []
    }
    states = next_states
  }
  let systems : Array[Array[Expr]] = []
  for state in states {
    let replacements = state.0
    let system : Array[Expr] = []
    let mut complete = true
    for target in targets {
      let mut rhs : Expr? = None
      for pair in replacements {
        if @symcore.compare_expr(pair.0, target) == 0 {
          rhs = Some(pair.1)
          break
        }
      }
      match rhs {
        Some(value) =>
          system.push(
            Expr::Relational(
              @symcore.RelOp::Eq,
              target,
              solver_finalize_solution_expr(value),
            ),
          )
        None => {
          complete = false
          break
        }
      }
    }
    if complete {
      systems.push(system)
    }
  }
  systems
}

///|
pub fn canonical_odes(
  eqs : Array[Expr],
  funcs : Array[Expr],
  t : Expr,
) -> Array[Array[Expr]] raise SolverError {
  guard !eqs.is_empty() else {
    raise SolverError::ValueError("canonical_odes expects at least one equation")
  }
  let orders = solver_func_orders(eqs, funcs)
  let targets : Array[Expr] = []
  for i in 0..<funcs.length() {
    targets.push(solver_ode_target(funcs[i], t, orders[i]))
  }
  let normalized_eqs = eqs.map(solver_normalize_equation)
  let (rewritten, symbols, backward) = solver_symbolize_targets(
    normalized_eqs,
    targets,
    "__ode_canonical_",
  )
  let solved_res : Result[SolveResult, SolverError] = try?
    solve(solve_exprs_input(rewritten), symbols=symbols)
  match solved_res {
    Ok(solved) => {
      let mappings = solver_maps_from_result(solved, symbols)
      let systems : Array[Array[Expr]] = []
      for mapping in mappings {
        let system : Array[Expr] = []
        for i in 0..<targets.length() {
          let rhs = mapping.get(solver_symbol_name(symbols[i])).unwrap_or(symbols[i])
          system.push(
            Expr::Relational(
              @symcore.RelOp::Eq,
              targets[i],
              solver_finalize_solution_expr(solver_replace_targets(rhs, backward)),
            ),
          )
        }
        systems.push(system)
      }
      if !systems.is_empty() {
        return systems
      }
    }
    Err(_) => ()
  }
  let coeff_rows : Array[Array[Expr]] = []
  let rhs_rows : Array[Array[Expr]] = []
  let mut linear_possible = true
  for eq in normalized_eqs {
    match solver_extract_linear_targets(eq, targets) {
      Some((coeffs, constant)) => {
        coeff_rows.push(coeffs)
        rhs_rows.push([canonical_expr(@symcore.mul([@symcore.int(-1), constant]))])
      }
      None => {
        linear_possible = false
        break
      }
    }
  }
  let direct_system = if linear_possible {
    match solver_solve_linear_expr_system(coeff_rows, rhs_rows) {
      Some(values) => {
        let system : Array[Expr] = []
        for i in 0..<targets.length() {
          system.push(
            Expr::Relational(
              @symcore.RelOp::Eq,
              targets[i],
              solver_finalize_solution_expr(values[i]),
            ),
          )
        }
        Some(system)
      }
      None => None
    }
  } else {
    None
  }
  match direct_system {
    Some(system) => return [system]
    None => ()
  }
  let separable = solver_separable_canonical_systems(normalized_eqs, targets)
  if !separable.is_empty() {
    return separable
  }
  []
}

///|
fn solver_matrix_negate(
  matrix : @symmatrices.Matrix,
  context : String,
) -> @symmatrices.Matrix raise SolverError {
  let negated = matrix.applyfunc(value =>
    canonical_expr(@symcore.mul([@symcore.int(-1), value]))
  ) catch {
    err => raise wrap_matrix_error(context, err)
  }
  solver_matrix_normalize_entries(negated, context)
}

///|
pub fn linear_ode_to_matrix(
  eqs : Array[Expr],
  funcs : Array[Expr],
  t : Expr,
  order : Int,
) -> (Array[@symmatrices.Matrix], @symmatrices.Matrix) raise SolverError {
  guard order >= 0 else {
    raise SolverError::ValueError("linear_ode_to_matrix expects a nonnegative order")
  }
  for eq in eqs {
    for func in funcs {
      if ode_order(eq, func) > order {
        raise SolverError::ValueError(
          "Cannot represent system in " + order.to_string() + "-order form",
        )
      }
    }
  }
  let matrices : Array[@symmatrices.Matrix] = []
  let mut current_eqs = eqs.map(solver_normalize_equation)
  let mut rhs : @symmatrices.Matrix? = None
  let mut current_order = order
  while current_order >= 0 {
    let targets = funcs.map(func => solver_ode_target(func, t, current_order))
    let (rewritten, symbols, _) = solver_symbolize_targets(
      current_eqs,
      targets,
      "__ode_matrix_",
    )
    let (a_i_raw, b_i_raw) = match
      (try? linear_eq_to_matrix(rewritten, symbols) :
      Result[(@symmatrices.Matrix, @symmatrices.Matrix), SolverError]) {
      Ok(value) => value
      Err(_) => raise SolverError::ValueError("The system of ODEs is nonlinear.")
    }
    let a_i = solver_matrix_normalize_entries(a_i_raw, "linear_ode_to_matrix")
    matrices.push(
      if current_order == order {
        a_i
      } else {
        solver_matrix_negate(a_i, "linear_ode_to_matrix")
      },
    )
    if current_order > 0 {
      let next_eqs : Array[Expr] = []
      for row in b_i_raw.to_list() {
        next_eqs.push(canonical_expr(@symcore.mul([@symcore.int(-1), row[0]])))
      }
      current_eqs = next_eqs
    } else {
      rhs = Some(solver_matrix_normalize_entries(b_i_raw, "linear_ode_to_matrix"))
    }
    current_order -= 1
  }
  (matrices, rhs.unwrap())
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
fn solver_swap_expr_rows(
  rows : Array[Array[Expr]],
  i : Int,
  j : Int,
) -> Unit {
  if i == j {
    return
  }
  let tmp = rows[i]
  rows[i] = rows[j]
  rows[j] = tmp
}

///|
fn solver_expr_divide(lhs : Expr, rhs : Expr) -> Expr {
  canonical_expr(@symcore.mul([lhs, @symcore.pow(rhs, @symcore.int(-1))]))
}

///|
fn solver_solve_linear_expr_system(
  coeff_rows : Array[Array[Expr]],
  rhs_rows : Array[Array[Expr]],
) -> Array[Expr]? {
  let n = coeff_rows.length()
  if n == 0 || rhs_rows.length() != n {
    return None
  }
  let left : Array[Array[Expr]] = []
  let right : Array[Array[Expr]] = []
  for i in 0..<n {
    if coeff_rows[i].length() != n || rhs_rows[i].length() != 1 {
      return None
    }
    left.push(coeff_rows[i].copy())
    right.push(rhs_rows[i].copy())
  }
  let mut pivot_row = 0
  for col in 0..<n {
    let mut found = -1
    for candidate in pivot_row..<n {
      if expr_is_zeroish(left[candidate][col]) != Some(true) {
        found = candidate
        break
      }
    }
    if found < 0 {
      return None
    }
    solver_swap_expr_rows(left, pivot_row, found)
    solver_swap_expr_rows(right, pivot_row, found)
    let pivot = left[pivot_row][col]
    for j in col..<n {
      left[pivot_row][j] = solver_expr_divide(left[pivot_row][j], pivot)
    }
    right[pivot_row][0] = solver_expr_divide(right[pivot_row][0], pivot)
    for i in 0..<n {
      if i == pivot_row {
        continue
      }
      let factor = left[i][col]
      if expr_is_zeroish(factor) == Some(true) {
        continue
      }
      for j in col..<n {
        left[i][j] = canonical_expr(
          @symcore.add([
            left[i][j],
            @symcore.mul([@symcore.int(-1), factor, left[pivot_row][j]]),
          ]),
        )
      }
      right[i][0] = canonical_expr(
        @symcore.add([
          right[i][0],
          @symcore.mul([@symcore.int(-1), factor, right[pivot_row][0]]),
        ]),
      )
    }
    pivot_row += 1
  }
  for i in 0..<n {
    for j in 0..<n {
      let expected = if i == j { @symcore.int(1) } else { @symcore.int(0) }
      let difference = canonical_expr(
        @symcore.add([
          left[i][j],
          @symcore.mul([@symcore.int(-1), expected]),
        ]),
      )
      if expr_is_zeroish(difference) != Some(true) {
        return None
      }
    }
  }
  let out : Array[Expr] = []
  for row in right {
    out.push(canonical_expr(row[0]))
  }
  Some(out)
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
priv struct SolverLieContext {
  x : Expr
  y : Expr
  func : Expr
  h_raw : Expr
  h : Expr
  hx_raw : Expr
  hy_raw : Expr
  hx : Expr
  hy : Expr
  hinv_raw : Expr
  hinv : Expr
  hinvx : Expr
  hinvy : Expr
}

///|
priv struct SolverLieSeparated {
  coeff : Expr
  x_part : Expr
  y_part : Expr
}

///|
let solver_lie_heuristics : Array[String] = [
  "abaco1_simple",
  "abaco1_product",
  "abaco2_similar",
  "abaco2_unique_unknown",
  "abaco2_unique_general",
  "linear",
  "function_sum",
  "bivariate",
  "chi",
]

///|
fn solver_lie_restore_func(expr : Expr, ctx : SolverLieContext) -> Expr {
  @symcore.xreplace(expr, [(ctx.y, ctx.func)])
}

///|
fn solver_lie_collect_monomial_factor(
  expr : Expr,
  sign : Int,
  counts : Map[String, Int],
  factors : Map[String, Expr],
) -> Unit {
  match expr {
    Expr::Mul(args) =>
      for arg in args {
        solver_lie_collect_monomial_factor(arg, sign, counts, factors)
      }
    Expr::Pow(base, Expr::Number(exp)) if exp.is_integral() => {
      let coeff = exp.numerator().to_int() * sign
      if coeff != 0 {
        let key = @symprint.debug_repr(base)
        factors[key] = base
        counts[key] = counts.get(key).unwrap_or(0) + coeff
      }
    }
    _ => {
      let key = @symprint.debug_repr(expr)
      factors[key] = expr
      counts[key] = counts.get(key).unwrap_or(0) + sign
    }
  }
}

///|
fn solver_lie_monomial_power(base : Expr, exp : Int) -> Expr {
  if exp == 1 {
    base
  } else {
    @symcore.pow(base, @symcore.int(exp))
  }
}

///|
fn solver_lie_cancel_monomial_ratio(expr : Expr) -> Expr {
  let (num, den) = @symsimplify.fraction(expr)
  if @symcore.compare_expr(den, @symcore.int(1)) == 0 {
    return expr
  }
  let counts : Map[String, Int] = {}
  let factors : Map[String, Expr] = {}
  solver_lie_collect_monomial_factor(num, 1, counts, factors)
  solver_lie_collect_monomial_factor(den, -1, counts, factors)
  let num_out : Array[Expr] = []
  let den_out : Array[Expr] = []
  for key, coeff in counts {
    if coeff > 0 {
      num_out.push(solver_lie_monomial_power(factors[key], coeff))
    } else if coeff < 0 {
      den_out.push(solver_lie_monomial_power(factors[key], -coeff))
    }
  }
  let rebuilt_num = solver_mul_all(num_out)
  let rebuilt_den = solver_mul_all(den_out)
  if @symcore.compare_expr(rebuilt_den, @symcore.int(1)) == 0 {
    rebuilt_num
  } else {
    solver_expr_divide(rebuilt_num, rebuilt_den)
  }
}

///|
fn solver_lie_cancel_products(expr : Expr) -> Expr {
  let rewritten = @symcore.map_children(expr, child => solver_lie_cancel_products(child))
  solver_lie_cancel_monomial_ratio(rewritten)
}

///|
fn solver_lie_mul_factors(expr : Expr) -> Array[Expr] {
  match canonical_expr(expr) {
    Expr::Mul(args) => args
    other => [other]
  }
}

fn solver_lie_remove_factor_once(factors : Array[Expr], target : Expr) -> Unit {
  for i in 0..<factors.length() {
    if @symcore.compare_expr(factors[i], target) == 0 {
      ignore(factors.remove(i))
      return
    }
  }
}

///|
fn solver_lie_factor_common_add(expr : Expr) -> Expr {
  match canonical_expr(expr) {
    Expr::Add(args) if args.length() >= 2 => {
      let common : Array[Expr] = []
      let first = solver_lie_mul_factors(args[0])
      for factor in first {
        if args[1:].all(term => solver_expr_in_list(solver_lie_mul_factors(term), factor)) &&
          !solver_expr_in_list(common, factor) {
          common.push(factor)
        }
      }
      if common.is_empty() {
        return expr
      }
      let remainders : Array[Expr] = []
      for term in args {
        let factors = solver_lie_mul_factors(term)
        for factor in common {
          solver_lie_remove_factor_once(factors, factor)
        }
        remainders.push(solver_mul_all(factors))
      }
      canonical_expr(@symcore.mul([solver_mul_all(common), @symcore.add(remainders)]))
    }
    _ => expr
  }
}

///|
fn solver_lie_power_base_exp(expr : Expr) -> (Expr, Expr) {
  match canonical_expr(expr) {
    Expr::Pow(base, exp) =>
      match canonical_expr(base) {
        Expr::Pow(inner_base, inner_exp) if solver_lie_exact_integer(exp) =>
          (inner_base, solver_lie_light_normalize(@symcore.mul([inner_exp, exp])))
        _ => (base, exp)
      }
    other => (other, @symcore.int(1))
  }
}

///|
fn solver_lie_merge_mul_powers(expr : Expr) -> Expr {
  match canonical_expr(expr) {
    Expr::Mul(args) => {
      let merged_args : Array[Expr] = []
      for arg in args {
        match solver_lie_merge_mul_powers(arg) {
          Expr::Mul(inner) =>
            for item in inner {
              merged_args.push(item)
            }
          other => merged_args.push(other)
        }
      }
      let bases : Array[Expr] = []
      let exps : Array[Expr] = []
      for arg in merged_args {
        let (base, exp) = solver_lie_power_base_exp(arg)
        let mut merged = false
        for i in 0..<bases.length() {
          if @symcore.compare_expr(bases[i], base) == 0 {
            exps[i] = solver_lie_light_normalize(@symcore.add([exps[i], exp]))
            merged = true
            break
          }
        }
        if !merged {
          bases.push(base)
          exps.push(exp)
        }
      }
      let rebuilt : Array[Expr] = []
      for i in 0..<bases.length() {
        let exp = solver_lie_light_normalize(exps[i])
        if expr_is_zeroish(exp) == Some(true) {
          continue
        }
        if @symcore.compare_expr(exp, @symcore.int(1)) == 0 {
          rebuilt.push(bases[i])
        } else {
          rebuilt.push(@symcore.pow(bases[i], exp))
        }
      }
      canonical_expr(@symcore.mul(rebuilt))
    }
    Expr::Add(args) =>
      canonical_expr(@symcore.add(args.map(arg => solver_lie_merge_mul_powers(arg))))
    other => other
  }
}

///|
fn solver_lie_atomize_poly_expr(
  expr : Expr,
  prefix : String,
) -> (Expr, Array[(Expr, Expr)]) {
  let normalized = solver_lie_light_normalize(expr)
  let atoms : Array[Expr] = []
  for node in @symcore.preorder(normalized) {
    if solver_lie_cancel_atom(node) && !solver_expr_in_list(atoms, node) {
      atoms.push(node)
    }
  }
  let atomized_pairs : Array[(Expr, Expr)] = []
  let restore_pairs : Array[(Expr, Expr)] = []
  for i in 0..<atoms.length() {
    let sym = Expr::Symbol("\{prefix}_atom\{i}")
    atomized_pairs.push((atoms[i], sym))
    restore_pairs.push((sym, atoms[i]))
  }
  let atomized = if atomized_pairs.is_empty() {
    normalized
  } else {
    @symcore.xreplace(normalized, atomized_pairs)
  }
  let dummy_pairs : Array[(Expr, Expr)] = []
  let dummy_restore_pairs : Array[(Expr, Expr)] = []
  let free = @symcore.free_symbols(atomized)
  for i in 0..<free.length() {
    match free[i] {
      Expr::Dummy(_, _) => {
        let sym = Expr::Symbol("\{prefix}_free\{i}")
        dummy_pairs.push((free[i], sym))
        dummy_restore_pairs.push((sym, free[i]))
      }
      _ => ()
    }
  }
  let poly_ready = if dummy_pairs.is_empty() {
    atomized
  } else {
    @symcore.xreplace(atomized, dummy_pairs)
  }
  let restore_all : Array[(Expr, Expr)] = []
  for pair in dummy_restore_pairs {
    restore_all.push(pair)
  }
  for pair in restore_pairs {
    restore_all.push(pair)
  }
  (poly_ready, restore_all)
}

///|
fn solver_lie_atomize_poly_exprs(
  exprs : Array[Expr],
  prefix : String,
) -> (Array[Expr], Array[(Expr, Expr)]) {
  let normalized = exprs.map(expr => solver_lie_light_normalize(expr))
  let atoms : Array[Expr] = []
  for expr in normalized {
    for node in @symcore.preorder(expr) {
      if solver_lie_cancel_atom(node) && !solver_expr_in_list(atoms, node) {
        atoms.push(node)
      }
    }
  }
  let atomized_pairs : Array[(Expr, Expr)] = []
  let restore_pairs : Array[(Expr, Expr)] = []
  for i in 0..<atoms.length() {
    let sym = Expr::Symbol("\{prefix}_atom\{i}")
    atomized_pairs.push((atoms[i], sym))
    restore_pairs.push((sym, atoms[i]))
  }
  let atomized = if atomized_pairs.is_empty() {
    normalized
  } else {
    normalized.map(expr => @symcore.xreplace(expr, atomized_pairs))
  }
  let dummy_pairs : Array[(Expr, Expr)] = []
  let dummy_restore_pairs : Array[(Expr, Expr)] = []
  let combined_free : Array[Expr] = []
  for expr in atomized {
    for sym in @symcore.free_symbols(expr) {
      if !solver_expr_in_list(combined_free, sym) {
        combined_free.push(sym)
      }
    }
  }
  for i in 0..<combined_free.length() {
    match combined_free[i] {
      Expr::Dummy(_, _) => {
        let sym = Expr::Symbol("\{prefix}_free\{i}")
        dummy_pairs.push((combined_free[i], sym))
        dummy_restore_pairs.push((sym, combined_free[i]))
      }
      _ => ()
    }
  }
  let poly_ready = if dummy_pairs.is_empty() {
    atomized
  } else {
    atomized.map(expr => @symcore.xreplace(expr, dummy_pairs))
  }
  let restore_all : Array[(Expr, Expr)] = []
  for pair in dummy_restore_pairs {
    restore_all.push(pair)
  }
  for pair in restore_pairs {
    restore_all.push(pair)
  }
  (poly_ready, restore_all)
}

///|
fn solver_lie_try_exact_div_expr(
  dividend : Expr,
  divisor : Expr,
) -> Expr? {
  let dividend_norm = solver_lie_light_normalize(dividend)
  let divisor_norm = solver_lie_light_normalize(divisor)
  let (dividend_num, dividend_den) = @symsimplify.fraction(dividend_norm)
  let (divisor_num, divisor_den) = @symsimplify.fraction(divisor_norm)
  let lhs = solver_lie_light_normalize(
    @symsimplify.numer_expand(@symcore.mul([dividend_num, divisor_den])),
  )
  let rhs = solver_lie_light_normalize(
    @symsimplify.numer_expand(@symcore.mul([dividend_den, divisor_num])),
  )
  let (poly_ready, restore_all) = solver_lie_atomize_poly_exprs(
    [lhs, rhs],
    "__lie_exact_div",
  )
  let dividend_ready = poly_ready[0]
  let divisor_ready = poly_ready[1]
  let symbols_res : Result[Array[Expr], SolverError] = try?
    solver_sorted_unique_symbols(
      @symcore.free_symbols(@symcore.mul([dividend_ready, divisor_ready])),
    )
  let symbols = match symbols_res {
    Ok(value) => value
    Err(_) => return None
  }
  let gens_res : Result[Array[String], SolverError] = try?
    solver_symbol_names(symbols)
  let gens = match gens_res {
    Ok(value) => value
    Err(_) => return None
  }
  if gens.is_empty() {
    return None
  }
  let dividend_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(dividend_ready, gens, @sympolys.Domain::EX)
  let divisor_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(divisor_ready, gens, @sympolys.Domain::EX)
  match (dividend_poly_res, divisor_poly_res) {
    (Ok(dividend_poly), Ok(divisor_poly)) => {
      if divisor_poly.is_zero() {
        return None
      }
      let div_res : Result[
        (Array[@sympolys.Poly], @sympolys.Poly),
        @sympolys.PolyError,
      ] = try? dividend_poly.divmod_multivar([divisor_poly])
      match div_res {
        Ok((quotients, remainder)) =>
          if !remainder.is_zero() {
            None
          } else {
            let quotient_expr = solver_lie_light_normalize(quotients[0].to_expr())
            Some(
              if restore_all.is_empty() {
                quotient_expr
              } else {
                solver_lie_light_normalize(@symcore.xreplace(quotient_expr, restore_all))
              },
            )
          }
        Err(_) => None
      }
    }
    _ => None
  }
}

///|
fn solver_lie_cancel_explicit_den_factors(expr : Expr) -> Expr {
  let normalized = canonical_expr(@symsimplify.fraction_expand(canonical_expr(expr)))
  let (num0, den0) = @symsimplify.fraction(normalized)
  let mut num = canonical_expr(num0)
  let den_factors = solver_lie_mul_factors(den0).copy()
  let mut changed = true
  while changed {
    changed = false
    for i in 0..<den_factors.length() {
      match den_factors[i] {
        Expr::Number(_) => ()
        factor =>
          match solver_lie_try_exact_div_expr(num, factor) {
            Some(quotient) => {
              num = canonical_expr(quotient)
              ignore(den_factors.remove(i))
              changed = true
              break
            }
            None => ()
          }
      }
    }
  }
  let den = solver_mul_all(den_factors)
  if @symcore.compare_expr(den, @symcore.int(1)) == 0 {
    num
  } else {
    canonical_expr(@symcore.mul([num, @symcore.pow(den, @symcore.int(-1))]))
  }
}

///|
fn solver_lie_try_poly_factor_expr(expr : Expr) -> Expr? {
  let normalized = canonical_expr(expr)
  let (poly_ready, restore_all) = solver_lie_atomize_poly_expr(
    normalized,
    "__lie_factor",
  )
  let symbols_res : Result[Array[Expr], SolverError] = try?
    solver_sorted_unique_symbols(@symcore.free_symbols(poly_ready))
  let symbols = match symbols_res {
    Ok(value) => value
    Err(_) => return None
  }
  let gens_res : Result[Array[String], SolverError] = try?
    solver_symbol_names(symbols)
  let gens = match gens_res {
    Ok(value) => value
    Err(_) => return None
  }
  if gens.is_empty() {
    return Some(normalized)
  }
  let poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(poly_ready, gens, @sympolys.Domain::EX)
  let poly = match poly_res {
    Ok(value) => value
    Err(_) => return None
  }
  let factor_list_res : Result[(@symnum.BigRational, Array[(@sympolys.Poly, Int)]), @sympolys.PolyError] = try?
    poly.factor_list()
  let (content, factors) = match factor_list_res {
    Ok(value) => value
    Err(_) => return None
  }
  let rebuilt : Array[Expr] = []
  if content.compare(@symnum.BigRational::one()) != 0 {
    rebuilt.push(Expr::Number(content))
  }
  for factor in factors {
    let factor_expr = factor.0.to_expr()
    if factor.1 == 1 {
      rebuilt.push(factor_expr)
    } else {
      rebuilt.push(@symcore.pow(factor_expr, @symcore.int(factor.1)))
    }
  }
  let factored = solver_mul_all(rebuilt)
  if restore_all.is_empty() {
    Some(canonical_expr(factored))
  } else {
    Some(canonical_expr(@symcore.xreplace(factored, restore_all)))
  }
}

///|
fn solver_lie_restore_pairs_from_posify(restore : Map[String, Expr]) -> Array[(Expr, Expr)] {
  let out : Array[(Expr, Expr)] = []
  for name, value in restore {
    out.push((Expr::Symbol(name), value))
  }
  out
}

///|
fn solver_lie_node_count(expr : Expr) -> Int {
  let mut count = 0
  for _ in @symcore.preorder(expr) {
    count += 1
  }
  count
}

///|
fn solver_lie_allow_poly_factor(expr : Expr) -> Bool {
  ignore(expr)
  false
}

///|
fn solver_lie_allow_heavy_normalize(expr : Expr) -> Bool {
  let free_count = @symcore.free_symbols(expr).length()
  free_count <= 1 || solver_lie_node_count(expr) <= 120
}

///|
fn solver_lie_factor_expr(expr : Expr) -> Expr {
  let canonical = canonical_expr(expr)
  let normalized = if solver_lie_allow_heavy_normalize(canonical) {
    solver_lie_cancel_expr(canonical)
  } else {
    canonical
  }
  let (num, den) = @symsimplify.fraction(normalized)
  let poly_factored_num = if solver_lie_allow_poly_factor(num) {
    solver_lie_try_poly_factor_expr(num)
  } else {
    None
  }
  let factored_num = match poly_factored_num {
    Some(value) => value
    None => solver_lie_factor_common_add(num)
  }
  if @symcore.compare_expr(den, @symcore.int(1)) == 0 {
    return canonical_expr(factored_num)
  }
  let poly_factored_den = if solver_lie_allow_poly_factor(den) {
    solver_lie_try_poly_factor_expr(den)
  } else {
    None
  }
  let factored_den = match poly_factored_den {
    Some(value) => value
    None => solver_lie_factor_common_add(den)
  }
  canonical_expr(
    @symcore.mul([factored_num, @symcore.pow(factored_den, @symcore.int(-1))]),
  )
}

///|
fn solver_lie_simplify_univariate_factor(expr : Expr) -> Expr {
  let normalized = solver_lie_light_normalize(
    @symsimplify.fraction_expand(solver_lie_light_normalize(expr)),
  )
  let (_, den) = @symsimplify.fraction(normalized)
  if @symcore.compare_expr(den, @symcore.int(1)) == 0 {
    return normalized
  }
  solver_lie_cancel_expr(
    solver_lie_cancel_explicit_den_factors(normalized),
  )
}

///|
fn solver_lie_univariate_reciprocal(expr : Expr) -> Expr {
  let normalized = canonical_expr(expr)
  match normalized {
    Expr::Mul(args) =>
      canonical_expr(@symcore.mul(args.map(arg => solver_lie_univariate_reciprocal(arg))))
    Expr::Pow(base, exp) =>
      canonical_expr(
        @symcore.pow(
          base,
          canonical_expr(@symcore.mul([@symcore.int(-1), exp])),
        ),
      )
    _ => canonical_expr(@symcore.pow(normalized, @symcore.int(-1)))
  }
}

///|
fn solver_lie_simplify(expr : Expr) -> Expr {
  let canceled = solver_lie_merge_mul_powers(solver_lie_cancel_products(expr))
  solver_lie_merge_mul_powers(
    canonical_expr(
      @symsimplify.simplify(
        @symsimplify.ratsimp(
          @symsimplify.powsimp(
            @symsimplify.numer_expand(solver_lie_merge_mul_powers(canceled)),
          ),
        ),
      ),
    ),
  )
}

///|
fn solver_lie_sympy_zero_check(expr : Expr, expand? : Bool = false) -> Bool {
  let candidate = if expand { solver_expand_expr(expr) } else { expr }
  let simplified = solver_lie_simplify(candidate)
  if expr_is_zeroish(simplified) == Some(true) ||
    solver_lie_quick_zero(simplified) ||
    solver_lie_single_sqrt_zero(simplified) {
    return true
  }
  let trig = solver_lie_simplify(@symsimplify.trigsimp(simplified))
  if expr_is_zeroish(trig) == Some(true) ||
    solver_lie_quick_zero(trig) ||
    solver_lie_single_sqrt_zero(trig) {
    return true
  }
  let sec = solver_lie_simplify(solver_lie_rewrite_sec_pow2(trig))
  expr_is_zeroish(sec) == Some(true) ||
  solver_lie_quick_zero(sec) ||
  solver_lie_single_sqrt_zero(sec)
}

///|
fn solver_lie_split_fraction_add(expr : Expr) -> Expr {
  let normalized = canonical_expr(expr)
  let (numer, denom) = @symsimplify.fraction(normalized)
  if @symcore.compare_expr(denom, @symcore.int(1)) == 0 {
    return normalized
  }
  match numer {
    Expr::Add(args) => {
      let terms : Array[Expr] = []
      for arg in args {
        let term_fraction = canonical_expr(
          @symsimplify.fraction_expand(solver_expr_divide(arg, denom)),
        )
        terms.push(
          solver_lie_cancel_explicit_den_factors(
            solver_lie_cancel_expr(
              solver_lie_light_normalize(term_fraction),
            ),
          ),
        )
      }
      canonical_expr(@symcore.add(terms))
    }
    _ => normalized
  }
}

///|
fn solver_finalize_lie_expr(expr : Expr) -> Expr {
  let exact = solver_exact_root_simplify(canonical_expr(expr))
  let simplified = solver_lie_simplify(solver_lie_split_fraction_add(exact))
  solver_sort_add_terms(
    solver_lie_split_fraction_add(
      canonical_expr(solver_lie_factor_common_add(simplified)),
    ),
  )
}

///|
fn solver_output_lie_expr(expr : Expr) -> Expr {
  solver_finalize_lie_expr(expr)
}

///|
fn solver_lie_polynomial_zero(expr : Expr) -> Bool {
  let symbol_names : Array[String] = []
  for symbol in @symcore.free_symbols(expr) {
    match symbol {
      Expr::Symbol(name) =>
        if !symbol_names.contains(name) {
          symbol_names.push(name)
        }
      _ => ()
    }
  }
  if symbol_names.is_empty() {
    return false
  }
  let (numer, denom) = @symsimplify.fraction(expr)
  let numer_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(
      canonical_expr(numer),
      symbol_names,
      @sympolys.Domain::EX,
    )
  let denom_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(
      canonical_expr(denom),
      symbol_names,
      @sympolys.Domain::EX,
    )
  match (numer_poly_res, denom_poly_res) {
    (Ok(numer_poly), Ok(denom_poly)) => !denom_poly.is_zero() && numer_poly.is_zero()
    _ => false
  }
}

///|
fn solver_lie_polynomial_zero_atomized(expr : Expr) -> Bool {
  let atomized_res = solver_lie_atomize_poly_expr(
    solver_lie_merge_mul_powers(expr),
    "__lie_zero",
  )
  let atomized = atomized_res.0
  let symbols_res : Result[Array[Expr], SolverError] = try?
    solver_sorted_unique_symbols(@symcore.free_symbols(atomized))
  let symbols = match symbols_res {
    Ok(value) => value
    Err(_) => return false
  }
  let gens_res : Result[Array[String], SolverError] = try?
    solver_symbol_names(symbols)
  let gens = match gens_res {
    Ok(value) => value
    Err(_) => return false
  }
  if gens.is_empty() {
    return false
  }
  let (numer, denom) = @symsimplify.fraction(atomized)
  let numer_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(
      canonical_expr(numer),
      gens,
      @sympolys.Domain::EX,
    )
  let denom_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(
      canonical_expr(denom),
      gens,
      @sympolys.Domain::EX,
    )
  match (numer_poly_res, denom_poly_res) {
    (Ok(numer_poly), Ok(denom_poly)) => !denom_poly.is_zero() && numer_poly.is_zero()
    _ => false
  }
}

///|
fn solver_expr_from_bigint(value : @bigint.BigInt) -> Expr {
  Expr::Number(@symnum.BigRational::new(value, 1N) catch {
    _ => @symnum.BigRational::zero()
  })
}

///|
fn solver_lie_single_sqrt_atom(expr : Expr) -> (Expr, Expr)? {
  let mut atom : Expr? = None
  let mut radicand : Expr? = None
  for node in @symcore.preorder(canonical_expr(expr)) {
    match node {
      Expr::Apply(Expr::FunctionHead("sqrt"), [arg]) =>
        match atom {
          Some(existing) =>
            if @symcore.compare_expr(existing, node) != 0 {
              return None
            }
          None => {
            atom = Some(node)
            radicand = Some(arg)
          }
        }
      _ => ()
    }
  }
  match (atom, radicand) {
    (Some(a), Some(r)) => Some((a, r))
    _ => None
  }
}

///|
fn solver_lie_reduce_single_sqrt_powers(
  expr : Expr,
  atom : Expr,
  radicand : Expr,
) -> Expr {
  let rewrite_child = fn(child : Expr) { solver_lie_reduce_single_sqrt_powers(child, atom, radicand) }
  match canonical_expr(expr) {
    Expr::Add(args) => canonical_expr(@symcore.add(args.map(rewrite_child)))
    Expr::Mul(args) => canonical_expr(@symcore.mul(args.map(rewrite_child)))
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) if den.compare(1N) == 0 => {
          let reduced_base = rewrite_child(base)
          if @symcore.compare_expr(reduced_base, atom) == 0 {
            if num.compare(0N) == 0 {
              return @symcore.int(1)
            }
            if num.compare(0N) > 0 {
              let q = num / 2N
              let r = num % 2N
              let outer : Array[Expr] = []
              if q.compare(0N) > 0 {
                outer.push(canonical_expr(@symcore.pow(radicand, solver_expr_from_bigint(q))))
              }
              if r.compare(1N) == 0 {
                outer.push(atom)
              }
              return solver_mul_all(outer)
            }
            let m = -num
            let q = m / 2N
            let r = m % 2N
            let outer : Array[Expr] = []
            if r.compare(1N) == 0 {
              outer.push(atom)
              outer.push(canonical_expr(@symcore.pow(radicand, solver_expr_from_bigint(-(q + 1N)))))
            } else if q.compare(0N) > 0 {
              outer.push(canonical_expr(@symcore.pow(radicand, solver_expr_from_bigint(-q))))
            } else {
              outer.push(@symcore.int(1))
            }
            return solver_mul_all(outer)
          }
          match reduced_base {
            Expr::Mul(args) => {
              let factors : Array[Expr] = []
              for arg in args {
                factors.push(rewrite_child(canonical_expr(@symcore.pow(arg, exp))))
              }
              solver_mul_all(factors)
            }
            _ => canonical_expr(@symcore.pow(reduced_base, exp))
          }
        }
        _ => canonical_expr(@symcore.pow(rewrite_child(base), rewrite_child(exp)))
      }
    Expr::Apply(head, args) =>
      @symcore.raw_apply(head, args.map(rewrite_child)).unwrap_or(
        Expr::Apply(head, args.map(rewrite_child)),
      )
    other => other
  }
}

///|
fn solver_lie_linear_in_single_sqrt(
  expr : Expr,
  atom : Expr,
  radicand : Expr,
) -> (Expr, Expr)? {
  let normalized = canonical_expr(expr)
  if @symcore.compare_expr(normalized, atom) == 0 {
    return Some((@symcore.int(0), @symcore.int(1)))
  }
  if !solver_lie_contains_expr(normalized, atom) {
    return Some((normalized, @symcore.int(0)))
  }
  match normalized {
    Expr::Add(args) => {
      let consts : Array[Expr] = []
      let coeffs : Array[Expr] = []
      for arg in args {
        match solver_lie_linear_in_single_sqrt(arg, atom, radicand) {
          Some((const_part, coeff_part)) => {
            consts.push(const_part)
            coeffs.push(coeff_part)
          }
          None => return None
        }
      }
      Some((solver_add_all(consts), solver_add_all(coeffs)))
    }
    Expr::Mul(args) => {
      let mut const_part = @symcore.int(1)
      let mut coeff_part = @symcore.int(0)
      for arg in args {
        let (next_const, next_coeff) = match solver_lie_linear_in_single_sqrt(arg, atom, radicand) {
          Some(value) => value
          None => return None
        }
        let new_const = canonical_expr(
          @symcore.add([
            @symcore.mul([const_part, next_const]),
            @symcore.mul([coeff_part, next_coeff, radicand]),
          ]),
        )
        let new_coeff = canonical_expr(
          @symcore.add([
            @symcore.mul([const_part, next_coeff]),
            @symcore.mul([coeff_part, next_const]),
          ]),
        )
        const_part = new_const
        coeff_part = new_coeff
      }
      Some((const_part, coeff_part))
    }
    _ => None
  }
}

///|
fn solver_lie_is_zero_core(expr : Expr) -> Bool {
  let expanded = canonical_expr(@symsimplify.numer_expand(expr))
  let factored = solver_lie_factor_common_add(expr)
  let factored_expanded = solver_lie_factor_common_add(expanded)
  for candidate in [expr, expanded, factored, factored_expanded] {
    if expr_is_zeroish(candidate) == Some(true) {
      return true
    }
    if expr_is_zeroish(solver_lie_simplify(candidate)) == Some(true) {
      return true
    }
    if solver_lie_polynomial_zero_atomized(candidate) {
      return true
    }
  }
  solver_lie_polynomial_zero(expr) ||
  solver_lie_polynomial_zero(expanded) ||
  solver_lie_polynomial_zero_atomized(expr) ||
  solver_lie_polynomial_zero_atomized(expanded)
}

///|
fn solver_lie_single_sqrt_zero(expr : Expr) -> Bool {
  let candidates = [
    canonical_expr(expr),
    canonical_expr(@symsimplify.fraction_expand(expr)),
    solver_expand_expr(canonical_expr(@symsimplify.fraction_expand(expr))),
    solver_lie_light_normalize(expr),
  ]
  for candidate in candidates {
    match solver_lie_single_sqrt_atom(candidate) {
      Some((atom, radicand)) => {
        let reduced = solver_lie_reduce_single_sqrt_powers(candidate, atom, radicand)
        match solver_lie_linear_in_single_sqrt(reduced, atom, radicand) {
          Some((const_part, coeff_part)) =>
            if solver_lie_is_zero_core(const_part) && solver_lie_is_zero_core(coeff_part) {
              return true
            }
          None => ()
        }
      }
      None => ()
    }
  }
  false
}

///|
fn solver_lie_is_zero(expr : Expr) -> Bool {
  solver_lie_is_zero_core(expr) || solver_lie_single_sqrt_zero(expr)
}

///|
fn solver_lie_quick_zero(expr : Expr) -> Bool {
  if expr_is_zeroish(expr) == Some(true) {
    return true
  }
  let (numer, denom) = @symsimplify.fraction(expr)
  if expr_is_zeroish(numer) == Some(true) && expr_is_zeroish(denom) != Some(true) {
    return true
  }
  let expanded = @symsimplify.numer_expand(expr)
  let (expanded_num, expanded_den) = @symsimplify.fraction(expanded)
  if expr_is_zeroish(expanded_num) == Some(true) && expr_is_zeroish(expanded_den) != Some(true) {
    return true
  }
  solver_lie_polynomial_zero(expr) || solver_lie_polynomial_zero(expanded)
}

///|
fn solver_lie_zero_on_atomized_samples(expr : Expr) -> Bool {
  let atomized = solver_lie_atomize_poly_expr(
    solver_lie_merge_mul_powers(expr),
    "__lie_sample",
  ).0
  let free = @symcore.free_symbols(atomized)
  if free.is_empty() {
    return expr_is_zeroish(atomized) == Some(true)
  }
  let sample_values = [1, 2, -1, 3]
  let mut checked = 0
  for shift in 0..<sample_values.length() {
    let pairs : Array[(Expr, Expr)] = []
    for i in 0..<free.length() {
      pairs.push((free[i], @symcore.int(sample_values[(i + shift) % sample_values.length()])))
    }
    let substituted = canonical_expr(@symcore.xreplace(atomized, pairs))
    if @symcore.is_nan(substituted) || @symcore.is_infinite(substituted) {
      continue
    }
    match @symcore.exact_numeric_expr_num_den(substituted) {
      Some((num, den)) if den.compare(0N) != 0 => {
        if num.compare(0N) == 0 {
          checked += 1
        } else {
          return false
        }
      }
      _ => ()
    }
  }
  checked >= 2
}

///|
fn solver_lie_nonzero_on_atomized_samples(expr : Expr) -> Bool {
  let atomized = solver_lie_atomize_poly_expr(
    solver_lie_merge_mul_powers(expr),
    "__lie_sample",
  ).0
  let free = @symcore.free_symbols(atomized)
  if free.is_empty() {
    return expr_is_zeroish(atomized) == Some(false)
  }
  let sample_values = [1, 2, -1, 3]
  for shift in 0..<sample_values.length() {
    let pairs : Array[(Expr, Expr)] = []
    for i in 0..<free.length() {
      pairs.push((free[i], @symcore.int(sample_values[(i + shift) % sample_values.length()])))
    }
    let substituted = canonical_expr(@symcore.xreplace(atomized, pairs))
    if @symcore.is_nan(substituted) || @symcore.is_infinite(substituted) {
      continue
    }
    match @symcore.exact_numeric_expr_num_den(substituted) {
      Some((num, den)) if den.compare(0N) != 0 =>
        if num.compare(0N) != 0 {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn solver_lie_rewrite_sec_pow2(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) => canonical_expr(@symcore.add(args.map(arg => solver_lie_rewrite_sec_pow2(arg))))
    Expr::Mul(args) => canonical_expr(@symcore.mul(args.map(arg => solver_lie_rewrite_sec_pow2(arg))))
    Expr::Pow(Expr::Apply(Expr::FunctionHead("sec"), [arg]), exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some((num, den)) if num.compare(2N) == 0 && den.compare(1N) == 0 =>
          canonical_expr(
            @symcore.add([
              @symcore.int(1),
              @symcore.pow(
                canonical_expr(@symcore.function("tan", [solver_lie_rewrite_sec_pow2(arg)])),
                @symcore.int(2),
              ),
            ]),
          )
        _ =>
          canonical_expr(
            @symcore.pow(
              solver_lie_rewrite_sec_pow2(@symcore.function("sec", [arg])),
              solver_lie_rewrite_sec_pow2(exp),
            ),
          )
      }
    Expr::Pow(base, exp) =>
      canonical_expr(@symcore.pow(solver_lie_rewrite_sec_pow2(base), solver_lie_rewrite_sec_pow2(exp)))
    Expr::Apply(head, args) =>
      @symcore.raw_apply(head, args.map(arg => solver_lie_rewrite_sec_pow2(arg))).unwrap_or(
        Expr::Apply(head, args.map(arg => solver_lie_rewrite_sec_pow2(arg))),
      )
    _ => expr
  }
}

///|
fn solver_lie_abaco_zero(expr : Expr) -> Bool {
  let expanded = canonical_expr(@symsimplify.fraction_expand(expr))
  let simplified = solver_lie_simplify(expr)
  let expanded_simplified = solver_lie_simplify(expanded)
  let trig_expanded = solver_lie_simplify(@symsimplify.trigsimp(expanded_simplified))
  let sec_expanded = solver_lie_simplify(solver_lie_rewrite_sec_pow2(trig_expanded))
  for candidate in [sec_expanded, trig_expanded, expanded_simplified, simplified, expanded] {
    if solver_lie_is_zero(candidate) || solver_lie_quick_zero(candidate) {
      return true
    }
  }
  false
}

///|
fn solver_lie_depends_on(expr : Expr, sym : Expr) -> Bool {
  solver_expr_in_list(@symcore.free_symbols(expr), sym)
}

///|
fn solver_lie_expr_size(expr : Expr) -> Int {
  let mut size = 0
  for _ in @symcore.preorder(expr) {
    size += 1
  }
  size
}

///|
fn solver_lie_contains_expr(expr : Expr, target : Expr) -> Bool {
  for node in @symcore.preorder(expr) {
    if @symcore.compare_expr(node, target) == 0 {
      return true
    }
  }
  false
}

///|
fn solver_lie_has_mixed_application(expr : Expr, x : Expr, y : Expr) -> Bool {
  for node in @symcore.preorder(expr) {
    match @symcore.application_parts(node) {
      Some(_) =>
        if solver_lie_depends_on(node, x) && solver_lie_depends_on(node, y) {
          return true
        }
      None => ()
    }
  }
  false
}

///|
fn solver_lie_swap_xy(expr : Expr, x : Expr, y : Expr) -> Expr {
  let temp = @symcore.dummy(name="lie_swap")
  let step1 = @symcore.xreplace(expr, [(x, temp)])
  let step2 = @symcore.xreplace(step1, [(y, x)])
  @symcore.xreplace(step2, [(temp, y)])
}

///|
fn solver_lie_strip_xy_constants(expr : Expr, x : Expr, y : Expr) -> Expr {
  match canonical_expr(expr) {
    Expr::Mul(args) => {
      let kept : Array[Expr] = []
      for arg in args {
        if solver_lie_depends_on(arg, x) || solver_lie_depends_on(arg, y) {
          kept.push(arg)
        }
      }
      solver_mul_all(kept)
    }
    other => other
  }
}

///|
fn solver_lie_light_normalize(expr : Expr) -> Expr {
  let rational = @symsimplify.ratsimp(canonical_expr(expr), max_passes=3)
  let normalized = @sympolys.domain_normal_expr(@sympolys.Domain::EX, rational) catch {
    _ => rational
  }
  @symsimplify.ratsimp(normalized, max_passes=1)
}

///|
fn solver_lie_cancel_atom(expr : Expr) -> Bool {
  match expr {
    Expr::Pow(_, exp) => !solver_lie_exact_integer(exp)
    _ => @symcore.application_parts(expr) is Some(_)
  }
}

fn solver_lie_cancel_expr(expr : Expr) -> Expr {
  let normalized = canonical_expr(expr)
  let atoms : Array[Expr] = []
  for node in @symcore.preorder(normalized) {
    if solver_lie_cancel_atom(node) && !solver_expr_in_list(atoms, node) {
      atoms.push(node)
    }
  }
  let atomized_pairs : Array[(Expr, Expr)] = []
  let restored_pairs : Array[(Expr, Expr)] = []
  for i in 0..<atoms.length() {
    let sym = Expr::Symbol("__lie_cancel_atom\{i}")
    atomized_pairs.push((atoms[i], sym))
    restored_pairs.push((sym, atoms[i]))
  }
  let atomized = if atomized_pairs.is_empty() {
    normalized
  } else {
    @symcore.xreplace(normalized, atomized_pairs)
  }
  let free_pairs : Array[(Expr, Expr)] = []
  let free_restored_pairs : Array[(Expr, Expr)] = []
  let atomized_free = @symcore.free_symbols(atomized)
  for i in 0..<atomized_free.length() {
    match atomized_free[i] {
      Expr::Dummy(_, _) => {
        let sym = Expr::Symbol("__lie_cancel_free\{i}")
        free_pairs.push((atomized_free[i], sym))
        free_restored_pairs.push((sym, atomized_free[i]))
      }
      _ => ()
    }
  }
  let poly_ready = if free_pairs.is_empty() {
    atomized
  } else {
    @symcore.xreplace(atomized, free_pairs)
  }
  let rational_ready = @symsimplify.fraction_expand(
    solver_lie_light_normalize(poly_ready),
  )
  let restore_all : Array[(Expr, Expr)] = []
  for pair in free_restored_pairs {
    restore_all.push(pair)
  }
  for pair in restored_pairs {
    restore_all.push(pair)
  }
  let (numer, denom) = @symsimplify.fraction(rational_ready)
  let symbols = solver_sorted_unique_symbols(@symcore.free_symbols(@symcore.mul([numer, denom]))) catch {
    _ => []
  }
  let gens = solver_symbol_names(symbols) catch { _ => [] }
  if gens.is_empty() {
    return if restore_all.is_empty() { rational_ready } else { canonical_expr(@symcore.xreplace(rational_ready, restore_all)) }
  }
  let num_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(canonical_expr(numer), gens, @sympolys.Domain::EX)
  let den_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(canonical_expr(denom), gens, @sympolys.Domain::EX)
  let canceled = match (num_poly_res, den_poly_res) {
    (Ok(num_poly), Ok(den_poly)) => {
      let cancel_res : Result[(@sympolys.Poly, @sympolys.Poly), @sympolys.PolyError] = try?
        @sympolys.cancel(num_poly, den_poly)
      match cancel_res {
        Ok((num_s, den_s)) => {
          let den_expr = den_s.to_expr()
          if @symcore.compare_expr(den_expr, @symcore.int(1)) == 0 {
            num_s.to_expr()
          } else {
            canonical_expr(@symcore.mul([num_s.to_expr(), den_expr ^ @symcore.int(-1)]))
          }
        }
        Err(_) => rational_ready
      }
    }
    _ => rational_ready
  }
  if restore_all.is_empty() {
    canceled
  } else {
    canonical_expr(@symcore.xreplace(canceled, restore_all))
  }
}

///|
fn solver_lie_logdiff(expr : Expr, wrt : Expr) -> Expr {
  let normalized = canonical_expr(expr)
  match normalized {
    Expr::Mul(args) =>
      solver_add_all(args.map(arg => solver_lie_logdiff(arg, wrt)))
    Expr::Pow(base, exp) if !solver_lie_depends_on(exp, wrt) =>
      @symcore.mul([exp, solver_lie_logdiff(base, wrt)])
    _ => solver_expr_divide(@symcalculus.diff(normalized, wrt), normalized)
  }
}

///|
fn solver_lie_gamma_from_factor(factor : Expr, x : Expr, y : Expr) -> Expr {
  let (numer, denom) = @symsimplify.fraction(solver_lie_cancel_expr(factor))
  let numer_x = solver_lie_logdiff(numer, x)
  let numer_y = solver_lie_logdiff(numer, y)
  let denom_x = solver_lie_logdiff(denom, x)
  let denom_y = solver_lie_logdiff(denom, y)
  let factorx = solver_add_all([numer_x, @symcore.mul([@symcore.int(-1), denom_x])])
  let factory = solver_add_all([numer_y, @symcore.mul([@symcore.int(-1), denom_y])])
  solver_lie_cancel_expr(solver_expr_divide(factorx, factory))
}

///|
fn solver_lie_distribute_mul(lhs : Expr, rhs : Expr) -> Expr {
  match (lhs, rhs) {
    (Expr::Add(args), other) =>
      Expr::Add(args.map(arg => Expr::Mul([arg, other])))
    (other, Expr::Add(args)) =>
      Expr::Add(args.map(arg => Expr::Mul([other, arg])))
    _ => Expr::Mul([lhs, rhs])
  }
}

///|
fn solver_lie_abs_arg(expr : Expr) -> Expr? {
  match @symcore.application_parts(expr) {
    Some((Expr::FunctionHead(name), [arg])) if name == "Abs" || name == "abs" =>
      Some(arg)
    Some((Expr::UndefinedFunction(name), [arg])) if name == "Abs" || name == "abs" =>
      Some(arg)
    _ => None
  }
}

///|
fn solver_lie_is_e_constant(expr : Expr) -> Bool {
  @symcore.compare_expr(
    expr,
    Expr::NumberSymbol(@symcore.NumberSymbolKind::Exp1),
  ) == 0
}

///|
fn solver_lie_term_nonconstant_factors(expr : Expr) -> Array[Expr] {
  let out : Array[Expr] = []
  let factors = match canonical_expr(expr) {
    Expr::Mul(args) => args
    other => [other]
  }
  for factor in factors {
    match factor {
      Expr::Number(_) => ()
      _ =>
        if !solver_expr_in_list(out, factor) {
          out.push(factor)
        }
    }
  }
  out
}

///|
fn solver_lie_term_remove_factors_once(expr : Expr, factors_to_remove : Array[Expr]) -> Expr {
  let factors = match canonical_expr(expr) {
    Expr::Mul(args) => args
    other => [other]
  }
  let remaining = factors.copy()
  for factor in factors_to_remove {
    solver_lie_remove_factor_once(remaining, factor)
  }
  solver_mul_all(remaining)
}

///|
fn solver_lie_sympy_separatevars_expr(
  expr : Expr,
  x : Expr,
  y : Expr,
  force? : Bool = false,
) -> Expr {
  ignore((x, y))
  let normalized = expr
  match solver_lie_abs_arg(expr) {
    Some(arg) =>
      match arg {
        Expr::Mul(_) => {
          let separated = solver_lie_sympy_separatevars_expr(arg, x, y, force~)
          match solver_lie_symbolic_separatevars_xy(separated, x, y) {
            Some(parts) =>
              return canonical_expr(
                @symcore.mul([
                  @symcore.function("Abs", [parts.coeff]),
                  @symcore.function("Abs", [parts.x_part]),
                  @symcore.function("Abs", [parts.y_part]),
                ]),
              )
            None => return normalized
          }
        }
        _ => ()
      }
    None => ()
  }
  if @symcore.free_symbols(normalized).length() < 2 {
    return normalized
  }
  match normalized {
    Expr::Mul(args) => {
      let rebuilt : Array[Expr] = []
      let mut changed = false
      for arg in args {
        let next = solver_lie_sympy_separatevars_expr(arg, x, y, force~)
        changed = changed || @symcore.compare_expr(next, arg) != 0
        rebuilt.push(next)
      }
      if changed {
        return canonical_expr(@symcore.mul(rebuilt))
      }
      return normalized
    }
    _ => ()
  }
  let prepared = match normalized {
    Expr::Pow(base, exp) if !solver_lie_is_e_constant(base) =>
      canonical_expr(
        @symcore.pow(
          solver_lie_sympy_separatevars_expr(base, x, y, force~),
          exp,
        ),
      )
    _ => normalized
  }
  let factored = if force {
    let (posified, restore) = @symsimplify.posify(prepared)
    let factored_posified = solver_lie_factor_expr(posified)
    canonical_expr(
      @symcore.xreplace(
        factored_posified,
        solver_lie_restore_pairs_from_posify(restore),
      ),
    )
  } else {
    solver_lie_factor_common_add(prepared)
  }
  match factored {
    Expr::Add(args) => {
      let mut common = solver_lie_term_nonconstant_factors(args[0])
      for i in 1..<args.length() {
        let current = solver_lie_term_nonconstant_factors(args[i])
        let kept : Array[Expr] = []
        for factor in common {
          if solver_expr_in_list(current, factor) {
            kept.push(factor)
          }
        }
        common = kept
      }
      let common_expr = solver_mul_all(common)
      let remainders : Array[Expr] = []
      for arg in args {
        remainders.push(solver_lie_term_remove_factors_once(arg, common))
      }
      let mut nonsepar = solver_add_all(remainders)
      if @symcore.free_symbols(nonsepar).length() > 1 {
        let refactored = if force {
          let (posified, restore) = @symsimplify.posify(nonsepar)
          let factored_posified = solver_lie_factor_expr(posified)
          canonical_expr(
            @symcore.xreplace(
              factored_posified,
              solver_lie_restore_pairs_from_posify(restore),
            ),
          )
        } else {
          solver_lie_factor_common_add(nonsepar)
        }
        match refactored {
          Expr::Add(_) => ()
          _ => nonsepar = refactored
        }
      }
      canonical_expr(@symcore.mul([common_expr, nonsepar]))
    }
    _ => factored
  }
}

///|
fn solver_lie_sympy_separatevars_dict_xy(
  expr : Expr,
  x : Expr,
  y : Expr,
  force? : Bool = false,
) -> SolverLieSeparated? {
  let separated = solver_lie_sympy_separatevars_expr(expr, x, y, force~)
  let factors = match separated {
    Expr::Mul(args) => args
    other => [other]
  }
  let coeffs : Array[Expr] = []
  let xs : Array[Expr] = []
  let ys : Array[Expr] = []
  for factor in factors {
    let has_x = solver_lie_depends_on(factor, x)
    let has_y = solver_lie_depends_on(factor, y)
    if has_x && has_y {
      return None
    }
    if has_x {
      xs.push(factor)
    } else if has_y {
      ys.push(factor)
    } else {
      coeffs.push(factor)
    }
  }
  let x_part0 = solver_mul_all(xs)
  let y_part0 = solver_mul_all(ys)
  let (x_coeff, x_part) = solver_lie_split_numeric_factor(x_part0)
  let (y_coeff, y_part) = solver_lie_split_numeric_factor(y_part0)
  Some(SolverLieSeparated::{
    coeff: canonical_expr(@symcore.mul([solver_mul_all(coeffs), x_coeff, y_coeff])),
    x_part,
    y_part,
  })
}

///|
fn solver_lie_separatevars_xy(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  match solver_lie_sample_separate_xy(expr, x, y) {
    Some(parts) => return Some(parts)
    None => ()
  }
  match solver_separate_mul_parts_raw(expr, x, y) {
    Some(parts) => Some(parts)
    None => {
      match solver_lie_symbolic_separatevars_xy(expr, x, y) {
        Some(parts) => Some(parts)
        None => None
      }
    }
  }
}

///|
fn solver_lie_sample_separate_xy(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  let sample_pairs = [
    (@symcore.int(1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(3)),
    (@symcore.int(-1), @symcore.int(2)),
  ]
  let validate_coeff = fn(
    x_part : Expr,
    y_part : Expr,
    coeff : Expr,
  ) -> Bool {
    for pair in sample_pairs {
      let x1 = pair.0
      let y1 = pair.1
      let lhs = solver_lie_light_normalize(
        @symcore.xreplace(@symcore.xreplace(expr, [(x, x1)]), [(y, y1)]),
      )
      let rhs = solver_lie_light_normalize(
        @symcore.mul([
          coeff,
          @symcore.xreplace(x_part, [(x, x1)]),
          @symcore.xreplace(y_part, [(y, y1)]),
        ]),
      )
      let delta = solver_lie_light_normalize(
        @symcore.add([lhs, @symcore.mul([@symcore.int(-1), rhs])]),
      )
      if !solver_lie_quick_zero(delta) && !solver_lie_is_zero(delta) {
        return false
      }
    }
    true
  }
  for pair in sample_pairs {
    let x0 = pair.0
    let y0 = pair.1
    let exy = solver_lie_light_normalize(
      @symcore.xreplace(@symcore.xreplace(expr, [(x, x0)]), [(y, y0)]),
    )
    if solver_lie_quick_zero(exy) || solver_lie_is_zero(exy) {
      continue
    }
    let ex = @symcore.xreplace(expr, [(y, y0)])
    let ey = @symcore.xreplace(expr, [(x, x0)])
    let x_raw = @symcore.mul([ex, @symcore.pow(exy, @symcore.int(-1))])
    let y_raw = @symcore.mul([ey, @symcore.pow(exy, @symcore.int(-1))])
    let x_part = if @symcore.free_symbols(x_raw).length() <= 1 {
      solver_lie_simplify_univariate_factor(x_raw)
    } else {
      x_raw
    }
    let y_part = if @symcore.free_symbols(y_raw).length() <= 1 {
      solver_lie_simplify_univariate_factor(y_raw)
    } else {
      y_raw
    }
    if solver_lie_depends_on(x_part, y) || solver_lie_depends_on(y_part, x) {
      continue
    }
    let x_value = @symcore.xreplace(x_part, [(x, x0)])
    let y_value = @symcore.xreplace(y_part, [(y, y0)])
    let coeff_eval = solver_lie_cancel_expr(
      solver_lie_light_normalize(
        solver_expr_divide(exy, @symcore.mul([x_value, y_value])),
      ),
    )
    let coeff = if !solver_lie_depends_on(coeff_eval, x) &&
      !solver_lie_depends_on(coeff_eval, y) &&
      validate_coeff(x_part, y_part, coeff_eval) {
      coeff_eval
    } else {
      let coeff_symbolic_raw = solver_expr_divide(
        expr,
        canonical_expr(@symcore.mul([x_part, y_part])),
      )
      let coeff_symbolic = solver_lie_cancel_expr(
        solver_lie_light_normalize(coeff_symbolic_raw),
      )
      if !solver_lie_depends_on(coeff_symbolic, x) &&
        !solver_lie_depends_on(coeff_symbolic, y) {
        coeff_symbolic
      } else if !solver_lie_depends_on(coeff_eval, x) &&
        !solver_lie_depends_on(coeff_eval, y) {
        coeff_eval
      } else {
        exy
      }
    }
    return Some(SolverLieSeparated::{
      coeff,
      x_part,
      y_part,
    })
  }
  None
}

///|
fn solver_lie_symbolic_separatevars_xy(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  solver_lie_sympy_separatevars_dict_xy(expr, x, y)
}

///|
fn solver_lie_poly_divmod_exprs(
  dividend : Expr,
  divisor : Expr,
  gens : Array[String],
) -> (Expr, Expr)? {
  let dividend_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(
      canonical_expr(dividend),
      gens,
      @sympolys.Domain::EX,
    )
  let divisor_poly_res : Result[@sympolys.Poly, @sympolys.PolyError] = try?
    @sympolys.Poly::from_expr(
      canonical_expr(divisor),
      gens,
      @sympolys.Domain::EX,
    )
  match (dividend_poly_res, divisor_poly_res) {
    (Ok(dividend_poly), Ok(divisor_poly)) => {
      if divisor_poly.is_zero() {
        return None
      }
      let div_res : Result[
        (Array[@sympolys.Poly], @sympolys.Poly),
        @sympolys.PolyError,
      ] = try? dividend_poly.divmod_multivar([divisor_poly])
      match div_res {
        Ok((quotients, remainder)) =>
          Some(
            (
              canonical_expr(quotients[0].to_expr()),
              canonical_expr(remainder.to_expr()),
            ),
          )
        Err(_) => None
      }
    }
    _ => None
  }
}

///|
fn solver_lie_restore_xi_eta_from_chi(
  ctx : SolverLieContext,
  chi_val : Expr,
) -> (Expr, Expr) {
  let y_sym = Expr::Symbol("__lie_y")
  let x_name = match ctx.x {
    Expr::Symbol(name) => name
    _ => "x"
  }
  let chi_sym = @symcore.xreplace(chi_val, [(ctx.func, y_sym)])
  match solver_lie_poly_divmod_exprs(chi_sym, ctx.h, [x_name, "__lie_y"]) {
    Some((xi_quot, eta_rem)) =>
      (
        canonical_expr(
          @symcore.mul([
            @symcore.int(-1),
            @symcore.xreplace(xi_quot, [(y_sym, ctx.func)]),
          ]),
        ),
        canonical_expr(@symcore.xreplace(eta_rem, [(y_sym, ctx.func)])),
      )
    None => (@symcore.int(0), canonical_expr(chi_val))
  }
}

///|
fn solver_lie_separate_xy(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  let attempts = [
    canonical_expr(expr),
    canonical_expr(@symsimplify.separatevars(canonical_expr(expr))),
    solver_lie_simplify(expr),
    solver_lie_simplify(@symsimplify.separatevars(solver_lie_simplify(expr))),
  ]
  for candidate in attempts {
    match solver_separate_mul_parts(candidate, x, y) {
      Some(parts) => return Some(parts)
      None => ()
    }
    let (num, den) = @symsimplify.fraction(candidate)
    if @symcore.compare_expr(den, @symcore.int(1)) != 0 {
      match (solver_separate_mul_parts(num, x, y), solver_separate_mul_parts(den, x, y)) {
        (Some(num_parts), Some(den_parts)) =>
          return Some(SolverLieSeparated::{
            coeff: canonical_expr(
              @symcore.mul([
                num_parts.coeff,
                @symcore.pow(den_parts.coeff, @symcore.int(-1)),
              ]),
            ),
            x_part: canonical_expr(
              @symcore.mul([
                num_parts.x_part,
                @symcore.pow(den_parts.x_part, @symcore.int(-1)),
              ]),
            ),
            y_part: canonical_expr(
              @symcore.mul([
                num_parts.y_part,
                @symcore.pow(den_parts.y_part, @symcore.int(-1)),
              ]),
            ),
          })
        _ => ()
      }
    }
  }
  let sample_pairs = [
    (@symcore.int(1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(3)),
    (@symcore.int(-1), @symcore.int(2)),
  ]
  for pair in sample_pairs {
    let x0 = pair.0
    let y0 = pair.1
    let exy = solver_lie_simplify(@symcore.xreplace(@symcore.xreplace(expr, [(x, x0)]), [(y, y0)]))
    if solver_lie_is_zero(exy) {
      continue
    }
    let ex = solver_lie_simplify(@symcore.xreplace(expr, [(y, y0)]))
    let ey = solver_lie_simplify(@symcore.xreplace(expr, [(x, x0)]))
    let x_part = solver_lie_simplify(solver_expr_divide(ex, exy))
    let y_part = solver_lie_simplify(solver_expr_divide(ey, exy))
    if solver_lie_depends_on(x_part, y) || solver_lie_depends_on(y_part, x) {
      continue
    }
    return Some(SolverLieSeparated::{ coeff: exy, x_part, y_part })
  }
  None
}

///|
fn solver_lie_sample_separate_xy_fast(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> SolverLieSeparated? {
  let sample_pairs = [
    (@symcore.int(1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(3)),
    (@symcore.int(-1), @symcore.int(2)),
  ]
  for pair in sample_pairs {
    let x0 = pair.0
    let y0 = pair.1
    let exy = @symsimplify.simplify(@symcore.xreplace(@symcore.xreplace(expr, [(x, x0)]), [(y, y0)]))
    if expr_is_zeroish(exy) == Some(true) {
      continue
    }
    let ex = @symsimplify.simplify(@symcore.xreplace(expr, [(y, y0)]))
    let ey = @symsimplify.simplify(@symcore.xreplace(expr, [(x, x0)]))
    let x_raw = @symsimplify.simplify(solver_expr_divide(ex, exy))
    let y_raw = @symsimplify.simplify(solver_expr_divide(ey, exy))
    let x_part = if @symcore.free_symbols(x_raw).length() <= 1 {
      solver_lie_simplify_univariate_factor(x_raw)
    } else {
      x_raw
    }
    let y_part = if @symcore.free_symbols(y_raw).length() <= 1 {
      solver_lie_simplify_univariate_factor(y_raw)
    } else {
      y_raw
    }
    if solver_lie_depends_on(x_part, y) || solver_lie_depends_on(y_part, x) {
      continue
    }
    return Some(SolverLieSeparated::{
      coeff: exy,
      x_part,
      y_part,
    })
  }
  None
}

///|
fn solver_lie_residual_y(
  ctx : SolverLieContext,
  xi_y : Expr,
  eta_y : Expr,
) -> Expr {
  let xi_zero = expr_is_zeroish(xi_y) == Some(true)
  let eta_zero = expr_is_zeroish(eta_y) == Some(true)
  if xi_zero && eta_zero {
    return @symcore.int(0)
  }
  if xi_zero {
    return @symcore.add([
      @symcalculus.diff(eta_y, ctx.x),
      @symcore.mul([@symcalculus.diff(eta_y, ctx.y), ctx.h]),
      @symcore.mul([@symcore.int(-1), eta_y, ctx.hy]),
    ])
  }
  if eta_zero {
    return @symcore.add([
      @symcore.mul([
        @symcore.int(-1),
        @symcalculus.diff(xi_y, ctx.x),
        ctx.h,
      ]),
      @symcore.mul([
        @symcore.int(-1),
        @symcalculus.diff(xi_y, ctx.y),
        ctx.h ^ @symcore.int(2),
      ]),
      @symcore.mul([@symcore.int(-1), xi_y, ctx.hx]),
    ])
  }
  @symcore.add([
    @symcalculus.diff(eta_y, ctx.x),
    @symcore.mul([
      @symcore.add([
        @symcalculus.diff(eta_y, ctx.y),
        @symcore.mul([@symcore.int(-1), @symcalculus.diff(xi_y, ctx.x)]),
      ]),
      ctx.h,
    ]),
    @symcore.mul([
      @symcore.int(-1),
      @symcalculus.diff(xi_y, ctx.y),
      ctx.h ^ @symcore.int(2),
    ]),
    @symcore.mul([@symcore.int(-1), xi_y, ctx.hx]),
    @symcore.mul([@symcore.int(-1), eta_y, ctx.hy]),
  ])
}

///|
fn solver_lie_zero_on_samples(expr : Expr, x : Expr, y : Expr) -> Bool {
  let samples = [
    (@symcore.int(1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(3)),
    (@symcore.int(3), @symcore.int(2)),
    (@symcore.int(-1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(-1)),
  ]
  let extra_values = [@symcore.int(1), @symcore.int(2), @symcore.int(-1), @symcore.int(3)]
  let mut checked = 0
  for i in 0..<samples.length() {
    let pair = samples[i]
    let partially_substituted = @symcore.xreplace(
      @symcore.xreplace(expr, [(x, pair.0)]),
      [(y, pair.1)],
    )
    let extra_pairs : Array[(Expr, Expr)] = []
    let remaining = @symcore.free_symbols(partially_substituted)
    for j in 0..<remaining.length() {
      extra_pairs.push((remaining[j], extra_values[(i + j) % extra_values.length()]))
    }
    let substituted = if extra_pairs.is_empty() {
      partially_substituted
    } else {
      @symcore.xreplace(partially_substituted, extra_pairs)
    }
    if @symcore.is_nan(substituted) || @symcore.is_infinite(substituted) {
      continue
    }
    let verdict = expr_is_zeroish(@symcore.evalf(substituted, prec=80))
    match verdict {
      Some(true) => checked += 1
      Some(false) => return false
      None => ()
    }
  }
  checked >= 3
}

///|
fn solver_lie_nonzero_on_samples(expr : Expr, x : Expr, y : Expr) -> Bool {
  let samples = [
    (@symcore.int(1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(3)),
    (@symcore.int(3), @symcore.int(2)),
    (@symcore.int(-1), @symcore.int(2)),
    (@symcore.int(2), @symcore.int(-1)),
  ]
  let extra_values = [@symcore.int(1), @symcore.int(2), @symcore.int(-1), @symcore.int(3)]
  for i in 0..<samples.length() {
    let pair = samples[i]
    let partially_substituted = @symcore.xreplace(
      @symcore.xreplace(expr, [(x, pair.0)]),
      [(y, pair.1)],
    )
    let extra_pairs : Array[(Expr, Expr)] = []
    let remaining = @symcore.free_symbols(partially_substituted)
    for j in 0..<remaining.length() {
      extra_pairs.push((remaining[j], extra_values[(i + j) % extra_values.length()]))
    }
    let substituted = if extra_pairs.is_empty() {
      partially_substituted
    } else {
      @symcore.xreplace(partially_substituted, extra_pairs)
    }
    if @symcore.is_nan(substituted) || @symcore.is_infinite(substituted) {
      continue
    }
    let verdict = expr_is_zeroish(@symcore.evalf(substituted, prec=80))
    if verdict == Some(false) {
      return true
    }
  }
  false
}

///|
fn solver_lie_candidate_valid(
  ctx : SolverLieContext,
  xi : Expr,
  eta : Expr,
) -> Bool {
  let xi_y = @symcore.xreplace(xi, [(ctx.func, ctx.y)])
  let eta_y = @symcore.xreplace(eta, [(ctx.func, ctx.y)])
  let residual = solver_lie_residual_y(ctx, xi_y, eta_y)
  let residual_light = solver_lie_light_normalize(residual)
  let residual_cancel = solver_lie_cancel_expr(residual)
  let residual_cancel_merge = solver_lie_merge_mul_powers(residual_cancel)
  let residual_trig = solver_lie_simplify(
    solver_lie_rewrite_sec_pow2(@symsimplify.trigsimp(residual_cancel_merge)),
  )
  for candidate in [
    residual_trig,
    residual_cancel_merge,
    residual_cancel,
    residual_light,
    residual,
  ] {
    if solver_lie_is_zero(candidate) || solver_lie_quick_zero(candidate) {
      return true
    }
  }
  solver_lie_zero_on_samples(residual, ctx.x, ctx.y)
}

///|
fn solver_lie_push_valid(
  out : Array[Map[String, Expr]],
  ctx : SolverLieContext,
  xi : Expr,
  eta : Expr,
) -> Bool {
  let xi0 = solver_lie_split_fraction_add(
    solver_lie_cancel_expr(solver_lie_light_normalize(xi)),
  )
  let eta0 = solver_lie_split_fraction_add(
    solver_lie_cancel_expr(solver_lie_light_normalize(eta)),
  )
  if expr_is_zeroish(xi0) == Some(true) && expr_is_zeroish(eta0) == Some(true) {
    return false
  }
  if !solver_lie_candidate_valid(ctx, xi0, eta0) {
    return false
  }
  let xi_out = solver_output_lie_expr(xi0)
  let eta_out = solver_output_lie_expr(eta0)
  solver_lie_push_unique(out, xi_out, eta_out)
  true
}

///|
fn solver_lie_substitute_symbol(
  expr : Expr,
  symbol : Expr,
  value : Expr,
) -> Expr {
  match symbol {
    Expr::Symbol(name) => {
      let env : Map[String, Expr] = {}
      env[name] = value
      canonical_expr(@symcore.subst(expr, env))
    }
    _ => canonical_expr(@symcore.xreplace(expr, [(symbol, value)]))
  }
}

///|
fn solver_lie_first_solve_value(
  expr : Expr,
  symbol : Expr,
) -> Expr? raise SolverError {
  let solved = solve(solve_expr_input(expr), symbols=[symbol])
  let mappings = solver_maps_from_result(solved, [symbol])
  let key = solver_symbol_name(symbol)
  for mapping in mappings {
    match mapping.get(key) {
      Some(value) => return Some(value)
      None => ()
    }
  }
  None
}

///|
fn solver_lie_factor_terms_xy(expr : Expr, x : Expr, y : Expr) -> Expr {
  let separated = solver_lie_split_fraction_add(canonical_expr(expr))
  solver_lie_strip_xy_constants(
    solver_lie_factor_common_numeric_add(
      solver_lie_factor_common_add(separated),
    ),
    x,
    y,
  )
}

///|
fn solver_lie_normalize_add_term(expr : Expr) -> Expr {
  if @symcore.free_symbols(expr).length() <= 1 {
    solver_lie_simplify_univariate_factor(expr)
  } else {
    expr
  }
}

///|
fn solver_lie_normalize_add_terms(expr : Expr) -> Expr {
  match canonical_expr(expr) {
    Expr::Add(args) =>
      canonical_expr(@symcore.add(args.map(arg => solver_lie_normalize_add_term(arg))))
    other => solver_lie_normalize_add_term(other)
  }
}

///|
fn solver_lie_split_numeric_factor(term : Expr) -> (Expr, Expr) {
  match canonical_expr(term) {
    Expr::Number(_) => (term, @symcore.int(1))
    Expr::Mul(args) => {
      let numeric : Array[Expr] = []
      let nonnumeric : Array[Expr] = []
      for arg in args {
        let (coeff, rest) = solver_lie_split_numeric_factor(arg)
        if @symcore.compare_expr(coeff, @symcore.int(1)) != 0 {
          numeric.push(coeff)
        }
        if @symcore.compare_expr(rest, @symcore.int(1)) != 0 {
          nonnumeric.push(rest)
        }
      }
      if numeric.is_empty() {
        (@symcore.int(1), canonical_expr(term))
      } else {
        (canonical_expr(@symcore.mul(numeric)), canonical_expr(@symcore.mul(nonnumeric)))
      }
    }
    Expr::Pow(base, exp) if solver_lie_exact_integer(exp) => {
      let (base_coeff, base_rest) = solver_lie_split_numeric_factor(base)
      let coeff =
        if @symcore.compare_expr(base_coeff, @symcore.int(1)) == 0 {
          @symcore.int(1)
        } else {
          canonical_expr(@symcore.pow(base_coeff, exp))
        }
      let rest =
        if @symcore.compare_expr(base_rest, @symcore.int(1)) == 0 {
          @symcore.int(1)
        } else {
          canonical_expr(@symcore.pow(base_rest, exp))
        }
      (coeff, rest)
    }
    _ => (@symcore.int(1), canonical_expr(term))
  }
}

///|
fn solver_lie_factor_common_numeric_add(expr : Expr) -> Expr {
  match canonical_expr(expr) {
    Expr::Add(args) if !args.is_empty() => {
      let (coeff0, rest0) = solver_lie_split_numeric_factor(args[0])
      if @symcore.compare_expr(coeff0, @symcore.int(1)) == 0 {
        return canonical_expr(expr)
      }
      let rests : Array[Expr] = [rest0]
      for i in 1..<args.length() {
        let (coeff_i, rest_i) = solver_lie_split_numeric_factor(args[i])
        if @symcore.compare_expr(coeff_i, coeff0) != 0 {
          return canonical_expr(expr)
        }
        rests.push(rest_i)
      }
      canonical_expr(@symcore.add(rests))
    }
    _ => canonical_expr(expr)
  }
}

///|
fn solver_lie_exact_integer(expr : Expr) -> Bool {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((_, den)) => den.compare(1N) == 0
    None => false
  }
}

///|
fn solver_lie_h_from_equation(
  eq : Expr,
  func : Expr,
) -> Expr raise SolverError {
  let (_, args) = match @symcore.undefined_application_parts(func) {
    Some(parts) => parts
    None => raise SolverError::ValueError("expected applied undefined function")
  }
  guard args.length() == 1 else {
    raise SolverError::ValueError("ODE's have only one independent variable")
  }
  let x = args[0]
  let df = @symcalculus.diff(func, x)
  match solver_extract_linear_targets(solver_normalize_equation(eq), [df]) {
    Some((coeffs, constant)) if !@symcore.is_zero(coeffs[0]) =>
      canonical_expr(@symsimplify.simplify(
        @symcore.mul([
          @symcore.int(-1),
          constant,
          @symcore.pow(coeffs[0], @symcore.int(-1)),
        ]),
      ))
    _ => {
      let solved = solver_single_target_solutions(eq, df)
      guard !solved.is_empty() else {
        raise SolverError::ValueError(
          "Infinitesimals could not be found for the given ODE",
        )
      }
      canonical_expr(@symsimplify.simplify(solved[0]))
    }
  }
}

///|
fn solver_lie_context(
  eq : Expr,
  func : Expr,
  match_env : Map[String, Expr]?,
) -> SolverLieContext raise SolverError {
  let (_, args) = match @symcore.undefined_application_parts(func) {
    Some(parts) => parts
    None => raise SolverError::ValueError("expected applied undefined function")
  }
  guard args.length() == 1 else {
    raise SolverError::ValueError("ODE's have only one independent variable")
  }
  let x = args[0]
  let env : Map[String, Expr] = match match_env {
    Some(values) => values
    None => {}
  }
  let y = env.get("y").unwrap_or(@symcore.dummy(name="y"))
  let raw_h = match env.get("h") {
    Some(value) => value
    None => solver_lie_h_from_equation(eq, func)
  }
  let h_raw = @symsimplify.simplify(@symcore.xreplace(raw_h, [(func, y)]))
  let h = h_raw
  let hx_raw = @symcalculus.diff(h_raw, x)
  let hy_raw = @symcalculus.diff(h_raw, y)
  let hx = solver_lie_cancel_expr(solver_lie_light_normalize(hx_raw))
  let hy = solver_lie_cancel_expr(solver_lie_light_normalize(hy_raw))
  let u = @symcore.dummy(name="u")
  let hinv_raw = @symsimplify.simplify(
    @symcore.xreplace(
      @symcore.xreplace(
        @symcore.xreplace(solver_expr_divide(@symcore.int(1), h_raw), [(x, u)]),
        [(y, x)],
      ),
      [(u, y)],
    ),
  )
  let hinv = hinv_raw
  let hinvx = solver_lie_cancel_expr(solver_lie_light_normalize(@symcalculus.diff(hinv, x)))
  let hinvy = solver_lie_cancel_expr(solver_lie_light_normalize(@symcalculus.diff(hinv, y)))
  SolverLieContext::{ x, y, func, h_raw, h, hx_raw, hy_raw, hx, hy, hinv_raw, hinv, hinvx, hinvy }
}

///|
fn solver_lie_inf_equal(
  lhs : Map[String, Expr],
  rhs : Map[String, Expr],
) -> Bool {
  @symcore.compare_expr(
    lhs.get("xi").unwrap_or(@symcore.int(0)),
    rhs.get("xi").unwrap_or(@symcore.int(0)),
  ) == 0 &&
  @symcore.compare_expr(
    lhs.get("eta").unwrap_or(@symcore.int(0)),
    rhs.get("eta").unwrap_or(@symcore.int(0)),
  ) == 0
}

///|
fn solver_lie_push_unique(
  out : Array[Map[String, Expr]],
  xi : Expr,
  eta : Expr,
) -> Unit {
  let value : Map[String, Expr] = {}
  value["xi"] = xi
  value["eta"] = eta
  for existing in out {
    if solver_lie_inf_equal(existing, value) {
      return
    }
  }
  out.push(value)
}

///|
fn solver_lie_integral_exp(
  integrand : Expr,
  wrt : Expr,
) -> Expr {
  let normalized = canonical_expr(integrand)
  if !solver_lie_depends_on(normalized, wrt) {
    return canonical_expr(
      @symcore.function(
        "exp",
        [canonical_expr(@symcore.mul([normalized, wrt]))],
      ),
    )
  }
  let inv = canonical_expr(@symcore.pow(wrt, @symcore.int(-1)))
  if @symcore.compare_expr(normalized, inv) == 0 {
    return wrt
  }
  let neg_inv = canonical_expr(@symcore.mul([@symcore.int(-1), inv]))
  if @symcore.compare_expr(normalized, neg_inv) == 0 {
    return canonical_expr(@symcore.pow(wrt, @symcore.int(-1)))
  }
  @symcore.function(
    "exp",
    [solver_lie_integrate_wrt(normalized, wrt)],
  )
}

///|
fn solver_lie_integrate_wrt(expr : Expr, wrt : Expr) -> Expr {
  match wrt {
    Expr::Symbol(_) => canonical_expr(@symintegrals.integrate(expr, limits=[wrt]))
    Expr::Dummy(name, _) => {
      let lifted = Expr::Symbol(name)
      canonical_expr(
        @symcore.xreplace(
          @symintegrals.integrate(
            @symcore.xreplace(expr, [(wrt, lifted)]),
            limits=[lifted],
          ),
          [(lifted, wrt)],
        ),
      )
    }
    _ => canonical_expr(@symintegrals.integrate(expr, limits=[wrt]))
  }
}

///|
fn solver_lie_cross_log_derivative_raw(expr : Expr, x : Expr, y : Expr) -> Expr {
  let normalized = canonical_expr(expr)
  let (num, den) = @symsimplify.fraction(normalized)
  if @symcore.compare_expr(den, @symcore.int(1)) != 0 {
    return @symcore.add([
      solver_lie_cross_log_derivative_raw(num, x, y),
      @symcore.mul([
        @symcore.int(-1),
        solver_lie_cross_log_derivative_raw(den, x, y),
      ]),
    ])
  }
  match normalized {
    Expr::Mul(args) =>
      @symcore.add(args.map(arg => solver_lie_cross_log_derivative_raw(arg, x, y)))
    Expr::Pow(base, exp) =>
      match @symcore.exact_numeric_expr_num_den(exp) {
        Some(_) => @symcore.mul([exp, solver_lie_cross_log_derivative_raw(base, x, y)])
        None => {
          let dx = @symcalculus.diff(normalized, x)
          let dy = @symcalculus.diff(normalized, y)
          let dxy = @symcalculus.diff(dx, y)
          solver_expr_divide(
            @symcore.add([
              @symcore.mul([normalized, dxy]),
              @symcore.mul([@symcore.int(-1), dx, dy]),
            ]),
            normalized ^ @symcore.int(2),
          )
        }
      }
    _ => {
      let dx = @symcalculus.diff(normalized, x)
      let dy = @symcalculus.diff(normalized, y)
      let dxy = @symcalculus.diff(dx, y)
      solver_expr_divide(
        @symcore.add([
          @symcore.mul([normalized, dxy]),
          @symcore.mul([@symcore.int(-1), dx, dy]),
        ]),
        normalized ^ @symcore.int(2),
      )
    }
  }
}

///|
fn solver_lie_cross_log_derivative(expr : Expr, x : Expr, y : Expr) -> Expr {
  solver_lie_simplify(solver_lie_cross_log_derivative_raw(expr, x, y))
}

///|
fn solver_lie_heuristic_abaco1_simple(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] {
  let out : Array[Map[String, Expr]] = []
  if !solver_lie_depends_on(ctx.hy, ctx.y) {
    if solver_lie_push_valid(out, ctx, @symcore.int(0), solver_lie_integral_exp(ctx.hy, ctx.x)) &&
      !comp {
      return out
    }
  }
  let hy_over_h = canonical_expr(
    @symcore.mul([ctx.hy, @symcore.pow(ctx.h, @symcore.int(-1))]),
  )
  if !solver_lie_depends_on(hy_over_h, ctx.x) {
    if solver_lie_push_valid(
      out,
      ctx,
      @symcore.int(0),
      solver_lie_restore_func(solver_lie_integral_exp(hy_over_h, ctx.y), ctx),
    ) && !comp {
      return out
    }
  }
  let neg_hx_over_h = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      ctx.hx,
      @symcore.pow(ctx.h, @symcore.int(-1)),
    ]),
  )
  if !solver_lie_depends_on(neg_hx_over_h, ctx.y) {
    if solver_lie_push_valid(out, ctx, solver_lie_integral_exp(neg_hx_over_h, ctx.x), @symcore.int(0)) &&
      !comp {
      return out
    }
  }
  let neg_hx_over_h2 = canonical_expr(
    @symcore.mul([
      @symcore.int(-1),
      ctx.hx,
      @symcore.pow(ctx.h, @symcore.int(-2)),
    ]),
  )
  if !solver_lie_depends_on(neg_hx_over_h2, ctx.x) {
    ignore(
      solver_lie_push_valid(
        out,
        ctx,
        solver_lie_restore_func(solver_lie_integral_exp(neg_hx_over_h2, ctx.y), ctx),
        @symcore.int(0),
      ),
    )
  }
  out
}

///|
fn solver_lie_scale_with_ones(
  expr : Expr,
  symbols : Array[Expr],
) -> Expr raise SolverError {
  let scale : Map[String, Expr] = {}
  for symbol in symbols {
    scale[solver_symbol_name(symbol)] = @symcore.int(1)
  }
  canonical_expr(@symcore.subst(expr, scale))
}

///|
fn solver_lie_match_exp_form(
  expr : Expr,
  x : Expr,
  y : Expr,
) -> (Expr, Expr, Expr)? {
  let a = Expr::Wild("__lie_A", [y], [])
  let b = Expr::Wild("__lie_B", [y], [])
  let c = Expr::Wild("__lie_C", [x, y], [])
  let pattern = canonical_expr(
    @symcore.add([
      a,
      @symcore.mul([
        b,
        @symcore.function(
          "exp",
          [canonical_expr(@symcore.mul([y, @symcore.pow(c, @symcore.int(-1))]))],
        ),
      ]),
    ]),
  )
  match @symcore.expr_match(pattern, expr) {
    Some(mapping) =>
      match (mapping.get(a), mapping.get(b), mapping.get(c)) {
        (Some(av), Some(bv), Some(cv)) => Some((av, bv, cv))
        _ => None
      }
    None => None
  }
}

///|
fn solver_lie_unknown_atoms(ctx : SolverLieContext) -> Array[Expr] {
  let out : Array[Expr] = []
  for node in @symcore.preorder(ctx.h) {
    match node {
      Expr::Pow(base, exp) =>
        if solver_lie_depends_on(base, ctx.x) &&
          solver_lie_depends_on(base, ctx.y) &&
          !solver_lie_exact_integer(exp) &&
          !solver_expr_in_list(out, node) {
          out.push(node)
        }
      Expr::Apply(Expr::FunctionHead(name), [arg]) =>
        if (name == "sqrt" || name == "cbrt") &&
          solver_lie_depends_on(arg, ctx.x) &&
          solver_lie_depends_on(arg, ctx.y) &&
          !solver_expr_in_list(out, node) {
          out.push(node)
        }
      _ =>
        match @symcore.undefined_application_parts(node) {
          Some(_) =>
            if solver_lie_depends_on(node, ctx.x) &&
              solver_lie_depends_on(node, ctx.y) &&
              !solver_expr_in_list(out, node) {
              out.push(node)
            }
          None => ()
        }
    }
  }
  out
}

///|
fn solver_lie_heuristic_abaco1_product(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] {
  let out : Array[Map[String, Expr]] = []
  let probe_raw = solver_expr_divide(
    solver_lie_cross_log_derivative(ctx.h, ctx.x, ctx.y),
    ctx.h ^ @symcore.int(2),
  )
  match solver_lie_separate_xy(probe_raw, ctx.x, ctx.y) {
    Some(sep) if !solver_lie_is_zero(sep.coeff) => {
      let fx = sep.x_part
      let gy_int = solver_lie_simplify(
        @symcore.mul([
          fx,
          @symcalculus.diff(
            solver_expr_divide(
              @symcore.int(1),
              canonical_expr(@symcore.mul([fx, ctx.h])),
            ),
            ctx.x,
          ),
        ]),
      )
      if !solver_lie_depends_on(gy_int, ctx.x) {
        let xi = solver_lie_restore_func(
          canonical_expr(@symcore.mul([fx, solver_lie_integral_exp(gy_int, ctx.y)])),
          ctx,
        )
        if solver_lie_push_valid(out, ctx, xi, @symcore.int(0)) && !comp {
          return out
        }
      }
    }
    _ => ()
  }
  let inverse_probe_raw = solver_expr_divide(
    solver_lie_cross_log_derivative(ctx.hinv, ctx.x, ctx.y),
    ctx.hinv ^ @symcore.int(2),
  )
  let inverse_sep = match solver_lie_separate_xy(inverse_probe_raw, ctx.x, ctx.y) {
    Some(sep) if !solver_lie_is_zero(sep.coeff) => Some((inverse_probe_raw, sep))
    _ => {
      let h_swapped = solver_expr_divide(@symcore.int(1), ctx.hinv)
      let alternative = @symcore.mul([
        @symcore.int(-1),
        h_swapped ^ @symcore.int(2),
        solver_lie_cross_log_derivative(h_swapped, ctx.x, ctx.y),
      ])
      match solver_lie_separate_xy(alternative, ctx.x, ctx.y) {
        Some(sep) if !solver_lie_is_zero(sep.coeff) => Some((alternative, sep))
        _ => None
      }
    }
  }
  match inverse_sep {
    Some((inverse_probe_used, sep)) => {
      ignore(inverse_probe_used)
      let fx = sep.x_part
      let gy_int = solver_lie_simplify(
        @symcore.mul([
          fx,
          @symcalculus.diff(
            solver_expr_divide(
              @symcore.int(1),
              canonical_expr(@symcore.mul([fx, ctx.hinv])),
            ),
            ctx.x,
          ),
        ]),
      )
      if !solver_lie_depends_on(gy_int, ctx.x) {
        let swapped = solver_lie_swap_xy(
          canonical_expr(@symcore.mul([fx, solver_lie_integral_exp(gy_int, ctx.y)])),
          ctx.x,
          ctx.y,
        )
        let eta_try = solver_lie_restore_func(swapped, ctx)
        if solver_lie_push_valid(
          out,
          ctx,
          @symcore.int(0),
          eta_try,
        ) && !comp {
          return out
        }
      }
    }
    None => ()
  }
  out
}

///|
fn solver_lie_heuristic_function_sum(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] raise SolverError {
  let out : Array[Map[String, Expr]] = []
  let order = if comp { [true, false] } else { [false, true] }
  for inverse in order {
    let odefac = if inverse { ctx.hinv } else { ctx.h }
    let q = canonical_expr(solver_expr_divide(@symcore.int(1), odefac))
    let qxx = canonical_expr(@symcalculus.diff(@symcalculus.diff(q, ctx.x), ctx.x))
    let inv_factor = solver_lie_cancel_expr(
      solver_lie_cancel_explicit_den_factors(
        solver_lie_light_normalize(solver_expr_divide(q, qxx)),
      ),
    )
    let sep_probe = canonical_expr(@symcalculus.diff(inv_factor, ctx.y))
    let sep_try = solver_lie_sympy_separatevars_dict_xy(sep_probe, ctx.x, ctx.y)
    match sep_try {
      Some(sep) if !solver_lie_is_zero(sep.coeff) &&
        solver_lie_depends_on(sep.x_part, ctx.x) &&
        solver_lie_depends_on(sep.y_part, ctx.y) => {
        let k = Expr::Symbol("__lie_k")
        let gy = canonical_expr(
          @symcore.mul([k, solver_lie_integrate_wrt(sep.y_part, ctx.y)]),
        )
        let fdd = solver_lie_simplify(
          solver_expr_divide(
            @symcore.int(1),
            canonical_expr(@symcore.mul([k, sep.x_part, sep.coeff])),
          ),
        )
        let fx = solver_lie_simplify(
          @symcore.add([
            canonical_expr(@symcore.mul([fdd, inv_factor])),
            @symcore.mul([@symcore.int(-1), gy]),
          ]),
        )
        if !solver_lie_is_zero(fx) {
          let check = solver_lie_simplify(
            @symcore.add([
              @symcalculus.diff(@symcalculus.diff(fx, ctx.x), ctx.x),
              @symcore.mul([@symcore.int(-1), fdd]),
            ]),
          )
          let (fx0, gy0) = if solver_lie_sympy_zero_check(check) {
            (
              canonical_expr(@symcore.subst(fx, {"__lie_k": @symcore.int(1)})),
              solver_lie_simplify(solver_expr_divide(gy, k)),
            )
          } else {
            let solve_try : Result[SolveResult, SolverError] = try?
              solve(solve_expr_input(check), symbols=[k])
            let mappings = match solve_try {
              Ok(value) => solver_maps_from_result(value, [k])
              _ => []
            }
            guard !mappings.is_empty() else { continue }
            let kval = mappings[0].get("__lie_k").unwrap_or(@symcore.int(1))
            (
              canonical_expr(@symcore.subst(fx, {"__lie_k": kval})),
              canonical_expr(
                @symcore.mul([
                  solver_lie_simplify(solver_expr_divide(gy, k)),
                  kval,
                ]),
              ),
            )
          }
          let fx1 = if inverse { solver_lie_swap_xy(fx0, ctx.x, ctx.y) } else { fx0 }
          let gy1 = if inverse { solver_lie_swap_xy(gy0, ctx.x, ctx.y) } else { gy0 }
          let etaval = solver_lie_factor_terms_xy(
            solver_lie_simplify(@symcore.add([fx1, gy1])),
            ctx.x,
            ctx.y,
          )
          if inverse {
            solver_lie_push_unique(
              out,
              @symcore.int(0),
              solver_output_lie_expr(solver_lie_restore_func(etaval, ctx)),
            )
          } else {
            solver_lie_push_unique(
              out,
              solver_output_lie_expr(solver_lie_restore_func(etaval, ctx)),
              @symcore.int(0),
            )
          }
          if !comp && !out.is_empty() {
            return out
          }
        }
      }
      _ => ()
    }
    if !out.is_empty() {
      return out
    }
  }
  out
}

///|
fn solver_lie_heuristic_abaco2_similar(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] {
  ignore(comp)
  let out : Array[Map[String, Expr]] = []
  let direct_factor = solver_lie_cancel_expr(
    solver_expr_divide(ctx.hy, @symcalculus.diff(ctx.hy, ctx.y)),
  )
  let use_inverse_first = if solver_lie_expr_size(direct_factor) > 120 {
    let inverse_factor_probe = solver_lie_cancel_expr(
      solver_expr_divide(ctx.hinvy, @symcalculus.diff(ctx.hinvy, ctx.y)),
    )
    solver_lie_expr_size(inverse_factor_probe) < solver_lie_expr_size(direct_factor)
  } else {
    false
  }
  let branch_order = if use_inverse_first { [true, false] } else { [false, true] }
  for inverse in branch_order {
    let h0 = if inverse { ctx.hinv } else { ctx.h }
    let hx0 = if inverse { ctx.hinvx } else { ctx.hx }
    let hy0 = if inverse { ctx.hinvy } else { ctx.hy }
    let factor = if inverse {
      solver_lie_cancel_expr(solver_expr_divide(hy0, @symcalculus.diff(hy0, ctx.y)))
    } else {
      direct_factor
    }
    let pushed = if !solver_lie_depends_on(factor, ctx.x) && !solver_lie_depends_on(factor, ctx.y) {
      let matched = if inverse { solver_lie_match_exp_form(ctx.h, ctx.x, ctx.y) } else { solver_lie_match_exp_form(h0, ctx.x, ctx.y) }
      match matched {
        Some((aval, bval, cval)) => {
          let tau = solver_lie_light_normalize(
            @symcore.mul([
              solver_lie_integral_exp(
                @symcore.mul([
                  @symcore.int(-1),
                  aval,
                  @symcore.pow(cval, @symcore.int(-1)),
                ]),
                ctx.x,
              ),
              @symcore.pow(bval, @symcore.int(-1)),
            ]),
          )
          let gx = solver_lie_light_normalize(@symcore.mul([aval, tau]))
          if inverse {
            solver_lie_push_valid(
              out,
              ctx,
              solver_lie_restore_func(solver_lie_swap_xy(gx, ctx.x, ctx.y), ctx),
              solver_lie_restore_func(solver_lie_swap_xy(tau, ctx.x, ctx.y), ctx),
            )
          } else {
            solver_lie_push_valid(
              out,
              ctx,
              solver_lie_restore_func(tau, ctx),
              solver_lie_restore_func(gx, ctx),
            )
          }
        }
        None => false
      }
    } else {
      let gamma = solver_lie_gamma_from_factor(factor, ctx.x, ctx.y)
      if solver_lie_depends_on(gamma, ctx.y) {
        false
      } else {
        let tauint = solver_lie_cancel_expr(
          solver_expr_divide(
            @symcore.add([
              @symcore.mul([gamma, hy0]),
              @symcore.mul([@symcore.int(-1), @symcalculus.diff(gamma, ctx.x)]),
              @symcore.mul([@symcore.int(-1), hx0]),
            ]),
            @symcore.add([h0, gamma]),
          ),
        )
        if solver_lie_depends_on(tauint, ctx.y) {
          false
        } else {
          let tau = solver_lie_integral_exp(tauint, ctx.x)
          let gx = solver_lie_light_normalize(@symcore.mul([@symcore.int(-1), tau, gamma]))
          if inverse {
            solver_lie_push_valid(
              out,
              ctx,
              solver_lie_restore_func(solver_lie_swap_xy(gx, ctx.x, ctx.y), ctx),
              solver_lie_restore_func(solver_lie_swap_xy(tau, ctx.x, ctx.y), ctx),
            )
          } else {
            solver_lie_push_valid(
              out,
              ctx,
              solver_lie_restore_func(tau, ctx),
              solver_lie_restore_func(gx, ctx),
            )
          }
        }
      }
    }
    if pushed {
      return out
    }
  }
  out
}

///|
fn solver_lie_heuristic_abaco2_unique_unknown(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] {
  ignore(comp)
  let out : Array[Map[String, Expr]] = []
  for atom in solver_lie_unknown_atoms(ctx) {
    let frac = solver_lie_cancel_expr(
      solver_expr_divide(@symcalculus.diff(atom, ctx.y), @symcalculus.diff(atom, ctx.x)),
    )
    match solver_lie_sympy_separatevars_dict_xy(frac, ctx.x, ctx.y) {
      Some(sep) if !solver_lie_is_zero(sep.coeff) => {
        let xitry1 = sep.x_part
        let etatry1 = solver_lie_cancel_expr(
          @symcore.mul([
            @symcore.int(-1),
            @symcore.pow(
              canonical_expr(@symcore.mul([sep.y_part, sep.coeff])),
              @symcore.int(-1),
            ),
          ]),
        )
        let pde1 = @symcore.add([
          @symcore.mul([@symcalculus.diff(etatry1, ctx.y), ctx.h]),
          @symcore.mul([@symcore.int(-1), @symcalculus.diff(xitry1, ctx.x), ctx.h]),
          @symcore.mul([@symcore.int(-1), xitry1, ctx.hx]),
          @symcore.mul([@symcore.int(-1), etatry1, ctx.hy]),
        ])
        let etatry1_out = solver_lie_restore_func(etatry1, ctx)
        let pde1_simplified = solver_lie_simplify(pde1)
        if solver_lie_quick_zero(pde1_simplified) || solver_lie_is_zero(pde1_simplified) {
          solver_lie_push_unique(
            out,
            solver_output_lie_expr(xitry1),
            solver_output_lie_expr(etatry1_out),
          )
          return out
        }
        let xitry2 = canonical_expr(@symcore.pow(etatry1, @symcore.int(-1)))
        let etatry2 = canonical_expr(@symcore.pow(xitry1, @symcore.int(-1)))
        let pde2 = @symcore.add([
          @symcalculus.diff(etatry2, ctx.x),
          @symcore.mul([@symcore.int(-1), @symcalculus.diff(xitry2, ctx.y), ctx.h ^ @symcore.int(2)]),
          @symcore.mul([@symcore.int(-1), xitry2, ctx.hx]),
          @symcore.mul([@symcore.int(-1), etatry2, ctx.hy]),
        ])
        let xitry2_out = solver_lie_restore_func(xitry2, ctx)
        let pde2_simplified = solver_lie_simplify(solver_expand_expr(pde2))
        let pde2_trig = solver_lie_simplify(
          solver_lie_rewrite_sec_pow2(@symsimplify.trigsimp(pde2_simplified)),
        )
        if solver_lie_quick_zero(pde2_simplified) || solver_lie_is_zero(pde2_simplified) ||
          solver_lie_quick_zero(pde2_trig) || solver_lie_is_zero(pde2_trig) {
          solver_lie_push_unique(
            out,
            solver_output_lie_expr(xitry2_out),
            solver_output_lie_expr(etatry2),
          )
          return out
        }
      }
      _ => {
        let etatry = canonical_expr(@symcore.mul([@symcore.int(-1), @symcore.pow(frac, @symcore.int(-1))]))
        let pde = @symcore.add([
          @symcalculus.diff(etatry, ctx.x),
          @symcore.mul([@symcalculus.diff(etatry, ctx.y), ctx.h]),
          @symcore.mul([@symcore.int(-1), ctx.hx]),
          @symcore.mul([@symcore.int(-1), etatry, ctx.hy]),
        ])
        let etatry_out = solver_lie_restore_func(etatry, ctx)
        let pde_simplified = solver_lie_simplify(pde)
        if solver_lie_quick_zero(pde_simplified) || solver_lie_is_zero(pde_simplified) {
          solver_lie_push_unique(
            out,
            @symcore.int(1),
            solver_output_lie_expr(etatry_out),
          )
          return out
        }
        let xitry = canonical_expr(@symcore.mul([@symcore.int(-1), frac]))
        let pde = @symcore.add([
          @symcore.mul([@symcore.int(-1), @symcalculus.diff(xitry, ctx.x), ctx.h]),
          @symcore.mul([@symcore.int(-1), @symcalculus.diff(xitry, ctx.y), ctx.h ^ @symcore.int(2)]),
          @symcore.mul([@symcore.int(-1), xitry, ctx.hx]),
          @symcore.mul([@symcore.int(-1), ctx.hy]),
        ])
        let xitry_out = solver_lie_restore_func(xitry, ctx)
        let pde_simplified = solver_lie_simplify(solver_expand_expr(pde))
        if solver_lie_quick_zero(pde_simplified) || solver_lie_is_zero(pde_simplified) {
          solver_lie_push_unique(
            out,
            solver_output_lie_expr(xitry_out),
            @symcore.int(1),
          )
          return out
        }
      }
    }
  }
  out
}

///|
fn solver_lie_heuristic_abaco2_unique_general(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] {
  ignore(comp)
  let out : Array[Map[String, Expr]] = []
  let a_expr = solver_lie_simplify(@symcalculus.diff(ctx.hx, ctx.y))
  let b_expr = solver_lie_simplify(@symcore.add([@symcalculus.diff(ctx.hy, ctx.y), ctx.hy ^ @symcore.int(2)]))
  let c_expr = solver_lie_simplify(@symcore.add([@symcalculus.diff(ctx.hx, ctx.x), @symcore.mul([@symcore.int(-1), ctx.hx ^ @symcore.int(2)])]))
  if solver_lie_is_zero(a_expr) || solver_lie_is_zero(b_expr) || solver_lie_is_zero(c_expr) {
    return []
  }
  let ax = solver_lie_simplify(@symcalculus.diff(a_expr, ctx.x))
  let ay = solver_lie_simplify(@symcalculus.diff(a_expr, ctx.y))
  let axy = solver_lie_simplify(@symcalculus.diff(ax, ctx.y))
  let axx = solver_lie_simplify(@symcalculus.diff(ax, ctx.x))
  let ayy = solver_lie_simplify(@symcalculus.diff(ay, ctx.y))
  let d_expr = solver_lie_simplify(
    @symcore.add([
      @symcore.mul([
        @symcore.add([
          @symcore.mul([@symcore.int(2), axy]),
          @symcore.mul([ctx.hx, ay]),
          @symcore.mul([@symcore.int(-1), ax, ctx.hy]),
          @symcore.mul([@symcore.add([@symcore.mul([ctx.hx, ctx.hy]), @symcore.mul([@symcore.int(2), a_expr])]), a_expr]),
        ]),
        a_expr,
      ]),
      @symcore.mul([@symcore.int(-3), ax, ay]),
    ]),
  )
  if solver_lie_is_zero(d_expr) {
    let e1 = solver_lie_simplify(
      @symcore.add([
        @symcore.mul([@symcore.int(3), ax ^ @symcore.int(2)]),
        @symcore.mul([
          @symcore.add([
            @symcore.mul([ctx.hx ^ @symcore.int(2), a_expr]),
            @symcore.mul([@symcore.int(2), c_expr, a_expr]),
            @symcore.mul([@symcore.int(-2), axx]),
          ]),
          a_expr,
        ]),
      ]),
    )
    if solver_lie_is_zero(e1) {
      return []
    }
    let e2 = solver_lie_simplify(
      @symcore.add([
        @symcore.mul([
          @symcore.add([
            @symcore.mul([@symcore.int(2), ayy]),
            @symcore.mul([
              @symcore.add([
                @symcore.mul([@symcore.int(2), b_expr]),
                @symcore.mul([@symcore.int(-1), ctx.hy ^ @symcore.int(2)]),
              ]),
              a_expr,
            ]),
          ]),
          a_expr,
        ]),
        @symcore.mul([@symcore.int(-3), ay ^ @symcore.int(2)]),
      ]),
    )
    if !solver_lie_is_zero(e2) {
      return []
    }
    let e3 = solver_lie_simplify(
      @symcore.add([
        @symcore.mul([
          e1,
          @symcore.add([
            @symcore.mul([@symcore.add([@symcore.mul([@symcore.int(28), ax]), @symcore.mul([@symcore.int(4), ctx.hx, a_expr])]), a_expr ^ @symcore.int(3)]),
            @symcore.mul([@symcore.int(-1), e1, @symcore.add([@symcore.mul([ctx.hy, a_expr]), ay])]),
          ]),
        ]),
        @symcore.mul([@symcore.int(-1), @symcalculus.diff(e1, ctx.x), @symcore.int(8), a_expr ^ @symcore.int(4)]),
      ]),
    )
    if !solver_lie_is_zero(e3) {
      return []
    }
    let etaint = solver_lie_simplify(
      solver_expr_divide(
        @symcore.add([
          @symcore.mul([@symcore.int(4), a_expr ^ @symcore.int(3), @symcore.add([ax, @symcore.mul([@symcore.int(-1), ctx.hx, a_expr])])]),
          @symcore.mul([e1, @symcore.add([@symcore.mul([ctx.hy, a_expr]), @symcore.mul([@symcore.int(-1), ay])])]),
        ]),
        @symcore.mul([@symcore.int(2), a_expr, e1]),
      ),
    )
    if solver_lie_depends_on(etaint, ctx.x) {
      return []
    }
    let eta = solver_lie_integral_exp(etaint, ctx.y)
    let xi = solver_lie_simplify(
      @symcore.mul([
        @symcore.int(-1),
        @symcore.int(4),
        a_expr ^ @symcore.int(3),
        eta,
        @symcore.pow(e1, @symcore.int(-1)),
      ]),
    )
    if solver_lie_depends_on(xi, ctx.y) {
      return []
    }
    if solver_lie_push_valid(out, ctx, xi, solver_lie_restore_func(eta, ctx)) {
      return out
    }
    return []
  }
  let e1 = solver_lie_simplify(
    @symcore.add([
      @symcore.mul([
        @symcore.add([
          @symcore.mul([@symcore.int(2), ayy]),
          @symcore.mul([
            @symcore.add([
              @symcore.mul([@symcore.int(2), b_expr]),
              @symcore.mul([@symcore.int(-1), ctx.hy ^ @symcore.int(2)]),
            ]),
            a_expr,
          ]),
        ]),
        a_expr,
      ]),
      @symcore.mul([@symcore.int(-3), ay ^ @symcore.int(2)]),
    ]),
  )
  if solver_lie_is_zero(e1) {
    return []
  }
  let e2 = solver_lie_simplify(
    @symcore.add([
      @symcore.mul([@symcore.int(4), a_expr ^ @symcore.int(3), d_expr]),
      @symcore.mul([@symcore.int(-1), d_expr ^ @symcore.int(2)]),
      @symcore.mul([
        e1,
        @symcore.add([
          @symcore.mul([@symcore.add([@symcore.mul([@symcore.int(2), axx]), @symcore.mul([@symcore.int(-1), ctx.hx ^ @symcore.int(2), a_expr]), @symcore.mul([@symcore.int(-2), c_expr, a_expr])]), a_expr]),
          @symcore.mul([@symcore.int(-3), ax ^ @symcore.int(2)]),
        ]),
      ]),
    ]),
  )
  if !solver_lie_is_zero(e2) {
    return []
  }
  let e3 = solver_lie_simplify(
    @symcore.add([
      @symcore.mul([@symcore.int(-1), a_expr, d_expr, @symcalculus.diff(e1, ctx.y)]),
      @symcore.mul([
        @symcore.add([
          @symcore.mul([@symcalculus.diff(e1, ctx.x), a_expr]),
          @symcore.mul([@symcore.int(-1), ctx.hy, d_expr, a_expr]),
          @symcore.mul([@symcore.int(3), ay, d_expr]),
          @symcore.mul([@symcore.add([@symcore.mul([a_expr, ctx.hx]), @symcore.mul([@symcore.int(-3), ax])]), e1]),
        ]),
        e1,
      ]),
    ]),
  )
  if !solver_lie_is_zero(e3) {
    return []
  }
  let etaint = solver_lie_simplify(
    solver_expr_divide(
      @symcore.add([
        @symcore.mul([@symcore.add([@symcore.mul([a_expr, ctx.hx]), @symcore.mul([@symcore.int(-1), ax])]), e1]),
        @symcore.mul([@symcore.int(-1), @symcore.add([ay, @symcore.mul([a_expr, ctx.hy])]), d_expr]),
      ]),
      @symcore.mul([@symcore.int(2), a_expr, d_expr]),
    ),
  )
  if solver_lie_depends_on(etaint, ctx.x) {
    return []
  }
  let eta = solver_lie_integral_exp(etaint, ctx.y)
  let xi = solver_lie_simplify(
    @symcore.mul([
      @symcore.int(-1),
      e1,
      eta,
      @symcore.pow(d_expr, @symcore.int(-1)),
    ]),
  )
  if solver_lie_depends_on(xi, ctx.y) {
    return []
  }
  if solver_lie_push_valid(out, ctx, xi, solver_lie_restore_func(eta, ctx)) {
    return out
  }
  []
}

///|
fn solver_lie_linear_candidate(
  equations : Array[Expr],
  coeffs : Array[Expr],
) -> Map[String, Expr]? raise SolverError {
  let out : Map[String, Expr] = {}
  let mut remaining_coeffs = coeffs.copy()
  let mut remaining_eqs = equations.map(solver_normalize_equation)
  while true {
    remaining_eqs = substitute_equations(remaining_eqs, out)
    let live_eqs : Array[Expr] = []
    for eq in remaining_eqs {
      if expr_is_zeroish(eq) != Some(true) {
        live_eqs.push(eq)
      }
    }
    remaining_eqs = live_eqs
    if remaining_eqs.is_empty() {
      break
    }
    let mut progress = false
    for coeff in remaining_coeffs {
      let mut best_value : Expr? = None
      let mut best_score = 0
      for eq in remaining_eqs {
        match solver_extract_linear_targets(eq, [coeff]) {
          Some((coefs, constant)) if !@symcore.is_zero(coefs[0]) => {
            let solved = solver_lie_cancel_expr(
              solver_lie_light_normalize(
                canonical_expr(
                  @symcore.subst(
                    @symcore.mul([
                      @symcore.int(-1),
                      constant,
                      @symcore.pow(coefs[0], @symcore.int(-1)),
                    ]),
                    out,
                  ),
                ),
              ),
            )
            if solver_expr_has_target(solved, coeff) {
              continue
            }
            let score = solver_lie_expr_size(solved) + solver_lie_expr_size(coefs[0])
            match best_value {
              Some(_) if score >= best_score => ()
              _ => {
                best_value = Some(solved)
                best_score = score
              }
            }
          }
          _ => ()
        }
      }
      match best_value {
        Some(value) => {
          out[solver_symbol_name(coeff)] = value
          remaining_coeffs = drop_symbol(remaining_coeffs, coeff)
          progress = true
        }
        None => ()
      }
      if progress {
        break
      }
    }
    if !progress {
      for eq in remaining_eqs {
        let live = filtered_symbols(@symcore.free_symbols(eq), remaining_coeffs, [])
        if live.is_empty() && expr_is_zeroish(eq) != Some(true) {
          return None
        }
      }
      break
    }
  }
  for coeff in remaining_coeffs {
    let name = solver_symbol_name(coeff)
    if out.get(name) is None {
      out[name] = coeff
    }
  }
  Some(out)
}

///|
fn solver_lie_linear_eq_normalize(expr : Expr) -> Expr {
  let canceled = solver_lie_merge_mul_powers(solver_lie_cancel_products(expr))
  solver_lie_merge_mul_powers(
    canonical_expr(
      @symsimplify.powsimp(
        @symsimplify.numer_expand(canceled),
      ),
    ),
  )
}

///|
fn solver_lie_heuristic_linear(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] raise SolverError {
  ignore(comp)
  let c0 = Expr::Symbol("__lie_c0")
  let c1 = Expr::Symbol("__lie_c1")
  let c2 = Expr::Symbol("__lie_c2")
  let c3 = Expr::Symbol("__lie_c3")
  let c4 = Expr::Symbol("__lie_c4")
  let c5 = Expr::Symbol("__lie_c5")
  let coeffs = [c0, c1, c2, c3, c4, c5]
  let pde = solver_lie_simplify(
    @symcore.add([
      c3,
      @symcore.mul([@symcore.add([c4, @symcore.mul([@symcore.int(-1), c0])]), ctx.h]),
      @symcore.mul([
        @symcore.int(-1),
        @symcore.add([
          @symcore.mul([c0, ctx.x]),
          @symcore.mul([c1, ctx.y]),
          c2,
        ]),
        ctx.hx,
      ]),
      @symcore.mul([
        @symcore.int(-1),
        @symcore.add([
          @symcore.mul([c3, ctx.x]),
          @symcore.mul([c4, ctx.y]),
          c5,
        ]),
        ctx.hy,
      ]),
      @symcore.mul([@symcore.int(-1), c1, ctx.h ^ @symcore.int(2)]),
    ]),
  )
  let y_sym = Expr::Symbol("__lie_y")
  let pde_sym = @symcore.xreplace(pde, [(ctx.y, y_sym)])
  let (num, _) = @symsimplify.fraction(pde_sym)
  let pairs : Array[(Expr, Expr)] = []
  let terms = match solver_lie_simplify(num) {
    Expr::Add(args) => args
    other => [other]
  }
  for term in terms {
    let (coeff, basis) = solver_split_coeff_basis(term, [ctx.x, y_sym])
    if solver_depends_on_any(basis, coeffs) {
      return []
    }
    solver_collect_term_pair(pairs, basis, coeff)
  }
  let coeff_equations : Array[Expr] = []
  for pair in pairs {
    if !solver_lie_is_zero(pair.1) {
      coeff_equations.push(
        solver_lie_linear_eq_normalize(solver_normalize_equation(pair.1)),
      )
    }
  }
  if coeff_equations.is_empty() {
    return []
  }
  let candidates = match solver_lie_linear_candidate(coeff_equations, coeffs) {
    Some(value) => [value]
    None => []
  }
  for candidate in candidates {
    if !candidate.values().any(value => expr_is_zeroish(value) != Some(true)) {
      continue
    }
    let xival = solver_lie_scale_with_ones(
      canonical_expr(
        @symcore.subst(
          @symcore.add([
            @symcore.mul([c0, ctx.x]),
            @symcore.mul([c1, ctx.func]),
            c2,
          ]),
          candidate,
        ),
      ),
      coeffs,
    )
    let etaval = solver_lie_scale_with_ones(
      canonical_expr(
        @symcore.subst(
          @symcore.add([
            @symcore.mul([c3, ctx.x]),
            @symcore.mul([c4, ctx.func]),
            c5,
          ]),
          candidate,
        ),
      ),
      coeffs,
    )
    let out : Array[Map[String, Expr]] = []
    if solver_lie_push_valid(out, ctx, xival, etaval) {
      return out
    }
  }
  []
}

///|
fn solver_lie_heuristic_bivariate(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] raise SolverError {
  ignore(comp)
  let y_sym = Expr::Symbol("__lie_y")
  let h_sym = @symcore.xreplace(ctx.h, [(ctx.y, y_sym)])
  let hx_sym = @symcore.xreplace(ctx.hx, [(ctx.y, y_sym)])
  let hy_sym = @symcore.xreplace(ctx.hy, [(ctx.y, y_sym)])
  let etax = Expr::Symbol("__etax")
  let etay = Expr::Symbol("__etay")
  let etad = Expr::Symbol("__etad")
  let xix = Expr::Symbol("__xix")
  let xiy = Expr::Symbol("__xiy")
  let xid = Expr::Symbol("__xid")
  let degree_probe = canonical_expr(
    @symcore.add([
      etax,
      @symcore.mul([@symcore.add([etay, @symcore.mul([@symcore.int(-1), xix])]), h_sym]),
      @symcore.mul([@symcore.int(-1), xiy, h_sym ^ @symcore.int(2)]),
      @symcore.mul([@symcore.int(-1), xid, hx_sym]),
      @symcore.mul([@symcore.int(-1), etad, hy_sym]),
    ]),
  )
  let (probe_num, _) = @symsimplify.fraction(@symsimplify.numer_expand(degree_probe))
  let degree_poly = @sympolys.Poly::from_expr_defaults(
    probe_num,
    gens=["x", "__lie_y"],
  ) catch {
    _ => return []
  }
  let mut xieq = Expr::Symbol("xi0")
  let mut etaeq = Expr::Symbol("eta0")
  let max_degree = degree_poly.total_degree()
  for degree in 0..=max_degree {
    if degree > 0 {
      let xi_terms : Array[Expr] = []
      let eta_terms : Array[Expr] = []
      for power_x in 0..=degree {
        let power_y = degree - power_x
        let monomial = canonical_expr(
          @symcore.mul([
            ctx.x ^ @symcore.int(power_x),
            y_sym ^ @symcore.int(power_y),
          ]),
        )
        xi_terms.push(Expr::Symbol("xi_\{power_x}_\{power_y}") * monomial)
        eta_terms.push(Expr::Symbol("eta_\{power_x}_\{power_y}") * monomial)
      }
      xieq = canonical_expr(@symcore.add([xieq, @symcore.add(xi_terms)]))
      etaeq = canonical_expr(@symcore.add([etaeq, @symcore.add(eta_terms)]))
    }
    let coeff_symbols : Array[Expr] = []
    for symbol in filtered_symbols(@symcore.free_symbols(@symcore.add([xieq, etaeq])), [], []) {
      if @symcore.compare_expr(symbol, ctx.x) != 0 &&
        @symcore.compare_expr(symbol, y_sym) != 0 {
        coeff_symbols.push(symbol)
      }
    }
    let pde = canonical_expr(
      @symcore.add([
        @symcalculus.diff(etaeq, ctx.x),
        @symcore.mul([
          canonical_expr(
            @symcore.add([
              @symcalculus.diff(etaeq, y_sym),
              @symcore.mul([@symcore.int(-1), @symcalculus.diff(xieq, ctx.x)]),
            ]),
          ),
          h_sym,
        ]),
        @symcore.mul([
          @symcore.int(-1),
          @symcalculus.diff(xieq, y_sym),
          h_sym ^ @symcore.int(2),
        ]),
        @symcore.mul([@symcore.int(-1), xieq, hx_sym]),
        @symcore.mul([@symcore.int(-1), etaeq, hy_sym]),
      ]),
    )
    let (pde_num, _) = @symsimplify.fraction(@symsimplify.numer_expand(pde))
    let solved = solve_undetermined_coeffs(
      pde_num,
      coeff_symbols,
      syms=[ctx.x, y_sym],
      dict=true,
    )
    let candidates : Array[Map[String, Expr]] = match solved {
      Some(SolveResult::Dict(values)) => [values]
      Some(SolveResult::Dicts(items)) => items
      _ => []
    }
    for candidate in candidates {
      let xival = solver_lie_scale_with_ones(
        canonical_expr(
          @symcore.xreplace(@symcore.subst(xieq, candidate), [(y_sym, ctx.func)]),
        ),
        coeff_symbols,
      )
      let etaval = solver_lie_scale_with_ones(
        canonical_expr(
          @symcore.xreplace(@symcore.subst(etaeq, candidate), [(y_sym, ctx.func)]),
        ),
        coeff_symbols,
      )
      let out : Array[Map[String, Expr]] = []
      if solver_lie_push_valid(out, ctx, xival, etaval) {
        return out
      }
    }
  }
  []
}

///|
fn solver_lie_heuristic_chi(
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] raise SolverError {
  ignore(comp)
  let y_sym = Expr::Symbol("__lie_y")
  let h_sym = @symcore.xreplace(ctx.h, [(ctx.y, y_sym)])
  let hy_sym = @symcore.xreplace(ctx.hy, [(ctx.y, y_sym)])
  let schi = Expr::Symbol("__schi")
  let schix = Expr::Symbol("__schix")
  let schiy = Expr::Symbol("__schiy")
  let probe = solver_lie_simplify(
    @symcore.add([
      schix,
      @symcore.mul([h_sym, schiy]),
      @symcore.mul([@symcore.int(-1), hy_sym, schi]),
    ]),
  )
  let (probe_num, _) = @symsimplify.fraction(probe)
  let degree_probe_num = canonical_expr(
    @symcore.subst(
      probe_num,
      {
        "__schi": @symcore.int(1),
        "__schix": @symcore.int(1),
        "__schiy": @symcore.int(1),
      },
    ),
  )
  let degree_poly = @sympolys.Poly::from_expr_defaults(
    degree_probe_num,
    gens=["x", "__lie_y"],
  ) catch {
    _ => return []
  }
  let mut chieq = Expr::Symbol("chi")
  let max_degree = degree_poly.total_degree()
  for degree in 1..=max_degree {
    let chi_terms : Array[Expr] = []
    for power_x in 0..=degree {
      let power_y = degree - power_x
      let monomial = canonical_expr(
        @symcore.mul([
          ctx.x ^ @symcore.int(power_x),
          y_sym ^ @symcore.int(power_y),
        ]),
      )
      chi_terms.push(Expr::Symbol("chi_\{power_x}_\{power_y}") * monomial)
    }
    chieq = canonical_expr(@symcore.add([chieq, @symcore.add(chi_terms)]))
    let coeff_symbols : Array[Expr] = []
    for symbol in filtered_symbols(@symcore.free_symbols(chieq), [], []) {
      if @symcore.compare_expr(symbol, ctx.x) != 0 &&
        @symcore.compare_expr(symbol, y_sym) != 0 {
        coeff_symbols.push(symbol)
      }
    }
    let cpde = solver_lie_simplify(
      @symcore.add([
        @symcalculus.diff(chieq, ctx.x),
        @symcore.mul([h_sym, @symcalculus.diff(chieq, y_sym)]),
        @symcore.mul([@symcore.int(-1), hy_sym, chieq]),
      ]),
    )
    let (cpde_num, _) = @symsimplify.fraction(cpde)
    let solved = solve_undetermined_coeffs(
      cpde_num,
      coeff_symbols,
      syms=[ctx.x, y_sym],
      dict=true,
    )
    let candidates : Array[Map[String, Expr]] = match solved {
      Some(SolveResult::Dict(values)) => [values]
      Some(SolveResult::Dicts(items)) => items
      _ => []
    }
    for candidate in candidates {
      let chi_val = solver_lie_scale_with_ones(
        canonical_expr(@symcore.xreplace(@symcore.subst(chieq, candidate), [(y_sym, ctx.func)])),
        coeff_symbols,
      )
      let (xival, etaval) = solver_lie_restore_xi_eta_from_chi(ctx, chi_val)
      let out : Array[Map[String, Expr]] = []
      if solver_lie_push_valid(out, ctx, xival, etaval) {
        return out
      }
    }
  }
  []
}

///|
fn solver_lie_apply_heuristic(
  name : String,
  ctx : SolverLieContext,
  comp : Bool,
) -> Array[Map[String, Expr]] raise SolverError {
  match name {
    "abaco1_simple" => solver_lie_heuristic_abaco1_simple(ctx, comp)
    "abaco1_product" => solver_lie_heuristic_abaco1_product(ctx, comp)
    "abaco2_similar" => solver_lie_heuristic_abaco2_similar(ctx, comp)
    "abaco2_unique_unknown" => solver_lie_heuristic_abaco2_unique_unknown(ctx, comp)
    "abaco2_unique_general" => solver_lie_heuristic_abaco2_unique_general(ctx, comp)
    "linear" => solver_lie_heuristic_linear(ctx, comp)
    "function_sum" => solver_lie_heuristic_function_sum(ctx, comp)
    "bivariate" => solver_lie_heuristic_bivariate(ctx, comp)
    "chi" => solver_lie_heuristic_chi(ctx, comp)
    _ => []
  }
}

///|
pub fn infinitesimals(
  eq : Expr,
  func? : Expr? = None,
  order? : Int? = None,
  hint? : String = "default",
  match_env? : Map[String, Expr]? = None,
) -> Array[Map[String, Expr]] raise SolverError {
  let f = solver_infer_ode_function(eq, func)
  let ode_ord = order.unwrap_or(ode_order(eq, f))
  guard ode_ord == 1 else {
    raise SolverError::ValueError("Infinitesimals for only first order ODE's have been implemented")
  }
  let ctx = solver_lie_context(eq, f, match_env)
  if hint == "all" {
    let out : Array[Map[String, Expr]] = []
    for heuristic in solver_lie_heuristics {
      for item in solver_lie_apply_heuristic(heuristic, ctx, true) {
        if !out.any(existing => solver_lie_inf_equal(existing, item)) {
          out.push(item)
        }
      }
    }
    guard !out.is_empty() else {
      raise SolverError::ValueError("Infinitesimals could not be found for the given ODE")
    }
    return out
  }
  if hint == "default" {
    for heuristic in solver_lie_heuristics {
      let out = solver_lie_apply_heuristic(heuristic, ctx, false)
      if !out.is_empty() {
        return out
      }
    }
    raise SolverError::ValueError("Infinitesimals could not be found for the given ODE")
  }
  guard solver_lie_heuristics.contains(hint) else {
    raise SolverError::ValueError("Heuristic not recognized: " + hint)
  }
  let out = solver_lie_apply_heuristic(hint, ctx, true)
  guard !out.is_empty() else {
    raise SolverError::ValueError(
      "Infinitesimals could not be found using the given heuristic",
    )
  }
  out
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
    raise SolverError::ValueError(
      "Lie groups solver has been implemented only for first order differential equations",
    )
  }
  let ctx = solver_lie_context(eq, f, None)
  let out : Array[(Bool, Expr)] = []
  for infinitesimal in infinitesimal_solutions {
    let xi = solver_lie_cancel_expr(
      solver_lie_light_normalize(
        @symcore.xreplace(
          infinitesimal.get("xi").unwrap_or(@symcore.int(0)),
          [(ctx.func, ctx.y)],
        ),
      ),
    )
    let eta = solver_lie_cancel_expr(
      solver_lie_light_normalize(
        @symcore.xreplace(
          infinitesimal.get("eta").unwrap_or(@symcore.int(0)),
          [(ctx.func, ctx.y)],
        ),
      ),
    )
    let residual_y = solver_lie_residual_y(ctx, xi, eta)
    let residual_light = solver_lie_light_normalize(residual_y)
    let residual_cancel = solver_lie_cancel_expr(residual_y)
    let residual_cancel_merge = solver_lie_merge_mul_powers(residual_cancel)
    let residual_trig = solver_lie_simplify(
      solver_lie_rewrite_sec_pow2(@symsimplify.trigsimp(residual_cancel_merge)),
    )
    let residual_merge = solver_lie_merge_mul_powers(residual_y)
    let residual_candidates = [
      residual_trig,
      residual_cancel_merge,
      residual_cancel,
      residual_light,
      residual_merge,
      residual_y,
    ]
    let mut residual_zero = false
    let mut residual_best = residual_y
    for candidate in residual_candidates {
      residual_best = candidate
      if solver_lie_is_zero(candidate) || solver_lie_quick_zero(candidate) {
        residual_zero = true
        break
      }
    }
    let residual = canonical_expr(solver_lie_restore_func(residual_best, ctx))
    out.push(
      if residual_zero || solver_lie_zero_on_samples(residual_best, ctx.x, ctx.y) {
        (true, @symcore.int(0))
      } else {
        (false, residual)
      },
    )
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
  order? : Int? = None,
  solve_for_func? : Bool = true,
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
  let sol_eq = solver_checkodesol_rewrite_solution(sol, f)
  let ode_order_value = order.unwrap_or(ode_order(ode, f))
  let (_, args) = match @symcore.undefined_application_parts(f) {
    Some(parts) => parts
    None => raise SolverError::ValueError("expected applied undefined function")
  }
  guard args.length() == 1 else {
    raise SolverError::ValueError("func must be a function of one variable")
  }
  let x = args[0]
  if solve_for_func &&
    solver_checkodesol_solved_rhs(sol_eq, f) is None {
    let solved_try : Result[Array[Expr], SolverError] = try?
      solver_checkodesol_solve_target(sol_eq, f)
    match solved_try {
      Ok(solved) if solved.length() == 1 =>
        return checkodesol(
          ode,
          Expr::Relational(@symcore.RelOp::Eq, f, solved[0]),
          func=Some(f),
          order=Some(ode_order_value),
          solve_for_func=false,
        )
      _ => ()
    }
  }
  match solver_checkodesol_pass1(ode, sol_eq, f) {
    Some((true, residual)) => return (true, residual)
    _ => ()
  }
  let pass2 = solver_checkodesol_pass2(ode, sol_eq, f, x, ode_order_value)
  if pass2.0 {
    return pass2
  }
  match solver_checkodesol_pass3(ode, sol_eq, f, x, ode_order_value) {
    Some((true, residual)) => (true, residual)
    Some(residual) => residual
    None => pass2
  }
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
