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
fn unique_symbols_in_input_order(
  items : Array[Expr],
) -> Array[Expr] raise SolverError {
  let out : Array[Expr] = []
  for item in items {
    guard item is Expr::Symbol(_) else {
      raise SolverError::ValueError("expected Symbol in solver API")
    }
    if !out.any(existing => @symcore.compare_expr(existing, item) == 0) {
      out.push(item)
    }
  }
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
fn expr_arrays_equal(lhs : Array[Expr], rhs : Array[Expr]) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for i in 0..<lhs.length() {
    if @symcore.compare_expr(lhs[i], rhs[i]) != 0 {
      return false
    }
  }
  true
}

///|
fn solve_result_to_multi_symbol_tuple_exprs(
  result : SolveResult,
  symbols : Array[Expr],
) -> Array[Expr]? raise SolverError {
  match result {
    SolveResult::Dict(values) =>
      match solve_result_to_tuple_set([values], symbols) {
        @symsets.Set::FiniteSet(items) => Some(items)
        _ => None
      }
    SolveResult::Dicts(items) =>
      match solve_result_to_tuple_set(items, symbols) {
        @symsets.Set::FiniteSet(items) => Some(items)
        _ => None
      }
    SolveResult::List(items) =>
      if items.all(item => @symcore.tuple_items(item) is Some(_)) {
        Some(items)
      } else {
        None
      }
  }
}

///|
fn equation_has_exact_factor(equation : Expr, factor : Expr) -> Bool {
  if expr_is_zeroish(factor) == Some(true) {
    return false
  }
  let quotient_try : Result[Expr, _] = try? canonical_expr(
    @symsimplify.ratsimp(
      canonical_expr(
        @symcore.mul([equation, @symcore.pow(factor, @symcore.int(-1))]),
      ),
      max_passes=2,
    ),
  )
  let quotient = match quotient_try {
    Ok(value) => value
    Err(_) => return false
  }
  let (_, den) = @symsimplify.fraction(quotient)
  if @symcore.compare_expr(den, @symcore.int(1)) != 0 {
    return false
  }
  let reconstructed = canonical_expr(@symcore.mul([factor, quotient]))
  @symcore.compare_expr(reconstructed, canonical_expr(equation)) == 0
}

