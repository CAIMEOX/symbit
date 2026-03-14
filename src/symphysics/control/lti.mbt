///|
/// Core SISO LTI object model aligned with the high-value surface of
/// `sympy.physics.control.lti`.

///|
pub suberror ControlError {
  ValueError(String)
  TypeError(String)
  ShapeError(String)
  NotImplemented(String)
} derive(Show, Eq)

///|
pub struct TransferFunction {
  num_ : @symcore.Expr
  den_ : @symcore.Expr
  var_ : @symcore.Expr
} derive(Eq)

///|
pub struct DiscreteTransferFunction {
  num_ : @symcore.Expr
  den_ : @symcore.Expr
  var_ : @symcore.Expr
  sampling_time_ : @symcore.Expr
} derive(Eq)

///|
pub struct PIDController {
  kp_ : @symcore.Expr
  ki_ : @symcore.Expr
  kd_ : @symcore.Expr
  tf_ : @symcore.Expr
  var_ : @symcore.Expr
} derive(Eq)

///|
pub struct Series {
  args_ : Array[SISOLinearTimeInvariant]
} derive(Eq)

///|
pub struct Parallel {
  args_ : Array[SISOLinearTimeInvariant]
} derive(Eq)

///|
pub struct Feedback {
  sys1_ : SISOLinearTimeInvariant
  sys2_ : SISOLinearTimeInvariant
  sign_ : Int
} derive(Eq)

///|
pub enum SISOLinearTimeInvariant {
  TF(TransferFunction)
  DTF(DiscreteTransferFunction)
  PID(PIDController)
  SeriesLTI(Series)
  ParallelLTI(Parallel)
  FeedbackLTI(Feedback)
} derive(Eq)

///|
fn control_var_name(var_expr : @symcore.Expr) -> String raise ControlError {
  match var_expr {
    @symcore.Expr::Symbol(name) => name
    _ => raise ControlError::TypeError("control variable should be a symbol")
  }
}

///|
fn control_expr_is_zero(expr : @symcore.Expr) -> Bool {
  control_normalize(expr) == @symcore.int(0)
}

///|
fn control_expr_is_one(expr : @symcore.Expr) -> Bool {
  control_normalize(expr) == @symcore.int(1)
}

///|
fn control_negated_factor(expr : @symcore.Expr) -> @symcore.Expr? {
  match control_normalize(expr) {
    @symcore.Expr::Mul(args) if args.length() == 2 &&
      args[0] == @symcore.int(-1) => Some(args[1])
    _ => None
  }
}

///|
fn control_expand_mul_pair(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> @symcore.Expr {
  match (lhs, rhs) {
    (@symcore.Expr::Add(lhs_args), @symcore.Expr::Add(rhs_args)) => {
      let out : Array[@symcore.Expr] = []
      for a in lhs_args {
        for b in rhs_args {
          out.push(control_expand_expr(a * b))
        }
      }
      @symcore.add(out)
    }
    (@symcore.Expr::Add(lhs_args), _) =>
      @symcore.add(lhs_args.map(a => control_expand_expr(a * rhs)))
    (_, @symcore.Expr::Add(rhs_args)) =>
      @symcore.add(rhs_args.map(b => control_expand_expr(lhs * b)))
    _ => lhs * rhs
  }
}

///|
fn control_expand_pow(base : @symcore.Expr, exp : Int) -> @symcore.Expr {
  if exp < 0 {
    return @symcore.pow(control_expand_expr(base), @symcore.int(exp))
  }
  let mut out = @symcore.int(1)
  for _ in 0..<exp {
    out = control_expand_mul_pair(out, control_expand_expr(base))
  }
  out
}

///|
fn control_expand_expr(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Add(args) => @symcore.add(args.map(control_expand_expr))
    @symcore.Expr::Mul(args) => {
      let mut acc = @symcore.int(1)
      for arg in args {
        acc = control_expand_mul_pair(acc, control_expand_expr(arg))
      }
      acc
    }
    @symcore.Expr::Pow(base, @symcore.Expr::Number(n)) if n.is_integral() =>
      control_expand_pow(base, n.numerator().to_int())
    @symcore.Expr::Pow(base, exp) =>
      @symcore.pow(control_expand_expr(base), control_expand_expr(exp))
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(control_expand_expr))
    _ => expr
  }
}

///|
fn control_expr_from_coeffs(
  coeffs : Array[@symcore.Expr],
  var_expr : @symcore.Expr,
) -> @symcore.Expr {
  let degree = coeffs.length() - 1
  let terms : Array[@symcore.Expr] = []
  for i in 0..<coeffs.length() {
    let coeff = coeffs[i]
    let power = degree - i
    let term = if power == 0 {
      coeff
    } else if power == 1 {
      coeff * var_expr
    } else {
      coeff * (var_expr ^ @symcore.int(power))
    }
    terms.push(term)
  }
  control_normalize(@symcore.add(terms))
}

///|
fn control_fraction_mul(
  lhs : (@symcore.Expr, @symcore.Expr),
  rhs : (@symcore.Expr, @symcore.Expr),
) -> (@symcore.Expr, @symcore.Expr) {
  (control_normalize(lhs.0 * rhs.0), control_normalize(lhs.1 * rhs.1))
}

///|
fn control_fraction_add(
  lhs : (@symcore.Expr, @symcore.Expr),
  rhs : (@symcore.Expr, @symcore.Expr),
) -> (@symcore.Expr, @symcore.Expr) {
  (
    control_normalize(lhs.0 * rhs.1 + rhs.0 * lhs.1),
    control_normalize(lhs.1 * rhs.1),
  )
}

///|
fn control_fraction_pow(
  value : (@symcore.Expr, @symcore.Expr),
  power : Int,
) -> (@symcore.Expr, @symcore.Expr) {
  if power == 0 {
    return (@symcore.int(1), @symcore.int(1))
  }
  if power < 0 {
    let pos = control_fraction_pow(value, -power)
    return (pos.1, pos.0)
  }
  let mut out = (@symcore.int(1), @symcore.int(1))
  for _ in 0..<power {
    out = control_fraction_mul(out, value)
  }
  out
}

