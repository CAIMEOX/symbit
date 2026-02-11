///|
/// Products (Product, product).

///|
pub(all) struct Product {
  expr : @symcore.Expr
  limits : Array[LimitSpec]
}

///|
pub fn Product::as_expr(self : Product) -> @symcore.Expr {
  ExprWithLimits::{ expr: self.expr, limits: self.limits }.to_expr("Product")
}

///|
pub fn Product::doit(self : Product) -> @symcore.Expr {
  product(self.expr, limits=self.limits)
}

///|
pub fn Product::reverse_order(
  self : Product,
  symbols? : Array[@symcore.Expr] = [],
) -> Product {
  let mut out_expr = self.expr
  let out_limits : Array[LimitSpec] = Array::new()
  let reverse_all = symbols.is_empty()
  let target_names : Map[String, Bool] = {}
  if !reverse_all {
    for sym in symbols {
      match symbol_name(sym) {
        Some(name) => target_names[name] = true
        None => ()
      }
    }
  }
  for limit in self.limits {
    let sym = limit_symbol(limit)
    let do_reverse = if reverse_all {
      true
    } else {
      match symbol_name(sym) {
        Some(name) => target_names.get(name) is Some(_)
        None => false
      }
    }
    if do_reverse {
      match limit {
        LimitSpec::Range(sym, lower, upper) => {
          let new_lower = expr_add(upper, @symcore.int(1))
          let new_upper = expr_add(lower, @symcore.int(-1))
          out_limits.push(LimitSpec::Range(sym, new_lower, new_upper))
          match expr_inv(out_expr) {
            Some(inv) => out_expr = inv
            None => out_expr = @symcore.pow(out_expr, @symcore.int(-1))
          }
        }
        _ => out_limits.push(limit)
      }
    } else {
      out_limits.push(limit)
    }
  }
  Product::{ expr: out_expr, limits: out_limits }
}

///|
pub fn Product::reorder(self : Product, order : Array[Int]) -> Product {
  if order.length() != self.limits.length() {
    return self
  }
  let out_limits : Array[LimitSpec] = Array::new()
  for idx in order {
    if idx < 0 || idx >= self.limits.length() {
      return self
    }
    out_limits.push(self.limits[idx])
  }
  Product::{ expr: self.expr, limits: out_limits }
}

///|
pub fn Product::change_index(
  self : Product,
  sym : @symcore.Expr,
  trafo : @symcore.Expr,
  newvar? : @symcore.Expr = sym,
) -> Product {
  let var_name = match symbol_name(sym) {
    Some(name) => name
    None => return self
  }
  let (a, b) = match linear_coeffs(trafo, var_name) {
    Some(v) => v
    None => return self
  }
  if !(a == 1 || a == -1) {
    return self
  }
  let new_sym = newvar
  let replacement = if a == 1 {
    expr_sub(new_sym, @symcore.int(b))
  } else {
    expr_sub(@symcore.int(b), new_sym)
  }
  let env : Map[String, @symcore.Expr] = {}
  env[var_name] = replacement
  let new_expr = @symcore.subst(self.expr, env)
  let out_limits : Array[LimitSpec] = Array::new()
  for limit in self.limits {
    match limit {
      LimitSpec::Range(sym, lower, upper) =>
        if symbol_name(sym) == Some(var_name) {
          let mut new_lower = expr_add(
            expr_mul(@symcore.int(a), lower),
            @symcore.int(b),
          )
          let mut new_upper = expr_add(
            expr_mul(@symcore.int(a), upper),
            @symcore.int(b),
          )
          if a < 0 {
            let tmp = new_lower
            new_lower = new_upper
            new_upper = tmp
          }
          out_limits.push(LimitSpec::Range(new_sym, new_lower, new_upper))
        } else {
          out_limits.push(limit)
        }
      LimitSpec::Lower(sym, lower) =>
        if symbol_name(sym) == Some(var_name) {
          let new_lower = expr_add(
            expr_mul(@symcore.int(a), lower),
            @symcore.int(b),
          )
          out_limits.push(LimitSpec::Lower(new_sym, new_lower))
        } else {
          out_limits.push(limit)
        }
      LimitSpec::Var(sym) =>
        if symbol_name(sym) == Some(var_name) {
          out_limits.push(LimitSpec::Var(new_sym))
        } else {
          out_limits.push(limit)
        }
    }
  }
  Product::{ expr: new_expr, limits: out_limits }
}

