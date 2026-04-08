///|
pub struct RewriteRule {
  source : @symcore.Expr
  target : @symcore.Expr
  variables : Array[@symcore.Expr]
  condition : (Array[@symcore.Expr]) -> Bool
  assumption_query : @symassume.Query?
}

///|
fn query_xreplace(
  query : @symassume.Query,
  rules : Array[(@symcore.Expr, @symcore.Expr)],
) -> @symassume.Query {
  match query {
    @symassume.Query::Bool(value) => @symassume.Query::Bool(value)
    @symassume.Query::Atom(key, args) =>
      @symassume.Query::Atom(
        key,
        args.map(arg => @symcore.xreplace(arg, rules)),
      )
    @symassume.Query::Not(inner) =>
      @symassume.not_q(query_xreplace(inner, rules))
    @symassume.Query::And(items) =>
      @symassume.and_q(items.map(item => query_xreplace(item, rules)))
    @symassume.Query::Or(items) =>
      @symassume.or_q(items.map(item => query_xreplace(item, rules)))
    @symassume.Query::Implies(lhs, rhs) =>
      @symassume.implies_q(
        query_xreplace(lhs, rules),
        query_xreplace(rhs, rules),
      )
    @symassume.Query::Equivalent(items) =>
      @symassume.equivalent_q(items.map(item => query_xreplace(item, rules)))
  }
}

///|
fn match_rules(
  match_ : Map[@symcore.Expr, @symcore.Expr],
) -> Array[(@symcore.Expr, @symcore.Expr)] {
  let out : Array[(@symcore.Expr, @symcore.Expr)] = []
  for key, value in match_ {
    out.push((key, value))
  }
  out
}

///|
fn positive_integer_exp(expr : @symcore.Expr) -> Bool {
  match @symcore.expr_form(expr) {
    @symcore.ExprForm::Number(value) =>
      value.is_integral() && value.compare(@symnum.BigRational::zero()) > 0
    _ => false
  }
}

///|
fn rewrite_expr_is_commutative(expr : @symcore.Expr) -> Bool {
  expr_is_commutative(expr)
}

///|
fn rewrite_expand_commutative_pow(expr : @symcore.Expr) -> @symcore.Expr {
  let expr = @symcore.normalize_legacy_expr(expr)
  match expr {
    @symcore.Expr::Add(args) =>
      @symcore.Expr::Add(args.map(rewrite_expand_commutative_pow))
    @symcore.Expr::Mul(args) =>
      @symcore.Expr::Mul(args.map(rewrite_expand_commutative_pow))
    @symcore.Expr::Pow(base, exp) => {
      let base1 = rewrite_expand_commutative_pow(base)
      let exp1 = rewrite_expand_commutative_pow(exp)
      match @symcore.expr_form(base1) {
        @symcore.ExprForm::Mul(args) =>
          if positive_integer_exp(exp1) && args.all(rewrite_expr_is_commutative) {
            @symcore.Expr::Mul(args.map(arg => @symcore.Expr::Pow(arg, exp1)))
          } else {
            @symcore.Expr::Pow(base1, exp1)
          }
        _ => @symcore.Expr::Pow(base1, exp1)
      }
    }
    @symcore.Expr::Mod(lhs, rhs) =>
      @symcore.Expr::Mod(
        rewrite_expand_commutative_pow(lhs),
        rewrite_expand_commutative_pow(rhs),
      )
    @symcore.Expr::Tuple(items) =>
      @symcore.Expr::Tuple(items.map(rewrite_expand_commutative_pow))
    @symcore.Expr::Dict(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        out.push(
          (
            rewrite_expand_commutative_pow(item.0),
            rewrite_expand_commutative_pow(item.1),
          ),
        )
      }
      @symcore.Expr::Dict(out)
    }
    @symcore.Expr::Relational(op, lhs, rhs) =>
      @symcore.Expr::Relational(
        op,
        rewrite_expand_commutative_pow(lhs),
        rewrite_expand_commutative_pow(rhs),
      )
    @symcore.Expr::Derivative(inner, deriv_args) =>
      @symcore.Expr::Derivative(
        rewrite_expand_commutative_pow(inner),
        deriv_args.map(rewrite_expand_commutative_pow),
      )
    @symcore.Expr::Subs(inner, variable, value) =>
      @symcore.Expr::Subs(
        rewrite_expand_commutative_pow(inner),
        rewrite_expand_commutative_pow(variable),
        rewrite_expand_commutative_pow(value),
      )
    @symcore.Expr::Lambda(vars, body) =>
      @symcore.Expr::Lambda(
        rewrite_expand_commutative_pow(vars),
        rewrite_expand_commutative_pow(body),
      )
    @symcore.Expr::Apply(head, args) =>
      @symcore.Expr::Apply(
        rewrite_expand_commutative_pow(head),
        args.map(rewrite_expand_commutative_pow),
      )
    _ => expr
  }
}

