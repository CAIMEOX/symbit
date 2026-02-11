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
  LimitSpec::Var(symbol)
}

///|
pub fn limit_lower(symbol : @symcore.Expr, lower : @symcore.Expr) -> LimitSpec {
  LimitSpec::Lower(symbol, lower)
}

///|
pub fn limit_range(
  symbol : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> LimitSpec {
  LimitSpec::Range(symbol, lower, upper)
}

///|
pub fn limit_symbol(spec : LimitSpec) -> @symcore.Expr {
  match spec {
    LimitSpec::Var(sym) => sym
    LimitSpec::Lower(sym, _) => sym
    LimitSpec::Range(sym, _, _) => sym
  }
}

///|
pub fn limit_bounds(spec : LimitSpec) -> (@symcore.Expr?, @symcore.Expr?) {
  match spec {
    LimitSpec::Var(_) => (None, None)
    LimitSpec::Lower(_, lower) => (Some(lower), None)
    LimitSpec::Range(_, lower, upper) => (Some(lower), Some(upper))
  }
}

///|
fn limit_to_tuple(spec : LimitSpec) -> @symcore.Expr {
  match spec {
    LimitSpec::Var(sym) => @symcore.function("Tuple", [sym])
    LimitSpec::Lower(sym, lower) => @symcore.function("Tuple", [sym, lower])
    LimitSpec::Range(sym, lower, upper) =>
      @symcore.function("Tuple", [sym, lower, upper])
  }
}

///|
fn is_infinite_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) if name == "oo" || name == "zoo" => true
    @symcore.Expr::Mul(args) if args.length() == 2 => {
      let a = args[0]
      let b = args[1]
      match (a, b) {
        (@symcore.Expr::Number(n), @symcore.Expr::Symbol(name)) =>
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
    LimitSpec::Range(_, lower, upper) =>
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
  let acc : Map[String, Bool] = {}
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
      LimitSpec::Var(_) => return true
      LimitSpec::Lower(_, lower) => {
        if is_infinite_expr(lower) {
          return true
        }
        return true
      }
      LimitSpec::Range(_, lower, upper) =>
        if is_infinite_expr(lower) || is_infinite_expr(upper) {
          return true
        }
    }
  }
  false
}
