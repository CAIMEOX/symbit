///|
/// Lightweight Gruntz-style asymptotic evaluator:
/// - finite points via x = x0 + t
/// - infinities via x = ±1/t
/// - leading order from local Laurent data

///|
fn oo_expr() -> @symcore.Expr {
  @symcore.symbol("oo")
}

///|
fn neg_oo_expr() -> @symcore.Expr {
  @symcore.mul([@symcore.int(-1), oo_expr()])
}

///|
fn zoo_expr() -> @symcore.Expr {
  @symcore.symbol("zoo")
}

///|
fn is_pos_oo(expr : @symcore.Expr) -> Bool {
  expr == oo_expr()
}

///|
fn is_neg_oo(expr : @symcore.Expr) -> Bool {
  expr == neg_oo_expr()
}

///|
fn infinity_from_sign(sign : Int) -> @symcore.Expr {
  if sign < 0 {
    neg_oo_expr()
  } else {
    oo_expr()
  }
}

///|
fn leading_rational_near_zero(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  dir : String,
) -> @symcore.Expr? {
  let var_name = match t {
    @symcore.Expr::Symbol(name) => name
    _ => return None
  }
  let (num_expr, den_expr) = split_num_den(expr)
  match (
    local_series_poly(num_expr, var_name, @symcore.int(0)),
    local_series_poly(den_expr, var_name, @symcore.int(0)),
  ) {
    (Some(num_local), Some(den_local)) => {
      let ord_num = first_nonzero_order(num_local)
      let ord_den = first_nonzero_order(den_local)
      if ord_num >= num_local.length() {
        return Some(@symcore.int(0))
      }
      if ord_den >= den_local.length() {
        return None
      }
      let lead_num = num_local[ord_num]
      let lead_den = den_local[ord_den]
      let inv_lead_den = match expr_inv(lead_den) {
        Some(v) => v
        None => return None
      }
      let lead_coeff = expr_mul(lead_num, inv_lead_den)
      if ord_num >= ord_den {
        if ord_num == ord_den {
          return Some(lead_coeff)
        }
        return Some(@symcore.int(0))
      }
      let pole_order = ord_den - ord_num
      if dir == "+-" && pole_order % 2 == 1 {
        return Some(zoo_expr())
      }
      let side_sign =
        if dir == "-" && pole_order % 2 == 1 {
          -1
        } else {
          1
        }
      let sign = sign_of_expr(lead_coeff)
      Some(match sign {
        Some(0) => @symcore.int(0)
        Some(s) => infinity_from_sign(s * side_sign)
        None => oo_expr()
      })
    }
    _ => None
  }
}

///|
fn leading_series_near_zero(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  dir : String,
) -> @symcore.Expr? {
  let (rest, exp_sum) = extract_t_power(expr, t)
  match series_poly(rest, t, 8) {
    Some((poly, _)) => {
      let mut idx = 0
      while idx < poly.length() && is_zero_expr(poly[idx]) {
        idx += 1
      }
      if idx >= poly.length() {
        return Some(@symcore.int(0))
      }
      let total_order = idx + exp_sum
      if total_order > 0 {
        return Some(@symcore.int(0))
      }
      if total_order == 0 {
        return Some(poly[idx])
      }
      if dir == "+-" && total_order % 2 != 0 {
        return Some(zoo_expr())
      }
      let side_sign =
        if dir == "-" && total_order % 2 != 0 {
          -1
        } else {
          1
        }
      let sign = sign_of_expr(poly[idx])
      Some(match sign {
        Some(0) => @symcore.int(0)
        Some(s) => infinity_from_sign(s * side_sign)
        None => oo_expr()
      })
    }
    None => None
  }
}

///|
fn strip_order_terms(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function(name, _) if name == "O" => @symcore.int(0)
    @symcore.Expr::Add(args) => {
      let kept : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Function(name, _) if name == "O" => ()
          _ => kept.push(arg)
        }
      }
      if kept.is_empty() {
        @symcore.int(0)
      } else if kept.length() == 1 {
        kept[0]
      } else {
        @symcore.add(kept)
      }
    }
    _ => expr
  }
}

///|
fn subst_symbol(expr : @symcore.Expr, name : String, value : @symcore.Expr) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env[name] = value
  @symcore.subst(expr, env)
}

