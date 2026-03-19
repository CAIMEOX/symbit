///|
/// Simplify Bessel-function expressions.
pub fn besselsimp(expr : Expr, max_passes? : Int = 8) -> Expr {
  fixpoint_compat(expr, rewrite_besselsimp, max_passes~)
}

///|
/// Simplify Kronecker-delta expressions.
pub fn kroneckersimp(
  expr : Expr,
  max_passes? : Int = 8,
) -> Expr {
  fixpoint_compat(expr, rewrite_kroneckersimp, max_passes~)
}

///|
/// Convert numeric expressions to exact symbolic forms when recognized.
pub fn nsimplify(
  expr : Expr,
  constants? : Array[Expr] = [],
  full? : Bool = false,
  rational? : Bool = true,
  max_passes? : Int = 8,
) -> Expr {
  let _ = constants
  let _ = full
  let _ = rational
  simplify(expr, max_passes~)
}

///|
fn fixpoint_compat(
  expr : Expr,
  rule : (Expr) -> Expr,
  max_passes? : Int = 8,
) -> Expr {
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
  expr : Expr,
  rule : (Expr) -> Expr,
) -> Expr {
  let rewritten = @symcore.map_children(expr, child => {
    rewrite_bottom_up_compat(child, rule)
  })
  rule(rewritten)
}

///|
fn rewrite_besselsimp(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [nu, z]) => {
      if !is_zero_number(z) {
        return expr
      }
      if !is_nonnegative_integer_expr(nu) {
        return expr
      }
      let n = integer_expr_value(nu)
      match name {
        "besselj" => if n == 0 { int(1) } else { int(0) }
        "besseli" => if n == 0 { int(1) } else { int(0) }
        _ => expr
      }
    }
    _ => expr
  }
}

///|
fn rewrite_kroneckersimp(expr : Expr) -> Expr {
  match expr {
    Expr::Function(name, [a, b]) if name == "KroneckerDelta" =>
      simplify_delta(a, b)
    Expr::Mul(args) => {
      let env : Map[String, Expr] = {}
      let kept : Array[Expr] = Array::new()
      for arg in args {
        match arg {
          Expr::Function(name, [a, b]) if name == "KroneckerDelta" =>
            match simplify_delta(a, b) {
              Expr::Number(n) if n.is_zero() => return int(0)
              Expr::Number(n) if n.is_one() => ()
              Expr::Function(_, _) =>
                if try_bind_delta(env, a, b) {
                  ()
                } else {
                  kept.push(arg)
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
fn simplify_delta(a : Expr, b : Expr) -> Expr {
  if a == b {
    return int(1)
  }
  match (a, b) {
    (Expr::Number(x), Expr::Number(y)) =>
      if x == y {
        int(1)
      } else {
        int(0)
      }
    _ => @symcore.function("KroneckerDelta", [a, b])
  }
}

///|
fn try_bind_delta(
  env : Map[String, Expr],
  a : Expr,
  b : Expr,
) -> Bool {
  match (a, b) {
    (Expr::Symbol(name), value) => bind_symbol(env, name, value)
    (value, Expr::Symbol(name)) => bind_symbol(env, name, value)
    _ => false
  }
}

///|
fn bind_symbol(
  env : Map[String, Expr],
  name : String,
  value : Expr,
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
fn is_zero_number(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
fn is_nonnegative_integer_expr(expr : Expr) -> Bool {
  match expr {
    Expr::Number(n) => n.is_integral() && n.numerator().to_int() >= 0
    _ => false
  }
}

///|
fn integer_expr_value(expr : Expr) -> Int {
  match expr {
    Expr::Number(n) => n.numerator().to_int()
    _ => 0
  }
}