///|
fn control_rational_parts(
  expr : @symcore.Expr,
  variable_name : String,
) -> (@symcore.Expr, @symcore.Expr) raise ControlError {
  match expr {
    @symcore.Expr::Number(_) => (expr, @symcore.int(1))
    @symcore.Expr::Symbol(name) =>
      if name == variable_name {
        (expr, @symcore.int(1))
      } else {
        (expr, @symcore.int(1))
      }
    @symcore.Expr::Add(args) => {
      let mut out = (@symcore.int(0), @symcore.int(1))
      for arg in args {
        out = control_fraction_add(
          out,
          control_rational_parts(arg, variable_name),
        )
      }
      out
    }
    @symcore.Expr::Mul(args) => {
      let mut out = (@symcore.int(1), @symcore.int(1))
      for arg in args {
        out = control_fraction_mul(
          out,
          control_rational_parts(arg, variable_name),
        )
      }
      out
    }
    @symcore.Expr::Pow(base, @symcore.Expr::Number(n)) if n.is_integral() =>
      control_fraction_pow(
        control_rational_parts(base, variable_name),
        n.numerator().to_int(),
      )
    @symcore.Expr::Pow(_, _) => (expr, @symcore.int(1))
    @symcore.Expr::Function("exp", [arg]) if control_expr_depends_on_symbol(
        expr, variable_name,
      ) =>
      match control_negated_factor(arg) {
        Some(inner) => (@symcore.int(1), @symcore.function("exp", [inner]))
        None => (expr, @symcore.int(1))
      }
    @symcore.Expr::Function(_, _) => (expr, @symcore.int(1))
  }
}

///|
fn control_poly_degree(
  expr : @symcore.Expr,
  variable_name : String,
) -> Int raise ControlError {
  match (try? poly_from_expr(expr, variable_name)) {
    Ok(poly) => coeff_array(poly).0
    Err(_) => {
      if control_expr_depends_on_symbol(expr, variable_name) {
        raise ControlError::NotImplemented(
          "requires polynomial numerator/denominator",
        )
      }
      0
    }
  }
}

///|
fn control_poly_roots(
  expr : @symcore.Expr,
  variable_name : String,
) -> Array[@symcore.Expr] raise ControlError {
  if control_expr_is_zero(expr) {
    return []
  }
  let poly = @sympolys.Poly::from_expr_defaults(expr, gens=[variable_name]) catch {
    _ =>
      raise ControlError::NotImplemented(
        "requires polynomial numerator/denominator",
      )
  }
  @sympolys.roots(poly).map(control_normalize) catch {
    _ =>
      raise ControlError::NotImplemented(
        "root finding not available for this polynomial",
      )
  }
}

///|
fn control_tf_expr(
  numerator : @symcore.Expr,
  denominator : @symcore.Expr,
) -> @symcore.Expr {
  if control_expr_is_zero(numerator) {
    @symcore.raw_mul([
      @symcore.int(0),
      @symcore.raw_pow(denominator, @symcore.int(-1)),
    ])
  } else if control_expr_is_one(denominator) {
    if control_expr_is_one(numerator) {
      @symcore.raw_pow(@symcore.int(1), @symcore.int(-1))
    } else {
      @symcore.raw_mul([
        numerator,
        @symcore.raw_pow(@symcore.int(1), @symcore.int(-1)),
      ])
    }
  } else {
    @symcore.raw_mul([
      numerator,
      @symcore.raw_pow(denominator, @symcore.int(-1)),
    ])
  }
}

///|
fn control_unit_like(
  system : SISOLinearTimeInvariant,
) -> SISOLinearTimeInvariant raise ControlError {
  match system {
    SISOLinearTimeInvariant::DTF(tf) =>
      SISOLinearTimeInvariant::DTF(
        discrete_transfer_function(
          @symcore.int(1),
          @symcore.int(1),
          tf.var_,
          sampling_time=tf.sampling_time_,
        ),
      )
    _ =>
      SISOLinearTimeInvariant::TF(
        transfer_function(@symcore.int(1), @symcore.int(1), system.var()),
      )
  }
}

///|
fn control_lti_time_signature(
  system : SISOLinearTimeInvariant,
) -> (@symcore.Expr, Bool, @symcore.Expr?) raise ControlError {
  match system {
    SISOLinearTimeInvariant::TF(tf) => (tf.var_, false, None)
    SISOLinearTimeInvariant::DTF(tf) => (tf.var_, true, Some(tf.sampling_time_))
    SISOLinearTimeInvariant::PID(pid) => (pid.var_, false, None)
    SISOLinearTimeInvariant::SeriesLTI(series) =>
      control_lti_time_signature(series.args_[0])
    SISOLinearTimeInvariant::ParallelLTI(parallel) =>
      control_lti_time_signature(parallel.args_[0])
    SISOLinearTimeInvariant::FeedbackLTI(feedback) =>
      control_lti_time_signature(feedback.sys1_)
  }
}

///|
fn control_require_compatible_systems(
  args : Array[SISOLinearTimeInvariant],
) -> Unit raise ControlError {
  guard !args.is_empty() else {
    raise ControlError::ValueError("expected at least one system")
  }
  let sig0 = control_lti_time_signature(args[0])
  let var0 = sig0.0
  let discrete0 = sig0.1
  let sample0 = sig0.2
  for arg in args {
    let sig = control_lti_time_signature(arg)
    guard sig.0 == var0 else {
      raise ControlError::ValueError(
        "systems should use the same complex variable",
      )
    }
    guard sig.1 == discrete0 else {
      raise ControlError::TypeError(
        "cannot mix continuous and discrete systems",
      )
    }
    if discrete0 {
      guard sig.2 == sample0 else {
        raise ControlError::ValueError(
          "discrete systems should use the same sampling time",
        )
      }
    }
  }
}

///|
fn control_as_base(
  system : SISOLinearTimeInvariant,
) -> SISOLinearTimeInvariant raise ControlError {
  match system {
    SISOLinearTimeInvariant::TF(_) | SISOLinearTimeInvariant::DTF(_) => system
    SISOLinearTimeInvariant::PID(pid) => SISOLinearTimeInvariant::TF(pid.doit())
    SISOLinearTimeInvariant::SeriesLTI(series) => series.doit()
    SISOLinearTimeInvariant::ParallelLTI(parallel) => parallel.doit()
    SISOLinearTimeInvariant::FeedbackLTI(feedback) => feedback.doit()
  }
}

