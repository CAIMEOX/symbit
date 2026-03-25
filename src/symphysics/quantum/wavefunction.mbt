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
  expr : Expr
  coords : Array[Expr]
} derive(Eq)

///|
fn wavefunction_coord_var(coord : Expr) -> Expr {
  match @symcore.tuple_items(coord) {
    Some(args) if !args.is_empty() => args[0]
    _ => coord
  }
}

///|
fn wavefunction_coord_limit(coord : Expr) -> (Expr, Expr) {
  match @symcore.tuple_items(coord) {
    Some(args) if args.length() == 3 => (args[1], args[2])
    _ => (@symcore.neg_oo(), @symcore.oo())
  }
}

///|
pub fn wavefunction(expr : Expr, coords : Array[Expr]) -> WavefunctionExpr {
  WavefunctionExpr::{ expr, coords }
}

///|
pub fn WavefunctionExpr::as_expr(self : WavefunctionExpr) -> Expr {
  let args = [self.expr]
  for coord in self.coords {
    args.push(coord)
  }
  @symcore.raw_function("Wavefunction", args)
}

///|
pub fn WavefunctionExpr::variables(self : WavefunctionExpr) -> Array[Expr] {
  self.coords.map(wavefunction_coord_var)
}

///|
pub fn WavefunctionExpr::limits(
  self : WavefunctionExpr,
) -> Map[String, (Expr, Expr)] {
  let out : Map[String, (Expr, Expr)] = {}
  for coord in self.coords {
    let coord_var = wavefunction_coord_var(coord)
    match coord_var {
      Expr::Symbol(name) => out[name] = wavefunction_coord_limit(coord)
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
fn wavefunction_numeric_lt(lhs : Expr, rhs : Expr) -> Bool {
  match (@symcore.expr_form(lhs), @symcore.expr_form(rhs)) {
    (@symcore.ExprForm::Number(a), @symcore.ExprForm::Number(b)) =>
      a.compare(b) < 0
    (@symcore.ExprForm::Float(a), @symcore.ExprForm::Float(b)) =>
      @symnum.mpf_cmp(a.to_mpf(), b.to_mpf()) < 0
    (@symcore.ExprForm::Number(a), @symcore.ExprForm::Float(b)) => {
      let fa = @symcore.Float::from_rational(
        a.numerator(),
        a.denominator(),
        b.precision(),
      ) catch {
        _ => return false
      }
      @symnum.mpf_cmp(fa.to_mpf(), b.to_mpf()) < 0
    }
    (@symcore.ExprForm::Float(a), @symcore.ExprForm::Number(b)) => {
      let fb = @symcore.Float::from_rational(
        b.numerator(),
        b.denominator(),
        a.precision(),
      ) catch {
        _ => return false
      }
      @symnum.mpf_cmp(a.to_mpf(), fb.to_mpf()) < 0
    }
    _ => false
  }
}

///|
fn wavefunction_numeric_gt(lhs : Expr, rhs : Expr) -> Bool {
  match (@symcore.expr_form(lhs), @symcore.expr_form(rhs)) {
    (@symcore.ExprForm::Number(a), @symcore.ExprForm::Number(b)) =>
      a.compare(b) > 0
    (@symcore.ExprForm::Float(a), @symcore.ExprForm::Float(b)) =>
      @symnum.mpf_cmp(a.to_mpf(), b.to_mpf()) > 0
    (@symcore.ExprForm::Number(a), @symcore.ExprForm::Float(b)) => {
      let fa = @symcore.Float::from_rational(
        a.numerator(),
        a.denominator(),
        b.precision(),
      ) catch {
        _ => return false
      }
      @symnum.mpf_cmp(fa.to_mpf(), b.to_mpf()) > 0
    }
    (@symcore.ExprForm::Float(a), @symcore.ExprForm::Number(b)) => {
      let fb = @symcore.Float::from_rational(
        b.numerator(),
        b.denominator(),
        a.precision(),
      ) catch {
        _ => return false
      }
      @symnum.mpf_cmp(a.to_mpf(), fb.to_mpf()) > 0
    }
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
fn wavefunction_simplify_mul(args : Array[Expr]) -> Expr {
  let base_expr = @symcore.mul(args)
  let factors = match base_expr {
    Expr::Mul(items) => items.copy()
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
        (Expr::Pow(base, Expr::Number(n)), other) =>
          if n.is_integral() && n.numerator().to_int() == -1 && base == other {
            removed[idx] = true
            removed[jdx] = true
            break
          }
        (other, Expr::Pow(base, Expr::Number(n))) =>
          if n.is_integral() && n.numerator().to_int() == -1 && base == other {
            removed[idx] = true
            removed[jdx] = true
            break
          }
        _ => ()
      }
    }
  }
  let kept : Array[Expr] = []
  for idx in 0..<factors.length() {
    if !removed[idx] {
      kept.push(factors[idx])
    }
  }
  let used = Array::make(kept.length(), false)
  let simplified : Array[Expr] = []
  for idx in 0..<kept.length() {
    if used[idx] {
      continue
    }
    match kept[idx] {
      Expr::Function("sqrt", args) if args.length() == 1 => {
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
      Expr::Pow(Expr::Function("sqrt", args), Expr::Number(n)) =>
        if args.length() == 1 && n.is_integral() && n.numerator().to_int() == 2 {
          simplified.push(args[0])
        } else {
          simplified.push(kept[idx])
        }
      _ => simplified.push(kept[idx])
    }
  }
  @symcore.mul(simplified)
}

///|
fn wavefunction_simplify_expr(expr : Expr) -> Expr {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::NumberSymbol(_)
    | @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_)
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_)
    | @symcore.ExprForm::Boolean(_) => expr
    @symcore.ExprForm::AppliedUndef(name, args) =>
      @symcore.applied_undefined_function(
        name,
        args.map(wavefunction_simplify_expr),
      )
    @symcore.ExprForm::Add(args) =>
      @symcore.add(args.map(wavefunction_simplify_expr))
    @symcore.ExprForm::Mul(args) =>
      wavefunction_simplify_mul(args.map(wavefunction_simplify_expr))
    @symcore.ExprForm::Pow(base, exp) => {
      let sbase = wavefunction_simplify_expr(base)
      let sexp = wavefunction_simplify_expr(exp)
      match (sbase, sexp) {
        (Expr::Pow(inner_base, Expr::Number(inner_exp)), Expr::Number(outer_exp)
        ) =>
          if inner_exp.is_integral() && outer_exp.is_integral() {
            @symcore.pow(
              inner_base,
              int(
                inner_exp.numerator().to_int() * outer_exp.numerator().to_int(),
              ),
            )
          } else {
            @symcore.pow(sbase, sexp)
          }
        (Expr::Function("sqrt", args), Expr::Number(e)) =>
          if args.length() == 1 &&
            e.is_integral() &&
            e.numerator().to_int() == 2 {
            args[0]
          } else {
            @symcore.pow(sbase, sexp)
          }
        (Expr::Number(b), Expr::Number(e)) =>
          if e.is_integral() && e.numerator().to_int() >= 0 {
            @symcore.number(wavefunction_numeric_pow(b, e.numerator().to_int()))
          } else {
            @symcore.pow(sbase, sexp)
          }
        _ => @symcore.pow(sbase, sexp)
      }
    }
    @symcore.ExprForm::Mod(lhs, rhs) =>
      @symcore.mod_expr(
        wavefunction_simplify_expr(lhs),
        wavefunction_simplify_expr(rhs),
      )
    @symcore.ExprForm::Applied("sqrt", args) if args.length() == 1 => {
      let inner = wavefunction_simplify_expr(args[0])
      match inner {
        Expr::Number(n) if n.is_zero() => int(0)
        Expr::Number(n) if n.is_one() => int(1)
        _ => @symcore.raw_function("sqrt", [inner])
      }
    }
    @symcore.ExprForm::Tuple(args) =>
      @symcore.tuple_expr(args.map(wavefunction_simplify_expr))
    @symcore.ExprForm::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (wavefunction_simplify_expr(key), wavefunction_simplify_expr(value)),
        )
      }
      @symcore.dict_expr(out)
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          @symcore.eq(
            wavefunction_simplify_expr(lhs),
            wavefunction_simplify_expr(rhs),
          )
        @symcore.RelOp::Ne =>
          @symcore.ne(
            wavefunction_simplify_expr(lhs),
            wavefunction_simplify_expr(rhs),
          )
        @symcore.RelOp::Lt =>
          @symcore.lt(
            wavefunction_simplify_expr(lhs),
            wavefunction_simplify_expr(rhs),
          )
        @symcore.RelOp::Le =>
          @symcore.le(
            wavefunction_simplify_expr(lhs),
            wavefunction_simplify_expr(rhs),
          )
        @symcore.RelOp::Gt =>
          @symcore.gt(
            wavefunction_simplify_expr(lhs),
            wavefunction_simplify_expr(rhs),
          )
        @symcore.RelOp::Ge =>
          @symcore.ge(
            wavefunction_simplify_expr(lhs),
            wavefunction_simplify_expr(rhs),
          )
      }
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let args : Array[Expr] = [wavefunction_simplify_expr(inner)]
      for arg in deriv_args {
        args.push(wavefunction_simplify_expr(arg))
      }
      @symcore.raw_derivative(args[0], args[1:])
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        wavefunction_simplify_expr(inner),
        wavefunction_simplify_expr(variable),
        wavefunction_simplify_expr(value),
      )
    @symcore.ExprForm::Lambda(vars, body) =>
      @symcore.lambda_expr(
        wavefunction_simplify_expr(vars),
        wavefunction_simplify_expr(body),
      )
    @symcore.ExprForm::Applied(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_simplify_expr))
  }
}

