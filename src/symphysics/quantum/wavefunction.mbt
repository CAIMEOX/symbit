///|
/// Continuous-basis wavefunctions and differential operators for the
/// operator/state/qapply subset of `sympy.physics.quantum`.
///
/// The normalization helpers stay symbolic by building `Integral(...)`
/// expressions, while `qapply` on a `DifferentialOperator * Wavefunction`
/// genuinely substitutes the wavefunction into the operator expression and
/// evaluates explicit `Derivative(...)` nodes with `@symcalculus.diff`.

///|
pub struct WavefunctionExpr {
  expr : @symcore.Expr
  coords : Array[@symcore.Expr]
} derive(Eq)

///|
fn wavefunction_coord_var(coord : @symcore.Expr) -> @symcore.Expr {
  match coord {
    @symcore.Expr::Function("Tuple", args) if !args.is_empty() => args[0]
    _ => coord
  }
}

///|
fn wavefunction_coord_limit(
  coord : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr) {
  match coord {
    @symcore.Expr::Function("Tuple", args) if args.length() == 3 =>
      (args[1], args[2])
    _ => (@symcore.symbol("-oo"), @symcore.symbol("oo"))
  }
}

///|
pub fn wavefunction(
  expr : @symcore.Expr,
  coords : Array[@symcore.Expr],
) -> WavefunctionExpr {
  WavefunctionExpr::{ expr, coords }
}

///|
pub fn WavefunctionExpr::as_expr(self : WavefunctionExpr) -> @symcore.Expr {
  let args = [self.expr]
  for coord in self.coords {
    args.push(coord)
  }
  @symcore.raw_function("Wavefunction", args)
}

///|
pub fn WavefunctionExpr::variables(
  self : WavefunctionExpr,
) -> Array[@symcore.Expr] {
  self.coords.map(wavefunction_coord_var)
}

///|
pub fn WavefunctionExpr::limits(
  self : WavefunctionExpr,
) -> Map[String, (@symcore.Expr, @symcore.Expr)] {
  let out : Map[String, (@symcore.Expr, @symcore.Expr)] = {}
  for coord in self.coords {
    let coord_var = wavefunction_coord_var(coord)
    match coord_var {
      @symcore.Expr::Symbol(name) => out[name] = wavefunction_coord_limit(coord)
      _ => ()
    }
  }
  out
}

///|
pub fn WavefunctionExpr::repr(self : WavefunctionExpr) -> String {
  let args = [self.expr]
  for coord in self.coords {
    args.push(coord)
  }
  let rendered = args.map(quantum_repr_expr).join(",")
  "Wavefunction(\{rendered})"
}

///|
fn wavefunction_numeric_lt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  match (lhs, rhs) {
    (@symcore.Expr::Number(a), @symcore.Expr::Number(b)) => a.compare(b) < 0
    _ => false
  }
}

///|
fn wavefunction_numeric_gt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Bool {
  match (lhs, rhs) {
    (@symcore.Expr::Number(a), @symcore.Expr::Number(b)) => a.compare(b) > 0
    _ => false
  }
}

///|
fn wavefunction_numeric_pow(
  base : @symnum.BigRational,
  exp : Int,
) -> @symnum.BigRational {
  let mut out = @symnum.BigRational::one()
  for _ in 0..<exp {
    out = out.mul_r(base)
  }
  out
}

