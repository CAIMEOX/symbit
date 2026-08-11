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
  Symbolic(kind~ : SymbolicKind, params~ : Array[@symcore.Expr])
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
pub fn symbolic_rv_data(
  rv : RandomVar,
) -> (SymbolicKind, Array[@symcore.Expr])? {
  match rv.kind {
    Symbolic(kind~, params~) => Some((kind, params))
    _ => None
  }
}

///|
pub fn random_symbol(rv : RandomVar) -> @symcore.Expr {
  Symbol(rv.name)
}

///|
fn symbolic_distribution_expr(
  name : String,
  params : Array[@symcore.Expr],
) -> @symcore.Expr {
  @symcore.function(name, params)
}

///|
pub fn rename_random_var(rv : RandomVar, name : String) -> RandomVar {
  match rv.kind {
    JointIndependent(items) => {
      let renamed : Array[RandomVar] = Array::new()
      for item in items {
        renamed.push(rename_random_var(item, item.name))
      }
      { name, kind: JointIndependent(renamed) }
    }
    Compound(items) => {
      let renamed : Array[(@symnum.BigRational, RandomVar)] = Array::new()
      for pair in items {
        let (w, item) = pair
        renamed.push((w, rename_random_var(item, name)))
      }
      { name, kind: Compound(renamed) }
    }
    _ => { name, kind: rv.kind }
  }
}

///|
pub fn rel(op : RelOp, lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  Rel(op~, lhs~, rhs~)
}

///|
pub fn eq(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(Eq, lhs, rhs)
}

///|
pub fn ne(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(Ne, lhs, rhs)
}

///|
pub fn lt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(Lt, lhs, rhs)
}

///|
pub fn le(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(Le, lhs, rhs)
}

///|
pub fn gt(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(Gt, lhs, rhs)
}

///|
pub fn ge(lhs : @symcore.Expr, rhs : @symcore.Expr) -> Event {
  rel(Ge, lhs, rhs)
}

///|
pub fn relop_to_name(op : RelOp) -> String {
  match op {
    Eq => "Eq"
    Ne => "Ne"
    Lt => "Lt"
    Le => "Le"
    Gt => "Gt"
    Ge => "Ge"
  }
}

///|
pub fn invert_relop(op : RelOp) -> RelOp {
  match op {
    Eq => Eq
    Ne => Ne
    Lt => Gt
    Le => Ge
    Gt => Lt
    Ge => Le
  }
}

///|
pub fn not_event(event : Event) -> Event {
  match event {
    Bool(v) => Bool(!v)
    Not(inner) => inner
    _ => Not(event)
  }
}

///|
pub fn and_event(items : Array[Event]) -> Event {
  let flat : Array[Event] = Array::new()
  for item in items {
    match item {
      Bool(false) => return Bool(false)
      Bool(true) => ()
      And(inner) =>
        for child in inner {
          flat.push(child)
        }
      _ => flat.push(item)
    }
  }
  if flat.is_empty() {
    Bool(true)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    And(flat)
  }
}

///|
pub fn or_event(items : Array[Event]) -> Event {
  let flat : Array[Event] = Array::new()
  for item in items {
    match item {
      Bool(true) => return Bool(true)
      Bool(false) => ()
      Or(inner) =>
        for child in inner {
          flat.push(child)
        }
      _ => flat.push(item)
    }
  }
  if flat.is_empty() {
    Bool(false)
  } else if flat.length() == 1 {
    flat[0]
  } else {
    Or(flat)
  }
}

///|
pub fn event_to_expr(event : Event) -> @symcore.Expr {
  match event {
    Bool(v) => Symbol(if v { "True" } else { "False" })
    Rel(op~, lhs~, rhs~) => @symcore.function(relop_to_name(op), [lhs, rhs])
    Not(inner) => @symcore.function("Not", [event_to_expr(inner)])
    And(items) =>
      @symcore.function("And", items.map(item => event_to_expr(item)))
    Or(items) => @symcore.function("Or", items.map(item => event_to_expr(item)))
  }
}

///|
pub fn probability_expr(event : Event) -> @symcore.Expr {
  @symcore.function("Probability", [event_to_expr(event)])
}