///|
pub fn WavefunctionExpr::call(
  self : WavefunctionExpr,
  values : Array[Expr],
  env? : Map[String, Expr] = {},
) -> Expr raise @symphysics.PhysicsError {
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
      return int(0)
    }
  }
  let subst_env : Map[String, Expr] = {}
  for idx in 0..<vars.length() {
    match vars[idx] {
      Expr::Symbol(name) => subst_env[name] = values[idx]
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
pub fn WavefunctionExpr::norm_expr(self : WavefunctionExpr) -> Expr {
  let mut integrand = self.expr * expr_conjugate(self.expr)
  for coord in self.coords {
    let coord_var = wavefunction_coord_var(coord)
    let (lower, upper) = wavefunction_coord_limit(coord)
    integrand = @symcore.raw_function("Integral", [
      integrand,
      @symcore.tuple_expr([coord_var, lower, upper]),
    ])
  }
  @symcore.raw_function("sqrt", [integrand])
}

///|
fn wavefunction_expr_contains_symbol(expr : Expr, name : String) -> Bool {
  match expr {
    Expr::Symbol(sym) => sym == name
    Expr::Add(args) | Expr::Mul(args) | Expr::Function(_, args) =>
      args.any(arg => wavefunction_expr_contains_symbol(arg, name))
    Expr::Pow(base, exp) =>
      wavefunction_expr_contains_symbol(base, name) ||
      wavefunction_expr_contains_symbol(exp, name)
    _ => false
  }
}

///|
fn wavefunction_realify_conjugates(expr : Expr) -> Expr {
  match expr {
    Expr::Function("conjugate", args) if args.length() == 1 =>
      wavefunction_realify_conjugates(args[0])
    Expr::Add(args) =>
      @symcore.raw_add(args.map(wavefunction_realify_conjugates))
    Expr::Mul(args) =>
      @symcore.raw_mul(args.map(wavefunction_realify_conjugates))
    Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        wavefunction_realify_conjugates(base),
        wavefunction_realify_conjugates(exp),
      )
    Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_realify_conjugates))
    _ => expr
  }
}

