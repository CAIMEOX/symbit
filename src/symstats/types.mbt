///|
/// Core types for `symstats`.

///|
pub enum TriBool {
  True
  False
  Unknown
}

///|
pub(all) enum RelOp {
  Eq
  Ne
  Lt
  Le
  Gt
  Ge
}

///|
pub(all) enum Event {
  Bool(Bool)
  Rel(op~ : RelOp, lhs~ : @symcore.Expr, rhs~ : @symcore.Expr)
  Not(Event)
  And(Array[Event])
  Or(Array[Event])
}

///|
pub(all) enum ProcessKind {
  PoissonProcess(rate~ : @symcore.Expr, time_symbol~ : String)
  WienerProcess(time_symbol~ : String)
}

///|
pub(all) enum MatrixKind {
  Wishart(df~ : @symcore.Expr, scale~ : @symcore.Expr)
  MatrixNormal(
    mean~ : @symcore.Expr,
    rowcov~ : @symcore.Expr,
    colcov~ : @symcore.Expr
  )
  GOE(size~ : @symcore.Expr)
  GUE(size~ : @symcore.Expr)
}

///|
pub(all) enum RVKind {
  Finite(Array[(@symcore.Expr, @symnum.BigRational)])
  Binomial(n~ : @symcore.Expr, p~ : @symcore.Expr)
  Poisson(rate~ : @symcore.Expr)
  Geometric(p~ : @symcore.Expr)
  NegativeBinomial(r~ : @symcore.Expr, p~ : @symcore.Expr)
  Normal(mu~ : @symcore.Expr, sigma~ : @symcore.Expr)
  Exponential(rate~ : @symcore.Expr)
  Gamma(shape~ : @symcore.Expr, scale~ : @symcore.Expr)
  JointIndependent(Array[RandomVar])
  Compound(Array[(@symnum.BigRational, RandomVar)])
  StochasticProcess(ProcessKind)
  Matrix(MatrixKind)
  Symbolic(tag~ : String, params~ : Array[@symcore.Expr])
}

///|
pub struct RandomVar {
  name : String
  kind : RVKind
}

///|
pub fn random_var(name : String, kind : RVKind) -> RandomVar {
  { name, kind }
}

///|
pub fn symbolic_rv_data(rv : RandomVar) -> (String, Array[@symcore.Expr])? {
  match rv.kind {
    RVKind::Symbolic(tag~, params~) => Some((tag, params))
    _ => None
  }
}

///|
fn symbolic_tag_parts(tag : String) -> (String, String) {
  let parts = tag.split(":").to_array()
  if parts.length() >= 2 {
    (parts[0].to_string(), parts[1].to_string())
  } else {
    ("", tag)
  }
}

///|
pub fn symbolic_tag_family(tag : String) -> String {
  symbolic_tag_parts(tag).0
}

///|
pub fn symbolic_tag_name(tag : String) -> String {
  symbolic_tag_parts(tag).1
}

///|
pub fn symbolic_opaque_stats_name(name : String) -> Bool {
  match name {
    "StochasticProcess" |
    "DiscreteTimeStochasticProcess" |
    "DiscreteMarkovChain" |
    "ContinuousMarkovChain" |
    "CircularEnsemble" |
    "CircularUnitaryEnsemble" |
    "CircularOrthogonalEnsemble" |
    "CircularSymplecticEnsemble" |
    "GaussianEnsemble" |
    "GaussianUnitaryEnsemble" |
    "GaussianOrthogonalEnsemble" |
    "GaussianSymplecticEnsemble" |
    "JointEigenDistribution" |
    "level_spacing_distribution" |
    "JointRV" |
    "GeneralizedMultivariateLogGamma" |
    "GeneralizedMultivariateLogGammaOmega" |
    "MultivariateEwens" |
    "ContinuousRV" |
    "DiscreteRV" |
    "FiniteDistributionHandmade" |
    "ContinuousDistributionHandmade" |
    "DiscreteDistributionHandmade" => true
    _ => false
  }
}

