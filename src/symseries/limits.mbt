///|
/// Front doors for one-variable limits.
///
/// Current Limits:
/// - The public API is centered on one-variable symbolic limits.
/// - Coverage is strongest for rational expressions and asymptotic fallback cases.

///|
/// Store a deferred limit evaluation request.
///
/// - Does: Bundles the expression, variable, point, and direction into one limit object.
/// - Input: Raw `Expr` fields for the expression, variable, limit point, and side.
/// - Returns: A `Limit` record that can be evaluated later.
/// - Limits: This struct does not validate the fields by itself; validation happens when evaluated.
pub(all) struct Limit {
  expr : @symcore.Expr
  variable : @symcore.Expr
  point : @symcore.Expr
  dir : String
}

///|
/// Evaluate a deferred limit request.
///
/// - Does: Calls the package-level `limit` front door using the stored fields.
/// - Input: One `Limit` value.
/// - Returns: One `Expr` with the evaluated limit.
/// - Limits: Raises under the same conditions as `limit`.
pub fn Limit::doit(self : Limit) -> @symcore.Expr raise {
  limit(self.expr, self.variable, self.point, dir=self.dir)
}

///|
/// Evaluate a one-variable symbolic limit.
///
/// - Does: Computes the limit of `expr` as `x` approaches `x0`, using rational evaluation first and asymptotic fallback when needed.
/// - Input: `expr` is the source expression, `x` is the variable Symbol, `x0` is the limit point, and `dir` chooses the side.
/// - Returns: One `Expr` for the resulting limit.
/// - Limits: Raises if `x` is not a Symbol; unsupported cases fall through to the asymptotic path and may stay coarse.
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
          match
            (
              local_series_poly(num_expr, var_name, x0),
              local_series_poly(den_expr, var_name, x0),
            ) {
            (Some(num_local), Some(den_local)) => {
              let ord_num = first_nonzero_order(num_local)
              let ord_den = first_nonzero_order(den_local)
              if ord_num >= num_local.length() {
                return @symcore.int(0)
              }
              if ord_den >= den_local.length() {
                return gruntz(expr, x, x0, dir~)
              }
              let lead_num = num_local[ord_num]
              let lead_den = den_local[ord_den]
              let inv_lead_den = match expr_inv(lead_den) {
                Some(v) => v
                None => fail("limit division by zero")
              }
              let lead_coeff = expr_mul(lead_num, inv_lead_den)
              if ord_num >= ord_den {
                if ord_num == ord_den {
                  return lead_coeff
                }
                return @symcore.int(0)
              }
              let pole_order = ord_den - ord_num
              if dir == "+-" && pole_order % 2 == 1 {
                return @symcore.Expr::NumberSymbol(
                  @symcore.NumberSymbolKind::ComplexInfinity,
                )
              }
              let side_sign = if dir == "-" && pole_order % 2 == 1 {
                -1
              } else {
                1
              }
              let sign = sign_of_expr(lead_coeff)
              return match sign {
                Some(0) => @symcore.int(0)
                Some(s) => {
                  let final_sign = s * side_sign
                  if final_sign < 0 {
                    @symcore.mul([
                      @symcore.int(-1),
                      @symcore.Expr::NumberSymbol(
                        @symcore.NumberSymbolKind::Infinity,
                      ),
                    ])
                  } else {
                    @symcore.Expr::NumberSymbol(
                      @symcore.NumberSymbolKind::Infinity,
                    )
                  }
                }
                None =>
                  @symcore.Expr::NumberSymbol(
                    @symcore.NumberSymbolKind::Infinity,
                  )
              }
            }
            _ => ()
          }
        }
        _ => ()
      }
      // Fallback to series expansion at x0
      let t = @symcore.Expr::Symbol("__limit_t")
      let env : Map[String, @symcore.Expr] = Map([])
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
              @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
            }
          }
        }
        None => gruntz(expr, x, x0, dir~)
      }
    }
    @symcore.Expr::Symbol(name) if name == "oo" => {
      let (num_expr, den_expr) = split_num_den(expr)
      let num_poly = match poly_from_expr(num_expr, x) {
        Some(v) => v
        None => return gruntz(expr, x, x0, dir~)
      }
      let den_poly = match poly_from_expr(den_expr, x) {
        Some(v) => v
        None => return gruntz(expr, x, x0, dir~)
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
        Some(1) =>
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
        Some(-1) =>
          @symcore.mul([
            @symcore.int(-1),
            @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity),
          ])
        Some(0) => @symcore.int(0)
        Some(_) =>
          @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
        None => @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::Infinity)
      }
    }
    _ => gruntz(expr, x, x0, dir~)
  }
}

///|
fn poly_eval(poly : Array[@symcore.Expr], x0 : @symcore.Expr) -> @symcore.Expr {
  let mut acc = @symcore.int(0)
  let mut i = poly.length()
  while i > 0 {
    i -= 1
    acc = expr_add(poly[i], expr_mul(acc, x0))
  }
  acc
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
