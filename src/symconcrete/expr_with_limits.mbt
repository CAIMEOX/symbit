///|
/// Base structures for expressions with limits.

///|
pub(all) enum LimitSpec {
  Var(@symcore.Expr)
  Lower(@symcore.Expr, @symcore.Expr)
  Range(@symcore.Expr, @symcore.Expr, @symcore.Expr)
}

///|
pub(all) struct ExprWithLimits {
  expr : @symcore.Expr
  limits : Array[LimitSpec]
}

///|
pub fn limit_var(symbol : @symcore.Expr) -> LimitSpec {
  Var(symbol)
}

///|
pub fn limit_lower(symbol : @symcore.Expr, lower : @symcore.Expr) -> LimitSpec {
  Lower(symbol, lower)
}

///|
pub fn limit_range(
  symbol : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> LimitSpec {
  Range(symbol, lower, upper)
}

///|
pub fn limit_symbol(spec : LimitSpec) -> @symcore.Expr {
  match spec {
    Var(sym) => sym
    Lower(sym, _) => sym
    Range(sym, _, _) => sym
  }
}

///|
pub fn limit_bounds(spec : LimitSpec) -> (@symcore.Expr?, @symcore.Expr?) {
  match spec {
    Var(_) => (None, None)
    Lower(_, lower) => (Some(lower), None)
    Range(_, lower, upper) => (Some(lower), Some(upper))
  }
}

///|
fn limit_to_tuple(spec : LimitSpec) -> @symcore.Expr {
  match spec {
    Var(sym) => Tuple([sym])
    Lower(sym, lower) => Tuple([sym, lower])
    Range(sym, lower, upper) => Tuple([sym, lower, upper])
  }
}

///|
fn is_infinite_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    Symbol(name) if name == "oo" || name == "zoo" => true
    Mul(args) if args.length() == 2 => {
      let a = args[0]
      let b = args[1]
      match (a, b) {
        (Number(n), Symbol(name)) =>
          if n.is_integral() && n.numerator().to_int() == -1 && name == "oo" {
            true
          } else {
            false
          }
        _ => false
      }
    }
    _ => false
  }
}

///|
pub fn limit_is_finite_int(spec : LimitSpec) -> Bool {
  match spec {
    Range(_, lower, upper) =>
      is_integer_expr(lower) &&
      is_integer_expr(upper) &&
      !is_infinite_expr(lower) &&
      !is_infinite_expr(upper)
    _ => false
  }
}

///|
pub fn ExprWithLimits::to_expr(
  self : ExprWithLimits,
  func_name : String,
) -> @symcore.Expr {
  let args : Array[@symcore.Expr] = Array::new()
  args.push(self.expr)
  for limit in self.limits {
    args.push(limit_to_tuple(limit))
  }
  @symcore.function(func_name, args)
}

///|
pub fn ExprWithLimits::variables(self : ExprWithLimits) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for limit in self.limits {
    out.push(limit_symbol(limit))
  }
  out
}

///|
pub fn ExprWithLimits::bound_symbol_names(
  self : ExprWithLimits,
) -> Array[String] {
  let out : Array[String] = Array::new()
  for limit in self.limits {
    match symbol_name(limit_symbol(limit)) {
      Some(name) => out.push(name)
      None => ()
    }
  }
  out
}

///|
pub fn ExprWithLimits::free_symbols(self : ExprWithLimits) -> Array[String] {
  let acc : Map[String, Bool] = Map([])
  collect_symbol_names(self.expr, acc)
  for name in self.bound_symbol_names() {
    acc.remove(name)
  }
  let out : Array[String] = Array::new()
  for name, _ in acc {
    out.push(name)
  }
  out.sort()
  out
}

///|
pub fn ExprWithLimits::has_finite_limits(self : ExprWithLimits) -> Bool {
  if self.limits.is_empty() {
    return false
  }
  for limit in self.limits {
    if !limit_is_finite_int(limit) {
      return false
    }
  }
  true
}

///|
pub fn ExprWithLimits::has_infinite_limits(self : ExprWithLimits) -> Bool {
  if self.limits.is_empty() {
    return true
  }
  for limit in self.limits {
    match limit {
      Var(_) => return true
      Lower(_, lower) => {
        if is_infinite_expr(lower) {
          return true
        }
        return true
      }
      Range(_, lower, upper) =>
        if is_infinite_expr(lower) || is_infinite_expr(upper) {
          return true
        }
    }
  }
  false
}