///|
fn wavefunction_expand_expr(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      quantum_add_from_args_preserve(args.map(wavefunction_expand_expr))
    Expr::Mul(args) => {
      let partials : Array[Expr] = [int(1)]
      for arg in args {
        let expanded_arg = wavefunction_expand_expr(arg)
        let terms = match expanded_arg {
          Expr::Add(items) => items.copy()
          _ => [expanded_arg]
        }
        let next : Array[Expr] = []
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
    Expr::Pow(base, Expr::Number(n)) if n.is_integral() &&
      n.numerator().to_int() >= 0 => {
      let power = n.numerator().to_int()
      if power == 0 {
        int(1)
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
    Expr::Pow(base, exp) =>
      @symcore.raw_pow(
        wavefunction_expand_expr(base),
        wavefunction_expand_expr(exp),
      )
    Expr::Function(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_expand_expr))
    _ => expr
  }
}

///|
fn wavefunction_is_infinite_bound(expr : Expr) -> Bool {
  match expr {
    Expr::Symbol(name) => name == "oo" || name == "-oo"
    Expr::Mul(args) if args.length() == 2 =>
      args[0] == int(-1) && args[1] == @symcore.oo()
    _ => false
  }
}

///|
fn wavefunction_poly_term(expr : Expr, var_name : String) -> (Expr, Int)? {
  match expr {
    Expr::Number(_) => Some((expr, 0))
    Expr::Symbol(name) =>
      if name == var_name {
        Some((int(1), 1))
      } else {
        Some((expr, 0))
      }
    Expr::Pow(base, exp) =>
      match (base, exp) {
        (Expr::Symbol(name), Expr::Number(n)) =>
          if name == var_name && n.is_integral() && n.numerator().to_int() >= 0 {
            Some((int(1), n.numerator().to_int()))
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
    Expr::Mul(args) => {
      let coeffs : Array[Expr] = []
      let mut power = 0
      for arg in args {
        match wavefunction_poly_term(arg, var_name) {
          Some((coeff, arg_power)) => {
            power += arg_power
            if coeff != int(1) {
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
  coeff : Expr,
  power : Int,
  lower : Expr,
  upper : Expr,
) -> Expr? {
  if coeff == int(0) {
    return Some(int(0))
  }
  if wavefunction_is_infinite_bound(lower) ||
    wavefunction_is_infinite_bound(upper) {
    return Some(@symcore.oo())
  }
  let next_power = power + 1
  let numerator = @symcore.raw_pow(upper, int(next_power)) -
    @symcore.raw_pow(lower, int(next_power))
  let reciprocal = @symcore.raw_pow(int(next_power), int(-1))
  Some(wavefunction_simplify_expr(coeff * numerator * reciprocal))
}

///|
fn wavefunction_integrate_polynomial(
  expr : Expr,
  var_name : String,
  lower : Expr,
  upper : Expr,
) -> Expr? {
  let expanded = wavefunction_expand_expr(wavefunction_simplify_expr(expr))
  match expanded {
    Expr::Add(args) => {
      let terms : Array[Expr] = []
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
fn wavefunction_norm_sq_of(wf : WavefunctionExpr) -> Expr? {
  let mut integrand = wavefunction_realify_conjugates(
    wavefunction_simplify_expr(wf.expr * expr_conjugate(wf.expr)),
  )
  for coord in wf.coords {
    let coord_var = wavefunction_coord_var(coord)
    let (lower, upper) = wavefunction_coord_limit(coord)
    let var_name = match coord_var {
      Expr::Symbol(name) => name
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
pub fn WavefunctionExpr::norm(self : WavefunctionExpr) -> Expr {
  match wavefunction_norm_sq_of(self) {
    Some(value) if value == @symcore.oo() => value
    Some(value) =>
      wavefunction_simplify_expr(@symcore.raw_function("sqrt", [value]))
    None => self.norm_expr()
  }
}

///|
pub fn WavefunctionExpr::is_normalized(self : WavefunctionExpr) -> Bool {
  let simplified_norm = wavefunction_simplify_expr(self.norm())
  if simplified_norm == int(1) {
    return true
  }
  match wavefunction_norm_sq_of(self) {
    Some(value) => wavefunction_simplify_expr(value) == int(1)
    None => false
  }
}

///|
pub fn WavefunctionExpr::normalize(self : WavefunctionExpr) -> WavefunctionExpr {
  let norm = wavefunction_simplify_expr(self.norm())
  if self.is_normalized() {
    return self
  }
  wavefunction(@symcore.raw_pow(norm, int(-1)) * self.expr, self.coords)
}

///|
pub fn wavefunction_from_expr(expr : Expr) -> WavefunctionExpr? {
  match expr {
    Expr::Function("Wavefunction", args) if args.length() >= 2 => {
      let coords : Array[Expr] = []
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
  expr : Expr
  function_expr : Expr
} derive(Eq)

///|
pub fn differential_operator(
  expr : Expr,
  function_expr : Expr,
) -> DifferentialOperatorExpr {
  DifferentialOperatorExpr::{ expr, function_expr }
}

///|
pub fn DifferentialOperatorExpr::as_expr(
  self : DifferentialOperatorExpr,
) -> Expr {
  @symcore.raw_function("DifferentialOperator", [self.expr, self.function_expr])
}

///|
pub fn DifferentialOperatorExpr::variables(
  self : DifferentialOperatorExpr,
) -> Array[Expr] {
  match self.function_expr {
    Expr::Function(_, args) => args
    _ => []
  }
}

///|
pub fn differential_operator_from_expr(
  expr : Expr,
) -> DifferentialOperatorExpr? {
  match expr {
    Expr::Function("DifferentialOperator", args) if args.length() == 2 =>
      Some(differential_operator(args[0], args[1]))
    _ => None
  }
}

///|
fn quantum_replace_exact(
  expr : Expr,
  needle : Expr,
  replacement : Expr,
) -> Expr {
  if expr == needle {
    return replacement
  }
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::NumberSymbol(_)
    | @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_)
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_)
    | @symcore.ExprForm::Boolean(_) => expr
    @symcore.ExprForm::AppliedUndef(name, args) =>
      @symcore.applied_undefined_function(
        name,
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
    @symcore.ExprForm::Add(args) =>
      @symcore.raw_add(
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
    @symcore.ExprForm::Mul(args) =>
      @symcore.raw_mul(
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
    @symcore.ExprForm::Pow(base, exp) =>
      @symcore.raw_pow(
        quantum_replace_exact(base, needle, replacement),
        quantum_replace_exact(exp, needle, replacement),
      )
    @symcore.ExprForm::Mod(lhs, rhs) =>
      @symcore.raw_mod_expr(
        quantum_replace_exact(lhs, needle, replacement),
        quantum_replace_exact(rhs, needle, replacement),
      )
    @symcore.ExprForm::Tuple(args) =>
      @symcore.tuple_expr(
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
    @symcore.ExprForm::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (
            quantum_replace_exact(key, needle, replacement),
            quantum_replace_exact(value, needle, replacement),
          ),
        )
      }
      @symcore.dict_expr(out)
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          @symcore.eq(
            quantum_replace_exact(lhs, needle, replacement),
            quantum_replace_exact(rhs, needle, replacement),
          )
        @symcore.RelOp::Ne =>
          @symcore.ne(
            quantum_replace_exact(lhs, needle, replacement),
            quantum_replace_exact(rhs, needle, replacement),
          )
        @symcore.RelOp::Lt =>
          @symcore.lt(
            quantum_replace_exact(lhs, needle, replacement),
            quantum_replace_exact(rhs, needle, replacement),
          )
        @symcore.RelOp::Le =>
          @symcore.le(
            quantum_replace_exact(lhs, needle, replacement),
            quantum_replace_exact(rhs, needle, replacement),
          )
        @symcore.RelOp::Gt =>
          @symcore.gt(
            quantum_replace_exact(lhs, needle, replacement),
            quantum_replace_exact(rhs, needle, replacement),
          )
        @symcore.RelOp::Ge =>
          @symcore.ge(
            quantum_replace_exact(lhs, needle, replacement),
            quantum_replace_exact(rhs, needle, replacement),
          )
      }
    @symcore.ExprForm::Derivative(inner, deriv_args) => {
      let args : Array[Expr] = [
        quantum_replace_exact(inner, needle, replacement),
      ]
      for arg in deriv_args {
        args.push(quantum_replace_exact(arg, needle, replacement))
      }
      @symcore.raw_derivative(args[0], args[1:])
    }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        quantum_replace_exact(inner, needle, replacement),
        quantum_replace_exact(variable, needle, replacement),
        quantum_replace_exact(value, needle, replacement),
      )
    @symcore.ExprForm::Lambda(vars, body) =>
      @symcore.lambda_expr(
        quantum_replace_exact(vars, needle, replacement),
        quantum_replace_exact(body, needle, replacement),
      )
    @symcore.ExprForm::Applied(name, args) =>
      @symcore.raw_function(
        name,
        args.map(arg => quantum_replace_exact(arg, needle, replacement)),
      )
  }
}

///|
fn wavefunction_eval_derivatives(expr : Expr) -> Expr {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::NumberSymbol(_)
    | @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_)
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_)
    | @symcore.ExprForm::Boolean(_) => expr
    @symcore.ExprForm::AppliedUndef(name, args) =>
      @symcore.applied_undefined_function(
        name,
        args.map(wavefunction_eval_derivatives),
      )
    @symcore.ExprForm::Add(args) =>
      @symcore.add(args.map(wavefunction_eval_derivatives))
    @symcore.ExprForm::Mul(args) =>
      wavefunction_simplify_mul(args.map(wavefunction_eval_derivatives))
    @symcore.ExprForm::Pow(base, exp) =>
      wavefunction_simplify_expr(
        @symcore.raw_pow(
          wavefunction_eval_derivatives(base),
          wavefunction_eval_derivatives(exp),
        ),
      )
    @symcore.ExprForm::Mod(lhs, rhs) =>
      wavefunction_simplify_expr(
        @symcore.raw_mod_expr(
          wavefunction_eval_derivatives(lhs),
          wavefunction_eval_derivatives(rhs),
        ),
      )
    @symcore.ExprForm::Derivative(inner, deriv_args) =>
      if deriv_args.length() >= 1 {
        let base = wavefunction_eval_derivatives(inner)
        let mut out = base
        let mut last_var : Expr? = None
        for arg in deriv_args {
          match arg {
            Expr::Number(n) if n.is_integral() && n.numerator().to_int() >= 0 =>
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
      } else {
        @symcore.raw_derivative(wavefunction_eval_derivatives(inner), [])
      }
    @symcore.ExprForm::Tuple(args) =>
      @symcore.tuple_expr(args.map(wavefunction_eval_derivatives))
    @symcore.ExprForm::Dict(items) => {
      let out : Array[(Expr, Expr)] = []
      for item in items {
        let (key, value) = item
        out.push(
          (
            wavefunction_eval_derivatives(key),
            wavefunction_eval_derivatives(value),
          ),
        )
      }
      @symcore.dict_expr(out)
    }
    @symcore.ExprForm::Relational(op, lhs, rhs) =>
      match op {
        @symcore.RelOp::Eq =>
          @symcore.eq(
            wavefunction_eval_derivatives(lhs),
            wavefunction_eval_derivatives(rhs),
          )
        @symcore.RelOp::Ne =>
          @symcore.ne(
            wavefunction_eval_derivatives(lhs),
            wavefunction_eval_derivatives(rhs),
          )
        @symcore.RelOp::Lt =>
          @symcore.lt(
            wavefunction_eval_derivatives(lhs),
            wavefunction_eval_derivatives(rhs),
          )
        @symcore.RelOp::Le =>
          @symcore.le(
            wavefunction_eval_derivatives(lhs),
            wavefunction_eval_derivatives(rhs),
          )
        @symcore.RelOp::Gt =>
          @symcore.gt(
            wavefunction_eval_derivatives(lhs),
            wavefunction_eval_derivatives(rhs),
          )
        @symcore.RelOp::Ge =>
          @symcore.ge(
            wavefunction_eval_derivatives(lhs),
            wavefunction_eval_derivatives(rhs),
          )
      }
    @symcore.ExprForm::Subs(inner, variable, value) =>
      @symcore.subs_expr(
        wavefunction_eval_derivatives(inner),
        wavefunction_eval_derivatives(variable),
        wavefunction_eval_derivatives(value),
      )
    @symcore.ExprForm::Lambda(vars, body) =>
      @symcore.lambda_expr(
        wavefunction_eval_derivatives(vars),
        wavefunction_eval_derivatives(body),
      )
    @symcore.ExprForm::Applied(name, args) =>
      @symcore.raw_function(name, args.map(wavefunction_eval_derivatives))
  }
}

///|
pub fn differential_operator_apply_to_wavefunction(
  op_expr : Expr,
  wf_expr : Expr,
) -> Expr? {
  match
    (differential_operator_from_expr(op_expr), wavefunction_from_expr(wf_expr)) {
    (Some(op), Some(wf)) => {
      let vars = op.variables()
      let wf_vars = wf.variables()
      let body = if vars.length() == wf_vars.length() {
        let env : Map[String, Expr] = {}
        for idx in 0..<vars.length() {
          match wf_vars[idx] {
            Expr::Symbol(name) => env[name] = vars[idx]
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