///|
fn wavefunction_simplify_mul(args : Array[@symcore.Expr]) -> @symcore.Expr {
  let base_expr = @symcore.mul(args)
  let factors = match base_expr {
    @symcore.Expr::Mul(items) => items.copy()
    _ => return base_expr
  }
  if factors.length() <= 1 {
    return base_expr
  }
  let removed = Array::make(factors.length(), false)
  for idx in 0..<factors.length() {
    if removed[idx] {
      continue
    }
    for jdx in (idx + 1)..<factors.length() {
      if removed[jdx] {
        continue
      }
      match (factors[idx], factors[jdx]) {
        (@symcore.Expr::Pow(base, @symcore.Expr::Number(n)), other) =>
          if n.is_integral() && n.numerator().to_int() == -1 && base == other {
            removed[idx] = true
            removed[jdx] = true
            break
          }
        (other, @symcore.Expr::Pow(base, @symcore.Expr::Number(n))) =>
          if n.is_integral() && n.numerator().to_int() == -1 && base == other {
            removed[idx] = true
            removed[jdx] = true
            break
          }
        _ => ()
      }
    }
  }
  let kept : Array[@symcore.Expr] = []
  for idx in 0..<factors.length() {
    if !removed[idx] {
      kept.push(factors[idx])
    }
  }
  let used = Array::make(kept.length(), false)
  let simplified : Array[@symcore.Expr] = []
  for idx in 0..<kept.length() {
    if used[idx] {
      continue
    }
    match kept[idx] {
      @symcore.Expr::Function("sqrt", args) if args.length() == 1 => {
        let mut paired = false
        for jdx in (idx + 1)..<kept.length() {
          if used[jdx] {
            continue
          }
          if kept[jdx] == kept[idx] {
            used[jdx] = true
            simplified.push(args[0])
            paired = true
            break
          }
        }
        if !paired {
          simplified.push(kept[idx])
        }
      }
      _ => simplified.push(kept[idx])
    }
  }
  @symcore.mul(simplified)
}

///|
fn wavefunction_simplify_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => expr
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(wavefunction_simplify_expr))
    @symcore.Expr::Mul(args) =>
      wavefunction_simplify_mul(args.map(wavefunction_simplify_expr))
    @symcore.Expr::Pow(base, exp) => {
      let sbase = wavefunction_simplify_expr(base)
      let sexp = wavefunction_simplify_expr(exp)
      match (sbase, sexp) {
        (@symcore.Expr::Number(b), @symcore.Expr::Number(e)) =>
          if e.is_integral() && e.numerator().to_int() >= 0 {
            @symcore.number(wavefunction_numeric_pow(b, e.numerator().to_int()))
          } else {
            @symcore.pow(sbase, sexp)
          }
        _ => @symcore.pow(sbase, sexp)
      }
    }
    @symcore.Expr::Function("sqrt", args) if args.length() == 1 => {
      let inner = wavefunction_simplify_expr(args[0])
      match inner {
        @symcore.Expr::Number(n) if n.is_zero() => @symcore.int(0)
        @symcore.Expr::Number(n) if n.is_one() => @symcore.int(1)
        _ => @symcore.raw_function("sqrt", [inner])
      }
    }
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_simplify_expr))
  }
}

///|
pub fn WavefunctionExpr::call(
  self : WavefunctionExpr,
  values : Array[@symcore.Expr],
  env? : Map[String, @symcore.Expr] = {},
) -> @symcore.Expr raise @symphysics.PhysicsError {
  let vars = self.variables()
  guard values.length() == vars.length() else {
    raise @symphysics.PhysicsError::ValueError(
      "Incorrect number of arguments to Wavefunction",
    )
  }
  for idx in 0..<self.coords.length() {
    let (lower, upper) = wavefunction_coord_limit(self.coords[idx])
    let value = values[idx]
    if wavefunction_numeric_lt(value, lower) ||
      wavefunction_numeric_gt(value, upper) {
      return @symcore.int(0)
    }
  }
  let subst_env : Map[String, @symcore.Expr] = {}
  for idx in 0..<vars.length() {
    match vars[idx] {
      @symcore.Expr::Symbol(name) => subst_env[name] = values[idx]
      _ => ()
    }
  }
  for entry in env {
    subst_env[entry.0] = entry.1
  }
  wavefunction_simplify_expr(@symcore.subst(self.expr, subst_env))
}

///|
pub fn WavefunctionExpr::prob(self : WavefunctionExpr) -> WavefunctionExpr {
  wavefunction(self.expr * expr_conjugate(self.expr), self.variables())
}

///|
pub fn WavefunctionExpr::norm_expr(self : WavefunctionExpr) -> @symcore.Expr {
  let mut integrand = self.expr * expr_conjugate(self.expr)
  for coord in self.coords {
    let coord_var = wavefunction_coord_var(coord)
    let (lower, upper) = wavefunction_coord_limit(coord)
    integrand = @symcore.raw_function("Integral", [
      integrand,
      @symcore.raw_function("Tuple", [coord_var, lower, upper]),
    ])
  }
  @symcore.raw_function("sqrt", [integrand])
}

