///|
pub type ExprOp = @strategies_util.ExprOp

///|
fn expr_op(expr : @symcore.Expr) -> ExprOp {
  @strategies_util.expr_op(expr)
}

///|
fn expr_new_raw(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  @strategies_util.expr_new_raw(op, args)
}

///|
fn expr_is_commutative(expr : @symcore.Expr) -> Bool {
  let expr = @symcore.normalize_legacy_expr(expr)
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(_)
    | @symcore.ExprForm::Float(_)
    | @symcore.ExprForm::ComplexFloat(_)
    | @symcore.ExprForm::NumberSymbol(_)
    | @symcore.ExprForm::Boolean(_)
    | @symcore.ExprForm::IdentityFunction
    | @symcore.ExprForm::Symbol(_)
    | @symcore.ExprForm::Dummy(_, _)
    | @symcore.ExprForm::Wild(_, _, _)
    | @symcore.ExprForm::WildFunction(_, _)
    | @symcore.ExprForm::FunctionHead(_)
    | @symcore.ExprForm::UndefinedFunction(_) => true
    @symcore.ExprForm::Add(_) => true
    @symcore.ExprForm::Mul(args) => args.all(expr_is_commutative)
    @symcore.ExprForm::Pow(base, exp) =>
      expr_is_commutative(base) && expr_is_commutative(exp)
    @symcore.ExprForm::Tuple(items) => items.all(expr_is_commutative)
    @symcore.ExprForm::Dict(items) =>
      items.all(item => {
        expr_is_commutative(item.0) && expr_is_commutative(item.1)
      })
    @symcore.ExprForm::Relational(_, lhs, rhs) =>
      expr_is_commutative(lhs) && expr_is_commutative(rhs)
    @symcore.ExprForm::Derivative(inner, args) =>
      expr_is_commutative(inner) && args.all(expr_is_commutative)
    @symcore.ExprForm::Subs(inner, variable, value) =>
      expr_is_commutative(inner) &&
      expr_is_commutative(variable) &&
      expr_is_commutative(value)
    @symcore.ExprForm::Lambda(vars, body) =>
      expr_is_commutative(vars) && expr_is_commutative(body)
    @symcore.ExprForm::Mod(lhs, rhs) =>
      expr_is_commutative(lhs) && expr_is_commutative(rhs)
    @symcore.ExprForm::Apply(head, args) =>
      match @symcore.function_head_name(head) {
        Some("MatAdd")
        | Some("Union")
        | Some("Intersection")
        | Some("FiniteSet") => true
        Some("MatMul") | Some("MatrixSymbol") => false
        _ => expr_is_commutative(head) && args.all(expr_is_commutative)
      }
  }
}

///|
fn op_is_associative(op : ExprOp) -> Bool {
  match op {
    @strategies_util.ExprOp::Add | @strategies_util.ExprOp::Mul => true
    @strategies_util.ExprOp::Function(name) =>
      name == "MatAdd" ||
      name == "MatMul" ||
      name == "Union" ||
      name == "Intersection" ||
      name == "FiniteSet"
    _ => false
  }
}

///|
fn op_is_commutative(op : ExprOp) -> Bool {
  match op {
    @strategies_util.ExprOp::Add => true
    @strategies_util.ExprOp::Function(name) =>
      name == "MatAdd" ||
      name == "Union" ||
      name == "Intersection" ||
      name == "FiniteSet"
    _ => false
  }
}

///|
pub fn is_associative(term : UnifyTerm[@symcore.Expr, ExprOp]) -> Bool {
  match term {
    UnifyTerm::Compound(op, _) => op_is_associative(op)
    _ => false
  }
}

///|
pub fn is_commutative(term : UnifyTerm[@symcore.Expr, ExprOp]) -> Bool {
  match term {
    UnifyTerm::Compound(op, args) =>
      if op_is_commutative(op) {
        true
      } else {
        match op {
          @strategies_util.ExprOp::Mul =>
            args.all(arg => expr_is_commutative(construct(arg)))
          _ => false
        }
      }
    _ => false
  }
}

///|
pub fn deconstruct(
  expr : @symcore.Expr,
  variables? : Array[@symcore.Expr] = [],
) -> UnifyTerm[@symcore.Expr, ExprOp] {
  let expr = @symcore.normalize_legacy_expr(expr)
  if variables.any(item => item == expr) {
    return variable_term(variable(expr))
  }
  if @symcore.is_atomic(expr) {
    return atom(expr)
  }
  compound(
    expr_op(expr),
    @symcore.args(expr).map(arg => deconstruct(arg, variables~)),
  )
}

///|
pub fn construct(term : UnifyTerm[@symcore.Expr, ExprOp]) -> @symcore.Expr {
  match term {
    UnifyTerm::Atom(expr) => expr
    UnifyTerm::Variable(key) => key.arg()
    UnifyTerm::CondVariable(key, _) => key.arg()
    UnifyTerm::Sequence(items) =>
      @symcore.Expr::Tuple(items.map(item => construct(item)))
    UnifyTerm::Compound(op, args) =>
      expr_new_raw(op, args.map(arg => construct(arg)))
  }
}

///|
pub fn rebuild(expr : @symcore.Expr) -> @symcore.Expr {
  construct(deconstruct(expr))
}

///|
fn internal_substitution(
  values : Map[@symcore.Expr, @symcore.Expr],
  variables : Array[@symcore.Expr],
) -> Substitution[@symcore.Expr, ExprOp] {
  let out : Substitution[@symcore.Expr, ExprOp] = {}
  for key, value in values {
    out[MatchVar::Variable(variable(key))] = deconstruct(value, variables~)
  }
  out
}

///|
fn external_substitution(
  values : Substitution[@symcore.Expr, ExprOp],
) -> Map[@symcore.Expr, @symcore.Expr] {
  let out : Map[@symcore.Expr, @symcore.Expr] = {}
  for key, value in values {
    out[match_var_arg(key)] = construct(value)
  }
  out
}

///|
pub fn unify(
  lhs : @symcore.Expr,
  rhs : @symcore.Expr,
  s? : Map[@symcore.Expr, @symcore.Expr] = {},
  variables? : Array[@symcore.Expr] = [],
) -> Array[Map[@symcore.Expr, @symcore.Expr]] {
  let matches = core_unify(
    deconstruct(lhs, variables~),
    deconstruct(rhs, variables~),
    s=internal_substitution(s, variables),
    is_associative~,
    is_commutative~,
  )
  matches.map(match_ => external_substitution(match_))
}
