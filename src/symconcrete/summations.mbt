///|
/// Summations (Sum, summation).

///|
pub(all) struct Sum {
  expr : @symcore.Expr
  limits : Array[LimitSpec]
}

///|
pub fn Sum::as_expr(self : Sum) -> @symcore.Expr {
  ExprWithLimits::{ expr: self.expr, limits: self.limits }.to_expr("Sum")
}

///|
pub fn Sum::doit(self : Sum) -> @symcore.Expr {
  summation(self.expr, limits=self.limits)
}

///|
pub fn Sum::reverse_order(
  self : Sum,
  symbols? : Array[@symcore.Expr] = [],
) -> Sum {
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
          out_expr = expr_neg(out_expr)
        }
        _ => out_limits.push(limit)
      }
    } else {
      out_limits.push(limit)
    }
  }
  Sum::{ expr: out_expr, limits: out_limits }
}

///|
pub fn Sum::reorder(self : Sum, order : Array[Int]) -> Sum {
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
  Sum::{ expr: self.expr, limits: out_limits }
}

///|
pub fn Sum::change_index(
  self : Sum,
  sym : @symcore.Expr,
  trafo : @symcore.Expr,
  newvar? : @symcore.Expr = sym,
) -> Sum {
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
          let mut new_lower = expr_add(expr_mul(@symcore.int(a), lower), @symcore.int(b))
          let mut new_upper = expr_add(expr_mul(@symcore.int(a), upper), @symcore.int(b))
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
          let new_lower = expr_add(expr_mul(@symcore.int(a), lower), @symcore.int(b))
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
  Sum::{ expr: new_expr, limits: out_limits }
}

///|
pub fn summation(
  expr : @symcore.Expr,
  limits? : Array[LimitSpec] = [],
) -> @symcore.Expr {
  match eval_sum(expr, limits) {
    Some(res) => res
    None => Sum::{ expr, limits }.as_expr()
  }
}

///|
pub fn eval_sum(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  if limits.is_empty() {
    return Some(expr)
  }
  match eval_sum_direct(expr, limits) {
    Some(res) => return Some(res)
    None => ()
  }
  match eval_sum_symbolic(expr, limits) {
    Some(res) => Some(res)
    None => None
  }
}

///|
fn eval_finite_sum(
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
        None => return Sum::{ expr, limits }.as_expr()
      }
      let lo = match int_value(lower) {
        Some(v) => v
        None => return Sum::{ expr, limits }.as_expr()
      }
      let hi = match int_value(upper) {
        Some(v) => v
        None => return Sum::{ expr, limits }.as_expr()
      }
      if !contains_symbol(expr, name) {
        let count = if hi >= lo { hi - lo + 1 } else { 0 }
        return expr_mul(expr, @symcore.int(count))
      }
      let mut acc = @symcore.int(0)
      if hi < lo {
        return acc
      }
      for k in lo..=hi {
        let env : Map[String, @symcore.Expr] = {}
        env[name] = @symcore.int(k)
        let term = @symcore.subst(expr, env)
        let nested = eval_finite_sum(term, limits, idx + 1)
        acc = expr_add(acc, nested)
      }
      acc
    }
    _ => Sum::{ expr, limits }.as_expr()
  }
}

///|
pub fn eval_sum_direct(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  for limit in limits {
    if !limit_is_finite_int(limit) {
      return None
    }
  }
  Some(eval_finite_sum(expr, limits, 0))
}

