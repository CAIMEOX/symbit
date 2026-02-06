///|
pub struct HolonomicFunction {
  annihilator : DifferentialOperator?
  x : @symcore.Expr
  x0 : @symcore.Expr
  y0 : Array[@symcore.Expr]
  expr_hint : @symcore.Expr?
}

///|
fn copy_expr_array(values : Array[@symcore.Expr]) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for v in values {
    out.push(v)
  }
  out
}

///|
fn depends_on(expr : @symcore.Expr, x : @symcore.Expr) -> Bool {
  if expr == x {
    return true
  }
  match expr {
    @symcore.Expr::Add(args) | @symcore.Expr::Mul(args) =>
      args.any(arg => depends_on(arg, x))
    @symcore.Expr::Pow(base, exp) => depends_on(base, x) || depends_on(exp, x)
    @symcore.Expr::Function(_, args) => args.any(arg => depends_on(arg, x))
    _ => false
  }
}

///|
fn to_number(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(v) => Some(v)
    _ => None
  }
}

///|
fn factorial_bigint(n : Int) -> BigInt {
  if n <= 1 {
    return BigInt::from_int(1)
  }
  let mut acc = BigInt::from_int(1)
  for i in 2..=n {
    acc = acc.mul(BigInt::from_int(i))
  }
  acc
}

///|
fn factorial_rat(n : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_bigint(factorial_bigint(n))
}

///|
fn rising_factorial_expr(n : @symcore.Expr, k : Int) -> @symcore.Expr {
  if k <= 0 {
    return holo_one()
  }
  let terms : Array[@symcore.Expr] = Array::new()
  for i in 1..=k {
    terms.push(expr_add(n, @symcore.int(i)))
  }
  @symcore.mul(terms)
}

///|
fn split_linear_in_x(
  expr : @symcore.Expr,
  x : @symcore.Expr,
) -> (@symnum.BigRational, @symcore.Expr)? {
  if expr == x {
    return Some((@symnum.BigRational::one(), @symcore.int(0)))
  }
  match expr {
    @symcore.Expr::Add(args) => {
      let mut coeff = @symnum.BigRational::zero()
      let mut const_term = @symcore.int(0)
      for arg in args {
        if arg == x {
          coeff = coeff.add_r(@symnum.BigRational::one())
          continue
        }
        match arg {
          @symcore.Expr::Mul(factors) if factors.length() == 2 => {
            match (factors[0], factors[1]) {
              (@symcore.Expr::Number(c), t) if t == x =>
                coeff = coeff.add_r(c)
              _ => const_term = expr_add(const_term, arg)
            }
          }
          _ => const_term = expr_add(const_term, arg)
        }
      }
      Some((coeff, const_term))
    }
    @symcore.Expr::Mul(args) if args.length() == 2 =>
      match (args[0], args[1]) {
        (@symcore.Expr::Number(c), t) if t == x => Some((c, @symcore.int(0)))
        _ => None
      }
    _ => None
  }
}

///|
fn make_hf(
  annihilator : DifferentialOperator?,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
  y0 : Array[@symcore.Expr],
  expr_hint : @symcore.Expr?,
) -> HolonomicFunction {
  HolonomicFunction::{ annihilator, x, x0, y0: copy_expr_array(y0), expr_hint }
}

///|
pub fn holonomic_function(
  annihilator : DifferentialOperator,
  x : @symcore.Expr,
  x0? : @symcore.Expr = @symcore.int(0),
  y0? : Array[@symcore.Expr] = [],
  expr_hint? : @symcore.Expr? = None,
) -> HolonomicFunction {
  ignore(require_symbol_name(x))
  make_hf(Some(annihilator), x, x0, y0, expr_hint)
}

///|
fn infer_expr_from_operator(hf : HolonomicFunction) -> @symcore.Expr? {
  match hf.annihilator {
    None => None
    Some(op) => {
      let coeffs = op.coefficients()
      if coeffs.length() == 2 {
        if coeffs[0] == @symcore.int(-1) && coeffs[1] == @symcore.int(1) && hf.y0.length() >= 1 {
          if hf.y0[0] == @symcore.int(1) {
            return Some(@symcore.function("exp", [hf.x]))
          }
          return Some(@symcore.mul([hf.y0[0], @symcore.function("exp", [hf.x])]))
        }
        if coeffs[0] == @symcore.int(0) && coeffs[1] == @symcore.int(1) && hf.y0.length() >= 1 {
          return Some(hf.y0[0])
        }
      }
      if coeffs.length() == 3 && coeffs[0] == @symcore.int(1) && coeffs[1] == @symcore.int(0) && coeffs[2] == @symcore.int(1) && hf.y0.length() >= 2 {
        if hf.y0[0] == @symcore.int(0) && hf.y0[1] == @symcore.int(1) {
          return Some(@symcore.function("sin", [hf.x]))
        }
        if hf.y0[0] == @symcore.int(1) && hf.y0[1] == @symcore.int(0) {
          return Some(@symcore.function("cos", [hf.x]))
        }
      }
      None
    }
  }
}