///|
fn wavefunction_expr_contains_symbol(
  expr : @symcore.Expr,
  name : String,
) -> Bool {
  match expr {
    @symcore.Expr::Symbol(sym) => sym == name
    @symcore.Expr::Add(args)
    | @symcore.Expr::Mul(args)
    | @symcore.Expr::Function(_, args) =>
      args.any(arg => wavefunction_expr_contains_symbol(arg, name))
    @symcore.Expr::Pow(base, exp) =>
      wavefunction_expr_contains_symbol(base, name) ||
      wavefunction_expr_contains_symbol(exp, name)
    _ => false
  }
}

///|
fn wavefunction_realify_conjugates(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("conjugate", args) if args.length() == 1 =>
      wavefunction_realify_conjugates(args[0])
    @symcore.Expr::Add(args) =>
      @symcore.raw_add(args.map(wavefunction_realify_conjugates))
    @symcore.Expr::Mul(args) =>
      @symcore.raw_mul(args.map(wavefunction_realify_conjugates))
    @symcore.Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        wavefunction_realify_conjugates(base),
        wavefunction_realify_conjugates(exp),
      )
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_realify_conjugates))
    _ => expr
  }
}

///|
fn wavefunction_expand_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) =>
      quantum_add_from_args_preserve(args.map(wavefunction_expand_expr))
    @symcore.Expr::Mul(args) => {
      let partials : Array[@symcore.Expr] = [@symcore.int(1)]
      for arg in args {
        let expanded_arg = wavefunction_expand_expr(arg)
        let terms = match expanded_arg {
          @symcore.Expr::Add(items) => items.copy()
          _ => [expanded_arg]
        }
        let next : Array[@symcore.Expr] = []
        for partial in partials {
          for term in terms {
            next.push(
              wavefunction_simplify_expr(
                quantum_mul_from_args_preserve([partial, term]),
              ),
            )
          }
        }
        partials.clear()
        for item in next {
          partials.push(item)
        }
      }
      quantum_add_from_args_preserve(partials)
    }
    @symcore.Expr::Pow(base, @symcore.Expr::Number(n)) if n.is_integral() &&
      n.numerator().to_int() >= 0 => {
      let power = n.numerator().to_int()
      if power == 0 {
        @symcore.int(1)
      } else {
        let expanded_base = wavefunction_expand_expr(base)
        let mut out = expanded_base
        for _ in 1..<power {
          out = wavefunction_expand_expr(
            quantum_mul_from_args_preserve([out, expanded_base]),
          )
        }
        out
      }
    }
    @symcore.Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        wavefunction_expand_expr(base),
        wavefunction_expand_expr(exp),
      )
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_expand_expr))
    _ => expr
  }
}

///|
fn wavefunction_is_infinite_bound(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Symbol(name) => name == "oo" || name == "-oo"
    @symcore.Expr::Mul(args) if args.length() == 2 =>
      args[0] == @symcore.int(-1) && args[1] == @symcore.symbol("oo")
    _ => false
  }
}

///|
fn wavefunction_poly_term(
  expr : @symcore.Expr,
  var_name : String,
) -> (@symcore.Expr, Int)? {
  match expr {
    @symcore.Expr::Number(_) => Some((expr, 0))
    @symcore.Expr::Symbol(name) =>
      if name == var_name {
        Some((@symcore.int(1), 1))
      } else {
        Some((expr, 0))
      }
    @symcore.Expr::Pow(base, exp) =>
      match (base, exp) {
        (@symcore.Expr::Symbol(name), @symcore.Expr::Number(n)) =>
          if name == var_name && n.is_integral() && n.numerator().to_int() >= 0 {
            Some((@symcore.int(1), n.numerator().to_int()))
          } else if !wavefunction_expr_contains_symbol(expr, var_name) {
            Some((expr, 0))
          } else {
            None
          }
        _ =>
          if !wavefunction_expr_contains_symbol(expr, var_name) {
            Some((expr, 0))
          } else {
            None
          }
      }
    @symcore.Expr::Mul(args) => {
      let coeffs : Array[@symcore.Expr] = []
      let mut power = 0
      for arg in args {
        match wavefunction_poly_term(arg, var_name) {
          Some((coeff, arg_power)) => {
            power += arg_power
            if coeff != @symcore.int(1) {
              coeffs.push(coeff)
            }
          }
          None => return None
        }
      }
      Some((quantum_mul_from_args_preserve(coeffs), power))
    }
    _ =>
      if !wavefunction_expr_contains_symbol(expr, var_name) {
        Some((expr, 0))
      } else {
        None
      }
  }
}

