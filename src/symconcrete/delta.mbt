///|
/// Delta summation/product helpers.

///|
pub fn deltasummation(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr {
  if limits.length() != 1 {
    return summation(expr, limits=limits)
  }
  match limits[0] {
    LimitSpec::Range(sym, lower, upper) => {
      let name = match symbol_name(sym) {
        Some(n) => n
        None => return summation(expr, limits=limits)
      }
      match extract_delta(expr, name) {
        Some((delta_arg, rest)) =>
          match eval_delta_sum(delta_arg, rest, name, lower, upper) {
            Some(res) => res
            None => summation(expr, limits=limits)
          }
        None => summation(expr, limits=limits)
      }
    }
    _ => summation(expr, limits=limits)
  }
}

///|
pub fn deltaproduct(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr {
  if limits.length() != 1 {
    return product(expr, limits=limits)
  }
  match limits[0] {
    LimitSpec::Range(sym, lower, upper) => {
      let name = match symbol_name(sym) {
        Some(n) => n
        None => return product(expr, limits=limits)
      }
      match extract_delta(expr, name) {
        Some((delta_arg, rest)) =>
          match eval_delta_product(delta_arg, rest, name, lower, upper) {
            Some(res) => res
            None => product(expr, limits=limits)
          }
        None => product(expr, limits=limits)
      }
    }
    _ => product(expr, limits=limits)
  }
}

///|
fn extract_delta(
  expr : @symcore.Expr,
  name : String,
) -> (@symcore.Expr, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Function("KroneckerDelta", args) if args.length() == 2 =>
      match (args[0], args[1]) {
        (@symcore.Expr::Symbol(sym), other) if sym == name =>
          Some((other, @symcore.int(1)))
        (other, @symcore.Expr::Symbol(sym)) if sym == name =>
          Some((other, @symcore.int(1)))
        _ => None
      }
    @symcore.Expr::Mul(args) => {
      let mut delta_arg : @symcore.Expr? = None
      let rest_args : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Function("KroneckerDelta", dargs) if dargs.length() == 2 =>
            match (dargs[0], dargs[1]) {
              (@symcore.Expr::Symbol(sym), other) if sym == name =>
                if delta_arg is None {
                  delta_arg = Some(other)
                } else {
                  return None
                }
              (other, @symcore.Expr::Symbol(sym)) if sym == name =>
                if delta_arg is None {
                  delta_arg = Some(other)
                } else {
                  return None
                }
              _ => rest_args.push(arg)
            }
          _ => rest_args.push(arg)
        }
      }
      match delta_arg {
        Some(d) => {
          let rest = if rest_args.is_empty() {
            @symcore.int(1)
          } else if rest_args.length() == 1 {
            rest_args[0]
          } else {
            @symcore.mul(rest_args)
          }
          Some((d, rest))
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn eval_delta_sum(
  delta_arg : @symcore.Expr,
  rest : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  if contains_symbol(delta_arg, name) {
    return None
  }
  let lo = int_value(lower)
  let hi = int_value(upper)
  let dval = int_value(delta_arg)
  if lo is Some(lv) && hi is Some(hv) && dval is Some(dv) {
    if hv < lv {
      return Some(@symcore.int(0))
    }
    if dv < lv || dv > hv {
      return Some(@symcore.int(0))
    }
    let env : Map[String, @symcore.Expr] = {}
    env[name] = delta_arg
    return Some(@symcore.subst(rest, env))
  }
  if lower == upper && delta_arg == lower {
    let env : Map[String, @symcore.Expr] = {}
    env[name] = delta_arg
    return Some(@symcore.subst(rest, env))
  }
  let env : Map[String, @symcore.Expr] = {}
  env[name] = delta_arg
  let rest_sub = @symcore.subst(rest, env)
  let cond = symbolic_range_cond(delta_arg, lower, upper)
  Some(piecewise_expr(rest_sub, cond))
}

///|
fn eval_delta_product(
  delta_arg : @symcore.Expr,
  rest : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  if contains_symbol(delta_arg, name) {
    return None
  }
  let lo = int_value(lower)
  let hi = int_value(upper)
  let dval = int_value(delta_arg)
  if lo is Some(lv) && hi is Some(hv) && dval is Some(dv) {
    if hv < lv {
      return Some(@symcore.int(1))
    }
    if lv == hv {
      if dv != lv {
        return Some(@symcore.int(0))
      }
      let env : Map[String, @symcore.Expr] = {}
      env[name] = delta_arg
      return Some(@symcore.subst(rest, env))
    }
    return Some(@symcore.int(0))
  }
  if lower == upper && delta_arg == lower {
    let env : Map[String, @symcore.Expr] = {}
    env[name] = delta_arg
    return Some(@symcore.subst(rest, env))
  }
  let env : Map[String, @symcore.Expr] = {}
  env[name] = delta_arg
  let rest_sub = @symcore.subst(rest, env)
  let cond = symbolic_singleton_cond(delta_arg, lower, upper)
  Some(piecewise_expr(rest_sub, cond))
}

///|
fn piecewise_expr(
  expr : @symcore.Expr,
  cond : @symcore.Expr,
) -> @symcore.Expr {
  let pair1 = @symcore.function("Tuple", [expr, cond])
  let pair2 = @symcore.function("Tuple", [@symcore.int(0), @symcore.symbol("True")])
  @symcore.function("Piecewise", [pair1, pair2])
}

///|
fn symbolic_range_cond(
  value : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr {
  let rel1 = rel_le(lower, value)
  let rel2 = rel_le(value, upper)
  rel_and([rel1, rel2])
}

///|
fn symbolic_singleton_cond(
  value : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr {
  let rel1 = rel_eq(lower, upper)
  let rel2 = rel_eq(value, lower)
  rel_and([rel1, rel2])
}

///|
fn rel_le(left : @symcore.Expr, right : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Le", [left, right])
}

///|
fn rel_eq(left : @symcore.Expr, right : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Eq", [left, right])
}

///|
fn rel_and(args : Array[@symcore.Expr]) -> @symcore.Expr {
  @symcore.function("And", args)
}