///|
pub fn eval_sum_symbolic(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  if limits.length() != 1 {
    return None
  }
  match limits[0] {
    LimitSpec::Range(sym, lower, upper) if is_oo(upper) => {
      let name = match symbol_name(sym) {
        Some(n) => n
        None => return None
      }
      return eval_sum_infinite(expr, name, lower, sym, limits)
    }
    LimitSpec::Range(sym, lower, upper) => {
      let name = match symbol_name(sym) {
        Some(n) => n
        None => return None
      }
      match harmonic_sum(expr, sym, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      match telescoping_sum(expr, name, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      match geometric_sum(expr, name, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      match hyper_sum(expr, sym, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      match gosper_definite(expr, sym, lower, upper) {
        Some(res) => return Some(res)
        None => ()
      }
      polynomial_sum(expr, sym, lower, upper)
    }
    _ => None
  }
}

///|
pub fn eval_sum_hyper(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  if limits.length() != 1 {
    return None
  }
  match limits[0] {
    LimitSpec::Range(sym, lower, upper) => hyper_sum(expr, sym, lower, upper)
    _ => None
  }
}

///|
pub fn eval_sum_residue(
  expr : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  let _ = expr
  let _ = limits
  None
}

///|
pub fn telescopic(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
) -> @symcore.Expr? {
  let name = match symbol_name(sym) {
    Some(n) => n
    None => return None
  }
  telescoping_antiderivative(expr, name)
}

///|
pub fn telescopic_direct(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let name = match symbol_name(sym) {
    Some(n) => n
    None => return None
  }
  telescoping_sum(expr, name, lower, upper)
}

///|
pub fn gosper_sum(expr : @symcore.Expr, sym : @symcore.Expr) -> @symcore.Expr? {
  let name = match symbol_name(sym) {
    Some(n) => n
    None => return None
  }
  match telescoping_antiderivative(expr, name) {
    Some(g) => Some(g)
    None => {
      match gosper_geometric(expr, name, sym) {
        Some(g) => Some(g)
        None => None
      }
    }
  }
}

///|
fn gosper_geometric(
  expr : @symcore.Expr,
  name : String,
  sym : @symcore.Expr,
) -> @symcore.Expr? {
  match split_geometric(expr, name) {
    Some((coeff, base)) => {
      if base == @symcore.int(1) {
        return Some(expr_mul(coeff, sym))
      }
      let denom = expr_sub(base, @symcore.int(1))
      let inv = match expr_inv(denom) {
        Some(v) => v
        None => @symcore.pow(denom, @symcore.int(-1))
      }
      return Some(expr_mul(coeff, expr_mul(@symcore.pow(base, sym), inv)))
    }
    None => ()
  }
  match split_geometric_weighted(expr, name, sym) {
    Some((coeff, base)) => {
      if base == @symcore.int(1) {
        let k = sym
        let half = try! @symcore.rational_from_ints(1, 2)
        let g = expr_mul(half, expr_mul(k, expr_add(k, @symcore.int(-1))))
        return Some(expr_mul(coeff, g))
      }
      let denom = expr_sub(base, @symcore.int(1))
      let inv = match expr_inv(denom) {
        Some(v) => v
        None => @symcore.pow(denom, @symcore.int(-1))
      }
      let denom_sq = expr_mul(denom, denom)
      let inv_sq = match expr_inv(denom_sq) {
        Some(v) => v
        None => @symcore.pow(denom_sq, @symcore.int(-1))
      }
      let k = sym
      let term1 = expr_mul(k, inv)
      let term2 = expr_mul(base, inv_sq)
      let inner = expr_sub(term1, term2)
      let g = expr_mul(@symcore.pow(base, k), inner)
      Some(expr_mul(coeff, g))
    }
    None => None
  }
}

///|
fn split_geometric_weighted(
  expr : @symcore.Expr,
  name : String,
  sym : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Mul(args) => {
      let coeffs : Array[@symcore.Expr] = Array::new()
      let mut base : @symcore.Expr? = None
      let mut has_sym = false
      for arg in args {
        if arg == sym {
          has_sym = true
          continue
        }
        if contains_symbol(arg, name) {
          match arg {
            @symcore.Expr::Pow(b, exp) if exp == sym => {
              if base is None {
                base = Some(b)
              } else {
                return None
              }
            }
            _ => return None
          }
        } else {
          coeffs.push(arg)
        }
      }
      if !has_sym {
        return None
      }
      match base {
        Some(b) => {
          let coeff = if coeffs.is_empty() {
            @symcore.int(1)
          } else if coeffs.length() == 1 {
            coeffs[0]
          } else {
            @symcore.mul(coeffs)
          }
          Some((coeff, b))
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn gosper_definite(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let name = match symbol_name(sym) {
    Some(n) => n
    None => return None
  }
  let g = match gosper_sum(expr, sym) {
    Some(v) => v
    None => return None
  }
  let upper_env : Map[String, @symcore.Expr] = {}
  let lower_env : Map[String, @symcore.Expr] = {}
  upper_env[name] = expr_add(upper, @symcore.int(1))
  lower_env[name] = lower
  let g_upper = @symcore.subst(g, upper_env)
  let g_lower = @symcore.subst(g, lower_env)
  Some(expr_sub(g_upper, g_lower))
}

///|
fn eval_sum_infinite(
  expr : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  sym : @symcore.Expr,
  limits : Array[LimitSpec],
) -> @symcore.Expr? {
  match sum_zeta(expr, sym, lower) {
    Some(v) => return Some(v)
    None => ()
  }
  match split_geometric(expr, name) {
    Some((coeff, base)) => {
      let denom = expr_sub(@symcore.int(1), base)
      let inv = match expr_inv(denom) {
        Some(v) => v
        None => @symcore.pow(denom, @symcore.int(-1))
      }
      let factor = expr_mul(coeff, @symcore.pow(base, lower))
      let value = expr_mul(factor, inv)
      let cond = rel_lt(@symcore.function("Abs", [base]), @symcore.int(1))
      let sum_expr = Sum::{ expr, limits }.as_expr()
      return Some(piecewise_expr3(value, cond, sum_expr))
    }
    None => ()
  }
  None
}

///|
fn piecewise_expr3(
  expr : @symcore.Expr,
  cond : @symcore.Expr,
  default : @symcore.Expr,
) -> @symcore.Expr {
  let pair1 = @symcore.function("Tuple", [expr, cond])
  let pair2 = @symcore.function("Tuple", [default, @symcore.symbol("True")])
  @symcore.function("Piecewise", [pair1, pair2])
}

///|
fn rel_lt(left : @symcore.Expr, right : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Lt", [left, right])
}

///|
fn sum_zeta(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
) -> @symcore.Expr? {
  let exp = match expr {
    @symcore.Expr::Pow(base, e) if base == sym => e
    _ => return None
  }
  let p = match int_exp(exp) {
    Some(v) => v
    None => return None
  }
  if p >= 0 {
    return None
  }
  let s = -p
  if lower == @symcore.int(1) {
    if s == 1 {
      return Some(@symcore.symbol("oo"))
    }
    return Some(@symspec.zeta(@symcore.int(s)))
  }
  None
}

///|
fn harmonic_sum(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let exp = match expr {
    @symcore.Expr::Pow(base, e) if base == sym => e
    _ => return None
  }
  let p = match int_exp(exp) {
    Some(v) => v
    None => return None
  }
  if p >= 0 {
    return None
  }
  let s = -p
  if lower != @symcore.int(1) {
    return None
  }
  if s == 1 {
    return Some(@symcomb.harmonic(upper))
  }
  Some(@symcore.function("harmonic", [upper, @symcore.int(s)]))
}

///|
fn is_oo(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name == "oo"
    _ => false
  }
}

///|
fn telescoping_sum(
  expr : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let t0 = args[0]
      let t1 = args[1]
      match telescoping_pair(t0, t1, name, lower, upper) {
        Some(res) => Some(res)
        None => telescoping_pair(t1, t0, name, lower, upper)
      }
    }
    _ => None
  }
}

///|
fn telescoping_pair(
  pos_term : @symcore.Expr,
  neg_term : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let (base, is_neg) = strip_neg(neg_term)
  if !is_neg {
    return None
  }
  let shift_plus = shift_expr(base, name, 1)
  if shift_plus == pos_term {
    let upper_env : Map[String, @symcore.Expr] = {}
    let lower_env : Map[String, @symcore.Expr] = {}
    upper_env[name] = expr_add(upper, @symcore.int(1))
    lower_env[name] = lower
    let g_upper = @symcore.subst(base, upper_env)
    let g_lower = @symcore.subst(base, lower_env)
    return Some(expr_sub(g_upper, g_lower))
  }
  let shift_minus = shift_expr(base, name, -1)
  if shift_minus == pos_term {
    let upper_env : Map[String, @symcore.Expr] = {}
    let lower_env : Map[String, @symcore.Expr] = {}
    upper_env[name] = upper
    lower_env[name] = expr_add(lower, @symcore.int(-1))
    let g_upper = @symcore.subst(base, upper_env)
    let g_lower = @symcore.subst(base, lower_env)
    return Some(expr_sub(g_lower, g_upper))
  }
  None
}

///|
fn telescoping_antiderivative(
  expr : @symcore.Expr,
  name : String,
) -> @symcore.Expr? {
  match expr {
    @symcore.Expr::Add(args) if args.length() == 2 => {
      let t0 = args[0]
      let t1 = args[1]
      match telescoping_antiderivative_pair(t0, t1, name) {
        Some(res) => Some(res)
        None => telescoping_antiderivative_pair(t1, t0, name)
      }
    }
    _ => None
  }
}

///|
fn telescoping_antiderivative_pair(
  pos_term : @symcore.Expr,
  neg_term : @symcore.Expr,
  name : String,
) -> @symcore.Expr? {
  let (base, is_neg) = strip_neg(neg_term)
  if !is_neg {
    return None
  }
  let shift_plus = shift_expr(base, name, 1)
  if shift_plus == pos_term {
    return Some(base)
  }
  let shift_minus = shift_expr(base, name, -1)
  if shift_minus == pos_term {
    return Some(expr_neg(base))
  }
  None
}

///|
fn shift_expr(expr : @symcore.Expr, name : String, shift : Int) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  let sym = @symcore.symbol(name)
  env[name] = expr_add(sym, @symcore.int(shift))
  @symcore.subst(expr, env)
}

///|
fn strip_neg(expr : @symcore.Expr) -> (@symcore.Expr, Bool) {
  match expr {
    @symcore.Expr::Mul(args) => {
      let mut neg = false
      let rest : Array[@symcore.Expr] = Array::new()
      for arg in args {
        match arg {
          @symcore.Expr::Number(n) if n.is_integral() && n.numerator().to_int() == -1 && !neg =>
            neg = true
          _ => rest.push(arg)
        }
      }
      if neg {
        if rest.is_empty() {
          (@symcore.int(1), true)
        } else if rest.length() == 1 {
          (rest[0], true)
        } else {
          (@symcore.mul(rest), true)
        }
      } else {
        (expr, false)
      }
    }
    _ => (expr, false)
  }
}

///|
fn geometric_sum(
  expr : @symcore.Expr,
  name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  match split_geometric(expr, name) {
    Some((coeff, base)) => {
      if base == @symcore.int(1) {
        let count = expr_add(expr_sub(upper, lower), @symcore.int(1))
        return Some(expr_mul(coeff, count))
      }
      let count = expr_add(expr_sub(upper, lower), @symcore.int(1))
      let base_pow_count = @symcore.pow(base, count)
      let numerator = expr_sub(base_pow_count, @symcore.int(1))
      let denom = expr_sub(base, @symcore.int(1))
      let inv = match expr_inv(denom) {
        Some(v) => v
        None => @symcore.pow(denom, @symcore.int(-1))
      }
      let factor = expr_mul(@symcore.pow(base, lower), expr_mul(numerator, inv))
      Some(expr_mul(coeff, factor))
    }
    None => None
  }
}

///|
fn split_geometric(
  expr : @symcore.Expr,
  name : String,
) -> (@symcore.Expr, @symcore.Expr)? {
  match expr {
    @symcore.Expr::Pow(base, exp) =>
      match exp_shift(exp, name) {
        Some(shift) => {
          let coeff = if shift == 0 {
            @symcore.int(1)
          } else {
            @symcore.pow(base, @symcore.int(shift))
          }
          Some((coeff, base))
        }
        None => None
      }
    @symcore.Expr::Mul(args) => {
      let coeffs : Array[@symcore.Expr] = Array::new()
      let mut pow_part : (@symcore.Expr, Int)? = None
      for arg in args {
        if contains_symbol(arg, name) {
          match arg {
            @symcore.Expr::Pow(base, exp) =>
              match exp_shift(exp, name) {
                Some(shift) =>
                  if pow_part is None {
                    pow_part = Some((base, shift))
                  } else {
                    return None
                  }
                None => return None
              }
            _ => return None
          }
        } else {
          coeffs.push(arg)
        }
      }
      match pow_part {
        Some((base, shift)) => {
          let mut coeff = if coeffs.is_empty() {
            @symcore.int(1)
          } else if coeffs.length() == 1 {
            coeffs[0]
          } else {
            @symcore.mul(coeffs)
          }
          if shift != 0 {
            coeff = expr_mul(coeff, @symcore.pow(base, @symcore.int(shift)))
          }
          Some((coeff, base))
        }
        None => None
      }
    }
    _ => None
  }
}

///|
fn exp_shift(exp : @symcore.Expr, name : String) -> Int? {
  match exp {
    @symcore.Expr::Symbol(sym) if sym == name => Some(0)
    @symcore.Expr::Add(args) => {
      let mut shift = 0
      let mut seen = false
      for arg in args {
        match arg {
          @symcore.Expr::Symbol(sym) if sym == name && !seen => seen = true
          _ =>
            match int_value(arg) {
              Some(v) => shift = shift + v
              None => return None
            }
        }
      }
      if seen { Some(shift) } else { None }
    }
    _ => None
  }
}

///|
fn polynomial_sum(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let poly = match poly_from_expr(expr, sym) {
    Some(p) => p
    None => return None
  }
  if poly.is_empty() {
    return Some(@symcore.int(0))
  }
  let upper_sum = poly_sum_to(upper, poly)
  let lower_minus = expr_add(lower, @symcore.int(-1))
  let lower_sum = poly_sum_to(lower_minus, poly)
  Some(expr_sub(upper_sum, lower_sum))
}

///|
fn hyper_sum(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let lower_int = match int_value(lower) {
    Some(v) => v
    None => return None
  }
  if lower_int != 0 {
    return None
  }
  let (n_expr, base_opt, has_k, rest) = match analyze_hyper(expr, sym) {
    Some(v) => v
    None => return None
  }
  if upper != n_expr {
    return None
  }
  let a = match base_opt {
    Some(v) => v
    None => @symcore.int(1)
  }
  let one_plus = @symcore.add([@symcore.int(1), a])
  let sum_pow = @symcore.pow(one_plus, n_expr)
  let sum_basic = expr_mul(rest, sum_pow)
  if !has_k {
    return Some(sum_basic)
  }
  let pref = expr_mul(rest, expr_mul(n_expr, a))
  let sum_pow2 = @symcore.pow(one_plus, expr_add(n_expr, @symcore.int(-1)))
  Some(expr_mul(pref, sum_pow2))
}

///|
fn analyze_hyper(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr?, Bool, @symcore.Expr)? {
  let name = match symbol_name(sym) {
    Some(n) => n
    None => return None
  }
  let factors = match expr {
    @symcore.Expr::Mul(args) => args
    _ => [expr]
  }
  let mut binom : @symcore.Expr? = None
  let mut base : @symcore.Expr? = None
  let mut has_k = false
  let rest_args : Array[@symcore.Expr] = Array::new()
  for factor in factors {
    match factor {
      @symcore.Expr::Function(namef, args) if namef == "binomial" && args.length() == 2 => {
        let n = args[0]
        let k = args[1]
        if k == sym && binom is None {
          binom = Some(n)
        } else {
          return None
        }
      }
      @symcore.Expr::Pow(base_expr, exp) if exp == sym => {
        if contains_symbol(base_expr, name) {
          return None
        }
        if base is None {
          base = Some(base_expr)
        } else {
          return None
        }
      }
      _ =>
        if factor == sym {
          has_k = true
        } else if contains_symbol(factor, name) {
          return None
        } else {
          rest_args.push(factor)
        }
    }
  }
  let n_expr = match binom {
    Some(v) => v
    None => return None
  }
  let rest = if rest_args.is_empty() {
    @symcore.int(1)
  } else if rest_args.length() == 1 {
    rest_args[0]
  } else {
    @symcore.mul(rest_args)
  }
  Some((n_expr, base, has_k, rest))
}

///|
fn poly_sum_to(
  n : @symcore.Expr,
  poly : Array[@symcore.Expr],
) -> @symcore.Expr {
  let terms : Array[@symcore.Expr] = Array::new()
  for p in 0..<poly.length() {
    let coeff = poly[p]
    if is_zero_expr(coeff) {
      continue
    }
    let term = expr_mul(coeff, sum_powers(n, p))
    terms.push(term)
  }
  if terms.is_empty() {
    @symcore.int(0)
  } else {
    @symcore.add(terms)
  }
}

///|
fn sum_powers(n : @symcore.Expr, p : Int) -> @symcore.Expr {
  if p == 0 {
    return expr_add(n, @symcore.int(1))
  }
  let acc : Array[@symcore.Expr] = Array::new()
  let n1 = expr_add(n, @symcore.int(1))
  for j in 0..=p {
    let bin = binomial_int(p + 1, j)
    let coeff = @symcore.int(bin)
    let bern = @symcomb.bernoulli(@symcore.int(j))
    let power = @symcore.pow(n1, @symcore.int(p + 1 - j))
    acc.push(expr_mul(coeff, expr_mul(bern, power)))
  }
  let inv = try! @symcore.rational_from_ints(1, p + 1)
  expr_mul(inv, @symcore.add(acc))
}

///|
fn binomial_int(n : Int, k0 : Int) -> Int {
  if k0 < 0 || k0 > n {
    return 0
  }
  let k = if k0 > n - k0 { n - k0 } else { k0 }
  let mut res = 1
  let mut i = 1
  while i <= k {
    res = res * (n - k + i) / i
    i = i + 1
  }
  res
}

///|
fn poly_from_expr(
  expr : @symcore.Expr,
  sym : @symcore.Expr,
) -> Array[@symcore.Expr]? {
  match expr {
    @symcore.Expr::Number(_) => Some([expr])
    @symcore.Expr::Symbol(_) =>
      if expr == sym {
        Some([@symcore.int(0), @symcore.int(1)])
      } else {
        Some([expr])
      }
    @symcore.Expr::Add(args) => {
      let mut acc : Array[@symcore.Expr] = [@symcore.int(0)]
      for arg in args {
        match poly_from_expr(arg, sym) {
          Some(poly) => acc = poly_add(acc, poly)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Mul(args) => {
      let mut acc : Array[@symcore.Expr] = [@symcore.int(1)]
      for arg in args {
        match poly_from_expr(arg, sym) {
          Some(poly) => acc = poly_mul(acc, poly)
          None => return None
        }
      }
      Some(acc)
    }
    @symcore.Expr::Pow(base, exp) =>
      match int_exp(exp) {
        Some(e) if e >= 0 =>
          match poly_from_expr(base, sym) {
            Some(poly) => Some(poly_pow(poly, e))
            None => None
          }
        _ => None
      }
    _ => None
  }
}

///|
fn int_exp(expr : @symcore.Expr) -> Int? {
  match expr {
    @symcore.Expr::Number(_) => int_value(expr)
    _ => None
  }
}

///|
fn poly_trim(poly : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let mut end = poly.length()
  while end > 0 && is_zero_expr(poly[end - 1]) {
    end -= 1
  }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 0..<end {
    out.push(poly[i])
  }
  out
}

///|
fn poly_add(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  let len = if a.length() > b.length() { a.length() } else { b.length() }
  let out : Array[@symcore.Expr] = Array::new()
  for i in 0..<len {
    let av = if i < a.length() { a[i] } else { @symcore.int(0) }
    let bv = if i < b.length() { b[i] } else { @symcore.int(0) }
    out.push(expr_add(av, bv))
  }
  poly_trim(out)
}

///|
fn poly_mul(
  a : Array[@symcore.Expr],
  b : Array[@symcore.Expr],
) -> Array[@symcore.Expr] {
  if a.is_empty() || b.is_empty() {
    return []
  }
  let out_len = a.length() + b.length() - 1
  let out : Array[@symcore.Expr] = Array::new()
  for _ in 0..<out_len {
    out.push(@symcore.int(0))
  }
  for i in 0..<a.length() {
    for j in 0..<b.length() {
      let idx = i + j
      out[idx] = expr_add(out[idx], expr_mul(a[i], b[j]))
    }
  }
  poly_trim(out)
}

///|
fn poly_pow(poly : Array[@symcore.Expr], exp : Int) -> Array[@symcore.Expr] {
  if exp <= 0 {
    return [@symcore.int(1)]
  }
  let mut result : Array[@symcore.Expr] = [@symcore.int(1)]
  let mut b = poly
  let mut e = exp
  while e > 0 {
    if e % 2 == 1 {
      result = poly_mul(result, b)
    }
    e = e / 2
    if e > 0 {
      b = poly_mul(b, b)
    }
  }
  result
}

///|
fn linear_coeffs(expr : @symcore.Expr, name : String) -> (Int, Int)? {
  match expr {
    @symcore.Expr::Symbol(sym) if sym == name => Some((1, 0))
    @symcore.Expr::Number(n) if n.is_integral() =>
      Some((0, n.numerator().to_int()))
    @symcore.Expr::Add(args) => {
      let mut a = 0
      let mut b = 0
      for arg in args {
        match linear_coeffs(arg, name) {
          Some((ai, bi)) => {
            a = a + ai
            b = b + bi
          }
          None => return None
        }
      }
      Some((a, b))
    }
    @symcore.Expr::Mul(args) => {
      let mut coeff = 1
      let mut seen_var = false
      for arg in args {
        if contains_symbol(arg, name) {
          if arg == @symcore.symbol(name) && !seen_var {
            seen_var = true
          } else {
            return None
          }
        } else {
          match int_value(arg) {
            Some(v) => coeff = coeff * v
            None => return None
          }
        }
      }
      if seen_var {
        Some((coeff, 0))
      } else {
        Some((0, coeff))
      }
    }
    _ => None
  }
}
