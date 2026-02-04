///|
/// Minimal limits of sequences.

///|
fn contains_symbol(expr : @symcore.Expr, name : String) -> Bool {
  match expr {
    @symcore.Expr::Symbol(n) => n == name
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) => {
      for child in args {
        if contains_symbol(child, name) {
          return true
        }
      }
      false
    }
    @symcore.Expr::Pow(base, exp) =>
      contains_symbol(base, name) || contains_symbol(exp, name)
    _ => false
  }
}

///|
fn sign_of_expr(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(n) => {
      let zero = @symnum.BigRational::zero()
      if n.compare(zero) < 0 {
        Some(-1)
      } else if n.compare(zero) > 0 {
        Some(1)
      } else {
        Some(0)
      }
    }
    _ => None
  }
}

///|
pub fn difference_delta(
  expr : @symcore.Expr,
  n? : @symcore.Expr = @symcore.symbol("n"),
  step? : Int = 1,
) -> @symcore.Expr raise {
  let var_name = match n {
    @symcore.Expr::Symbol(name) => name
    _ => fail("difference_delta requires a Symbol")
  }
  let shifted = @symcore.add([n, @symcore.int(step)])
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = shifted
  let new_expr = @symcore.subst(expr, env)
  @symcore.add([new_expr, @symcore.mul([@symcore.int(-1), expr])])
}

///|
pub fn limit_seq(
  expr : @symcore.Expr,
  n? : @symcore.Expr = @symcore.symbol("n"),
) -> @symcore.Expr raise {
  let var_name = match n {
    @symcore.Expr::Symbol(name) => name
    _ => fail("limit_seq requires a Symbol")
  }
  if !contains_symbol(expr, var_name) {
    return expr
  }
  let (num_expr, den_expr) = split_num_den(expr)
  let num_poly = match poly_from_expr(num_expr, n) {
    Some(v) => v
    None => fail("limit_seq unsupported expression")
  }
  let den_poly = match poly_from_expr(den_expr, n) {
    Some(v) => v
    None => fail("limit_seq unsupported expression")
  }
  let num_deg = if num_poly.is_empty() { -1 } else { num_poly.length() - 1 }
  let den_deg = if den_poly.is_empty() { -1 } else { den_poly.length() - 1 }
  if num_deg < den_deg {
    return @symcore.int(0)
  }
  let lead_num = if num_deg >= 0 { num_poly[num_deg] } else { @symcore.int(0) }
  let lead_den = if den_deg >= 0 { den_poly[den_deg] } else { @symcore.int(1) }
  if num_deg == den_deg {
    let inv = match expr_inv(lead_den) {
      Some(v) => v
      None => fail("limit_seq division by zero")
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