///|
fn wavefunction_integrate_poly_term(
  coeff : @symcore.Expr,
  power : Int,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  if coeff == @symcore.int(0) {
    return Some(@symcore.int(0))
  }
  if wavefunction_is_infinite_bound(lower) ||
    wavefunction_is_infinite_bound(upper) {
    return Some(@symcore.symbol("oo"))
  }
  let next_power = power + 1
  let numerator = @symcore.raw_pow(upper, @symcore.int(next_power)) -
    @symcore.raw_pow(lower, @symcore.int(next_power))
  let reciprocal = @symcore.raw_pow(@symcore.int(next_power), @symcore.int(-1))
  Some(wavefunction_simplify_expr(coeff * numerator * reciprocal))
}

///|
fn wavefunction_integrate_polynomial(
  expr : @symcore.Expr,
  var_name : String,
  lower : @symcore.Expr,
  upper : @symcore.Expr,
) -> @symcore.Expr? {
  let expanded = wavefunction_expand_expr(wavefunction_simplify_expr(expr))
  match expanded {
    @symcore.Expr::Add(args) => {
      let terms : Array[@symcore.Expr] = []
      for arg in args {
        match wavefunction_integrate_polynomial(arg, var_name, lower, upper) {
          Some(value) => terms.push(value)
          None => return None
        }
      }
      Some(wavefunction_simplify_expr(quantum_add_from_args_preserve(terms)))
    }
    _ =>
      match wavefunction_poly_term(expanded, var_name) {
        Some((coeff, power)) =>
          wavefunction_integrate_poly_term(coeff, power, lower, upper)
        None => None
      }
  }
}

///|
fn wavefunction_norm_sq_of(wf : WavefunctionExpr) -> @symcore.Expr? {
  let mut integrand = wavefunction_realify_conjugates(
    wavefunction_simplify_expr(wf.expr * expr_conjugate(wf.expr)),
  )
  for coord in wf.coords {
    let coord_var = wavefunction_coord_var(coord)
    let (lower, upper) = wavefunction_coord_limit(coord)
    let var_name = match coord_var {
      @symcore.Expr::Symbol(name) => name
      _ => return None
    }
    match wavefunction_integrate_polynomial(integrand, var_name, lower, upper) {
      Some(value) => integrand = wavefunction_simplify_expr(value)
      None => return None
    }
  }
  Some(integrand)
}

///|
pub fn WavefunctionExpr::norm(self : WavefunctionExpr) -> @symcore.Expr {
  match wavefunction_norm_sq_of(self) {
    Some(value) if value == @symcore.symbol("oo") => value
    Some(value) =>
      wavefunction_simplify_expr(@symcore.raw_function("sqrt", [value]))
    None => self.norm_expr()
  }
}

///|
pub fn WavefunctionExpr::is_normalized(self : WavefunctionExpr) -> Bool {
  self.norm() == @symcore.int(1)
}

///|
pub fn WavefunctionExpr::normalize(self : WavefunctionExpr) -> WavefunctionExpr {
  let norm = self.norm()
  if norm == @symcore.int(1) {
    return self
  }
  wavefunction(
    @symcore.raw_pow(norm, @symcore.int(-1)) * self.expr,
    self.coords,
  )
}

///|
pub fn wavefunction_from_expr(expr : @symcore.Expr) -> WavefunctionExpr? {
  match expr {
    @symcore.Expr::Function("Wavefunction", args) if args.length() >= 2 => {
      let coords : Array[@symcore.Expr] = []
      for idx in 1..<args.length() {
        coords.push(args[idx])
      }
      Some(wavefunction(args[0], coords))
    }
    _ => None
  }
}

