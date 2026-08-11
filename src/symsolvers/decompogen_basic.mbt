///|
fn expr_mentions_symbol(expr : Expr, symbol : Expr) -> Bool {
  @symcore.free_symbols(expr).any(item => {
    @symcore.compare_expr(item, symbol) == 0
  })
}

///|
fn expr_is_relational(expr : Expr) -> Bool {
  @symcore.relational_parts(expr) is Some(_)
}

///|
fn expr_lists_equal(lhs : Array[Expr], rhs : Array[Expr]) -> Bool {
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
fn expr_array_tail(items : Array[Expr], start : Int) -> Array[Expr] {
  let out : Array[Expr] = []
  for i in start..<items.length() {
    out.push(items[i])
  }
  out
}

///|
fn compogen_symbol_name(symbol : Expr) -> String {
  match @symcore.normalize_legacy_expr(symbol) {
    Expr::Symbol(name) => name
    Expr::Dummy(name, _) => name
    other => @symprint.pretty_string(other)
  }
}

///|
fn first_decompose_arg(expr : Expr) -> Expr? {
  match expr {
    Expr::Pow(base, exp) =>
      if base == Expr::NumberSymbol(@symcore.NumberSymbolKind::Exp1) {
        Some(exp)
      } else {
        Some(base)
      }
    _ =>
      match @symcore.application_args(expr) {
        Some(args) if !args.is_empty() => Some(args[0])
        _ => None
      }
  }
}

///|
fn decompogen_minmax(
  expr : Expr,
  symbol : Expr,
) -> Array[Expr] raise SolverError {
  let name = if @symcore.application_has_name(expr, "Max") {
    "Max"
  } else if @symcore.application_has_name(expr, "Min") {
    "Min"
  } else {
    return [expr]
  }
  let args = match @symcore.application_args(expr) {
    Some(items) => items.copy()
    None => return [expr]
  }
  let mut shared_tail : Array[Expr]? = None
  let mut last_head = symbol
  for i in 0..<args.length() {
    let arg = args[i]
    if !expr_mentions_symbol(arg, symbol) {
      continue
    }
    let mut d = decompogen(arg, symbol)
    if d.length() == 1 {
      d = [symbol] + d
    }
    let tail = expr_array_tail(d, 1)
    match shared_tail {
      None => shared_tail = Some(tail)
      Some(prev) => if !expr_lists_equal(prev, tail) { return [expr] }
    }
    args[i] = d[0]
    last_head = d[0]
  }
  if @symcore.compare_expr(last_head, symbol) == 0 {
    return [expr]
  }
  let out = [@symcore.function(name, args)]
  match shared_tail {
    Some(tail) => out + tail
    None => [expr]
  }
}

///|
fn replace_once(expr : Expr, old : Expr, fresh : Expr) -> Expr {
  @symcore.xreplace(expr, [(old, fresh)])
}

///|
fn find_subexpr_by_text(expr : Expr, target : String) -> Expr? {
  for node in @symcore.preorder(expr) {
    if @symprint.pretty_string(node) == target {
      return Some(node)
    }
  }
  None
}

///|
fn decompogen_via_generator_subexpr(
  expr : Expr,
  symbol : Expr,
) -> Array[Expr]? raise SolverError {
  let symbol_text = @symprint.pretty_string(symbol)
  let mut best : Array[Expr]? = None
  for node in @symcore.preorder(expr) {
    if @symcore.compare_expr(node, expr) == 0 ||
      @symcore.compare_expr(node, symbol) == 0 ||
      !expr_mentions_symbol(node, symbol) {
      continue
    }
    let lifted = replace_once(expr, node, symbol)
    if @symcore.compare_expr(lifted, expr) == 0 {
      continue
    }
    let candidate_ok = try
      @sympolys.Poly::from_expr_defaults(lifted, gens=[symbol_text])
    catch {
      _ => expr_is_polynomial_in_symbol(lifted, symbol)
    } noraise {
      _ => true
    }
    if candidate_ok {
      let candidate = [lifted] + decompogen(node, symbol)
      match best {
        None => best = Some(candidate)
        Some(current) =>
          if candidate.length() < current.length() ||
            (
              candidate.length() == current.length() &&
              @symprint.pretty_string(node).length() <
              @symprint.pretty_string(current[1]).length()
            ) {
            best = Some(candidate)
          }
      }
    }
  }
  best
}

///|
fn expr_is_polynomial_in_symbol(expr : Expr, symbol : Expr) -> Bool {
  if !expr_mentions_symbol(expr, symbol) {
    return true
  }
  match expr {
    Expr::Symbol(_) => @symcore.compare_expr(expr, symbol) == 0
    Expr::Add(args) | Expr::Mul(args) =>
      args.all(arg => expr_is_polynomial_in_symbol(arg, symbol))
    Expr::Pow(base, exp) =>
      if !expr_is_polynomial_in_symbol(base, symbol) {
        false
      } else {
        match @symcore.exact_numeric_expr_num_den(exp) {
          Some((num, den)) => den.compare(1N) == 0 && num.compare(0N) >= 0
          None => false
        }
      }
    _ => false
  }
}

///|
fn decompogen_from_poly(
  expr : Expr,
  symbol : Expr,
) -> Array[Expr]? raise SolverError {
  let poly : @sympolys.Poly = @sympolys.Poly::from_expr_defaults(expr) catch {
    _ => return None
  }
  if poly.gens.length() != 1 {
    return None
  }
  let symbol_text = @symprint.pretty_string(symbol)
  let gen_text = poly.gens[0]
  if gen_text != symbol_text {
    match find_subexpr_by_text(expr, gen_text) {
      Some(generator_expr) => {
        let lifted = replace_once(expr, generator_expr, symbol)
        return Some([lifted] + decompogen(generator_expr, symbol))
      }
      None => return Some([expr])
    }
  }
  let pieces = @sympolys.decompose(poly) catch { _ => return Some([expr]) }
  if pieces.is_empty() {
    return Some([expr])
  }
  Some(pieces.map(piece => piece.to_expr()))
}

///|
/// Decompose `expr` into a composition chain in `symbol`.
///
/// The result is ordered from outermost function to innermost function, and
/// irreducible expressions are returned as a singleton array.
pub fn decompogen(expr : Expr, symbol : Expr) -> Array[Expr] raise SolverError {
  ignore(symbol_name(symbol))
  if expr_is_relational(expr) {
    raise SolverError::ValueError("decompogen: expecting a non-relational Expr")
  }
  if !expr_mentions_symbol(expr, symbol) {
    return [expr]
  }
  if @symcore.application_has_name(expr, "Max") ||
    @symcore.application_has_name(expr, "Min") {
    return decompogen_minmax(expr, symbol)
  }
  match first_decompose_arg(expr) {
    Some(arg) =>
      if @symcore.compare_expr(arg, symbol) == 0 {
        [expr]
      } else {
        [replace_once(expr, arg, symbol)] + decompogen(arg, symbol)
      }
    None =>
      match decompogen_from_poly(expr, symbol) {
        Some(parts) => parts
        None =>
          match decompogen_via_generator_subexpr(expr, symbol) {
            Some(parts) => parts
            None => [expr]
          }
      }
  }
}

///|
/// Compose a decomposition chain produced by [`decompogen`](#decompogen).
///
/// `g_s[0]` is treated as the outermost function and each subsequent element is
/// substituted into the previous one using `symbol` as the composition hole.
pub fn compogen(g_s : Array[Expr], symbol : Expr) -> Expr {
  if g_s.length() <= 1 {
    return g_s[0]
  }
  let env : Map[String, Expr] = Map([])
  env.set(compogen_symbol_name(symbol), g_s[1])
  let composed = @symcore.subst(g_s[0], env)
  if g_s.length() == 2 {
    return composed
  }
  let rest = expr_array_tail(g_s, 2)
  compogen([composed] + rest, symbol)
}