///|
fn control_multiply_base(
  lhs : SISOLinearTimeInvariant,
  rhs : SISOLinearTimeInvariant,
) -> SISOLinearTimeInvariant raise ControlError {
  match (control_as_base(lhs), control_as_base(rhs)) {
    (SISOLinearTimeInvariant::TF(a), SISOLinearTimeInvariant::TF(b)) =>
      SISOLinearTimeInvariant::TF(
        transfer_function(a.num_ * b.num_, a.den_ * b.den_, a.var_),
      )
    (SISOLinearTimeInvariant::DTF(a), SISOLinearTimeInvariant::DTF(b)) =>
      SISOLinearTimeInvariant::DTF(
        discrete_transfer_function(
          a.num_ * b.num_,
          a.den_ * b.den_,
          a.var_,
          sampling_time=a.sampling_time_,
        ),
      )
    _ =>
      raise ControlError::TypeError(
        "cannot mix continuous and discrete systems",
      )
  }
}

///|
fn control_add_base(
  lhs : SISOLinearTimeInvariant,
  rhs : SISOLinearTimeInvariant,
) -> SISOLinearTimeInvariant raise ControlError {
  match (control_as_base(lhs), control_as_base(rhs)) {
    (SISOLinearTimeInvariant::TF(a), SISOLinearTimeInvariant::TF(b)) =>
      SISOLinearTimeInvariant::TF(
        transfer_function(
          a.num_ * b.den_ + b.num_ * a.den_,
          a.den_ * b.den_,
          a.var_,
        ),
      )
    (SISOLinearTimeInvariant::DTF(a), SISOLinearTimeInvariant::DTF(b)) =>
      SISOLinearTimeInvariant::DTF(
        discrete_transfer_function(
          a.num_ * b.den_ + b.num_ * a.den_,
          a.den_ * b.den_,
          a.var_,
          sampling_time=a.sampling_time_,
        ),
      )
    _ =>
      raise ControlError::TypeError(
        "cannot mix continuous and discrete systems",
      )
  }
}

///|
pub fn transfer_function(
  numerator : @symcore.Expr,
  denominator : @symcore.Expr,
  var : @symcore.Expr,
) -> TransferFunction raise ControlError {
  guard var is @symcore.Expr::Symbol(_) else {
    raise ControlError::TypeError("control variable should be a symbol")
  }
  let den_norm = control_normalize(denominator)
  guard !control_expr_is_zero(den_norm) else {
    raise ControlError::ValueError(
      "transfer function denominator should be nonzero",
    )
  }
  TransferFunction::{
    num_: control_normalize(numerator),
    den_: den_norm,
    var_: var,
  }
}

///|
pub fn discrete_transfer_function(
  numerator : @symcore.Expr,
  denominator : @symcore.Expr,
  var : @symcore.Expr,
  sampling_time? : @symcore.Expr = @symcore.int(1),
) -> DiscreteTransferFunction raise ControlError {
  guard var is @symcore.Expr::Symbol(_) else {
    raise ControlError::TypeError("control variable should be a symbol")
  }
  let den_norm = control_normalize(denominator)
  guard !control_expr_is_zero(den_norm) else {
    raise ControlError::ValueError(
      "transfer function denominator should be nonzero",
    )
  }
  DiscreteTransferFunction::{
    num_: control_normalize(numerator),
    den_: den_norm,
    var_: var,
    sampling_time_: control_normalize(sampling_time),
  }
}

///|
pub fn create_transfer_function(
  numerator : @symcore.Expr,
  denominator : @symcore.Expr,
  var : @symcore.Expr,
  sampling_time? : @symcore.Expr = @symcore.int(0),
) -> SISOLinearTimeInvariant raise ControlError {
  if control_expr_is_zero(sampling_time) {
    SISOLinearTimeInvariant::TF(transfer_function(numerator, denominator, var))
  } else {
    SISOLinearTimeInvariant::DTF(
      discrete_transfer_function(numerator, denominator, var, sampling_time~),
    )
  }
}

///|
pub fn TransferFunction::from_rational_expression(
  expr : @symcore.Expr,
  var? : @symcore.Expr,
) -> TransferFunction raise ControlError {
  let resolved_var = match var {
    Some(value) => value
    None => {
      let seen : Map[String, Bool] = {}
      control_collect_symbols(expr, seen)
      let names = seen
        .keys()
        .to_array()
        .filter(name => name != "I" && name != "pi")
      guard names.length() == 1 else {
        raise ControlError::ValueError(
          "from_rational_expression needs the complex variable when it cannot be inferred",
        )
      }
      @symcore.symbol(names[0])
    }
  }
  let variable_name = control_var_name(resolved_var)
  let parts = control_rational_parts(control_normalize(expr), variable_name)
  transfer_function(
    control_normalize(control_expand_expr(parts.0)),
    control_normalize(control_expand_expr(parts.1)),
    resolved_var,
  )
}

///|
pub fn TransferFunction::from_coeff_lists(
  numerator_coeffs : Array[@symcore.Expr],
  denominator_coeffs : Array[@symcore.Expr],
  var : @symcore.Expr,
) -> TransferFunction raise ControlError {
  guard !denominator_coeffs.all(coeff => control_expr_is_zero(coeff)) else {
    raise ControlError::ValueError(
      "transfer function denominator should be nonzero",
    )
  }
  transfer_function(
    control_expr_from_coeffs(numerator_coeffs, var),
    control_expr_from_coeffs(denominator_coeffs, var),
    var,
  )
}

///|
pub fn TransferFunction::from_zpk(
  zeros : Array[@symcore.Expr],
  poles : Array[@symcore.Expr],
  gain : @symcore.Expr,
  var : @symcore.Expr,
) -> TransferFunction raise ControlError {
  let mut numerator = gain
  for zero in zeros {
    numerator = numerator * (var - zero)
  }
  let mut denominator = @symcore.int(1)
  for pole in poles {
    denominator = denominator * (var - pole)
  }
  transfer_function(numerator, denominator, var)
}