///|
pub struct DifferentialOperatorExpr {
  expr : @symcore.Expr
  function_expr : @symcore.Expr
} derive(Eq)

///|
pub fn differential_operator(
  expr : @symcore.Expr,
  function_expr : @symcore.Expr,
) -> DifferentialOperatorExpr {
  DifferentialOperatorExpr::{ expr, function_expr }
}

///|
pub fn DifferentialOperatorExpr::as_expr(
  self : DifferentialOperatorExpr,
) -> @symcore.Expr {
  @symcore.raw_function("DifferentialOperator", [self.expr, self.function_expr])
}

///|
pub fn DifferentialOperatorExpr::variables(
  self : DifferentialOperatorExpr,
) -> Array[@symcore.Expr] {
  match self.function_expr {
    @symcore.Expr::Function(_, args) => args
    _ => []
  }
}

///|
pub fn differential_operator_from_expr(
  expr : @symcore.Expr,
) -> DifferentialOperatorExpr? {
  match expr {
    @symcore.Expr::Function("DifferentialOperator", args) if args.length() == 2 =>
      Some(differential_operator(args[0], args[1]))
    _ => None
  }
}

///|
fn quantum_replace_exact(
  expr : @symcore.Expr,
  needle : @symcore.Expr,
  replacement : @symcore.Expr,
) -> @symcore.Expr {
  if expr == needle {
    return replacement
  }
  match expr {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => expr
    @symcore.Expr::Add(args) =>
      @symcore.raw_add(
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
    @symcore.Expr::Mul(args) =>
      @symcore.raw_mul(
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
    @symcore.Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        quantum_replace_exact(base, needle, replacement),
        quantum_replace_exact(exp, needle, replacement),
      )
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(
        name,
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
  }
}

///|
fn wavefunction_eval_derivatives(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => expr
    @symcore.Expr::Add(args) =>
      @symcore.add(args.map(wavefunction_eval_derivatives))
    @symcore.Expr::Mul(args) =>
      wavefunction_simplify_mul(args.map(wavefunction_eval_derivatives))
    @symcore.Expr::Pow(base, exp) =>
      wavefunction_simplify_expr(
        @symcore.raw_pow(
          wavefunction_eval_derivatives(base),
          wavefunction_eval_derivatives(exp),
        ),
      )
    @symcore.Expr::Function("Derivative", args) if args.length() >= 2 => {
      let base = wavefunction_eval_derivatives(args[0])
      let mut out = base
      let mut last_var : @symcore.Expr? = None
      for idx in 1..<args.length() {
        match args[idx] {
          @symcore.Expr::Number(n) if n.is_integral() &&
            n.numerator().to_int() >= 0 =>
            match last_var {
              Some(diff_var) =>
                for _ in 1..<n.numerator().to_int() {
                  out = @symcalculus.diff(out, diff_var)
                }
              None => ()
            }
          diff_var => {
            out = @symcalculus.diff(out, diff_var)
            last_var = Some(diff_var)
          }
        }
      }
      wavefunction_simplify_expr(out)
    }
    @symcore.Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_eval_derivatives))
  }
}

///|
pub fn differential_operator_apply_to_wavefunction(
  op_expr : @symcore.Expr,
  wf_expr : @symcore.Expr,
) -> @symcore.Expr? {
  match
    (differential_operator_from_expr(op_expr), wavefunction_from_expr(wf_expr)) {
    (Some(op), Some(wf)) => {
      let vars = op.variables()
      let wf_vars = wf.variables()
      let body = if vars.length() == wf_vars.length() {
        let env : Map[String, @symcore.Expr] = {}
        for idx in 0..<vars.length() {
          match wf_vars[idx] {
            @symcore.Expr::Symbol(name) => env[name] = vars[idx]
            _ => ()
          }
        }
        @symcore.subst(wf.expr, env)
      } else {
        wf.expr
      }
      let substituted = quantum_replace_exact(op.expr, op.function_expr, body)
      Some(
        wavefunction(
          wavefunction_simplify_expr(wavefunction_eval_derivatives(substituted)),
          wf.coords,
        ).as_expr(),
      )
    }
    _ => None
  }
}