///|
pub fn random_symbol(rv : RandomVar) -> @symcore.Expr {
  @symcore.symbol(rv.name)
}

///|
pub fn rename_random_var(rv : RandomVar, name : String) -> RandomVar {
  match rv.kind {
    RVKind::JointIndependent(items) => {
      let renamed : Array[RandomVar] = Array::new()
      for item in items {
        renamed.push(rename_random_var(item, item.name))
      }
      { name, kind: RVKind::JointIndependent(renamed) }
    }
    RVKind::Compound(items) => {
      let renamed : Array[(@symnum.BigRational, RandomVar)] = Array::new()
      for pair in items {
        let (w, item) = pair
        renamed.push((w, rename_random_var(item, name)))
      }
      { name, kind: RVKind::Compound(renamed) }
    }
    _ => { name, kind: rv.kind }
  }
}

///|
pub fn rel(op : RelOp, lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  Event::Rel(op~, lhs~, rhs~)
}

///|
pub fn eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(RelOp::Eq, lhs, rhs)
}

///|
pub fn ne(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(RelOp::Ne, lhs, rhs)
}

///|
pub fn lt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(RelOp::Lt, lhs, rhs)
}

///|
pub fn le(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(RelOp::Le, lhs, rhs)
}

///|
pub fn gt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(RelOp::Gt, lhs, rhs)
}

///|
pub fn ge(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(RelOp::Ge, lhs, rhs)
}

///|
pub fn relop_to_name(op : RelOp) -> String {
  match op {
    RelOp::Eq => "Eq"
    RelOp::Ne => "Ne"
    RelOp::Lt => "Lt"
    RelOp::Le => "Le"
    RelOp::Gt => "Gt"
    RelOp::Ge => "Ge"
  }
}

///|
pub fn invert_relop(op : RelOp) -> RelOp {
  match op {
    RelOp::Eq => RelOp::Eq
    RelOp::Ne => RelOp::Ne
    RelOp::Lt => RelOp::Gt
    RelOp::Le => RelOp::Ge
    RelOp::Gt => RelOp::Lt
    RelOp::Ge => RelOp::Le
  }
}

///|
pub fn not_event(event : Event) -> Event {
  match event {
    Event::Bool(v) => Event::Bool(!v)
    Event::Not(inner) => inner
    _ => Event::Not(event)
  }
}

///|
pub fn and_event(items : Array[Event]) -> Event {
  let flat : Array[Event] = Array::new()
  for item in items {
    match item {
      Event::Bool(false) => return Event::Bool(false)
      Event::Bool(true) => ()
      Event::And(inner) =>
        for child in inner {
          flat.push(child)
        }
      _ => flat.push(item)
    }
  }
  if flat.is_empty() {
    Event::Bool(true)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    Event::And(flat)
  }
}

///|
pub fn or_event(items : Array[Event]) -> Event {
  let flat : Array[Event] = Array::new()
  for item in items {
    match item {
      Event::Bool(true) => return Event::Bool(true)
      Event::Bool(false) => ()
      Event::Or(inner) =>
        for child in inner {
          flat.push(child)
        }
      _ => flat.push(item)
    }
  }
  if flat.is_empty() {
    Event::Bool(false)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    Event::Or(flat)
  }
}

///|
pub fn event_to_expr(event : Event) -> @symcore.Expr {
  match event {
    Event::Bool(v) => @symcore.symbol(if v { "True" } else { "False" })
    Event::Rel(op~, lhs~, rhs~) =>
      @symcore.function(relop_to_name(op), [lhs, rhs])
    Event::Not(inner) => @symcore.function("Not", [event_to_expr(inner)])
    Event::And(items) =>
      @symcore.function("And", items.map(item => event_to_expr(item)))
    Event::Or(items) =>
      @symcore.function("Or", items.map(item => event_to_expr(item)))
  }
}

///|
pub fn probability_expr(event : Event) -> @symcore.Expr {
  @symcore.function("Probability", [event_to_expr(event)])
}