///|
pub fn TransferFunction::num(self : TransferFunction) -> @symcore.Expr {
  self.num_
}

///|
pub fn TransferFunction::den(self : TransferFunction) -> @symcore.Expr {
  self.den_
}

///|
pub fn TransferFunction::var(self : TransferFunction) -> @symcore.Expr {
  self.var_
}

///|
pub fn TransferFunction::args(self : TransferFunction) -> Array[@symcore.Expr] {
  [self.num_, self.den_, self.var_]
}

///|
pub fn TransferFunction::sampling_time(
  self : TransferFunction,
) -> @symcore.Expr {
  @symcore.int(0)
}

///|
pub fn TransferFunction::as_system(
  self : TransferFunction,
) -> SISOLinearTimeInvariant {
  SISOLinearTimeInvariant::TF(self)
}

///|
pub fn TransferFunction::to_expr(self : TransferFunction) -> @symcore.Expr {
  control_tf_expr(self.num_, self.den_)
}

///|
pub fn TransferFunction::expand(
  self : TransferFunction,
) -> TransferFunction raise ControlError {
  transfer_function(
    control_expand_expr(self.num_),
    control_expand_expr(self.den_),
    self.var_,
  )
}

///|
pub fn TransferFunction::simplify(
  self : TransferFunction,
) -> TransferFunction raise ControlError {
  let reduced = @symsimplify.ratsimp(self.to_expr(), max_passes=8)
  TransferFunction::from_rational_expression(
    control_normalize(reduced),
    var=self.var_,
  )
}

///|
pub fn TransferFunction::eval_frequency(
  self : TransferFunction,
  point : @symcore.Expr,
) -> @symcore.Expr raise ControlError {
  let env : Map[String, @symcore.Expr] = {}
  env[control_var_name(self.var_)] = point
  control_normalize(@symcore.subst(self.to_expr(), env))
}

///|
pub fn TransferFunction::dc_gain(
  self : TransferFunction,
) -> @symcore.Expr raise ControlError {
  let simplified = self.simplify()
  let env : Map[String, @symcore.Expr] = {}
  env[control_var_name(self.var_)] = @symcore.int(0)
  let num0 = control_normalize(@symcore.subst(simplified.num_, env))
  let den0 = control_normalize(@symcore.subst(simplified.den_, env))
  if control_expr_is_zero(den0) {
    if control_expr_is_zero(num0) {
      raise ControlError::NotImplemented(
        "dc_gain is indeterminate for this transfer function",
      )
    }
    @symcore.symbol("oo")
  } else {
    control_normalize(num0 * @symcore.pow(den0, @symcore.int(-1)))
  }
}

///|
pub fn TransferFunction::poles(
  self : TransferFunction,
) -> Array[@symcore.Expr] raise ControlError {
  control_poly_roots(self.den_, control_var_name(self.var_))
}

///|
pub fn TransferFunction::zeros(
  self : TransferFunction,
) -> Array[@symcore.Expr] raise ControlError {
  if control_expr_is_zero(self.num_) {
    []
  } else {
    control_poly_roots(self.num_, control_var_name(self.var_))
  }
}

///|
pub fn TransferFunction::is_proper(
  self : TransferFunction,
) -> Bool raise ControlError {
  control_poly_degree(self.num_, control_var_name(self.var_)) <=
  control_poly_degree(self.den_, control_var_name(self.var_))
}

///|
pub fn TransferFunction::is_strictly_proper(
  self : TransferFunction,
) -> Bool raise ControlError {
  control_poly_degree(self.num_, control_var_name(self.var_)) <
  control_poly_degree(self.den_, control_var_name(self.var_))
}

///|
pub fn TransferFunction::is_biproper(
  self : TransferFunction,
) -> Bool raise ControlError {
  control_poly_degree(self.num_, control_var_name(self.var_)) ==
  control_poly_degree(self.den_, control_var_name(self.var_))
}

///|
pub fn TransferFunction::is_stable(
  self : TransferFunction,
) -> Bool? raise ControlError {
  let coeffs = match
    (try? control_poly_coeffs_as_doubles(self.den_, control_var_name(self.var_))) {
    Ok(Some(value)) => value
    Ok(None) => return None
    Err(_) => return None
  }
  let roots = match control_poly_numeric_roots(coeffs) {
    Some(value) => value
    None => return None
  }
  let mut saw_unknown = false
  for root in roots {
    if root.0 >= -1.0e-9 {
      return Some(false)
    }
    if root.0.abs() <= 1.0e-9 {
      saw_unknown = true
    }
  }
  if saw_unknown {
    None
  } else {
    Some(true)
  }
}

///|
pub fn TransferFunction::subs(
  self : TransferFunction,
  env : Map[String, @symcore.Expr],
) -> TransferFunction raise ControlError {
  transfer_function(
    @symcore.subst(self.num_, env),
    @symcore.subst(self.den_, env),
    self.var_,
  )
}

///|
pub fn TransferFunction::xreplace(
  self : TransferFunction,
  env : Map[String, @symcore.Expr],
) -> TransferFunction raise ControlError {
  let next_var = match self.var_ {
    @symcore.Expr::Symbol(name) =>
      match env.get(name) {
        Some(value) =>
          match value {
            @symcore.Expr::Symbol(_) => value
            _ => self.var_
          }
        None => self.var_
      }
    _ => self.var_
  }
  transfer_function(
    @symcore.subst(self.num_, env),
    @symcore.subst(self.den_, env),
    next_var,
  )
}

///|
pub impl Neg for TransferFunction with neg(self) {
  try! transfer_function(@symcore.int(-1) * self.num_, self.den_, self.var_)
}

///|
pub fn discrete_transfer_function_from_coeff_lists(
  numerator_coeffs : Array[@symcore.Expr],
  denominator_coeffs : Array[@symcore.Expr],
  var : @symcore.Expr,
  sampling_time? : @symcore.Expr = @symcore.int(1),
) -> DiscreteTransferFunction raise ControlError {
  discrete_transfer_function(
    control_expr_from_coeffs(numerator_coeffs, var),
    control_expr_from_coeffs(denominator_coeffs, var),
    var,
    sampling_time~,
  )
}

