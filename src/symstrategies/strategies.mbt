///|
/// High-level rule combinators for expression rewriting.

///|
/// Operator tag used by the expression strategy helpers.
pub type ExprOp = @strategies_util.ExprOp

///|
/// Bundle of constructor and query hooks used by canonicalization helpers.
pub type Fns[T, Op] = @strategies_util.Fns[T, Op]

///|
/// Default strategy hooks for plain expression trees.
pub let basic_fns : @strategies_util.Fns[@symcore.Expr, ExprOp] = @strategies_util.basic_fns

///|
/// Expression-specific strategy hooks with richer constructor behavior.
pub let expr_fns : @strategies_util.Fns[@symcore.Expr, ExprOp] = @strategies_util.expr_fns

///|
/// Rebuild an expression node from an operator tag and child array.
pub fn new(op : ExprOp, args : Array[@symcore.Expr]) -> @symcore.Expr {
  @strategies_util.new(op, args)
}

///|
/// Apply `rule` only when `cond` holds for the input value.
pub fn[T] condition(cond : (T) -> Bool, rule : (T) -> T) -> (T) -> T {
  @strategies_core.condition(cond, rule)
}

///|
/// Wrap a rule with debug logging.
///
/// The returned rule reports its input and output through `write` whenever it
/// runs.
pub fn[T : Eq + Show] debug(
  rule : (T) -> T,
  name? : String = "rule",
  write? : (String) -> Unit = s => println(s),
) -> (T) -> T {
  @strategies_core.debug(rule, name~, write~)
}

///|
/// Compose several rules left to right.
pub fn[T] chain(rules : Array[(T) -> T]) -> (T) -> T {
  @strategies_core.chain(rules)
}

///|
/// Turn a partial rule returning `T?` into a total rule.
///
/// `None` means “leave the input unchanged”.
pub fn[T] null_safe(rule : (T) -> T?) -> (T) -> T {
  @strategies_core.null_safe(rule)
}

///|
/// Try rules in order and keep the first one that changes the input.
pub fn[T : Eq] do_one(rules : Array[(T) -> T]) -> (T) -> T {
  @strategies_core.do_one(rules)
}

///|
/// Repeatedly apply a rule until it stops changing the input.
pub fn[T : Eq] exhaust(rule : (T) -> T) -> (T) -> T {
  @strategies_core.exhaust(rule)
}

///|
/// Pick the best result produced by a list of candidate rules.
///
/// `objective` maps each candidate result to the value used for comparison.
pub fn[T : Compare] minimize(
  rules : Array[(T) -> T],
  objective? : (T) -> T = @strategies_core.identity,
) -> (T) -> T {
  @strategies_core.minimize(rules, objective~)
}

///|
/// Convert a throwing rule into a non-throwing one.
///
/// When the wrapped rule raises, the original input is returned unchanged.
pub fn[T] tryit(rule : (T) -> T raise, exception? : String = "") -> (T) -> T {
  @strategies_core.tryit(rule, _exception=exception)
}

///|
/// Remove identity arguments from associative expression nodes.
pub fn rm_id(
  isid : (@symcore.Expr) -> Bool,
  new? : (ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.rm_id(isid, new~)
}

///|
/// Strip one layer of singleton wrappers introduced by tree constructors.
pub fn unpack(expr : @symcore.Expr) -> @symcore.Expr {
  @strategies_rl.unpack(expr)
}

///|
/// Flatten nested nodes with the same operator.
pub fn flatten(
  expr : @symcore.Expr,
  new? : (ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> @symcore.Expr {
  @strategies_rl.flatten(expr, new~)
}

///|
/// Sort the arguments of a node using a caller-supplied key.
pub fn[K : Compare] sort(
  key : (@symcore.Expr) -> K,
  new? : (ExprOp, Array[@symcore.Expr]) -> @symcore.Expr = @strategies_util.new,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.sort(key, new~)
}

///|
/// Group arguments that share the same key and merge them with `combine`.
pub fn[K : Eq + Hash, C : Add] glom(
  key : (@symcore.Expr) -> K,
  count : (@symcore.Expr) -> C,
  combine : (C, K) -> @symcore.Expr,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.glom(key, count, combine)
}

///|
/// Build a rule that distributes one operator over another.
pub fn distribute(
  opA : ExprOp,
  opB : ExprOp,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_rl.distribute(opA, opB)
}

///|
/// Rebuild an expression using the strategy-layer constructors.
pub fn rebuild(expr : @symcore.Expr) -> @symcore.Expr {
  @strategies_rl.rebuild(expr)
}

///|
/// Build a canonicalization pipeline from local rewrite rules and hooks.
///
/// The returned rule repeatedly normalizes nodes using the supplied helpers
/// until the expression reaches a stable form.
pub fn canon(
  rules : Array[(@symcore.Expr) -> @symcore.Expr],
  fns? : @strategies_util.Fns[@symcore.Expr, ExprOp] = @strategies_util.basic_fns,
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_tools.canon(rules, fns~)
}

///|
/// Dispatch rules by operator tag.
///
/// Expressions whose operator is missing from `ruletypes` are returned
/// unchanged.
pub fn typed(
  ruletypes : Map[ExprOp, (@symcore.Expr) -> @symcore.Expr],
) -> (@symcore.Expr) -> @symcore.Expr {
  @strategies_tools.typed(ruletypes)
}
