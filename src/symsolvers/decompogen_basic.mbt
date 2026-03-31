///|
fn expr_mentions_symbol(expr : Expr, symbol : Expr) -> Bool {
  @symcore.free_symbols(expr).any(item => @symcore.compare_expr(item, symbol) == 0)
}

///|
fn expr_is_relational(expr : Expr) -> Bool {
  @symcore.relational_parts(expr) is Some(_)
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
fn replace_once(expr : Expr, old : Expr, fresh : Expr) -> Expr {
  @symcore.xreplace(expr, [(old, fresh)])
}

///|
fn find_subexpr_by_text(expr : Expr, target : String) -> Expr? {
  for node in @symcore.preorder(expr) {
    if @symprint.to_string(node) == target {
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
  let symbol_text = @symprint.to_string(symbol)
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
    let poly_try : Result[@sympolys.Poly, @sympolys.PolyError] = try? @sympolys.Poly::from_expr_defaults(
      lifted,
      gens=[symbol_text],
    )
    match poly_try {
      Ok(_) => return Some([lifted] + decompogen(node, symbol))
      Err(_) => ()
    }
  }
  None
}

///|
fn decompogen_from_poly(expr : Expr, symbol : Expr) -> Array[Expr]? raise SolverError {
  let poly : @sympolys.Poly = @sympolys.Poly::from_expr_defaults(expr) catch {
    _ => return None
  }
  if poly.gens.length() != 1 {
    return None
  }
  let symbol_text = @symprint.to_string(symbol)
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
  let pieces = @sympolys.decompose(poly) catch {
    _ => return Some([expr])
  }
  if pieces.is_empty() {
    return Some([expr])
  }
  Some(pieces.map(piece => piece.to_expr()))
}

///|
pub fn decompogen(expr : Expr, symbol : Expr) -> Array[Expr] raise SolverError {
  ignore(symbol_name(symbol))
  if expr_is_relational(expr) {
    raise SolverError::ValueError("decompogen: expecting a non-relational Expr")
  }
  if !expr_mentions_symbol(expr, symbol) {
    return [expr]
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