///|
pub fn DiscreteTransferFunction::from_rational_expression(
  expr : @symcore.Expr,
  var : @symcore.Expr,
  sampling_time? : @symcore.Expr = @symcore.int(1),
) -> DiscreteTransferFunction raise ControlError {
  let parts = control_rational_parts(
    control_normalize(expr),
    control_var_name(var),
  )
  discrete_transfer_function(parts.0, parts.1, var, sampling_time~)
}

///|
pub fn DiscreteTransferFunction::from_coeff_lists(
  numerator_coeffs : Array[@symcore.Expr],
  denominator_coeffs : Array[@symcore.Expr],
  var : @symcore.Expr,
  sampling_time? : @symcore.Expr = @symcore.int(1),
) -> DiscreteTransferFunction raise ControlError {
  discrete_transfer_function_from_coeff_lists(
    numerator_coeffs,
    denominator_coeffs,
    var,
    sampling_time~,
  )
}

///|
pub fn DiscreteTransferFunction::from_zpk(
  zeros : Array[@symcore.Expr],
  poles : Array[@symcore.Expr],
  gain : @symcore.Expr,
  var : @symcore.Expr,
  sampling_time? : @symcore.Expr = @symcore.int(1),
) -> DiscreteTransferFunction raise ControlError {
  let tf = try! TransferFunction::from_zpk(zeros, poles, gain, var)
  discrete_transfer_function(tf.num_, tf.den_, var, sampling_time~)
}

///|
pub fn gbt(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
  alpha : @symcore.Expr,
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) raise ControlError {
  let variable_name = control_var_name(cont_tf.var_)
  let np = coeff_array(poly_from_expr(cont_tf.num_, variable_name)).1 catch {
      _ =>
        raise ControlError::NotImplemented("gbt requires polynomial numerator")
    }
  let dp = coeff_array(poly_from_expr(cont_tf.den_, variable_name)).1 catch {
      _ =>
        raise ControlError::NotImplemented(
          "gbt requires polynomial denominator",
        )
    }
  let z = cont_tf.var_
  let n = if np.length() > dp.length() {
    np.length() - 1
  } else {
    dp.length() - 1
  }
  let num_terms : Array[@symcore.Expr] = []
  let den_terms : Array[@symcore.Expr] = []
  for i in 0..<np.length() {
    let coeff = np[np.length() - 1 - i]
    let power = n - i
    num_terms.push(
      (sampling_time ^ @symcore.int(power)) *
      coeff *
      ((z - @symcore.int(1)) ^ @symcore.int(i)) *
      ((alpha * z + @symcore.int(1) - alpha) ^ @symcore.int(power)),
    )
  }
  for i in 0..<dp.length() {
    let coeff = dp[dp.length() - 1 - i]
    let power = n - i
    den_terms.push(
      (sampling_time ^ @symcore.int(power)) *
      coeff *
      ((z - @symcore.int(1)) ^ @symcore.int(i)) *
      ((alpha * z + @symcore.int(1) - alpha) ^ @symcore.int(power)),
    )
  }
  let num_expr = control_expand_expr(control_normalize(@symcore.add(num_terms)))
  let den_expr = control_expand_expr(control_normalize(@symcore.add(den_terms)))
  let num_coeffs = coeff_array(poly_from_expr(num_expr, variable_name)).1 catch {
      _ =>
        raise ControlError::NotImplemented(
          "gbt produced a non-polynomial numerator",
        )
    }
  let den_coeffs = coeff_array(poly_from_expr(den_expr, variable_name)).1 catch {
      _ =>
        raise ControlError::NotImplemented(
          "gbt produced a non-polynomial denominator",
        )
    }
  let lead = den_coeffs[0]
  (
    num_coeffs.map(coeff => control_normalize(coeff * (lead ^ @symcore.int(-1)))),
    den_coeffs.map(coeff => control_normalize(coeff * (lead ^ @symcore.int(-1)))),
  )
}

///|
pub fn bilinear(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) raise ControlError {
  gbt(cont_tf, sampling_time, try! @symcore.rational_from_ints(1, 2))
}

///|
pub fn forward_diff(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) raise ControlError {
  gbt(cont_tf, sampling_time, @symcore.int(0))
}

///|
pub fn backward_diff(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
) -> (Array[@symcore.Expr], Array[@symcore.Expr]) raise ControlError {
  gbt(cont_tf, sampling_time, @symcore.int(1))
}

///|
pub fn DiscreteTransferFunction::from_gbt(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
  alpha : @symcore.Expr,
  var : @symcore.Expr,
) -> DiscreteTransferFunction raise ControlError {
  let result = gbt(cont_tf, sampling_time, alpha)
  discrete_transfer_function(
    control_expr_from_coeffs(result.0, var),
    control_expr_from_coeffs(result.1, var),
    var,
    sampling_time~,
  )
}

///|
pub fn DiscreteTransferFunction::from_bilinear(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
  var : @symcore.Expr,
) -> DiscreteTransferFunction raise ControlError {
  DiscreteTransferFunction::from_gbt(
    cont_tf,
    sampling_time,
    try! @symcore.rational_from_ints(1, 2),
    var,
  )
}

///|
pub fn DiscreteTransferFunction::from_forward_diff(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
  var : @symcore.Expr,
) -> DiscreteTransferFunction raise ControlError {
  DiscreteTransferFunction::from_gbt(
    cont_tf,
    sampling_time,
    @symcore.int(0),
    var,
  )
}

///|
pub fn DiscreteTransferFunction::from_backward_diff(
  cont_tf : TransferFunction,
  sampling_time : @symcore.Expr,
  var : @symcore.Expr,
) -> DiscreteTransferFunction raise ControlError {
  DiscreteTransferFunction::from_gbt(
    cont_tf,
    sampling_time,
    @symcore.int(1),
    var,
  )
}

///|
pub fn DiscreteTransferFunction::discrete_tf_num(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.num_
}

///|
pub fn DiscreteTransferFunction::discrete_tf_den(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.den_
}