///|
fn try_constant_coeffs(
  op : DifferentialOperator,
) -> Array[@symnum.BigRational]? {
  let out : Array[@symnum.BigRational] = Array::new()
  for c in op.coefficients() {
    match to_number(c) {
      Some(v) => out.push(v)
      None => return None
    }
  }
  Some(out)
}

///|
fn solve_constant_ode_coefficients(
  coeffs : Array[@symnum.BigRational],
  init_derivs : Array[@symcore.Expr],
  terms : Int,
) -> Array[@symcore.Expr]? {
  if coeffs.is_empty() {
    return None
  }
  let r = coeffs.length() - 1
  if r <= 0 {
    return None
  }
  if init_derivs.length() < r {
    return None
  }
  let cr = coeffs[r]
  if cr.is_zero() {
    return None
  }
  let a : Array[@symcore.Expr] = Array::new()
  for k in 0..<r {
    let yk = init_derivs[k]
    let fk = factorial_rat(k)
    match to_number(yk) {
      Some(nk) => {
        let ak = try nk.div_r(fk) catch {
          _ => return None
        }
        a.push(@symcore.number(ak))
      }
      None => {
        a.push(expr_mul(yk, @symcore.number(try! fk.reciprocal())))
      }
    }
  }
  while a.length() < terms {
    let n = a.length() - r
    let mut sum = @symcore.int(0)
    for k in 0..<r {
      let ck = coeffs[k]
      if ck.is_zero() {
        continue
      }
      let num = factorial_bigint(n + k)
      let den = factorial_bigint(n + r)
      let ratio = @symnum.BigRational::new(num, den) catch {
        _ => return None
      }
      let scale = try ck.mul_r(ratio).div_r(cr) catch {
        _ => return None
      }
      let term = expr_mul(@symcore.number(scale), a[n + k])
      sum = expr_add(sum, term)
    }
    a.push(expr_neg(sum))
  }
  Some(a)
}

///|
fn sequence_from_constant_ode(
  hf : HolonomicFunction,
) -> HolonomicSequence? {
  if hf.x0 != @symcore.int(0) {
    return None
  }
  match hf.annihilator {
    None => None
    Some(op) =>
      match try_constant_coeffs(op) {
        None => None
        Some(cvals) => {
          let n = @symcore.symbol("n")
          let (r_alg, _) = recurrence_operators(symbol_var=n)
          let coeffs : Array[@symcore.Expr] = Array::new()
          for k, ck in cvals {
            if ck.is_zero() {
              coeffs.push(@symcore.int(0))
              continue
            }
            let scale = @symcore.number(ck)
            let rf = rising_factorial_expr(n, k)
            coeffs.push(expr_mul(scale, rf))
          }
          let rec = recurrence_operator(coeffs, r_alg)
          let init_terms = if hf.y0.length() < cvals.length() - 1 {
            hf.y0.length()
          } else {
            cvals.length() - 1
          }
          let init : Array[@symcore.Expr] = Array::new()
          for k in 0..<init_terms {
            let fk = factorial_rat(k)
            match to_number(hf.y0[k]) {
              Some(v) => {
                let ak = try v.div_r(fk) catch {
                  _ => return None
                }
                init.push(@symcore.number(ak))
              }
              None => init.push(expr_mul(hf.y0[k], @symcore.number(try! fk.reciprocal())))
            }
          }
          Some(holonomic_sequence(rec, u0=init))
        }
      }
  }
}

///|
pub fn HolonomicFunction::annihilator(self : HolonomicFunction) -> DifferentialOperator? {
  self.annihilator
}

///|
pub fn HolonomicFunction::variable(self : HolonomicFunction) -> @symcore.Expr {
  self.x
}

///|
pub fn HolonomicFunction::x0(self : HolonomicFunction) -> @symcore.Expr {
  self.x0
}

///|
pub fn HolonomicFunction::initial_values(self : HolonomicFunction) -> Array[@symcore.Expr] {
  copy_expr_array(self.y0)
}

///|
pub fn HolonomicFunction::to_expr(self : HolonomicFunction) -> @symcore.Expr {
  match self.expr_hint {
    Some(expr) => expr
    None =>
      match infer_expr_from_operator(self) {
        Some(expr) => expr
        None => @symcore.function("HolonomicFunctionExpr", [])
      }
  }
}

