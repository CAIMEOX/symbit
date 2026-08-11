///|
/// Pattern-based expression rewrite helpers.
///
/// Current Limits:
/// - Rewrites are based on the current `symunify` matcher.
/// - Guarded assumptions are checked through `symassume.ask`.
/// - Results are returned as all valid rewrites without ranking.

///|
/// Pattern-based rewrite rule.
///
/// `source` is the pattern to match, `target` is the replacement template,
/// `variables` marks the expression holes, `condition` can reject candidate
/// matches, and `assumption_query` can require extra facts before rewriting.
///
/// - Does: Stores one source pattern, replacement template, and optional guards.
/// - Input: Built by `rewriterule`.
/// - Returns: A `RewriteRule` value.
/// - Limits: Matching semantics follow the current expression unifier.
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
    Bool(value) => Bool(value)
    Atom(key, args) => Atom(key, args.map(arg => @symcore.xreplace(arg, rules)))
    Not(inner) => @symassume.not_q(query_xreplace(inner, rules))
    And(items) =>
      @symassume.and_q(items.map(item => query_xreplace(item, rules)))
    Or(items) => @symassume.or_q(items.map(item => query_xreplace(item, rules)))
    Implies(lhs, rhs) =>
      @symassume.implies_q(
        query_xreplace(lhs, rules),
        query_xreplace(rhs, rules),
      )
    Equivalent(items) =>
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
    Number(value) =>
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
    Add(args) => Add(args.map(rewrite_expand_commutative_pow))
    Mul(args) => Mul(args.map(rewrite_expand_commutative_pow))
    Pow(base, exp) => {
      let base1 = rewrite_expand_commutative_pow(base)
      let exp1 = rewrite_expand_commutative_pow(exp)
      match @symcore.expr_form(base1) {
        Mul(args) =>
          if positive_integer_exp(exp1) && args.all(rewrite_expr_is_commutative) {
            Mul(args.map(arg => Pow(arg, exp1)))
          } else {
            Pow(base1, exp1)
          }
        _ => Pow(base1, exp1)
      }
    }
    Mod(lhs, rhs) =>
      Mod(
        rewrite_expand_commutative_pow(lhs),
        rewrite_expand_commutative_pow(rhs),
      )
    Tuple(items) => Tuple(items.map(rewrite_expand_commutative_pow))
    Dict(items) => {
      let out : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        out.push(
          (
            rewrite_expand_commutative_pow(item.0),
            rewrite_expand_commutative_pow(item.1),
          ),
        )
      }
      Dict(out)
    }
    Relational(op, lhs, rhs) =>
      Relational(
        op,
        rewrite_expand_commutative_pow(lhs),
        rewrite_expand_commutative_pow(rhs),
      )
    Derivative(inner, deriv_args) =>
      Derivative(
        rewrite_expand_commutative_pow(inner),
        deriv_args.map(rewrite_expand_commutative_pow),
      )
    Subs(inner, variable, value) =>
      Subs(
        rewrite_expand_commutative_pow(inner),
        rewrite_expand_commutative_pow(variable),
        rewrite_expand_commutative_pow(value),
      )
    Lambda(vars, body) =>
      Lambda(
        rewrite_expand_commutative_pow(vars),
        rewrite_expand_commutative_pow(body),
      )
    Apply(head, args) =>
      Apply(
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
        Add(args) => {
          let items = args.map(arg => rewrite_subs_raw(arg, match_))
          items.sort_by((lhs, rhs) => @symcore.compare_expr(lhs, rhs))
          Add(items)
        }
        Mul(args) => Mul(args.map(arg => rewrite_subs_raw(arg, match_)))
        Pow(base, exp) =>
          Pow(rewrite_subs_raw(base, match_), rewrite_subs_raw(exp, match_))
        Mod(lhs, rhs) =>
          Mod(rewrite_subs_raw(lhs, match_), rewrite_subs_raw(rhs, match_))
        Tuple(items) => Tuple(items.map(item => rewrite_subs_raw(item, match_)))
        Dict(items) => {
          let out : Array[(@symcore.Expr, @symcore.Expr)] = []
          for item in items {
            out.push(
              (
                rewrite_subs_raw(item.0, match_),
                rewrite_subs_raw(item.1, match_),
              ),
            )
          }
          Dict(out)
        }
        Relational(op, lhs, rhs) =>
          Relational(
            op,
            rewrite_subs_raw(lhs, match_),
            rewrite_subs_raw(rhs, match_),
          )
        Derivative(inner, deriv_args) =>
          Derivative(
            rewrite_subs_raw(inner, match_),
            deriv_args.map(arg => rewrite_subs_raw(arg, match_)),
          )
        Subs(inner, variable, value) =>
          Subs(
            rewrite_subs_raw(inner, match_),
            rewrite_subs_raw(variable, match_),
            rewrite_subs_raw(value, match_),
          )
        Lambda(vars, body) =>
          Lambda(rewrite_subs_raw(vars, match_), rewrite_subs_raw(body, match_))
        Apply(head, args) =>
          Apply(
            rewrite_subs_raw(head, match_),
            args.map(arg => rewrite_subs_raw(arg, match_)),
          )
        _ => expr
      }
  }
}

///|
/// Build a rewrite rule from a source pattern and replacement template.
///
/// - Does: Constructs a pattern-based rewrite rule.
/// - Input: Source pattern, target template, optional variables, optional
///   condition, and optional assumption query.
/// - Returns: A `RewriteRule`.
/// - Limits: Does not validate that variables appear in the source or target.
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
/// Apply a rewrite rule to one expression and return every valid rewrite.
///
/// Matching may produce more than one result when the pattern is associative or
/// commutative. `assumptions` supplies additional facts used to validate guarded
/// rewrites.
///
/// - Does: Applies a rewrite rule to one expression.
/// - Input: A rule receiver, target expression, and optional assumptions.
/// - Returns: An array of rewritten expressions.
/// - Limits: Can raise `AskError` when an assumption guard cannot be evaluated.
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
          True => ()
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