///|
pub fn DiscreteTransferFunction::discrete_tf_var(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.var_
}

///|
pub fn DiscreteTransferFunction::num(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.num_
}

///|
pub fn DiscreteTransferFunction::den(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.den_
}

///|
pub fn DiscreteTransferFunction::var(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.var_
}

///|
pub fn DiscreteTransferFunction::sampling_time(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  self.sampling_time_
}

///|
pub fn DiscreteTransferFunction::args(
  self : DiscreteTransferFunction,
) -> Array[@symcore.Expr] {
  [self.num_, self.den_, self.var_, self.sampling_time_]
}

///|
pub fn DiscreteTransferFunction::as_system(
  self : DiscreteTransferFunction,
) -> SISOLinearTimeInvariant {
  SISOLinearTimeInvariant::DTF(self)
}

///|
pub fn DiscreteTransferFunction::to_expr(
  self : DiscreteTransferFunction,
) -> @symcore.Expr {
  control_tf_expr(self.num_, self.den_)
}

///|
pub fn DiscreteTransferFunction::expand(
  self : DiscreteTransferFunction,
) -> DiscreteTransferFunction raise ControlError {
  discrete_transfer_function(
    control_expand_expr(self.num_),
    control_expand_expr(self.den_),
    self.var_,
    sampling_time=self.sampling_time_,
  )
}

///|
pub fn DiscreteTransferFunction::simplify(
  self : DiscreteTransferFunction,
) -> DiscreteTransferFunction raise ControlError {
  let reduced = @symsimplify.ratsimp(self.to_expr(), max_passes=8)
  DiscreteTransferFunction::from_rational_expression(
    control_normalize(reduced),
    self.var_,
    sampling_time=self.sampling_time_,
  )
}

///|
pub fn DiscreteTransferFunction::eval_frequency(
  self : DiscreteTransferFunction,
  point : @symcore.Expr,
) -> @symcore.Expr raise ControlError {
  let env : Map[String, @symcore.Expr] = {}
  env[control_var_name(self.var_)] = point
  control_normalize(@symcore.subst(self.to_expr(), env))
}

///|
pub fn DiscreteTransferFunction::dc_gain(
  self : DiscreteTransferFunction,
) -> @symcore.Expr raise ControlError {
  let simplified = self.simplify()
  let env : Map[String, @symcore.Expr] = {}
  env[control_var_name(self.var_)] = @symcore.int(1)
  let num1 = control_normalize(@symcore.subst(simplified.num_, env))
  let den1 = control_normalize(@symcore.subst(simplified.den_, env))
  if control_expr_is_zero(den1) {
    if control_expr_is_zero(num1) {
      raise ControlError::NotImplemented(
        "dc_gain is indeterminate for this transfer function",
      )
    }
    @symcore.symbol("oo")
  } else {
    control_normalize(num1 * (den1 ^ @symcore.int(-1)))
  }
}

///|
pub fn DiscreteTransferFunction::poles(
  self : DiscreteTransferFunction,
) -> Array[@symcore.Expr] raise ControlError {
  control_poly_roots(self.den_, control_var_name(self.var_))
}

///|
pub fn DiscreteTransferFunction::zeros(
  self : DiscreteTransferFunction,
) -> Array[@symcore.Expr] raise ControlError {
  if control_expr_is_zero(self.num_) {
    []
  } else {
    control_poly_roots(self.num_, control_var_name(self.var_))
  }
}

///|
pub fn DiscreteTransferFunction::is_proper(
  self : DiscreteTransferFunction,
) -> Bool raise ControlError {
  control_poly_degree(self.num_, control_var_name(self.var_)) <=
  control_poly_degree(self.den_, control_var_name(self.var_))
}

///|
pub fn DiscreteTransferFunction::is_strictly_proper(
  self : DiscreteTransferFunction,
) -> Bool raise ControlError {
  control_poly_degree(self.num_, control_var_name(self.var_)) <
  control_poly_degree(self.den_, control_var_name(self.var_))
}

///|
pub fn DiscreteTransferFunction::is_biproper(
  self : DiscreteTransferFunction,
) -> Bool raise ControlError {
  control_poly_degree(self.num_, control_var_name(self.var_)) ==
  control_poly_degree(self.den_, control_var_name(self.var_))
}

///|
pub fn DiscreteTransferFunction::is_stable(
  self : DiscreteTransferFunction,
) -> Bool? raise ControlError {
  let coeffs = match
    (try? control_poly_coeffs_as_doubles(self.den_, control_var_name(self.var_))) {
    Ok(Some(value)) => value
    Ok(None) => return None
    Err(_) => return None
  }
  let roots = match control_poly_numeric_roots(coeffs) {
    Some(value) => value
    None => return None
  }
  let mut saw_border = false
  for root in roots {
    let abs = control_complex_abs(root)
    if abs > 1.0 + 1.0e-9 {
      return Some(false)
    }
    if abs >= 1.0 - 1.0e-9 {
      saw_border = true
    }
  }
  if saw_border {
    None
  } else {
    Some(true)
  }
}

///|
pub impl Neg for DiscreteTransferFunction with neg(self) {
  try! discrete_transfer_function(
    @symcore.int(-1) * self.num_,
    self.den_,
    self.var_,
    sampling_time=self.sampling_time_,
  )
}

///|
pub fn pid_controller(
  kp? : @symcore.Expr = @symcore.symbol("kp"),
  ki? : @symcore.Expr = @symcore.symbol("ki"),
  kd? : @symcore.Expr = @symcore.symbol("kd"),
  tf? : @symcore.Expr = @symcore.int(0),
  var? : @symcore.Expr = @symcore.symbol("s"),
) -> PIDController raise ControlError {
  guard var is @symcore.Expr::Symbol(_) else {
    raise ControlError::TypeError("control variable should be a symbol")
  }
  PIDController::{ kp_: kp, ki_: ki, kd_: kd, tf_: tf, var_: var }
}

///|
pub fn PIDController::kp(self : PIDController) -> @symcore.Expr {
  self.kp_
}

///|
pub fn PIDController::ki(self : PIDController) -> @symcore.Expr {
  self.ki_
}

