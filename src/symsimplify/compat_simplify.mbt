///|
pub fn besselsimp(
  expr : @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  fixpoint_compat(expr, rewrite_besselsimp, max_passes~)
}

///|
pub fn kroneckersimp(
  expr : @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  fixpoint_compat(expr, rewrite_kroneckersimp, max_passes~)
}

///|
pub fn nsimplify(
  expr : @symcore.Expr,
  constants? : Array[@symcore.Expr] = [],
  full? : Bool = false,
  rational? : Bool = true,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  let _ = constants
  let _ = full
  let _ = rational
  simplify(expr, max_passes~)
}

///|
fn fixpoint_compat(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
  max_passes? : Int = 8,
) -> @symcore.Expr {
  let passes = if max_passes <= 0 { 1 } else { max_passes }
  let mut cur = expr
  for _ in 0..<passes {
    let next = rewrite_bottom_up_compat(cur, rule)
    if next == cur {
      return next
    }
    cur = next
  }
  cur
}

///|
fn rewrite_bottom_up_compat(
  expr : @symcore.Expr,
  rule : (@symcore.Expr) -> @symcore.Expr,
) -> @symcore.Expr {
  let rewritten = @symcore.map_children(
    expr,
    child => rewrite_bottom_up_compat(child, rule),
  )
  rule(rewritten)
}

///|
fn rewrite_besselsimp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [nu, z]) => {
      if !is_zero_number(z) {
        return expr
      }
      if !is_nonnegative_integer_expr(nu) {
        return expr
      }
      let n = integer_expr_value(nu)
      match name {
        "besselj" =>
          if n == 0 {
            @symcore.int(1)
          } else {
            @symcore.int(0)
          }
        "besseli" =>
          if n == 0 {
            @symcore.int(1)
          } else {
            @symcore.int(0)
          }
        _ => expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_kroneckersimp(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, [a, b]) if name == "KroneckerDelta" =>
      simplify_delta(a, b)
    @symcore.Expr::Mul(args) => {
      let env : Map[String, @symcore.Expr] = {}
      let kept : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Function(name, [a, b]) if name == "KroneckerDelta" =>
            match simplify_delta(a, b) {
              @symcore.Expr::Number(n) if n.is_zero() => return @symcore.int(0)
              @symcore.Expr::Number(n) if n.is_one() => ()
              @symcore.Expr::Function(_, _) => {
                if try_bind_delta(env, a, b) {
                  ()
                } else {
                  kept.push(arg)
                }
              }
              other => kept.push(other)
            }
          _ => kept.push(arg)
        }
      }
      let substituted = kept.map(item => @symcore.subst(item, env))
      @symcore.mul(substituted)
    }
    _ => expr
  }
}

///|
fn simplify_delta(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  if a == b {
    return @symcore.int(1)
  }
  match (a, b) {
    (@symcore.Expr::Number(x), @symcore.Expr::Number(y)) =>
      if x == y {
        @symcore.int(1)
      } else {
        @symcore.int(0)
      }
    _ => @symcore.function("KroneckerDelta", [a, b])
  }
}

///|
fn try_bind_delta(
  env : Map[String, @symcore.Expr],
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> Bool {
  match (a, b) {
    (@symcore.Expr::Symbol(name), value) => bind_symbol(env, name, value)
    (value, @symcore.Expr::Symbol(name)) => bind_symbol(env, name, value)
    _ => false
  }
}

///|
fn bind_symbol(
  env : Map[String, @symcore.Expr],
  name : String,
  value : @symcore.Expr,
) -> Bool {
  match env.get(name) {
    Some(v) => v == value
    None => {
      env[name] = value
      true
    }
  }
}

///|
fn is_zero_number(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn is_nonnegative_integer_expr(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_integral() && n.numerator().to_int() >= 0
    _ => false
  }
}

///|
fn integer_expr_value(expr : @symcore.Expr) -> Int {
  match expr {
    @symcore.Expr::Number(n) => n.numerator().to_int()
    _ => 0
  }
}