///|
pub fn product(
  expr : @symcore.Expr,
  limits? : Array[LimitSpec] = [],
) -> @symcore.Expr {
  match eval_product(expr, limits) {
    Some(res) => res
    None => Product::{ expr, limits }.as_expr()
  }
}

///|
fn eval_product(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  if limits.is_empty() {
    return Some(expr)
  }
  match eval_product_direct(expr, limits) {
    Some(res) => return Some(res)
    None => ()
  }
  eval_product_symbolic(expr, limits)
}

///|
fn eval_finite_product(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
  idx : Int,
) -> @symcore.Expr {
  if idx >= limits.length() {
    return expr
  }
  let limit = limits[idx]
  match limit {
    LimitSpec::Range(sym, lower, upper) => {
      let name = match symbol_name(sym) {
        Some(n) => n
        None => return Product::{ expr, limits }.as_expr()
      }
      let lo = match int_value(lower) {
        Some(v) => v
        None => return Product::{ expr, limits }.as_expr()
      }
      let hi = match int_value(upper) {
        Some(v) => v
        None => return Product::{ expr, limits }.as_expr()
      }
      if !contains_symbol(expr, name) {
        let count = if hi >= lo { hi - lo + 1 } else { 0 }
        return @symcore.pow(expr, @symcore.int(count))
      }
      let mut acc = @symcore.int(1)
      if hi < lo {
        return acc
      }
      for k in lo..<=hi {
        let env : Map[String, @symcore.Expr] = {}
        env[name] = @symcore.int(k)
        let term = @symcore.subst(expr, env)
        let nested = eval_finite_product(term, limits, idx + 1)
        acc = expr_mul(acc, nested)
      }
      acc
    }
    _ => Product::{ expr, limits }.as_expr()
  }
}

///|
pub fn eval_product_direct(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  for limit in limits {
    if !limit_is_finite_int(limit) {
      return None
    }
  }
  Some(eval_finite_product(expr, limits, 0))
}

///|
pub fn eval_product_symbolic(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  if limits.length() != 1 {
    return None
  }
  match limits[0] {
    LimitSpec::Range(sym, lower, upper) => {
      let name = match symbol_name(sym) {
        Some(n) => n
        None => return None
      }
      match ratio_product(expr, name, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      match geometric_product(expr, name, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      match linear_product(expr, name, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      if !contains_symbol(expr, name) {
        let count = expr_add(expr_sub(upper, lower), @symcore.int(1))
        return Some(@symcore.pow(expr, count))
      }
      None
    }
    _ => None
  }
}

///|
fn ratio_product(
  expr : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Mul(args) if args.length() == 2 => {
      let a = args[0]
      let b = args[1]
      match extract_ratio(a, b, name, lower, upper) {
        Some(res) => Some(res)
        None => extract_ratio(b, a, name, lower, upper)
      }
    }
    _ => None
  }
}

///|
fn extract_ratio(
  num : @symcore.Expr,
  den : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let base = match inv_base(den) {
    Some(b) => b
    None => return None
  }
  let shift_plus = shift_expr(base, name, 1)
  if shift_plus == num {
    let upper_env : Map[String, @symcore.Expr] = {}
    let lower_env : Map[String, @symcore.Expr] = {}
    upper_env[name] = expr_add(upper, @symcore.int(1))
    lower_env[name] = lower
    let g_upper = @symcore.subst(base, upper_env)
    let g_lower = @symcore.subst(base, lower_env)
    let inv = match expr_inv(g_lower) {
      Some(v) => v
      None => @symcore.pow(g_lower, @symcore.int(-1))
    }
    return Some(expr_mul(g_upper, inv))
  }
  let shift_minus = shift_expr(base, name, -1)
  if shift_minus == num {
    let upper_env : Map[String, @symcore.Expr] = {}
    let lower_env : Map[String, @symcore.Expr] = {}
    upper_env[name] = upper
    lower_env[name] = expr_add(lower, @symcore.int(-1))
    let g_upper = @symcore.subst(base, upper_env)
    let g_lower = @symcore.subst(base, lower_env)
    let inv = match expr_inv(g_upper) {
      Some(v) => v
      None => @symcore.pow(g_upper, @symcore.int(-1))
    }
    return Some(expr_mul(g_lower, inv))
  }
  None
}

///|
fn inv_base(expr : @symcore.Expr) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      match int_value(exp) {
        Some(v) if v == -1 => Some(base)
        _ => None
      }
    _ => None
  }
}