///|
pub fn PIDController::kd(self : PIDController) -> @symcore.Expr {
  self.kd_
}

///|
pub fn PIDController::tf(self : PIDController) -> @symcore.Expr {
  self.tf_
}

///|
pub fn PIDController::var(self : PIDController) -> @symcore.Expr {
  self.var_
}

///|
pub fn PIDController::as_system(
  self : PIDController,
) -> SISOLinearTimeInvariant {
  SISOLinearTimeInvariant::PID(self)
}

///|
pub fn PIDController::doit(
  self : PIDController,
) -> TransferFunction raise ControlError {
  let numerator = self.kp_ * self.tf_ * (self.var_ ^ @symcore.int(2)) +
    self.kp_ * self.var_ +
    self.ki_ * self.tf_ * self.var_ +
    self.ki_ +
    self.kd_ * (self.var_ ^ @symcore.int(2))
  let denominator = self.tf_ * (self.var_ ^ @symcore.int(2)) + self.var_
  transfer_function(numerator, denominator, self.var_)
}

///|
pub fn PIDController::to_expr(
  self : PIDController,
) -> @symcore.Expr raise ControlError {
  self.doit().to_expr()
}

///|
pub fn series(
  args : Array[SISOLinearTimeInvariant],
) -> Series raise ControlError {
  control_require_compatible_systems(args)
  Series::{ args_: args }
}

///|
pub fn parallel(
  args : Array[SISOLinearTimeInvariant],
) -> Parallel raise ControlError {
  control_require_compatible_systems(args)
  Parallel::{ args_: args }
}

///|
pub fn feedback(
  sys1 : SISOLinearTimeInvariant,
  sys2? : SISOLinearTimeInvariant? = None,
  sign? : Int = -1,
) -> Feedback raise ControlError {
  let resolved_sys2 = match sys2 {
    Some(value) => value
    None => control_unit_like(sys1)
  }
  control_require_compatible_systems([sys1, resolved_sys2])
  guard sign == -1 || sign == 1 else {
    raise ControlError::ValueError("feedback sign should be -1 or 1")
  }
  Feedback::{ sys1_: sys1, sys2_: resolved_sys2, sign_: sign }
}

///|
pub fn Series::args(self : Series) -> Array[SISOLinearTimeInvariant] {
  self.args_
}

///|
pub fn Series::var(self : Series) -> @symcore.Expr raise ControlError {
  control_lti_time_signature(self.args_[0]).0
}

///|
pub fn Series::sampling_time(
  self : Series,
) -> @symcore.Expr? raise ControlError {
  control_lti_time_signature(self.args_[0]).2
}

///|
pub fn Series::as_system(self : Series) -> SISOLinearTimeInvariant {
  SISOLinearTimeInvariant::SeriesLTI(self)
}

///|
pub fn Series::doit(
  self : Series,
) -> SISOLinearTimeInvariant raise ControlError {
  let mut out = control_as_base(self.args_[0])
  for i in 1..<self.args_.length() {
    out = control_multiply_base(out, self.args_[i])
  }
  out
}

///|
pub fn Series::to_expr(self : Series) -> @symcore.Expr raise ControlError {
  self.doit().to_expr()
}

///|
pub fn Series::is_proper(self : Series) -> Bool raise ControlError {
  self.doit().is_proper()
}

///|
pub fn Series::is_strictly_proper(self : Series) -> Bool raise ControlError {
  self.doit().is_strictly_proper()
}

///|
pub fn Series::is_biproper(self : Series) -> Bool raise ControlError {
  self.doit().is_biproper()
}

///|
pub fn Parallel::args(self : Parallel) -> Array[SISOLinearTimeInvariant] {
  self.args_
}

///|
pub fn Parallel::var(self : Parallel) -> @symcore.Expr raise ControlError {
  control_lti_time_signature(self.args_[0]).0
}

///|
pub fn Parallel::sampling_time(
  self : Parallel,
) -> @symcore.Expr? raise ControlError {
  control_lti_time_signature(self.args_[0]).2
}

///|
pub fn Parallel::as_system(self : Parallel) -> SISOLinearTimeInvariant {
  SISOLinearTimeInvariant::ParallelLTI(self)
}

///|
pub fn Parallel::doit(
  self : Parallel,
) -> SISOLinearTimeInvariant raise ControlError {
  let mut out = control_as_base(self.args_[0])
  for i in 1..<self.args_.length() {
    out = control_add_base(out, self.args_[i])
  }
  out
}

///|
pub fn Parallel::to_expr(self : Parallel) -> @symcore.Expr raise ControlError {
  self.doit().to_expr()
}

///|
pub fn Parallel::is_proper(self : Parallel) -> Bool raise ControlError {
  self.doit().is_proper()
}

///|
pub fn Parallel::is_strictly_proper(self : Parallel) -> Bool raise ControlError {
  self.doit().is_strictly_proper()
}

///|
pub fn Parallel::is_biproper(self : Parallel) -> Bool raise ControlError {
  self.doit().is_biproper()
}

///|
pub fn Feedback::sys1(self : Feedback) -> SISOLinearTimeInvariant {
  self.sys1_
}

///|
pub fn Feedback::sys2(self : Feedback) -> SISOLinearTimeInvariant {
  self.sys2_
}

///|
pub fn Feedback::sign(self : Feedback) -> Int {
  self.sign_
}

///|
pub fn Feedback::var(self : Feedback) -> @symcore.Expr raise ControlError {
  control_lti_time_signature(self.sys1_).0
}

///|
pub fn Feedback::sampling_time(
  self : Feedback,
) -> @symcore.Expr? raise ControlError {
  control_lti_time_signature(self.sys1_).2
}

///|
pub fn Feedback::as_system(self : Feedback) -> SISOLinearTimeInvariant {
  SISOLinearTimeInvariant::FeedbackLTI(self)
}

///|
pub fn Feedback::num(self : Feedback) -> SISOLinearTimeInvariant {
  self.sys1_
}