///|
pub fn expectation_expr(expr : @symcore.Expr, rv : RandomVar?) -> @symcore.Expr {
  match rv {
    Some(v) => @symcore.function("Expectation", [expr, Symbol(v.name)])
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
pub fn expr_from_big_rational(n : @symnum.BigRational) -> @symcore.Expr {
  Number(n)
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
    Number(n) => Some(n)
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
fn pow_int(base : @symnum.BigRational, exp : Int) -> @symnum.BigRational? {
  if exp == 0 {
    return Some(@symnum.BigRational::one())
  }
  if exp > 0 {
    return Some(pow_int_nonneg(base, exp))
  }
  let pos = pow_int_nonneg(base, -exp)
  let value = @symnum.BigRational::one().div_r(pos) catch { _ => return None }
  Some(value)
}

///|
pub fn eval_arith(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    Number(_)
    | Float(_)
    | ComplexFloat(_)
    | NumberSymbol(_)
    | Boolean(_)
    | Symbol(_)
    | Dummy(_, _)
    | Wild(_, _, _)
    | FunctionHead(_)
    | UndefinedFunction(_) => expr
    Apply(head, args) =>
      @symcore.raw_apply(head, args.map(item => eval_arith(item))).unwrap_or(
        Apply(head, args.map(item => eval_arith(item))),
      )
    Tuple(args) => Tuple(args.map(item => eval_arith(item)))
    Dict(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        let (key, value) = item
        out.push((eval_arith(key), eval_arith(value)))
      }
      Dict(out)
    }
    Mod(lhs, rhs) => @symcore.mod_expr(eval_arith(lhs), eval_arith(rhs))
    Relational(op, lhs, rhs) =>
      match op {
        Eq => Relational(Eq, eval_arith(lhs), eval_arith(rhs))
        Ne => Relational(Ne, eval_arith(lhs), eval_arith(rhs))
        Lt => Relational(Lt, eval_arith(lhs), eval_arith(rhs))
        Le => Relational(Le, eval_arith(lhs), eval_arith(rhs))
        Gt => Relational(Gt, eval_arith(lhs), eval_arith(rhs))
        Ge => Relational(Ge, eval_arith(lhs), eval_arith(rhs))
      }
    Derivative(inner, deriv_args) => {
      let out : Array[@symcore.Expr] = []
      out.push(eval_arith(inner))
      for arg in deriv_args {
        out.push(eval_arith(arg))
      }
      @symcore.raw_function("Derivative", out)
    }
    Subs(inner, variable, value) =>
      @symcore.subs_expr(
        eval_arith(inner),
        eval_arith(variable),
        eval_arith(value),
      )
    Lambda(vars, body) =>
      @symcore.lambda_expr(eval_arith(vars), eval_arith(body))
    Add(args) => {
      let out = args.map(item => eval_arith(item))
      let mut all_num = true
      let mut sum = @symnum.BigRational::zero()
      for item in out {
        match item {
          Number(n) => sum = sum.add_r(n)
          _ => all_num = false
        }
      }
      if all_num {
        Number(sum)
      } else {
        @symcore.add(out)
      }
    }
    Mul(args) => {
      let out = args.map(item => eval_arith(item))
      let mut all_num = true
      let mut prod = @symnum.BigRational::one()
      for item in out {
        match item {
          Number(n) => prod = prod.mul_r(n)
          _ => all_num = false
        }
      }
      if all_num {
        Number(prod)
      } else {
        @symcore.mul(out)
      }
    }
    Pow(base, exp) => {
      let b = eval_arith(base)
      let e = eval_arith(exp)
      match (b, e) {
        (Number(nb), Number(ne)) =>
          if ne.is_integral() {
            match pow_int(nb, ne.numerator().to_int()) {
              Some(value) => Number(value)
              None => @symcore.pow(b, e)
            }
          } else {
            @symcore.pow(b, e)
          }
        _ => @symcore.pow(b, e)
      }
    }
    _ =>
      match @symcore.application_parts(expr) {
        Some((head, args)) =>
          match @symcore.raw_apply(head, args.map(item => eval_arith(item))) {
            Some(next) => next
            None => expr
          }
        None => expr
      }
  }
}

///|
pub fn substitute_symbol(
  expr : @symcore.Expr,
  name : String,
  value : @symcore.Expr,
) -> @symcore.Expr {
  let env : Map[String, @symcore.Expr] = Map([])
  env[name] = value
  @symcore.subst(expr, env)
}

///|
pub fn tri_not(v : TriBool) -> TriBool {
  match v {
    True => False
    False => True
    Unknown => Unknown
  }
}

///|
pub fn tri_and(lhs : TriBool, rhs : TriBool) -> TriBool {
  match (lhs, rhs) {
    (False, _) | (_, False) => False
    (True, True) => True
    _ => Unknown
  }
}

///|
pub fn tri_or(lhs : TriBool, rhs : TriBool) -> TriBool {
  match (lhs, rhs) {
    (True, _) | (_, True) => True
    (False, False) => False
    _ => Unknown
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
        Eq => cmp == 0
        Ne => cmp != 0
        Lt => cmp < 0
        Le => cmp <= 0
        Gt => cmp > 0
        Ge => cmp >= 0
      }
      if ok {
        True
      } else {
        False
      }
    }
    _ =>
      match op {
        Eq => if @symcore.compare_expr(l, r) == 0 { True } else { Unknown }
        Ne => if @symcore.compare_expr(l, r) == 0 { False } else { Unknown }
        _ => Unknown
      }
  }
}

///|
pub fn evaluate_event(
  event : Event,
  env : Map[String, @symcore.Expr],
) -> TriBool {
  match event {
    Bool(v) => if v { True } else { False }
    Rel(op~, lhs~, rhs~) => {
      let lhs_sub = @symcore.subst(lhs, env)
      let rhs_sub = @symcore.subst(rhs, env)
      eval_relation(op, lhs_sub, rhs_sub)
    }
    Not(inner) => tri_not(evaluate_event(inner, env))
    And(items) => {
      let mut acc = TriBool::True
      for item in items {
        acc = tri_and(acc, evaluate_event(item, env))
      }
      acc
    }
    Or(items) => {
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
    Symbol(name) => out[name] = true
    _ =>
      for child in @symcore.children(expr) {
        collect_expr_symbols(child, out)
      }
  }
}

///|
pub fn event_symbols(event : Event) -> Array[String] {
  let seen : Map[String, Bool] = Map([])
  match event {
    Bool(_) => ()
    Rel(lhs~, rhs~, op~) => {
      ignore(op)
      collect_expr_symbols(lhs, seen)
      collect_expr_symbols(rhs, seen)
    }
    Not(inner) =>
      for s in event_symbols(inner) {
        seen[s] = true
      }
    And(items) | Or(items) =>
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