///|
fn rewrite_subs_raw(
  expr : @symcore.Expr,
  match_ : Map[@symcore.Expr, @symcore.Expr],
) -> @symcore.Expr {
  let expr = @symcore.normalize_legacy_expr(expr)
  match match_.get(expr) {
    Some(replaced) => @symcore.normalize_legacy_expr(replaced)
    None =>
      match expr {
        @symcore.Expr::Add(args) => {
          let items = args.map(arg => rewrite_subs_raw(arg, match_))
          items.sort_by((lhs, rhs) => @symcore.compare_expr(lhs, rhs))
          @symcore.Expr::Add(items)
        }
        @symcore.Expr::Mul(args) =>
          @symcore.Expr::Mul(args.map(arg => rewrite_subs_raw(arg, match_)))
        @symcore.Expr::Pow(base, exp) =>
          @symcore.Expr::Pow(
            rewrite_subs_raw(base, match_),
            rewrite_subs_raw(exp, match_),
          )
        @symcore.Expr::Mod(lhs, rhs) =>
          @symcore.Expr::Mod(
            rewrite_subs_raw(lhs, match_),
            rewrite_subs_raw(rhs, match_),
          )
        @symcore.Expr::Tuple(items) =>
          @symcore.Expr::Tuple(
            items.map(item => rewrite_subs_raw(item, match_)),
          )
        @symcore.Expr::Dict(items) => {
          let out : Array[(@symcore.Expr, @symcore.Expr)] = []
          for item in items {
            out.push(
              (
                rewrite_subs_raw(item.0, match_),
                rewrite_subs_raw(item.1, match_),
              ),
            )
          }
          @symcore.Expr::Dict(out)
        }
        @symcore.Expr::Relational(op, lhs, rhs) =>
          @symcore.Expr::Relational(
            op,
            rewrite_subs_raw(lhs, match_),
            rewrite_subs_raw(rhs, match_),
          )
        @symcore.Expr::Derivative(inner, deriv_args) =>
          @symcore.Expr::Derivative(
            rewrite_subs_raw(inner, match_),
            deriv_args.map(arg => rewrite_subs_raw(arg, match_)),
          )
        @symcore.Expr::Subs(inner, variable, value) =>
          @symcore.Expr::Subs(
            rewrite_subs_raw(inner, match_),
            rewrite_subs_raw(variable, match_),
            rewrite_subs_raw(value, match_),
          )
        @symcore.Expr::Lambda(vars, body) =>
          @symcore.Expr::Lambda(
            rewrite_subs_raw(vars, match_),
            rewrite_subs_raw(body, match_),
          )
        @symcore.Expr::Apply(head, args) =>
          @symcore.Expr::Apply(
            rewrite_subs_raw(head, match_),
            args.map(arg => rewrite_subs_raw(arg, match_)),
          )
        _ => expr
      }
  }
}

///|
pub fn rewriterule(
  source : @symcore.Expr,
  target : @symcore.Expr,
  variables? : Array[@symcore.Expr] = [],
  condition? : (Array[@symcore.Expr]) -> Bool = _ => true,
  assumption_query? : @symassume.Query? = None,
) -> RewriteRule {
  { source, target, variables, condition, assumption_query }
}

///|
pub fn RewriteRule::apply(
  self : RewriteRule,
  expr : @symcore.Expr,
  assumptions? : @symassume.Query = @symassume.query_true(),
) -> Array[@symcore.Expr] raise @symassume.AskError {
  let out : Array[@symcore.Expr] = []
  for match_ in unify(self.source, expr, variables=self.variables) {
    let values = self.variables.map(symbol => {
      match_.get(symbol).unwrap_or(symbol)
    })
    if !(self.condition)(values) {
      continue
    }
    match self.assumption_query {
      Some(query) =>
        match
          @symassume.ask(
            query_xreplace(query, match_rules(match_)),
            assumptions~,
          ) {
          @symassume.Tri::True => ()
          _ => continue
        }
      None => ()
    }
    let rewritten = rewrite_expand_commutative_pow(
      rewrite_subs_raw(self.target, match_),
    )
    out.push(rewritten)
  }
  out
}