///|
pub fn HolonomicFunction::to_sequence(self : HolonomicFunction) -> Array[HolonomicSequence] {
  match sequence_from_constant_ode(self) {
    Some(seq) => [seq]
    None => []
  }
}

///|
pub fn HolonomicFunction::series(
  self : HolonomicFunction,
  n? : Int = 6,
) -> @symcore.Expr {
  if n <= 0 {
    return @symcore.int(0)
  }
  match self.annihilator {
    Some(op) =>
      match try_constant_coeffs(op) {
        Some(cvals) =>
          match solve_constant_ode_coefficients(cvals, self.y0, n) {
            Some(seq) => {
              let terms : Array[@symcore.Expr] = Array::new()
              for i in 0..<seq.length() {
                if expr_is_zero(seq[i]) {
                  continue
                }
                let term = if i == 0 {
                  seq[i]
                } else {
                  expr_mul(seq[i], expr_pow_int(self.x, i))
                }
                terms.push(term)
              }
              if terms.is_empty() {
                @symcore.int(0)
              } else {
                @symcore.add(terms)
              }
            }
            None => self.to_expr()
          }
        None => self.to_expr()
      }
    None => self.to_expr()
  }
}

///|
pub fn HolonomicFunction::evalf(
  self : HolonomicFunction,
  x_value : @symnum.BigRational,
  terms? : Int = 20,
) -> @symcore.Expr {
  let series_expr = self.series(n=terms)
  let env : Map[String, @symcore.Expr] = {}
  env[require_symbol_name(self.x)] = @symcore.number(x_value)
  @symcore.subst(series_expr, env)
}

///|
pub fn HolonomicFunction::diff(self : HolonomicFunction) -> HolonomicFunction {
  let expr = self.to_expr()
  let d = @symcalculus.diff(expr, self.x)
  expr_to_holonomic(d, x=self.x, x0=self.x0)
}

///|
fn integrate_expr(expr : @symcore.Expr, x : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(_) => expr_mul(expr, x)
    @symcore.Expr::Add(args) => {
      let out : Array[@symcore.Expr] = Array::new()
      for arg in args {
        out.push(integrate_expr(arg, x))
      }
      @symcore.add(out)
    }
    @symcore.Expr::Pow(base, exp) if base == x =>
      match expr_int(exp) {
        Some(e) if e >= 0 => {
          let n1 = e + 1
          expr_mul(@symcore.pow(x, @symcore.int(n1)), @symcore.number(
            try! @symnum.BigRational::from_int(n1).reciprocal(),
          ))
        }
        _ => @symcore.function("Integral", [expr, x])
      }
    @symcore.Expr::Function(name, args) if args.length() == 1 && args[0] == x =>
      match name {
        "exp" => @symcore.function("exp", [x])
        "sin" => expr_neg(@symcore.function("cos", [x]))
        "cos" => @symcore.function("sin", [x])
        _ => @symcore.function("Integral", [expr, x])
      }
    _ => @symcore.function("Integral", [expr, x])
  }
}

///|
pub fn HolonomicFunction::integrate(self : HolonomicFunction) -> HolonomicFunction {
  let expr = self.to_expr()
  let i_expr = integrate_expr(expr, self.x)
  expr_to_holonomic(i_expr, x=self.x, x0=self.x0)
}

///|
pub fn HolonomicFunction::composition(
  self : HolonomicFunction,
  arg : @symcore.Expr,
  x0? : @symcore.Expr = @symcore.int(0),
) -> HolonomicFunction {
  let env : Map[String, @symcore.Expr] = {}
  env[require_symbol_name(self.x)] = arg
  let composed = @symcore.subst(self.to_expr(), env)
  expr_to_holonomic(composed, x=self.x, x0~)
}

///|
pub fn HolonomicFunction::to_sympy_str(self : HolonomicFunction) -> String {
  let x_str = @symprint.to_string(self.x)
  let x0_str = @symprint.to_string(self.x0)
  match self.annihilator {
    Some(op) =>
      if self.y0.is_empty() {
        "HolonomicFunction(\{op.to_sympy_str()}, \{x_str})"
      } else {
        let vals = self.y0.map(v => expr_to_sympy_string(v)).join(", ")
        "HolonomicFunction(\{op.to_sympy_str()}, \{x_str}, \{x0_str}, [\{vals}])"
      }
    None =>
      "HolonomicFunction(\{expr_to_sympy_string(self.to_expr())}, \{x_str})"
  }
}