///|
fn geometric_product(
  expr : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  match split_geometric(expr, name) {
    Some((coeff, base)) => {
      let count = expr_add(expr_sub(upper, lower), @symcore.int(1))
      let sum_exp = expr_mul(
        expr_add(lower, upper),
        expr_mul(count, try! @symcore.rational_from_ints(1, 2)),
      )
      let base_pow = @symcore.pow(base, sum_exp)
      let coeff_pow = @symcore.pow(coeff, count)
      Some(expr_mul(coeff_pow, base_pow))
    }
    None => None
  }
}

///|
fn linear_product(
  expr : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let sym = @symcore.symbol(name)
  let n = expr_add(expr_sub(upper, lower), @symcore.int(1))
  match split_linear_ratio(expr, name) {
    Some((num_c, den_c, coeff)) => {
      let base_num = expr_add(lower, num_c)
      let num = @symcomb.rising_factorial(base_num, n)
      let base_den = expr_add(lower, den_c)
      let den = @symcomb.rising_factorial(base_den, n)
      let inv = match expr_inv(den) {
        Some(v) => v
        None => @symcore.pow(den, @symcore.int(-1))
      }
      let coeff_pow = @symcore.pow(coeff, n)
      return Some(expr_mul(coeff_pow, expr_mul(num, inv)))
    }
    None => ()
  }
  match linear_shift(expr, name) {
    Some(c) => {
      let base = expr_add(lower, c)
      if expr == sym && lower == @symcore.int(1) {
        return Some(@symcomb.factorial(upper))
      }
      return Some(@symcomb.rising_factorial(base, n))
    }
    None => None
  }
}

///|
fn linear_shift(expr : @symcore.Expr, name : String) -> @symcore.Expr? {
  let sym = @symcore.symbol(name)
  match expr {
    @symcore.Expr::Symbol(sym_name) if sym_name == name => Some(@symcore.int(0))
    @symcore.Expr::Add(args) => {
      let mut sym_seen = false
      let const_terms : Array[@symcore.Expr] = Array::new()
      for arg in args {
        if arg == sym && !sym_seen {
          sym_seen = true
        } else if contains_symbol(arg, name) {
          return None
        } else {
          const_terms.push(arg)
        }
      }
      if sym_seen {
        if const_terms.is_empty() {
          Some(@symcore.int(0))
        } else if const_terms.length() == 1 {
          Some(const_terms[0])
        } else {
          Some(@symcore.add(const_terms))
        }
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn split_linear_ratio(
  expr : @symcore.Expr,
  name : String,
) -> (@symcore.Expr, @symcore.Expr, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Mul(args) => {
      let num_terms : Array[@symcore.Expr] = Array::new()
      let den_terms : Array[@symcore.Expr] = Array::new()
      let coeff_terms : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Pow(base, exp) =>
            match int_value(exp) {
              Some(v) if v == -1 => den_terms.push(base)
              _ => num_terms.push(arg)
            }
          _ => num_terms.push(arg)
        }
      }
      if den_terms.length() != 1 || num_terms.length() == 0 {
        return None
      }
      let den = den_terms[0]
      let den_c = match linear_shift(den, name) {
        Some(v) => v
        None => return None
      }
      let mut num_lin : @symcore.Expr? = None
      for term in num_terms {
        match linear_shift(term, name) {
          Some(v) if num_lin is None => num_lin = Some(v)
          Some(_) => return None
          None =>
            if contains_symbol(term, name) {
              return None
            } else {
              coeff_terms.push(term)
            }
        }
      }
      let num_c = match num_lin {
        Some(v) => v
        None => return None
      }
      let coeff = if coeff_terms.is_empty() {
        @symcore.int(1)
      } else if coeff_terms.length() == 1 {
        coeff_terms[0]
      } else {
        @symcore.mul(coeff_terms)
      }
      Some((num_c, den_c, coeff))
    }
    _ => None
  }
}