///|
pub fn Feedback::den(
  self : Feedback,
) -> SISOLinearTimeInvariant raise ControlError {
  let unit = control_unit_like(self.sys1_)
  let loop_term = series([self.sys2_, self.sys1_]).as_system()
  if self.sign_ == 1 {
    parallel([unit, control_as_base(loop_term).neg_system()]).as_system()
  } else {
    parallel([unit, loop_term]).as_system()
  }
}

///|
pub fn Feedback::doit(
  self : Feedback,
) -> SISOLinearTimeInvariant raise ControlError {
  let forward = control_as_base(self.sys1_)
  let feedback_term = control_as_base(self.sys2_)
  match (forward, feedback_term) {
    (SISOLinearTimeInvariant::TF(g), SISOLinearTimeInvariant::TF(h)) => {
      let den = if self.sign_ == 1 {
        g.den_ * h.den_ - g.num_ * h.num_
      } else {
        g.den_ * h.den_ + g.num_ * h.num_
      }
      SISOLinearTimeInvariant::TF(
        transfer_function(g.num_ * h.den_, den, g.var_),
      )
    }
    (SISOLinearTimeInvariant::DTF(g), SISOLinearTimeInvariant::DTF(h)) => {
      let den = if self.sign_ == 1 {
        g.den_ * h.den_ - g.num_ * h.num_
      } else {
        g.den_ * h.den_ + g.num_ * h.num_
      }
      SISOLinearTimeInvariant::DTF(
        discrete_transfer_function(
          g.num_ * h.den_,
          den,
          g.var_,
          sampling_time=g.sampling_time_,
        ),
      )
    }
    _ =>
      raise ControlError::TypeError(
        "cannot mix continuous and discrete systems",
      )
  }
}

///|
pub fn Feedback::to_expr(self : Feedback) -> @symcore.Expr raise ControlError {
  self.doit().to_expr()
}

///|
pub fn SISOLinearTimeInvariant::var(
  self : SISOLinearTimeInvariant,
) -> @symcore.Expr raise ControlError {
  match self {
    SISOLinearTimeInvariant::TF(tf) => tf.var_
    SISOLinearTimeInvariant::DTF(tf) => tf.var_
    SISOLinearTimeInvariant::PID(pid) => pid.var_
    SISOLinearTimeInvariant::SeriesLTI(series) => series.var()
    SISOLinearTimeInvariant::ParallelLTI(parallel) => parallel.var()
    SISOLinearTimeInvariant::FeedbackLTI(feedback) => feedback.var()
  }
}

///|
pub fn SISOLinearTimeInvariant::sampling_time(
  self : SISOLinearTimeInvariant,
) -> @symcore.Expr? raise ControlError {
  match self {
    SISOLinearTimeInvariant::TF(_) | SISOLinearTimeInvariant::PID(_) => None
    SISOLinearTimeInvariant::DTF(tf) => Some(tf.sampling_time_)
    SISOLinearTimeInvariant::SeriesLTI(series) => series.sampling_time()
    SISOLinearTimeInvariant::ParallelLTI(parallel) => parallel.sampling_time()
    SISOLinearTimeInvariant::FeedbackLTI(feedback) => feedback.sampling_time()
  }
}

///|
pub fn SISOLinearTimeInvariant::is_discrete(
  self : SISOLinearTimeInvariant,
) -> Bool {
  match self {
    SISOLinearTimeInvariant::DTF(_) => true
    SISOLinearTimeInvariant::SeriesLTI(series) =>
      match series.args_[0] {
        SISOLinearTimeInvariant::DTF(_) => true
        _ => false
      }
    SISOLinearTimeInvariant::ParallelLTI(parallel) =>
      match parallel.args_[0] {
        SISOLinearTimeInvariant::DTF(_) => true
        _ => false
      }
    SISOLinearTimeInvariant::FeedbackLTI(feedback) =>
      feedback.sys1_.is_discrete()
    _ => false
  }
}

///|
pub fn SISOLinearTimeInvariant::doit(
  self : SISOLinearTimeInvariant,
) -> SISOLinearTimeInvariant raise ControlError {
  control_as_base(self)
}

///|
pub fn SISOLinearTimeInvariant::to_expr(
  self : SISOLinearTimeInvariant,
) -> @symcore.Expr raise ControlError {
  match control_as_base(self) {
    SISOLinearTimeInvariant::TF(tf) => tf.to_expr()
    SISOLinearTimeInvariant::DTF(tf) => tf.to_expr()
    _ => raise ControlError::NotImplemented("unexpected non-base system")
  }
}

///|
pub fn SISOLinearTimeInvariant::is_proper(
  self : SISOLinearTimeInvariant,
) -> Bool raise ControlError {
  match control_as_base(self) {
    SISOLinearTimeInvariant::TF(tf) => tf.is_proper()
    SISOLinearTimeInvariant::DTF(tf) => tf.is_proper()
    _ => raise ControlError::NotImplemented("unexpected non-base system")
  }
}

///|
pub fn SISOLinearTimeInvariant::is_strictly_proper(
  self : SISOLinearTimeInvariant,
) -> Bool raise ControlError {
  match control_as_base(self) {
    SISOLinearTimeInvariant::TF(tf) => tf.is_strictly_proper()
    SISOLinearTimeInvariant::DTF(tf) => tf.is_strictly_proper()
    _ => raise ControlError::NotImplemented("unexpected non-base system")
  }
}

///|
pub fn SISOLinearTimeInvariant::is_biproper(
  self : SISOLinearTimeInvariant,
) -> Bool raise ControlError {
  match control_as_base(self) {
    SISOLinearTimeInvariant::TF(tf) => tf.is_biproper()
    SISOLinearTimeInvariant::DTF(tf) => tf.is_biproper()
    _ => raise ControlError::NotImplemented("unexpected non-base system")
  }
}

///|
pub fn SISOLinearTimeInvariant::neg_system(
  self : SISOLinearTimeInvariant,
) -> SISOLinearTimeInvariant raise ControlError {
  match control_as_base(self) {
    SISOLinearTimeInvariant::TF(tf) => SISOLinearTimeInvariant::TF(-tf)
    SISOLinearTimeInvariant::DTF(tf) => SISOLinearTimeInvariant::DTF(-tf)
    _ => raise ControlError::NotImplemented("unexpected non-base system")
  }
}