///|
pub fn expectation_expr(expr : @symcore.Expr, rv : RandomVar?) -> @symcore.Expr {
  match rv {
    Some(v) => @symcore.function("Expectation", [expr, @symcore.symbol(v.name)])
    None => @symcore.function("Expectation", [expr])
  }
}

///|
pub fn variance_expr(expr : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Variance", [expr])
}

///|
pub fn covariance_expr(a : @symcore.Expr, b : @symcore.Expr) -> @symcore.Expr {
  @symcore.function("Covariance", [a, b])
}

///|
pub fn expr_zero() -> @symcore.Expr {
  @symcore.int(0)
}

///|
pub fn expr_one() -> @symcore.Expr {
  @symcore.int(1)
}

///|
pub fn expr_two() -> @symcore.Expr {
  @symcore.int(2)
}

///|
pub fn expr_from_big_rational(n : @symnum.BigRational) -> @symcore.Expr {
  @symcore.number(n)
}

///|
pub fn expr_from_int(n : Int) -> @symcore.Expr {
  @symcore.int(n)
}

///|
pub fn rat_from_int(n : Int) -> @symnum.BigRational {
  @symnum.BigRational::from_int(n)
}

///|
pub fn expr_as_number(expr : @symcore.Expr) -> @symnum.BigRational? {
  match expr {
    @symcore.Expr::Number(n) => Some(n)
    _ => None
  }
}

///|
pub fn expr_as_int(expr : @symcore.Expr) -> Int? {
  match expr_as_number(expr) {
    Some(n) if n.is_integral() => Some(n.numerator().to_int())
    _ => None
  }
}

///|
fn pow_int_nonneg(base : @symnum.BigRational, exp : Int) -> @symnum.BigRational {
  let mut out = @symnum.BigRational::one()
  for _ in 0..<exp {
    out = out.mul_r(base)
  }
  out
}

///|
fn pow_int(base : @symnum.BigRational, exp : Int) -> @symnum.BigRational {
  if exp == 0 {
    return @symnum.BigRational::one()
  }
  if exp > 0 {
    return pow_int_nonneg(base, exp)
  }
  let pos = pow_int_nonneg(base, -exp)
  try! @symnum.BigRational::one().div_r(pos)
}

///|
pub fn eval_arith(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Number(_) | @symcore.Expr::Symbol(_) => expr
    @symcore.Expr::Function(name, args) =>
      @symcore.function(name, args.map(item => eval_arith(item)))
    @symcore.Expr::Add(args) => {
      let out = args.map(item => eval_arith(item))
      let mut all_num = true
      let mut sum = @symnum.BigRational::zero()
      for item in out {
        match item {
          @symcore.Expr::Number(n) => sum = sum.add_r(n)
          _ => all_num = false
        }
      }
      if all_num {
        @symcore.number(sum)
      } else {
        @symcore.add(out)
      }
    }
    @symcore.Expr::Mul(args) => {
      let out = args.map(item => eval_arith(item))
      let mut all_num = true
      let mut prod = @symnum.BigRational::one()
      for item in out {
        match item {
          @symcore.Expr::Number(n) => prod = prod.mul_r(n)
          _ => all_num = false
        }
      }
      if all_num {
        @symcore.number(prod)
      } else {
        @symcore.mul(out)
      }
    }
    @symcore.Expr::Pow(base, exp) => {
      let b = eval_arith(base)
      let e = eval_arith(exp)
      match (b, e) {
        (@symcore.Expr::Number(nb), @symcore.Expr::Number(ne)) =>
          if ne.is_integral() {
            @symcore.number(pow_int(nb, ne.numerator().to_int()))
          } else {
            @symcore.pow(b, e)
          }
        _ => @symcore.pow(b, e)
      }
    }
  }
}

///|
pub fn substitute_symbol(
  expr : @symcore.Expr,
  name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = {}
  env[name] = value
  @symcore.subst(expr, env)
}