///|
fn fallback_from_expr(
  expr : @symcore.Expr,
  x : @symcore.Expr,
  x0 : @symcore.Expr,
) -> HolonomicFunction {
  make_hf(None, x, x0, [], Some(expr))
}

///|
pub fn expr_to_holonomic(
  expr : @symcore.Expr,
  x? : @symcore.Expr = @symcore.symbol("x"),
  x0? : @symcore.Expr = @symcore.int(0),
) -> HolonomicFunction {
  ignore(require_symbol_name(x))
  if !depends_on(expr, x) {
    let (alg, dx) = differential_operators(symbol_var=x)
    ignore(alg)
    return holonomic_function(dx, x, x0~, y0=[expr], expr_hint=Some(expr))
  }
  match expr {
    @symcore.Expr::Function(name, args) if args.length() == 1 =>
      match split_linear_in_x(args[0], x) {
        Some((a, b)) =>
          if a.is_zero() {
            fallback_from_expr(expr, x, x0)
          } else {
            let (alg, dx) = differential_operators(symbol_var=x)
            ignore(alg)
            match name {
              "exp" => {
                let op = differential_operator([@symcore.number(a.neg_r()), @symcore.int(1)], dx.parent)
                let y0 = if x0 == @symcore.int(0) {
                  if b == @symcore.int(0) {
                    [@symcore.int(1)]
                  } else {
                    [@symcore.function("exp", [b])]
                  }
                } else {
                  []
                }
                holonomic_function(op, x, x0~, y0~, expr_hint=Some(expr))
              }
              "sin" => {
                let a2 = a.mul_r(a)
                let op = differential_operator([@symcore.number(a2), @symcore.int(0), @symcore.int(1)], dx.parent)
                let y0 = if x0 == @symcore.int(0) {
                  let y = if b == @symcore.int(0) {
                    @symcore.int(0)
                  } else {
                    @symcore.function("sin", [b])
                  }
                  let dy = if b == @symcore.int(0) {
                    @symcore.number(a)
                  } else {
                    expr_mul(@symcore.number(a), @symcore.function("cos", [b]))
                  }
                  [y, dy]
                } else {
                  []
                }
                holonomic_function(op, x, x0~, y0~, expr_hint=Some(expr))
              }
              "cos" => {
                let a2 = a.mul_r(a)
                let op = differential_operator([@symcore.number(a2), @symcore.int(0), @symcore.int(1)], dx.parent)
                let y0 = if x0 == @symcore.int(0) {
                  let y = if b == @symcore.int(0) {
                    @symcore.int(1)
                  } else {
                    @symcore.function("cos", [b])
                  }
                  let dy = if b == @symcore.int(0) {
                    @symcore.int(0)
                  } else {
                    expr_mul(@symcore.number(a.neg_r()), @symcore.function("sin", [b]))
                  }
                  [y, dy]
                } else {
                  []
                }
                holonomic_function(op, x, x0~, y0~, expr_hint=Some(expr))
              }
              _ => fallback_from_expr(expr, x, x0)
            }
          }
        None => fallback_from_expr(expr, x, x0)
      }
    _ => fallback_from_expr(expr, x, x0)
  }
}

///|
pub impl Add for HolonomicFunction with add(self, other) {
  if self.x != other.x {
    return fallback_from_expr(expr_add(self.to_expr(), other.to_expr()), self.x, self.x0)
  }
  let expr = expr_add(self.to_expr(), other.to_expr())
  expr_to_holonomic(expr, x=self.x, x0=self.x0)
}

///|
pub impl Mul for HolonomicFunction with mul(self, other) {
  if self.x != other.x {
    return fallback_from_expr(expr_mul(self.to_expr(), other.to_expr()), self.x, self.x0)
  }
  let expr = expr_mul(self.to_expr(), other.to_expr())
  expr_to_holonomic(expr, x=self.x, x0=self.x0)
}

///|
pub fn HolonomicFunction::pow(self : HolonomicFunction, exp : Int) -> HolonomicFunction {
  if exp < 0 {
    return fallback_from_expr(self.to_expr(), self.x, self.x0)
  }
  let expr = expr_pow_int(self.to_expr(), exp)
  expr_to_holonomic(expr, x=self.x, x0=self.x0)
}

///|
pub impl Eq for HolonomicFunction with equal(self, other : HolonomicFunction) -> Bool {
  self.annihilator == other.annihilator &&
  self.x == other.x &&
  self.x0 == other.x0 &&
  self.y0 == other.y0 &&
  self.to_expr() == other.to_expr()
}

///|
pub impl Eq for HolonomicFunction with not_equal(self, other : HolonomicFunction) -> Bool {
  !self.equal(other)
}

///|
pub impl Show for HolonomicFunction with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_sympy_str())
}
