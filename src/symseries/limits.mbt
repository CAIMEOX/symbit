///|
/// Minimal limits for rational expressions.

///|
pub(all) struct Limit {
  expr : @symcore.Expr
  variable : @symcore.Expr
  point : @symcore.Expr
  dir : String
}

///|
pub fn Limit::doit(self : Limit) -> @symcore.Expr raise {
  limit(self.expr, self.variable, self.point, dir=self.dir)
}

///|
pub fn limit(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> @symcore.Expr raise {
  let var_name = match x {
    @symcore.Expr::Symbol(name) => name
    _ => fail("limit requires a Symbol")
  }
  if !contains_symbol(expr, var_name) {
    return expr
  }
  match x0 {
    @symcore.Expr::Number(_) => {
      // Try rational evaluation first.
      let (num_expr, den_expr) = split_num_den(expr)
      match (poly_from_expr(num_expr, x), poly_from_expr(den_expr, x)) {
        (Some(num_poly), Some(den_poly)) => {
          let num_val = poly_eval(num_poly, x0)
          let den_val = poly_eval(den_poly, x0)
          if !is_zero_expr(den_val) {
            let inv = match expr_inv(den_val) {
              Some(v) => v
              None => fail("limit division by zero")
            }
            return expr_mul(num_val, inv)
          }
          // Simple pole handling
          let den_deriv = poly_derivative(den_poly)
          let den_prime = poly_eval(den_deriv, x0)
          if is_zero_expr(den_prime) {
            fail("limit higher-order pole not implemented")
          }
          let inv = match expr_inv(den_prime) {
            Some(v) => v
            None => fail("limit division by zero")
          }
          let coeff = expr_mul(num_val, inv)
          let sign = sign_of_expr(coeff)
          return match sign {
            Some(0) => @symcore.int(0)
            Some(1) =>
              if dir == "-" {
                @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")])
              } else {
                @symcore.symbol("oo")
              }
            Some(-1) =>
              if dir == "-" {
                @symcore.symbol("oo")
              } else {
                @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")])
              }
            _ => @symcore.symbol("oo")
          }
        }
        _ => ()
      }
      // Fallback to series expansion at x0
      let t = @symcore.symbol("__limit_t")
      let env : Map[String, @symcore.Expr] = {}
      env[var_name] = @symcore.add([x0, t])
      let shifted = @symcore.subst(expr, env)
      let (rest, exp_sum) = extract_t_power(shifted, t)
      match series_poly(rest, t, 4) {
        Some((poly, _)) => {
          let mut idx = 0
          while idx < poly.length() && is_zero_expr(poly[idx]) {
            idx = idx + 1
          }
          if idx >= poly.length() {
            @symcore.int(0)
          } else {
            let total_order = idx + exp_sum
            if total_order == 0 {
              poly[idx]
            } else if total_order > 0 {
              @symcore.int(0)
            } else {
              @symcore.symbol("oo")
            }
          }
        }
        None => fail("limit unsupported expression")
      }
    }
    @symcore.Expr::Symbol(name) if name == "oo" => {
      let (num_expr, den_expr) = split_num_den(expr)
      let num_poly = match poly_from_expr(num_expr, x) {
        Some(v) => v
        None => fail("limit unsupported expression")
      }
      let den_poly = match poly_from_expr(den_expr, x) {
        Some(v) => v
        None => fail("limit unsupported expression")
      }
      let num_deg = if num_poly.is_empty() { -1 } else { num_poly.length() - 1 }
      let den_deg = if den_poly.is_empty() { -1 } else { den_poly.length() - 1 }
      if num_deg < den_deg {
        return @symcore.int(0)
      }
      let lead_num = if num_deg >= 0 {
        num_poly[num_deg]
      } else {
        @symcore.int(0)
      }
      let lead_den = if den_deg >= 0 {
        den_poly[den_deg]
      } else {
        @symcore.int(1)
      }
      if num_deg == den_deg {
        let inv = match expr_inv(lead_den) {
          Some(v) => v
          None => fail("limit division by zero")
        }
        return expr_mul(lead_num, inv)
      }
      let sign = sign_of_expr(
        expr_mul(lead_num, @symcore.pow(lead_den, @symcore.int(-1))),
      )
      match sign {
        Some(1) => @symcore.symbol("oo")
        Some(-1) => @symcore.mul([@symcore.int(-1), @symcore.symbol("oo")])
        Some(0) => @symcore.int(0)
        Some(_) => @symcore.symbol("oo")
        None => @symcore.symbol("oo")
      }
    }
    _ => fail("limit unsupported point")
  }
}

///|
fn poly_eval(poly : Array[@symcore.Expr], x0 : @symcore.Expr) -> @symcore.Expr {
  let mut acc = zero_expr()
  let mut i = poly.length()
  while i > 0 {
    i -= 1
    acc = expr_add(poly[i], expr_mul(acc, x0))
  }
  acc
}

///|
fn poly_derivative(poly : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  if poly.length() <= 1 {
    return []
  }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 1..<poly.length() {
    let coeff = poly[i]
    out.push(expr_mul(coeff, @symcore.int(i)))
  }
  poly_trim(out)
}

///|
fn extract_t_power(
  expr : @symcore.Expr,
  t : @symcore.Expr,
) -> (@symcore.Expr, Int) {
  match expr {
    @symcore.Expr::Pow(base, exp) if base == t =>
      match int_exp(exp) {
        Some(e) => (@symcore.int(1), e)
        None => (expr, 0)
      }
    @symcore.Expr::Mul(args) => {
      let rest : Array[@symcore.Expr] = Array::new()
      let mut exp_sum = 0
      for arg in args {
        match arg {
          @symcore.Expr::Pow(base, exp) if base == t =>
            match int_exp(exp) {
              Some(e) => exp_sum = exp_sum + e
              None => rest.push(arg)
            }
          _ => rest.push(arg)
        }
      }
      let rest_expr = if rest.is_empty() {
        @symcore.int(1)
      } else {
        @symcore.mul(rest)
      }
      (rest_expr, exp_sum)
    }
    _ => (expr, 0)
  }
}