///|
pub fn tri_not(v : TriBool) -> TriBool {
  match v {
    TriBool::True => TriBool::False
    TriBool::False => TriBool::True
    TriBool::Unknown => TriBool::Unknown
  }
}

///|
pub fn tri_and(lhs : TriBool, rhs : TriBool) -> TriBool {
  match (lhs, rhs) {
    (TriBool::False, _) | (_, TriBool::False) => TriBool::False
    (TriBool::True, TriBool::True) => TriBool::True
    _ => TriBool::Unknown
  }
}

///|
pub fn tri_or(lhs : TriBool, rhs : TriBool) -> TriBool {
  match (lhs, rhs) {
    (TriBool::True, _) | (_, TriBool::True) => TriBool::True
    (TriBool::False, TriBool::False) => TriBool::False
    _ => TriBool::Unknown
  }
}

///|
fn eval_relation(
  op : RelOp,
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
) -> TriBool {
  let l = eval_arith(lhs)
  let r = eval_arith(rhs)
  match (expr_as_number(l), expr_as_number(r)) {
    (Some(ln), Some(rn)) => {
      let cmp = ln.compare(rn)
      let ok = match op {
        RelOp::Eq => cmp == 0
        RelOp::Ne => cmp != 0
        RelOp::Lt => cmp < 0
        RelOp::Le => cmp <= 0
        RelOp::Gt => cmp > 0
        RelOp::Ge => cmp >= 0
      }
      if ok { TriBool::True } else { TriBool::False }
    }
    _ =>
      match op {
        RelOp::Eq =>
          if @symcore.compare_expr(l, r) == 0 {
            TriBool::True
          } else {
            TriBool::Unknown
          }
        RelOp::Ne =>
          if @symcore.compare_expr(l, r) == 0 {
            TriBool::False
          } else {
            TriBool::Unknown
          }
        _ => TriBool::Unknown
      }
  }
}

///|
pub fn evaluate_event(
  event : Event,
  env : Map[String, @symcore.Expr],
) -> TriBool {
  match event {
    Event::Bool(v) => if v { TriBool::True } else { TriBool::False }
    Event::Rel(op~, lhs~, rhs~) => {
      let lhs_sub = @symcore.subst(lhs, env)
      let rhs_sub = @symcore.subst(rhs, env)
      eval_relation(op, lhs_sub, rhs_sub)
    }
    Event::Not(inner) => tri_not(evaluate_event(inner, env))
    Event::And(items) => {
      let mut acc = TriBool::True
      for item in items {
        acc = tri_and(acc, evaluate_event(item, env))
      }
      acc
    }
    Event::Or(items) => {
      let mut acc = TriBool::False
      for item in items {
        acc = tri_or(acc, evaluate_event(item, env))
      }
      acc
    }
  }
}

///|
fn collect_expr_symbols(expr : @symcore.Expr, out : Map[String, Bool]) -> Unit {
  match expr {
    @symcore.Expr::Symbol(name) => out[name] = true
    _ =>
      for child in @symcore.children(expr) {
        collect_expr_symbols(child, out)
      }
  }
}

///|
pub fn event_symbols(event : Event) -> Array[String] {
  let seen : Map[String, Bool] = {}
  match event {
    Event::Bool(_) => ()
    Event::Rel(lhs~, rhs~, op~) => {
      ignore(op)
      collect_expr_symbols(lhs, seen)
      collect_expr_symbols(rhs, seen)
    }
    Event::Not(inner) =>
      for s in event_symbols(inner) {
        seen[s] = true
      }
    Event::And(items) | Event::Or(items) =>
      for item in items {
        for s in event_symbols(item) {
          seen[s] = true
        }
      }
  }
  let out : Array[String] = Array::new()
  for s, _ in seen {
    out.push(s)
  }
  out.sort()
  out
}

///|
pub fn event_depends_only_on(event : Event, name : String) -> Bool {
  for symbol in event_symbols(event) {
    if symbol != name {
      return false
    }
  }
  true
}