///|
fn reduce_redundant_equations(equations : Array[Expr]) -> Array[Expr] {
  if equations.length() <= 1 {
    return equations
  }
  let keep = Array::make(equations.length(), true)
  for i in 0..<equations.length() {
    if !keep[i] {
      continue
    }
    for j in 0..<equations.length() {
      if i == j || !keep[j] {
        continue
      }
      if equation_has_exact_factor(equations[i], equations[j]) {
        keep[i] = false
        break
      }
    }
  }
  let out : Array[Expr] = []
  for i in 0..<equations.length() {
    if keep[i] {
      out.push(equations[i])
    }
  }
  out
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
    let asked = unique_symbols_in_input_order(symbols)
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
fn collect_expr_denominator_factors(expr : Expr) -> Array[Expr] {
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
fn collect_denominator_factors(expr : Expr) -> Array[Expr] {
  match @symcore.relational_parts(expr) {
    Some((_, lhs, rhs)) => {
      let out = collect_expr_denominator_factors(lhs)
      for item in collect_expr_denominator_factors(rhs) {
        if !out.any(existing => @symcore.compare_expr(existing, item) == 0) {
          out.push(item)
        }
      }
      out
    }
    None => collect_expr_denominator_factors(expr)
  }
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
fn symbolic_condition_expr_text(expr : Expr) -> String {
  match expr {
    Expr::Add(args) => {
      let positive_parts : Array[String] = []
      let negative_parts : Array[String] = []
      for arg in args {
        let text = @symprint.to_string(arg)
        if text.has_prefix("-") {
          negative_parts.push(text.unsafe_substring(start=1, end=text.length()))
        } else {
          positive_parts.push(text)
        }
      }
      if positive_parts.is_empty() || negative_parts.is_empty() {
        @symprint.to_string(expr)
      } else {
        let mut out = positive_parts.join(" + ")
        for part in negative_parts {
          out = out + " - " + part
        }
        out
      }
    }
    _ => @symprint.to_string(expr)
  }
}

///|
fn symbolic_condition_set(expr : Expr, symbol : Expr, base : Set) -> Set {
  let text = "Eq(" + symbolic_condition_expr_text(expr) + ", 0)"
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
fn lightly_normalize_expr(expr : Expr) -> Expr {
  @sympolys.domain_normal_expr(@sympolys.Domain::EX, expr) catch {
    _ => expr
  }
}

///|
fn expr_contains_abs(expr : Expr) -> Bool {
  match expr {
    Expr::Apply(Expr::FunctionHead("Abs"), [_]) => true
    _ => {
      for child in @symcore.children(expr) {
        if expr_contains_abs(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn polynomial_term_map_one(coeff : Expr) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  if expr_is_zeroish(coeff) != Some(true) {
    out[0] = coeff
  }
  out
}

///|
fn polynomial_term_map_generator() -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  out[1] = @symcore.int(1)
  out
}

///|
fn polynomial_term_map_add(
  left : Map[Int, Expr],
  right : Map[Int, Expr],
) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  for degree, coeff in left {
    if expr_is_zeroish(coeff) != Some(true) {
      out[degree] = coeff
    }
  }
  for degree, coeff in right {
    if expr_is_zeroish(coeff) == Some(true) {
      continue
    }
    match out.get(degree) {
      Some(prev) => {
        let merged = canonical_expr(@symcore.add([prev, coeff]))
        if expr_is_zeroish(merged) == Some(true) {
          ignore(out.remove(degree))
        } else {
          out[degree] = merged
        }
      }
      None => out[degree] = coeff
    }
  }
  out
}

///|
fn polynomial_term_map_mul(
  left : Map[Int, Expr],
  right : Map[Int, Expr],
) -> Map[Int, Expr] {
  let out : Map[Int, Expr] = {}
  if left.is_empty() || right.is_empty() {
    return out
  }
  for ldeg, lcoeff in left {
    if expr_is_zeroish(lcoeff) == Some(true) {
      continue
    }
    for rdeg, rcoeff in right {
      if expr_is_zeroish(rcoeff) == Some(true) {
        continue
      }
      let degree = ldeg + rdeg
      let coeff = canonical_expr(@symcore.mul([lcoeff, rcoeff]))
      if expr_is_zeroish(coeff) == Some(true) {
        continue
      }
      match out.get(degree) {
        Some(prev) => {
          let merged = canonical_expr(@symcore.add([prev, coeff]))
          if expr_is_zeroish(merged) == Some(true) {
            ignore(out.remove(degree))
          } else {
            out[degree] = merged
          }
        }
        None => out[degree] = coeff
      }
    }
  }
  out
}

///|
fn polynomial_term_map_pow(terms : Map[Int, Expr], exp : Int) -> Map[Int, Expr] {
  if exp == 0 {
    return polynomial_term_map_one(@symcore.int(1))
  }
  let mut out = polynomial_term_map_one(@symcore.int(1))
  for _ in 0..<exp {
    out = polynomial_term_map_mul(out, terms)
  }
  out
}

///|
fn polynomial_nonnegative_int_exp(expr : Expr) -> Int? {
  match expr {
    Expr::Number(n) if n.is_integral() => {
      let value = n.numerator().to_int()
      if value >= 0 {
        Some(value)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn collect_univariate_polynomial_terms(
  expr : Expr,
  symbol : Expr,
) -> Map[Int, Expr]? {
  if !@symcore.has(expr, symbol) {
    return Some(polynomial_term_map_one(expr))
  }
  if @symcore.compare_expr(expr, symbol) == 0 {
    return Some(polynomial_term_map_generator())
  }
  match expr {
    Expr::Add(args) => {
      let mut acc : Map[Int, Expr] = {}
      for arg in args {
        match collect_univariate_polynomial_terms(arg, symbol) {
          Some(terms) => acc = polynomial_term_map_add(acc, terms)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Mul(args) => {
      let mut acc = polynomial_term_map_one(@symcore.int(1))
      for arg in args {
        match collect_univariate_polynomial_terms(arg, symbol) {
          Some(terms) => acc = polynomial_term_map_mul(acc, terms)
          None => return None
        }
      }
      Some(acc)
    }
    Expr::Pow(base, exp) =>
      match polynomial_nonnegative_int_exp(exp) {
        Some(k) =>
          match collect_univariate_polynomial_terms(base, symbol) {
            Some(terms) => Some(polynomial_term_map_pow(terms, k))
            None => None
          }
        None => None
      }
    _ =>
      if !@symcore.has(expr, symbol) {
        Some(polynomial_term_map_one(expr))
      } else {
        None
      }
  }
}

///|
fn polynomial_terms_degree(terms : Map[Int, Expr]) -> Int? {
  let mut degree : Int? = None
  for exp, coeff in terms {
    if expr_is_zeroish(coeff) == Some(true) {
      continue
    }
    degree = match degree {
      Some(prev) => Some(if exp > prev { exp } else { prev })
      None => Some(exp)
    }
  }
  degree
}

///|
fn polynomial_terms_coeff(terms : Map[Int, Expr], degree : Int) -> Expr {
  terms.get(degree).unwrap_or(@symcore.int(0))
}

///|
fn solve_univariate_composite_polynomial(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set? {
  let terms = match collect_univariate_polynomial_terms(expr, symbol) {
    Some(value) => value
    None => return None
  }
  let degree = match polynomial_terms_degree(terms) {
    Some(value) => value
    None => return Some(domain)
  }
  if degree == 0 {
    return Some(
      match expr_is_zeroish(polynomial_terms_coeff(terms, 0)) {
        Some(true) => domain
        _ => @symsets.empty_set()
      },
    )
  }
  let roots : Array[Expr] = []
  if degree == 1 {
    let a = polynomial_terms_coeff(terms, 1)
    let b = polynomial_terms_coeff(terms, 0)
    if expr_is_zeroish(a) == Some(true) {
      return None
    }
    roots.push(
      canonical_expr(
        @symcore.mul([negate_expr(b), @symcore.pow(a, @symcore.int(-1))]),
      ),
    )
  } else if degree == 2 {
    let a = polynomial_terms_coeff(terms, 2)
    if expr_is_zeroish(a) == Some(true) {
      return solve_univariate_composite_polynomial(
        canonical_expr(
          @symcore.add([
            polynomial_terms_coeff(terms, 1) * symbol,
            polynomial_terms_coeff(terms, 0),
          ]),
        ),
        symbol,
        domain,
      )
    }
    let b = polynomial_terms_coeff(terms, 1)
    let c = polynomial_terms_coeff(terms, 0)
    let disc = canonical_expr(
      @symcore.add([
        b ^ @symcore.int(2),
        negate_expr(@symcore.mul([@symcore.int(4), a, c])),
      ]),
    )
    let sqrt_disc = @symcore.function("sqrt", [disc])
    let denom_inv = @symcore.pow(
      @symcore.mul([@symcore.int(2), a]),
      @symcore.int(-1),
    )
    roots.push(
      canonical_expr(
        @symcore.mul([
          @symcore.add([negate_expr(b), negate_expr(sqrt_disc)]),
          denom_inv,
        ]),
      ),
    )
    roots.push(
      canonical_expr(
        @symcore.mul([@symcore.add([negate_expr(b), sqrt_disc]), denom_inv]),
      ),
    )
  } else {
    return None
  }
  let filtered : Array[Expr] = []
  for root in roots {
    if expr_in_domain(domain, root) &&
      !filtered.any(existing => @symcore.compare_expr(existing, root) == 0) {
      filtered.push(root)
    }
  }
  Some(@symsets.finite_set(filtered))
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
              match @symassume.is_real(expr) {
                @symassume.Tri::True => true
                @symassume.Tri::False => false
                @symassume.Tri::Unknown =>
                  if !@symcore.free_symbols(expr).is_empty() {
                    true
                  } else {
                    match @symcore.evalf(expr, prec=80) {
                      Expr::Number(_) | Expr::Float(_) => true
                      Expr::ComplexFloat(value) =>
                        @symnum.is_zero(value.to_mpc().imag)
                      _ => false
                    }
                  }
              }
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
enum DomainMembership {
  In
  Out
  Unknown
}

///|
fn domain_membership_status(domain : Set, expr : Expr) -> DomainMembership {
  match domain {
    @symsets.Set::Complexes => DomainMembership::In
    _ =>
      match @symsets.contains(domain, expr) {
        @symsets.SetBool::True => DomainMembership::In
        @symsets.SetBool::False => DomainMembership::Out
        @symsets.SetBool::Unknown =>
          match domain {
            @symsets.Set::Reals =>
              match @symassume.is_real(expr) {
                @symassume.Tri::True => DomainMembership::In
                @symassume.Tri::False => DomainMembership::Out
                @symassume.Tri::Unknown =>
                  if !@symcore.free_symbols(expr).is_empty() {
                    DomainMembership::Unknown
                  } else {
                    match @symcore.evalf(expr, prec=80) {
                      Expr::Number(_) | Expr::Float(_) => DomainMembership::In
                      Expr::ComplexFloat(value) =>
                        if @symnum.is_zero(value.to_mpc().imag) {
                          DomainMembership::In
                        } else {
                          DomainMembership::Out
                        }
                      _ => DomainMembership::Unknown
                    }
                  }
              }
            @symsets.Set::Rationals =>
              match
                @symassume.tri_to_bool_option(@symassume.is_rational(expr)) {
                Some(true) => DomainMembership::In
                Some(false) => DomainMembership::Out
                None => DomainMembership::Unknown
              }
            @symsets.Set::Integers =>
              match @symassume.tri_to_bool_option(@symassume.is_integer(expr)) {
                Some(true) => DomainMembership::In
                Some(false) => DomainMembership::Out
                None => DomainMembership::Unknown
              }
            _ => DomainMembership::Unknown
          }
      }
  }
}

///|
fn finalize_finite_set_domain(domain : Set, items : Array[Expr]) -> Set {
  let accepted : Array[Expr] = []
  let unknown : Array[Expr] = []
  for item in items {
    match domain_membership_status(domain, item) {
      DomainMembership::In => expr_push_unique(accepted, item)
      DomainMembership::Out => ()
      DomainMembership::Unknown => expr_push_unique(unknown, item)
    }
  }
  let accepted_set = @symsets.finite_set(accepted)
  let unknown_set = @symsets.finite_set(unknown)
  match (accepted_set, unknown_set) {
    (@symsets.Set::EmptySet, @symsets.Set::EmptySet) => @symsets.empty_set()
    (_, @symsets.Set::EmptySet) => accepted_set
    (@symsets.Set::EmptySet, _) => @symsets.intersection([unknown_set, domain])
    _ =>
      @symsets.union([
        accepted_set,
        @symsets.intersection([unknown_set, domain]),
      ])
  }
}

///|
fn finalize_solveset_domain(domain : Set, result : Set) -> Set {
  match result {
    @symsets.Set::FiniteSet(items) => finalize_finite_set_domain(domain, items)
    _ => result
  }
}

///|
fn expr_is_known_positive(expr : Expr) -> Bool {
  @symassume.tri_to_bool_option(@symassume.is_positive(expr)).unwrap_or(false)
}

///|
fn expr_is_known_nonpositive(expr : Expr) -> Bool {
  @symassume.tri_to_bool_option(@symassume.is_nonnegative(negate_expr(expr))).unwrap_or(
    false,
  )
}

///|
fn expr_is_known_nonnegative(expr : Expr) -> Bool {
  @symassume.tri_to_bool_option(@symassume.is_nonnegative(expr)).unwrap_or(
    false,
  )
}

///|
fn expr_is_known_negative(expr : Expr) -> Bool {
  expr_is_known_positive(negate_expr(expr))
}

///|
fn bigint_pow_int(base : BigInt, exp : Int) -> BigInt {
  let mut acc = 1N
  let mut factor = base
  let mut power = exp
  while power > 0 {
    if power % 2 == 1 {
      acc = acc * factor
    }
    power = power / 2
    if power > 0 {
      factor = factor * factor
    }
  }
  acc
}

///|
fn perfect_nth_root_bigint(value : BigInt, n : Int) -> BigInt? {
  if n <= 0 {
    return None
  }
  if value.compare(0N) == 0 || n == 1 {
    return Some(value)
  }
  if value.op_lt(0N) {
    return None
  }
  let mut lo = 0N
  let mut hi = 1N
  while bigint_pow_int(hi, n).compare(value) < 0 {
    hi = hi * 2N
  }
  while lo.compare(hi) <= 0 {
    let mid = (lo + hi) >> 1
    let mid_pow = bigint_pow_int(mid, n)
    let cmp = mid_pow.compare(value)
    if cmp == 0 {
      return Some(mid)
    }
    if cmp < 0 {
      lo = mid + 1N
    } else {
      hi = mid - 1N
    }
  }
  None
}

///|
fn exact_real_numeric_pow(
  base : @symnum.BigRational,
  exp_num : BigInt,
  exp_den : BigInt,
) -> Expr? {
  if exp_den.compare(0N) <= 0 || exp_num.compare(0N) == 0 {
    return None
  }
  if exp_num.bit_length() > 30 || exp_den.bit_length() > 30 {
    return None
  }
  let p = exp_num.to_int()
  let q = exp_den.to_int()
  let negative = base.compare(@symnum.BigRational::zero()) < 0
  if negative && q % 2 == 0 {
    return None
  }
  let abs_base = if negative { base.neg_r() } else { base }
  let num_root = match perfect_nth_root_bigint(abs_base.numerator(), q) {
    Some(root) => root
    None => return None
  }
  let den_root = match perfect_nth_root_bigint(abs_base.denominator(), q) {
    Some(root) => root
    None => return None
  }
  let mut rat = @symnum.BigRational::new(num_root, den_root) catch {
    _ => return None
  }
  let abs_p = if p < 0 { -p } else { p }
  let pow_num = bigint_pow_int(rat.numerator(), abs_p)
  let pow_den = bigint_pow_int(rat.denominator(), abs_p)
  rat = @symnum.BigRational::new(pow_num, pow_den) catch { _ => return None }
  if p < 0 {
    rat = rat.reciprocal() catch { _ => return None }
  }
  if negative && p % 2 != 0 {
    rat = rat.neg_r()
  }
  Some(Expr::Number(rat))
}

///|
fn real_root_inversion_expr(rhs : Expr, reciprocal : Expr) -> Expr {
  match (rhs, @symcore.exact_numeric_expr_num_den(reciprocal)) {
    (Expr::Number(base), Some((num, den))) =>
      match exact_real_numeric_pow(base, num, den) {
        Some(value) => value
        None => canonical_expr(@symcore.pow(rhs, reciprocal))
      }
    _ => canonical_expr(@symcore.pow(rhs, reciprocal))
  }
}

///|
fn exact_positive_integer_expr(expr : Expr) -> BigInt? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) =>
      if num.compare(0N) > 0 && den.compare(1N) == 0 {
        Some(num)
      } else {
        None
      }
    None => None
  }
}

///|
fn exact_integer_expr(expr : Expr) -> BigInt? {
  match @symcore.exact_numeric_expr_num_den(expr) {
    Some((num, den)) if den.compare(1N) == 0 => Some(num)
    _ => None
  }
}

///|
fn bigint_abs(value : BigInt) -> BigInt {
  if value.compare(0N) < 0 {
    -value
  } else {
    value
  }
}

///|
fn integer_log_exact(value : BigInt, base : BigInt) -> BigInt? {
  if base.compare(0N) == 0 || base.compare(1N) == 0 || base.compare(-1N) == 0 {
    return None
  }
  if value.compare(1N) == 0 {
    return Some(0N)
  }
  let abs_base = bigint_abs(base)
  let abs_value = bigint_abs(value)
  if abs_value.compare(0N) == 0 {
    return None
  }
  let mut exponent = 0N
  let mut reduced = abs_value
  while reduced.mod(abs_base).compare(0N) == 0 {
    reduced = reduced.div(abs_base)
    exponent = exponent + 1N
  }
  if reduced.compare(1N) != 0 {
    return None
  }
  if base.compare(0N) > 0 {
    return if value.compare(0N) > 0 { Some(exponent) } else { None }
  }
  let is_even = exponent.mod(2N).compare(0N) == 0
  if value.compare(0N) > 0 {
    if is_even {
      Some(exponent)
    } else {
      None
    }
  } else if value.compare(0N) < 0 {
    if is_even {
      None
    } else {
      Some(exponent)
    }
  } else {
    None
  }
}

///|
fn real_log_inversion_expr(rhs : Expr, base : Expr) -> Expr {
  match (exact_positive_integer_expr(rhs), exact_positive_integer_expr(base)) {
    (Some(rhs_int), Some(base_int)) if base_int.compare(1N) > 0 => {
      let mut exponent = 0N
      let mut reduced = rhs_int
      while reduced.mod(base_int).compare(0N) == 0 {
        reduced = reduced.div(base_int)
        exponent = exponent.add(1N)
      }
      let base_log_inv = @symcore.pow(
        @symcore.function("log", [base]),
        @symcore.int(-1),
      )
      let fallback = canonical_expr(
        @symcore.mul([@symcore.function("log", [rhs]), base_log_inv]),
      )
      let exponent_rat_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
        exponent, 1N,
      )
      let exponent_expr = match exponent_rat_res {
        Ok(value) => Expr::Number(value)
        Err(_) => return fallback
      }
      if exponent.compare(0N) == 0 {
        fallback
      } else if reduced.compare(1N) == 0 {
        exponent_expr
      } else {
        let reduced_rat_res : Result[@symnum.BigRational, @symnum.RationalError] = try? @symnum.BigRational::new(
          reduced, 1N,
        )
        let reduced_expr = match reduced_rat_res {
          Ok(value) => Expr::Number(value)
          Err(_) => return fallback
        }
        canonical_expr(
          @symcore.add([
            exponent_expr,
            @symcore.mul([
              @symcore.function("log", [reduced_expr]),
              base_log_inv,
            ]),
          ]),
        )
      }
    }
    _ =>
      canonical_expr(
        @symcore.mul([
          @symcore.function("log", [rhs]),
          @symcore.pow(@symcore.function("log", [base]), @symcore.int(-1)),
        ]),
      )
  }
}

///|
fn expr_push_unique(items : Array[Expr], expr : Expr) -> Unit {
  if !items.any(existing => @symcore.compare_expr(existing, expr) == 0) {
    items.push(expr)
  }
}

///|
fn solveset_symbol_core(expr : Expr, symbol : Expr) -> Expr {
  let mut current = expr
  match add_independent_decompose(current, symbol) {
    Some((_, dep)) => current = dep
    None => ()
  }
  match mul_independent_decompose(current, symbol) {
    Some((_, dep)) => current = dep
    None => ()
  }
  current
}

///|
fn expr_has_obvious_nonfinite_value(expr : Expr) -> Bool {
  if @symcore.is_infinite(expr) || @symcore.is_nan(expr) {
    return true
  }
  match expr {
    Expr::Mul(args) => {
      let mut has_infinite_factor = false
      let mut has_zero_factor = false
      for arg in args {
        if @symcore.is_infinite(arg) || @symcore.is_nan(arg) {
          has_infinite_factor = true
        }
        if @symcore.is_zero(arg) {
          has_zero_factor = true
        }
      }
      if has_infinite_factor && has_zero_factor {
        true
      } else {
        args.any(expr_has_obvious_nonfinite_value)
      }
    }
    Expr::Apply(Expr::FunctionHead("log"), [arg])
    | Expr::Apply(Expr::UndefinedFunction("log"), [arg]) =>
      if @symcore.compare_expr(arg, @symcore.int(0)) == 0 {
        true
      } else {
        expr_has_obvious_nonfinite_value(arg)
      }
    Expr::Pow(base, exp) =>
      if @symcore.is_zero(base) {
        match @symcore.exact_numeric_expr_num_den(exp) {
          Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) < 0 =>
            true
          _ =>
            expr_has_obvious_nonfinite_value(base) ||
            expr_has_obvious_nonfinite_value(exp)
        }
      } else {
        expr_has_obvious_nonfinite_value(base) ||
        expr_has_obvious_nonfinite_value(exp)
      }
    _ => {
      for child in @symcore.children(expr) {
        if expr_has_obvious_nonfinite_value(child) {
          return true
        }
      }
      false
    }
  }
}

///|
fn expr_has_obvious_nonfinite_under_subst(
  expr : Expr,
  env : Map[String, Expr],
) -> Bool {
  let substituted = @symcore.subst(expr, env)
  if @symcore.is_infinite(substituted) || @symcore.is_nan(substituted) {
    return true
  }
  match expr {
    Expr::Mul(args) => {
      let substituted_args = args.map(arg => @symcore.subst(arg, env))
      let has_infinite_factor = substituted_args.any(arg => {
        @symcore.is_infinite(arg) || @symcore.is_nan(arg)
      })
      let has_zero_factor = substituted_args.any(@symcore.is_zero)
      if has_infinite_factor && has_zero_factor {
        return true
      }
      args.any(arg => expr_has_obvious_nonfinite_under_subst(arg, env))
    }
    Expr::Apply(Expr::FunctionHead("log"), [arg])
    | Expr::Apply(Expr::UndefinedFunction("log"), [arg]) => {
      let substituted_arg = @symcore.subst(arg, env)
      if @symcore.compare_expr(substituted_arg, @symcore.int(0)) == 0 {
        true
      } else {
        expr_has_obvious_nonfinite_under_subst(arg, env)
      }
    }
    Expr::Pow(base, exp) => {
      let substituted_base = @symcore.subst(base, env)
      if @symcore.is_zero(substituted_base) {
        match @symcore.exact_numeric_expr_num_den(@symcore.subst(exp, env)) {
          Some((num, den)) if den.compare(1N) == 0 && num.compare(0N) < 0 =>
            true
          _ =>
            expr_has_obvious_nonfinite_under_subst(base, env) ||
            expr_has_obvious_nonfinite_under_subst(exp, env)
        }
      } else {
        expr_has_obvious_nonfinite_under_subst(base, env) ||
        expr_has_obvious_nonfinite_under_subst(exp, env)
      }
    }
    _ =>
      @symcore.children(expr).any(child => {
        expr_has_obvious_nonfinite_under_subst(child, env)
      })
  }
}

///|
fn solveset_domain_check(
  expr : Expr,
  symbol : Expr,
  candidate : Expr,
) -> Bool raise SolverError {
  if @symcore.is_infinite(candidate) || @symcore.is_nan(candidate) {
    return false
  }
  let name = symbol_name(symbol)
  let env : Map[String, Expr] = {}
  env[name] = candidate
  let core = expr
  fn check(current : Expr, env : Map[String, Expr], symbol : Expr) -> Bool {
    if !@symcore.has(current, symbol) {
      return true
    }
    if expr_has_obvious_nonfinite_under_subst(current, env) {
      return false
    }
    let substituted_raw = @symcore.subst(current, env)
    let substituted = canonical_expr(substituted_raw)
    if @symcore.is_infinite(substituted) || @symcore.is_nan(substituted) {
      return false
    }
    if @symcore.free_symbols(substituted).is_empty() {
      if expr_has_obvious_nonfinite_value(substituted) {
        return false
      }
    }
    for child in @symcore.children(current) {
      if !check(child, env, symbol) {
        return false
      }
    }
    true
  }
  check(core, env, symbol)
}

///|
fn valid_solution_for_expr(
  expr : Expr,
  symbol : Expr,
  candidate : Expr,
  domain : Set,
) -> Bool raise SolverError {
  let normalized = canonical_expr(candidate)
  if !expr_in_domain(domain, normalized) {
    return false
  }
  if !solveset_domain_check(expr, symbol, normalized) {
    return false
  }
  match checksol(expr, symbol, normalized) {
    Some(true) => true
    Some(false) => false
    None => {
      let env : Map[String, Expr] = {}
      env[symbol_name(symbol)] = normalized
      let residual = canonical_expr(
        @symcore.subst(normalize_equation(expr), env),
      )
      if @symcore.compare_expr(residual, @symcore.int(0)) == 0 ||
        @symcore.is_zero(residual) {
        true
      } else {
        let simplified = @symsimplify.simplify(residual)
        if @symcore.compare_expr(simplified, @symcore.int(0)) == 0 ||
          @symcore.is_zero(simplified) {
          true
        } else {
          !@symcore.free_symbols(normalized).is_empty()
        }
      }
    }
  }
}

///|
fn exclude_relational_singularities(
  expr : Expr,
  symbol : Expr,
  domain : Set,
  set : Set,
) -> Set {
  let dens = collect_denominator_factors(expr)
  if dens.is_empty() {
    return set
  }
  let invalid_parts : Array[Set] = []
  for factor in dens {
    let part_res : Result[Set, SolverError] = try? solveset(
      factor,
      symbol=Some(symbol),
      domain~,
    )
    match part_res {
      Ok(part) => invalid_parts.push(part)
      Err(_) => ()
    }
  }
  if invalid_parts.is_empty() {
    return set
  }
  let invalid = @symsets.union(invalid_parts)
  solver_set_difference(set, invalid)
}

///|
fn add_expr_items(items : Array[Expr]) -> Expr {
  if items.is_empty() {
    @symcore.int(0)
  } else if items.length() == 1 {
    items[0]
  } else {
    canonical_expr(@symcore.add(items))
  }
}

///|
fn mul_expr_items(items : Array[Expr]) -> Expr {
  if items.is_empty() {
    @symcore.int(1)
  } else if items.length() == 1 {
    items[0]
  } else {
    canonical_expr(@symcore.mul(items))
  }
}

///|
fn add_independent_decompose(expr : Expr, symbol : Expr) -> (Expr, Expr)? {
  match expr {
    Expr::Add(args) => {
      let indep : Array[Expr] = []
      let dep : Array[Expr] = []
      for arg in args {
        if @symcore.has(arg, symbol) {
          dep.push(arg)
        } else {
          indep.push(arg)
        }
      }
      if indep.is_empty() || dep.is_empty() {
        None
      } else {
        Some((add_expr_items(indep), add_expr_items(dep)))
      }
    }
    _ => None
  }
}

///|
fn mul_independent_decompose(expr : Expr, symbol : Expr) -> (Expr, Expr)? {
  match expr {
    Expr::Mul(args) => {
      let indep : Array[Expr] = []
      let dep : Array[Expr] = []
      for arg in args {
        if @symcore.has(arg, symbol) {
          dep.push(arg)
        } else {
          indep.push(arg)
        }
      }
      if indep.is_empty() || dep.is_empty() {
        None
      } else {
        Some((mul_expr_items(indep), mul_expr_items(dep)))
      }
    }
    _ => None
  }
}

///|
fn invert_real_expr(
  expr : Expr,
  rhs_items : Array[Expr],
  symbol : Expr,
) -> (Expr, Array[Expr]) {
  let normalized = canonical_expr(expr)
  if rhs_items.is_empty() || @symcore.compare_expr(normalized, symbol) == 0 {
    return (normalized, rhs_items)
  }

  match add_independent_decompose(normalized, symbol) {
    Some((g, h)) => {
      let shifted : Array[Expr] = []
      for rhs in rhs_items {
        shifted.push(canonical_expr(@symcore.add([rhs, negate_expr(g)])))
      }
      return invert_real_expr(h, shifted, symbol)
    }
    None => ()
  }

  match mul_independent_decompose(normalized, symbol) {
    Some((g, h)) => {
      let shifted : Array[Expr] = []
      for rhs in rhs_items {
        shifted.push(
          canonical_expr(@symcore.mul([rhs, @symcore.pow(g, @symcore.int(-1))])),
        )
      }
      return invert_real_expr(h, shifted, symbol)
    }
    None => ()
  }

  match normalized {
    Expr::Apply(Expr::FunctionHead("exp"), [arg]) => {
      let shifted : Array[Expr] = []
      for rhs in rhs_items {
        if expr_is_known_nonpositive(rhs) {
          return (arg, [])
        } else {
          shifted.push(canonical_expr(@symcore.function("log", [rhs])))
        }
      }
      return invert_real_expr(arg, shifted, symbol)
    }
    Expr::Apply(Expr::FunctionHead("log"), [arg]) => {
      let shifted : Array[Expr] = []
      for rhs in rhs_items {
        shifted.push(canonical_expr(@symcore.function("exp", [rhs])))
      }
      return invert_real_expr(arg, shifted, symbol)
    }
    Expr::Apply(Expr::FunctionHead("Abs"), [arg]) => {
      let shifted : Array[Expr] = []
      for rhs in rhs_items {
        if !expr_is_known_nonnegative(rhs) {
          return if expr_is_known_nonpositive(rhs) {
            (arg, [])
          } else {
            (normalized, rhs_items)
          }
        }
        let value = canonical_expr(rhs)
        expr_push_unique(shifted, value)
        expr_push_unique(shifted, canonical_expr(negate_expr(value)))
      }
      return invert_real_expr(arg, shifted, symbol)
    }
    Expr::Apply(Expr::FunctionHead("sqrt"), [arg]) => {
      let shifted : Array[Expr] = []
      for rhs in rhs_items {
        if expr_is_known_nonnegative(rhs) {
          shifted.push(canonical_expr(rhs ^ @symcore.int(2)))
        } else if expr_is_known_nonpositive(rhs) {
          return (arg, [])
        } else {
          return (normalized, rhs_items)
        }
      }
      return invert_real_expr(arg, shifted, symbol)
    }
    Expr::Pow(base, exp) => {
      let base_has_symbol = @symcore.has(base, symbol)
      let exp_has_symbol = @symcore.has(exp, symbol)
      if base_has_symbol && !exp_has_symbol {
        match @symcore.exact_numeric_expr_num_den(exp) {
          Some((num, den)) => {
            if num.compare(0N) == 0 || den.compare(0N) == 0 {
              return (normalized, rhs_items)
            }
            let reciprocal = Expr::Number(
              @symnum.BigRational::new(den, num) catch {
                _ => return (normalized, rhs_items)
              },
            )
            let shifted : Array[Expr] = []
            if den.mod(2N).is_zero() && !num.mod(2N).is_zero() {
              for rhs in rhs_items {
                if expr_is_known_nonnegative(rhs) {
                  shifted.push(real_root_inversion_expr(rhs, reciprocal))
                } else if expr_is_known_nonpositive(rhs) {
                  return (base, [])
                } else {
                  return (normalized, rhs_items)
                }
              }
              return invert_real_expr(base, shifted, symbol)
            }
            if !den.mod(2N).is_zero() {
              for rhs in rhs_items {
                let root = real_root_inversion_expr(rhs, reciprocal)
                shifted.push(root)
                if num.mod(2N).is_zero() {
                  shifted.push(canonical_expr(negate_expr(root)))
                }
              }
              return invert_real_expr(base, shifted, symbol)
            }
          }
          None => ()
        }
      }
      if !base_has_symbol && exp_has_symbol && expr_is_known_positive(base) {
        let shifted : Array[Expr] = []
        for rhs in rhs_items {
          if expr_is_known_positive(rhs) {
            shifted.push(real_log_inversion_expr(rhs, base))
          } else if expr_is_known_nonpositive(rhs) {
            return (exp, [])
          } else {
            shifted.push(real_log_inversion_expr(rhs, base))
          }
        }
        return invert_real_expr(exp, shifted, symbol)
      }
      if !base_has_symbol && exp_has_symbol {
        match exact_integer_expr(base) {
          Some(base_int) if base_int.compare(0N) < 0 => {
            let shifted : Array[Expr] = []
            for rhs in rhs_items {
              match exact_integer_expr(rhs) {
                Some(rhs_int) =>
                  match integer_log_exact(rhs_int, base_int) {
                    Some(power) => {
                      let power_rat_res : Result[
                        @symnum.BigRational,
                        @symnum.RationalError,
                      ] = try? @symnum.BigRational::new(power, 1N)
                      let power_expr = match power_rat_res {
                        Ok(value) => Expr::Number(value)
                        Err(_) => return (normalized, rhs_items)
                      }
                      shifted.push(power_expr)
                    }
                    None => return (exp, [])
                  }
                None => return (normalized, rhs_items)
              }
            }
            return invert_real_expr(exp, shifted, symbol)
          }
          _ => ()
        }
      }
      if !base_has_symbol &&
        exp_has_symbol &&
        @symcore.compare_expr(base, @symcore.int(0)) == 0 {
        let shifted : Array[Expr] = []
        for rhs in rhs_items {
          let one_eq = @symcore.compare_expr(rhs, @symcore.int(1)) == 0
          if !one_eq {
            return (exp, [])
          }
          shifted.push(@symcore.int(0))
        }
        return invert_real_expr(exp, shifted, symbol)
      }
    }
    _ => ()
  }

  (normalized, rhs_items)
}

///|
fn flip_relop(op : @symcore.RelOp) -> @symcore.RelOp {
  match op {
    @symcore.RelOp::Lt => @symcore.RelOp::Gt
    @symcore.RelOp::Le => @symcore.RelOp::Ge
    @symcore.RelOp::Gt => @symcore.RelOp::Lt
    @symcore.RelOp::Ge => @symcore.RelOp::Le
    other => other
  }
}

///|
fn invert_real_relational_monotonic(
  expr : Expr,
  rhs : Expr,
  symbol : Expr,
  op : @symcore.RelOp,
) -> (Expr, Expr, @symcore.RelOp)? {
  let normalized = canonical_expr(expr)
  if @symcore.compare_expr(normalized, symbol) == 0 {
    return Some((normalized, canonical_expr(rhs), op))
  }

  match add_independent_decompose(normalized, symbol) {
    Some((g, h)) =>
      return invert_real_relational_monotonic(
        h,
        canonical_expr(@symcore.add([rhs, negate_expr(g)])),
        symbol,
        op,
      )
    None => ()
  }

  match mul_independent_decompose(normalized, symbol) {
    Some((g, h)) =>
      if expr_is_known_positive(g) {
        return invert_real_relational_monotonic(
          h,
          canonical_expr(@symcore.mul([rhs, @symcore.pow(g, @symcore.int(-1))])),
          symbol,
          op,
        )
      } else if expr_is_known_negative(g) {
        return invert_real_relational_monotonic(
          h,
          canonical_expr(@symcore.mul([rhs, @symcore.pow(g, @symcore.int(-1))])),
          symbol,
          flip_relop(op),
        )
      }
    None => ()
  }

  match normalized {
    Expr::Apply(Expr::FunctionHead("log"), [arg]) =>
      return invert_real_relational_monotonic(
        arg,
        canonical_expr(@symcore.function("exp", [rhs])),
        symbol,
        op,
      )
    Expr::Apply(Expr::FunctionHead("exp"), [arg]) =>
      if expr_is_known_positive(rhs) {
        return invert_real_relational_monotonic(
          arg,
          canonical_expr(@symcore.function("log", [rhs])),
          symbol,
          op,
        )
      }
    _ => ()
  }

  None
}

///|
fn relational_bound_set(op : @symcore.RelOp, bound : Expr) -> Set {
  let inf = Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
  let ninf = Expr::NumberSymbol(@symcore.NumberSymbolKind::NegativeInfinity)
  match op {
    @symcore.RelOp::Lt =>
      @symsets.interval(ninf, bound, left_open=true, right_open=true)
    @symcore.RelOp::Le =>
      @symsets.interval(ninf, bound, left_open=true, right_open=false)
    @symcore.RelOp::Gt =>
      @symsets.interval(bound, inf, left_open=true, right_open=true)
    @symcore.RelOp::Ge =>
      @symsets.interval(bound, inf, left_open=false, right_open=true)
    @symcore.RelOp::Eq => @symsets.finite_set([bound])
    @symcore.RelOp::Ne =>
      @symsets.complement(@symsets.reals(), @symsets.finite_set([bound]))
  }
}

///|
fn solve_monotonic_relational_set(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set? {
  match @symcore.relational_parts(expr) {
    Some((op, lhs, rhs)) => {
      let target = canonical_expr(@symcore.add([lhs, negate_expr(rhs)]))
      match
        invert_real_relational_monotonic(target, @symcore.int(0), symbol, op) {
        Some((lhs, bound, solved_op)) if @symcore.compare_expr(lhs, symbol) == 0 =>
          Some(
            finalize_solveset_domain(
              domain,
              solver_set_intersection(
                relational_bound_set(solved_op, bound),
                domain,
              ),
            ),
          )
        _ => None
      }
    }
    None => None
  }
}

///|
fn solve_via_rational_expr(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set? raise SolverError {
  let normalized = normalize_equation(expr)
  let rational = canonical_expr(@symsimplify.ratsimp(normalized, max_passes=4))
  let (num, den) = @symsimplify.fraction(rational)
  if @symcore.compare_expr(den, @symcore.int(1)) == 0 ||
    !@symcore.has(den, symbol) {
    return None
  }
  let valid_set = solveset(num, symbol=Some(symbol), domain~)
  let valid_roots = match finite_set_items(valid_set) {
    Some(items) => items
    None => return None
  }
  let invalid_set = solveset(den, symbol=Some(symbol), domain~)
  let invalid_roots = match finite_set_items(invalid_set) {
    Some(items) => items
    None => []
  }
  let filtered : Array[Expr] = []
  for root in valid_roots {
    let candidate = canonical_expr(root)
    let is_invalid = invalid_roots.any(bad => {
      @symcore.compare_expr(candidate, canonical_expr(bad)) == 0
    })
    if !is_invalid &&
      valid_solution_for_expr(normalized, symbol, candidate, domain) {
      expr_push_unique(filtered, candidate)
    }
  }
  Some(@symsets.finite_set(filtered))
}

///|
fn solve_via_product_expr(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set? raise SolverError {
  let raw = normalize_equation(expr)
  guard raw is Expr::Mul(raw_args) else { return None }
  let dependent : Array[Expr] = []
  for arg in raw_args {
    if @symcore.has(arg, symbol) {
      dependent.push(arg)
    }
  }
  if dependent.length() <= 1 {
    return None
  }
  let normalized = canonical_expr(raw)
  let factors = match normalized {
    Expr::Mul(args) => args
    _ => dependent
  }
  let collected : Array[Expr] = []
  for factor in factors {
    if !@symcore.has(factor, symbol) {
      continue
    }
    let factor_set = solveset(factor, symbol=Some(symbol), domain~)
    let factor_items = match finite_set_items(factor_set) {
      Some(items) => items
      None => return None
    }
    for item in factor_items {
      let candidate = canonical_expr(item)
      if valid_solution_for_expr(raw, symbol, candidate, domain) {
        expr_push_unique(collected, candidate)
      }
    }
  }
  Some(@symsets.finite_set(collected))
}

///|
fn solve_via_invert_real(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set? raise SolverError {
  let (lhs, rhs_items) = invert_real_expr(
    normalize_equation(expr),
    [@symcore.int(0)],
    symbol,
  )
  if rhs_items.is_empty() {
    return Some(@symsets.empty_set())
  }
  if @symcore.compare_expr(lhs, symbol) != 0 {
    return None
  }
  let filtered : Array[Expr] = []
  for rhs in rhs_items {
    let candidate = canonical_expr(rhs)
    if valid_solution_for_expr(
        normalize_equation(expr),
        symbol,
        candidate,
        domain,
      ) {
      expr_push_unique(filtered, candidate)
    }
  }
  Some(@symsets.finite_set(filtered))
}

///|
fn solve_via_abs_expr(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set? raise SolverError {
  match @symsets.is_subset(domain, @symsets.reals()) {
    @symsets.SetBool::True => ()
    _ => return None
  }
  if !expr_contains_abs(expr) {
    return None
  }
  let terms = match canonical_expr(normalize_equation(expr)) {
    Expr::Add(args) => args
    other => [other]
  }
  let mut abs_coeff : Expr? = None
  let mut abs_arg : Expr? = None
  let rest : Array[Expr] = []
  for term in terms {
    match solver_single_abs_term(term) {
      Some((coeff, arg)) if abs_coeff is None => {
        abs_coeff = Some(coeff)
        abs_arg = Some(arg)
      }
      _ => rest.push(term)
    }
  }
  guard abs_coeff is Some(coeff) && abs_arg is Some(arg) else { return None }
  if @symcore.compare_expr(coeff, @symcore.int(0)) == 0 ||
    @symcore.compare_expr(arg, @symcore.int(0)) == 0 {
    return None
  }
  let q_pos_cond = match
    (
      try? solve_univariate_inequality(
        Expr::Relational(@symcore.RelOp::Ge, arg, @symcore.int(0)),
        symbol,
        relational=false,
        domain~,
      ) : Result[InequalityResult, SolverError]) {
    Ok(InequalityResult::Set(set)) => set
    Ok(_) => domain
    Err(_) => return None
  }
  let q_neg_cond = match
    (
      try? solve_univariate_inequality(
        Expr::Relational(@symcore.RelOp::Lt, arg, @symcore.int(0)),
        symbol,
        relational=false,
        domain~,
      ) : Result[InequalityResult, SolverError]) {
    Ok(InequalityResult::Set(set)) => set
    Ok(_) => @symsets.empty_set()
    Err(_) => return None
  }
  let pos_expr = canonical_expr(
    solver_add_all([@symcore.mul([coeff, arg]), solver_add_all(rest)]),
  )
  let neg_expr = canonical_expr(
    solver_add_all([
      @symcore.mul([coeff, negate_expr(arg)]),
      solver_add_all(rest),
    ]),
  )
  let sols_q_pos = @symsets.intersection([
    solveset(pos_expr, symbol=Some(symbol), domain~),
    q_pos_cond,
  ])
  let sols_q_neg = @symsets.intersection([
    solveset(neg_expr, symbol=Some(symbol), domain~),
    q_neg_cond,
  ])
  Some(@symsets.union([sols_q_pos, sols_q_neg]))
}

///|
fn solve_univariate_polynomial(
  expr : Expr,
  symbol : Expr,
  domain : Set,
) -> Set raise SolverError {
  let normalized = normalize_equation(expr)
  match solve_univariate_composite_polynomial(normalized, symbol, domain) {
    Some(set) => return set
    None => ()
  }
  let name = symbol_name(symbol)
  let poly_result : Result[@sympolys.Poly, @sympolys.PolyError] = try? @sympolys.Poly::from_expr_defaults(
    normalized,
    gens=[name],
  )
  let roots = match poly_result {
    Ok(poly) =>
      @sympolys.roots(poly) catch {
        err => raise wrap_poly_error("solveset", err)
      }
    Err(err) =>
      match solve_univariate_composite_polynomial(normalized, symbol, domain) {
        Some(set) => return set
        None => raise wrap_poly_error("solveset", err)
      }
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
fn solve_univariate_polynomial_from_poly(
  poly : @sympolys.Poly,
  domain : Set,
) -> Set raise SolverError {
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
  let linear_matrix_try : Result[(Matrix, Matrix), SolverError] = try? linear_eq_to_matrix(
    live_eqs, symbols,
  )
  match linear_matrix_try {
    Ok((lhs, rhs)) => {
      let symbolic = symbolic_linsolve_from_matrices(lhs, rhs, symbols, names)
      return match symbolic {
        Some(sol) => [merge_assignments(assignment, sol)]
        None => []
      }
    }
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
  match @symcore.relational_parts(expr) {
    Some((@symcore.RelOp::Ge, _, _))
    | Some((@symcore.RelOp::Gt, _, _))
    | Some((@symcore.RelOp::Le, _, _))
    | Some((@symcore.RelOp::Lt, _, _))
    | Some((@symcore.RelOp::Ne, _, _)) => {
      let inequality_res : Result[InequalityResult, SolverError] = try? solve_univariate_inequality(
        expr,
        sym,
        relational=false,
        domain~,
      )
      match inequality_res {
        Ok(InequalityResult::Set(set)) =>
          return exclude_relational_singularities(expr, sym, domain, set)
        _ =>
          match solve_monotonic_relational_set(expr, sym, domain) {
            Some(set) =>
              return exclude_relational_singularities(expr, sym, domain, set)
            None => ()
          }
      }
    }
    _ => ()
  }
  let raw_normalized = normalize_equation(expr)
  let normalized = lightly_normalize_expr(raw_normalized)
  let free = filtered_symbols(@symcore.free_symbols(normalized), [], [])
  if !expr_in_list(free, sym) {
    let simplified = canonical_expr(normalized)
    return match expr_is_zeroish(simplified) {
      Some(true) => domain
      _ => @symsets.empty_set()
    }
  }
  match solve_via_product_expr(raw_normalized, sym, domain) {
    Some(set) => return finalize_solveset_domain(domain, set)
    None => ()
  }
  match solve_via_abs_expr(raw_normalized, sym, domain) {
    Some(set) => return finalize_solveset_domain(domain, set)
    None => ()
  }
  let poly_name = symbol_name(sym)
  let poly_fast : Result[@sympolys.Poly, @sympolys.PolyError] = try? @sympolys.Poly::from_expr_defaults(
    normalized,
    gens=[poly_name],
  )
  match poly_fast {
    Ok(poly) if poly.degree(0) > 2 => {
      let set = solve_univariate_polynomial_from_poly(poly, domain)
      return finalize_solveset_domain(domain, set)
    }
    _ => ()
  }
  let linear = solve_linear(normalized, symbols=[sym], exclude=[])
  if @symcore.compare_expr(linear.0, sym) == 0 {
    let value = linear.1
    if valid_solution_for_expr(expr, sym, value, domain) {
      return finalize_solveset_domain(domain, @symsets.finite_set([value]))
    } else {
      return @symsets.empty_set()
    }
  }
  match solve_via_rational_expr(raw_normalized, sym, domain) {
    Some(set) => return finalize_solveset_domain(domain, set)
    None => ()
  }
  if domain == @symsets.reals() {
    match solve_via_invert_real(raw_normalized, sym, domain) {
      Some(set) => return finalize_solveset_domain(domain, set)
      None => ()
    }
  }
  let poly_try : Result[Set, SolverError] = try? solve_univariate_polynomial(
    normalized, sym, domain,
  )
  match poly_try {
    Ok(set) => finalize_solveset_domain(domain, set)
    Err(_) => symbolic_condition_set(normalized, sym, domain)
  }
}

///|
pub fn nonlinsolve(
  equations : Array[Expr],
  symbols : Array[Expr],
) -> Set raise SolverError {
  let syms = unique_symbols_in_input_order(symbols)
  let names = symbol_names(syms)
  let normalized = normalize_equations(equations)
  let linear_try : Result[Map[String, Expr]?, @sympolys.PolyError] = try? @sympolys._linsolve(
    normalized, names,
  )
  match linear_try {
    Ok(solution) => return tuple_solution_set(solution, syms, names)
    Err(_) => ()
  }
  let linear_matrix_try : Result[(Matrix, Matrix), SolverError] = try? linear_eq_to_matrix(
    normalized, syms,
  )
  match linear_matrix_try {
    Ok((lhs, rhs)) => {
      let symbolic = symbolic_linsolve_from_matrices(lhs, rhs, syms, names)
      return tuple_solution_set(symbolic, syms, names)
    }
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
fn solve_expr_has_float_leaf(expr : Expr) -> Bool {
  for node in @symcore.preorder(expr) {
    match node {
      Expr::Float(_) | Expr::ComplexFloat(_) => return true
      _ => ()
    }
  }
  false
}

///|
fn solve_expr_has_noninteger_rational_power(expr : Expr) -> Bool {
  for node in @symcore.preorder(expr) {
    match node {
      Expr::Apply(Expr::FunctionHead("sqrt"), _) => return true
      Expr::Apply(Expr::UndefinedFunction("sqrt"), _) => return true
      Expr::Pow(_, exp) =>
        match @symcore.exact_numeric_expr_num_den(exp) {
          Some((_, den)) if den.compare(1N) != 0 => return true
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn solve_floatify_expr(expr : Expr, preserve_float_context : Bool) -> Expr {
  if !preserve_float_context {
    return expr
  }
  match expr {
    Expr::Number(value) => {
      let approx : Result[@symcore.Float, _] = try? @symcore.Float::from_exact(
        value,
        prec=53,
      )
      match approx {
        Ok(float_value) => Expr::Float(float_value)
        Err(_) => @symcore.evalf(expr, prec=53)
      }
    }
    _ => expr
  }
}

///|
fn solve_coefficient_match_equations(
  equations : Array[Expr],
  requested : Array[Expr],
) -> Array[Expr]? raise SolverError {
  if equations.length() != 1 || requested.length() <= 1 {
    return None
  }
  let extras = filtered_symbols(
    @symcore.free_symbols(equations[0]),
    [],
    requested,
  )
  let normalized = canonical_expr(equations[0])
  for extra in extras {
    let terms = match collect_univariate_polynomial_terms(normalized, extra) {
      Some(value) => value
      None => continue
    }
    let degrees : Array[Int] = []
    for degree, coeff in terms {
      if expr_is_zeroish(coeff) != Some(true) {
        degrees.push(degree)
      }
    }
    if degrees.length() <= 1 {
      continue
    }
    degrees.sort()
    let coeff_eqs : Array[Expr] = []
    let mut valid = true
    for degree in degrees {
      let coeff = terms.get(degree).unwrap_or(@symcore.int(0))
      if expr_is_zeroish(coeff) != Some(true) {
        let normalized_coeff = canonical_expr(coeff)
        let coeff_syms = @symcore.free_symbols(normalized_coeff)
        if !requested.any(sym => expr_in_list(coeff_syms, sym)) {
          valid = false
          break
        }
        coeff_eqs.push(normalized_coeff)
      }
    }
    if valid && coeff_eqs.length() > 1 {
      return Some(coeff_eqs)
    }
  }
  None
}

///|
fn explicit_multi_symbol_solution_needs_tuples(
  items : Array[Expr],
  requested : Array[Expr],
) -> Bool {
  if items.length() != 1 {
    return true
  }
  match @symcore.tuple_items(items[0]) {
    Some(values) => {
      for i in 0..<requested.length() {
        let value = values.get(i).unwrap_or(requested[i])
        if @symcore.compare_expr(value, requested[i]) == 0 {
          return true
        }
        for symbol in requested {
          if @symcore.has(value, symbol) {
            return true
          }
        }
      }
      false
    }
    None => true
  }
}

///|
fn solve_factored_system_fallback(
  equations : Array[Expr],
  requested : Array[Expr],
) -> Set? raise SolverError {
  if requested.length() <= 1 || equations.length() <= 1 {
    return None
  }
  let systems_try : Result[Array[Array[Expr]], SolverError] = try? factor_system(
    equations,
    gens=requested,
  )
  let systems = match systems_try {
    Ok(value) => value
    Err(_) => return None
  }
  let changed = systems.any(system => !expr_arrays_equal(system, equations))
  if !changed {
    return None
  }
  let tuples : Array[Expr] = []
  for system in systems {
    if expr_arrays_equal(system, equations) {
      continue
    }
    let solved : Result[SolveResult, SolverError] = try? solve(
      solve_exprs_input(system),
      symbols=requested,
    )
    match solved {
      Ok(result) =>
        match solve_result_to_multi_symbol_tuple_exprs(result, requested) {
          Some(items) =>
            for item in items {
              tuples.push(item)
            }
          None => ()
        }
      Err(_) => ()
    }
  }
  Some(@symsets.finite_set(tuples))
}

///|
pub fn solve(
  input : SolveInput,
  symbols? : Array[Expr] = [],
) -> SolveResult raise SolverError {
  let equations = input_equations(input)
  let normalized = normalize_equations(equations)
  let explicit_symbols = !symbols.is_empty()
  let single_expr_input = match input {
    SolveInput::Expr(_) => true
    _ => false
  }
  let preserve_float_context = equations.any(solve_expr_has_float_leaf)
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
    unique_symbols_in_input_order(symbols)
  }
  if normalized.length() == 1 && requested.length() == 1 {
    if expr_is_zeroish(normalized[0]) == Some(true) {
      return SolveResult::List([])
    }
    match normalized[0] {
      Expr::Boolean(true) | Expr::Boolean(false) => return SolveResult::List([])
      _ => ()
    }
    let complex_items_try : Result[Array[Expr], SolverError] = try? solve_finite_set_items(
      solveset(normalized[0], symbol=Some(requested[0]), domain=complexes),
    )
    let items = match complex_items_try {
      Ok(value) => value
      Err(_) if solve_expr_has_noninteger_rational_power(normalized[0]) =>
        solve_finite_set_items(
          solveset(
            normalized[0],
            symbol=Some(requested[0]),
            domain=@symsets.reals(),
          ),
        )
      Err(err) => raise err
    }
    return SolveResult::List(
      items.map(expr => solve_floatify_expr(expr, preserve_float_context)),
    )
  }
  if requested.length() == 1 {
    let mut acc : Set? = None
    for eq in normalized {
      if expr_is_zeroish(eq) == Some(true) {
        continue
      }
      match eq {
        Expr::Boolean(true) => continue
        Expr::Boolean(false) => {
          acc = Some(@symsets.empty_set())
          break
        }
        _ => ()
      }
      let next = solveset(eq, symbol=Some(requested[0]), domain=complexes)
      acc = match acc {
        None => Some(next)
        Some(existing) => Some(@symsets.intersection([existing, next]))
      }
    }
    return SolveResult::List(
      solve_finite_set_items(acc.unwrap_or(@symsets.empty_set())).map(expr => {
        solve_floatify_expr(expr, preserve_float_context)
      }),
    )
  }
  let solving_equations = reduce_redundant_equations(
    solve_coefficient_match_equations(normalized, requested).unwrap_or(
      normalized,
    ),
  )
  let linear_solutions_try : Result[Set, SolverError] = try? linsolve(
    linsolve_equations_input(solving_equations),
    requested,
  )
  let solutions = match linear_solutions_try {
    Ok(set) => set
    Err(_) => nonlinsolve(solving_equations, requested)
  }
  let solutions = match solutions {
    @symsets.Set::EmptySet =>
      match solve_factored_system_fallback(solving_equations, requested) {
        Some(set) => set
        None => solutions
      }
    _ => solutions
  }
  let names = symbol_names(requested)
  match solutions {
    @symsets.Set::FiniteSet(items) => {
      if explicit_symbols &&
        explicit_multi_symbol_solution_needs_tuples(items, requested) {
        return SolveResult::List(items)
      }
      let dicts : Array[Map[String, Expr]] = []
      for item in items {
        match @symcore.tuple_items(item) {
          Some(values) => {
            let mapping : Map[String, Expr] = {}
            for i in 0..<names.length() {
              let value = values.get(i).unwrap_or(requested[i])
              if @symcore.compare_expr(value, requested[i]) != 0 {
                mapping[names[i]] = value
              }
            }
            dicts.push(mapping)
          }
          None => ()
        }
      }
      if !explicit_symbols && single_expr_input && requested.length() > 1 {
        return SolveResult::Dicts(dicts)
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
