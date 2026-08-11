///|
/// Singularity detection front door.
///
/// Current Limits:
/// - Detection focuses on simple negative powers and logarithmic arguments.
/// - Results are returned as symbolic set expressions.
/// - Branch cuts and many transcendental singularities are not complete.

///|
fn sing_set_empty() -> Expr {
  Symbol("EmptySet")
}

///|
fn sing_set_finite(items : Array[Expr]) -> Expr {
  @symcore.function("FiniteSet", items)
}

///|
fn sing_expr_is_symbol(expr : Expr, sym : Expr) -> Bool {
  @symcore.compare_expr(expr, sym) == 0
}

///|
fn sing_rat_add(a : BigRational, b : BigRational) -> BigRational {
  a.add_r(b)
}

///|
fn sing_rat_neg(a : BigRational) -> BigRational {
  a.neg_r()
}

///|
fn sing_rat_div(a : BigRational, b : BigRational) -> BigRational? {
  if b.is_zero() {
    None
  } else {
    Some(a.div_r(b) catch { _ => return None })
  }
}

///|
fn sing_linear_coeff_const(
  expr : Expr,
  sym : Expr,
) -> (BigRational, BigRational)? {
  match expr {
    Symbol(_) if sing_expr_is_symbol(expr, sym) =>
      Some((BigRational::one(), BigRational::zero()))
    Mul(args) if args.length() == 2 => {
      let mut coeff : BigRational? = None
      let mut saw_sym = false
      for arg in args {
        match arg {
          Number(c) => if coeff is None { coeff = Some(c) } else { return None }
          Symbol(_) if sing_expr_is_symbol(arg, sym) => saw_sym = true
          _ => return None
        }
      }
      if saw_sym {
        match coeff {
          Some(c) => Some((c, BigRational::zero()))
          None => None
        }
      } else {
        None
      }
    }
    Add(args) => {
      let mut coeff = BigRational::zero()
      let mut constant = BigRational::zero()
      for arg in args {
        match arg {
          Number(n) => constant = sing_rat_add(constant, n)
          Symbol(_) if sing_expr_is_symbol(arg, sym) =>
            coeff = sing_rat_add(coeff, BigRational::one())
          Mul(margs) if margs.length() == 2 => {
            let mut linear_coeff : BigRational? = None
            let mut saw_sym = false
            for marg in margs {
              match marg {
                Number(c) =>
                  if linear_coeff is None {
                    linear_coeff = Some(c)
                  } else {
                    return None
                  }
                Symbol(_) if sing_expr_is_symbol(marg, sym) => saw_sym = true
                _ => return None
              }
            }
            if saw_sym {
              match linear_coeff {
                Some(c) => coeff = sing_rat_add(coeff, c)
                None => return None
              }
            } else {
              return None
            }
          }
          _ => return None
        }
      }
      Some((coeff, constant))
    }
    _ => None
  }
}

///|
fn sing_solve_linear(expr : Expr, sym : Expr) -> Expr? {
  match sing_linear_coeff_const(expr, sym) {
    Some((coeff, constant)) =>
      if coeff.is_zero() {
        None
      } else {
        let neg_const = sing_rat_neg(constant)
        match sing_rat_div(neg_const, coeff) {
          Some(sol) => Some(Number(sol))
          None => None
        }
      }
    None => None
  }
}

///|
fn sing_is_negative_integer(expr : Expr) -> Bool {
  match expr {
    Number(n) => n.is_integral() && n.compare(BigRational::zero()) < 0
    _ => false
  }
}

///|
fn sing_contains_expr(items : Array[Expr], expr : Expr) -> Bool {
  for item in items {
    if @symcore.compare_expr(item, expr) == 0 {
      return true
    }
  }
  false
}

///|
fn sing_collect(expr : Expr, sym : Expr, out : Array[Expr]) -> Unit {
  match expr {
    Pow(base, exp) => {
      if sing_is_negative_integer(exp) {
        match sing_solve_linear(base, sym) {
          Some(sol) => if !sing_contains_expr(out, sol) { out.push(sol) }
          None => ()
        }
      }
      sing_collect(base, sym, out)
      sing_collect(exp, sym, out)
    }
    Add(args) | Mul(args) =>
      for arg in args {
        sing_collect(arg, sym, out)
      }
    _ =>
      match (@symcore.application_name(expr), @symcore.application_args(expr)) {
        (Some(name), Some(args)) => {
          if name == "log" && args.length() >= 1 {
            match sing_solve_linear(args[0], sym) {
              Some(sol) => if !sing_contains_expr(out, sol) { out.push(sol) }
              None => ()
            }
          }
          for arg in args {
            sing_collect(arg, sym, out)
          }
        }
        _ => ()
      }
  }
}

///|
/// Return isolated singular points of `expr` with respect to `sym`.
///
/// The current implementation focuses on poles from negative powers and
/// logarithmic singularities with linearly solvable arguments.
///
/// - Does: Collects isolated singular points of an expression in one symbol.
/// - Input: An expression and the symbol to analyze.
/// - Returns: A symbolic empty set or finite-set expression.
/// - Limits: Only simple pole/logarithm patterns are recognized.
pub fn singularities(expr : Expr, sym : Expr) -> Expr {
  let out : Array[Expr] = Array::new()
  sing_collect(expr, sym, out)
  if out.is_empty() {
    sing_set_empty()
  } else {
    sing_set_finite(out)
  }
}