///|
fn eval_elementary_from_leading(
  name : String,
  arg_lead : @symcore.Expr,
) -> @symcore.Expr? {
  match name {
    "exp" =>
      if is_pos_oo(arg_lead) {
        Some(oo_expr())
      } else if is_neg_oo(arg_lead) {
        Some(@symcore.int(0))
      } else {
        Some(@symcore.function("exp", [arg_lead]))
      }
    "log" =>
      if is_pos_oo(arg_lead) {
        Some(oo_expr())
      } else {
        match arg_lead {
          @symcore.Expr::Number(n) if n.is_zero() => Some(neg_oo_expr())
          @symcore.Expr::Number(_) => Some(@symcore.function("log", [arg_lead]))
          _ => None
        }
      }
    "sin" | "cos" | "tan" =>
      if is_pos_oo(arg_lead) || is_neg_oo(arg_lead) {
        None
      } else {
        Some(@symcore.function(name, [arg_lead]))
      }
    _ => None
  }
}

///|
fn gruntz_near_zero(
  expr : @symcore.Expr,
  t : @symcore.Expr,
  dir : String,
) -> @symcore.Expr raise {
  let t_name = match t {
    @symcore.Expr::Symbol(name) => name
    _ => fail("gruntz internal variable must be a Symbol")
  }
  if !contains_symbol(expr, t_name) {
    return expr
  }
  match leading_rational_near_zero(expr, t, dir) {
    Some(v) => return v
    None => ()
  }
  match leading_series_near_zero(expr, t, dir) {
    Some(v) => return v
    None => ()
  }
  match expr {
    @symcore.Expr::Function(name, args) if args.length() == 1 => {
      let arg_lead = gruntz_near_zero(args[0], t, dir)
      match eval_elementary_from_leading(name, arg_lead) {
        Some(v) => v
        None => {
          let at_zero = subst_symbol(expr, t_name, @symcore.int(0))
          if !contains_symbol(at_zero, t_name) {
            at_zero
          } else {
          let ser = series(expr, x=t, x0=@symcore.int(0), n=6)
          let no_o = strip_order_terms(ser)
          let v = subst_symbol(no_o, t_name, @symcore.int(0))
          if !contains_symbol(v, t_name) {
            v
          } else {
            at_zero
          }
        }
      }
    }
    }
    _ => {
      let at_zero = subst_symbol(expr, t_name, @symcore.int(0))
      if !contains_symbol(at_zero, t_name) {
        at_zero
      } else {
        let ser = series(expr, x=t, x0=@symcore.int(0), n=6)
        let no_o = strip_order_terms(ser)
        let v = subst_symbol(no_o, t_name, @symcore.int(0))
        if !contains_symbol(v, t_name) {
          v
        } else {
          at_zero
        }
      }
    }
  }
}

///|
fn finite_point_to_t(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  dir : String,
  t : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  let shift =
    if dir == "-" {
      @symcore.add([x0, expr_neg(t)])
    } else {
      @symcore.add([x0, t])
    }
  env[var_name] = shift
  @symcore.subst(expr, env)
}

///|
fn infinity_to_t(
  expr : @symcore.Expr,
  var_name : String,
  neg : Bool,
  t : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  let inv_t = @symcore.pow(t, @symcore.int(-1))
  env[var_name] = if neg { expr_neg(inv_t) } else { inv_t }
  @symcore.subst(expr, env)
}

///|
pub fn gruntz(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> @symcore.Expr raise {
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("gruntz requires a Symbol")
  }
  if !contains_symbol(expr, var_name) {
    return expr
  }
  let t = @symcore.symbol("__gruntz_t")
  if is_pos_oo(x0) {
    let transformed = infinity_to_t(expr, var_name, false, t)
    return gruntz_near_zero(transformed, t, "+")
  }
  if is_neg_oo(x0) {
    let transformed = infinity_to_t(expr, var_name, true, t)
    return gruntz_near_zero(transformed, t, "+")
  }
  let transformed = finite_point_to_t(expr, var_name, x0, dir, t)
  gruntz_near_zero(transformed, t, if dir == "+-" { "+-" } else { "+" })
}
