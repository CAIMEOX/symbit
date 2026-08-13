///|
priv struct StrategiesRecipe {
  builder : @recipe.Builder
  encoder : @exprcodec.Encoder
  mut scope : @recipe.ValueRef
}

///|
fn StrategiesRecipe::new() -> StrategiesRecipe raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let scope = builder.sympy_scope()
  { builder, encoder, scope }
}

///|
fn StrategiesRecipe::bind_int(
  self : StrategiesRecipe,
  name : String,
  value : Int,
) -> Unit raise {
  self.scope = self.builder.bind(
    self.scope,
    name,
    DecimalInt(Show::to_string(value)),
  )
}

///|
fn StrategiesRecipe::bind_bool(
  self : StrategiesRecipe,
  name : String,
  value : Bool,
) -> Unit raise {
  self.scope = self.builder.bind(self.scope, name, Bool(value))
}

///|
fn StrategiesRecipe::bind_expr(
  self : StrategiesRecipe,
  name : String,
  value : @symcore.Expr,
) -> Unit raise {
  self.scope = self.builder.bind(
    self.scope,
    name,
    Ref(self.encoder.encode(value)),
  )
}

///|
fn StrategiesRecipe::bind_expr_map(
  self : StrategiesRecipe,
  name : String,
  value : Map[@symcore.Expr, @symcore.Expr],
) -> Unit raise {
  let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for key, item in value {
    items.push((Ref(self.encoder.encode(key)), Ref(self.encoder.encode(item))))
  }
  let dictionary = self.builder.dict(items)
  self.scope = self.builder.bind(self.scope, name, Ref(dictionary))
}

///|
fn StrategiesRecipe::evaluate(
  self : StrategiesRecipe,
  source : String,
) -> @recipe.ValueRef raise {
  self.builder.require_non_none(
    self.builder.eval(self.scope, source),
    message="sympy-strategies-oracle-none",
  )
}

///|
fn StrategiesRecipe::request_str(
  self : StrategiesRecipe,
  source : String,
) -> String raise {
  self.builder.request_str(self.evaluate(source))
}

///|
fn parse_oracle_int(value : String) -> Int raise {
  @string.parse_int(value) catch {
    _ => fail("sympy-strategies-int:" + value)
  }
}

///|
fn StrategiesRecipe::request_int(
  self : StrategiesRecipe,
  source : String,
) -> Int raise {
  parse_oracle_int(self.builder.request_int(self.evaluate(source)))
}

///|
fn StrategiesRecipe::request_int_array(
  self : StrategiesRecipe,
  source : String,
) -> Array[Int] raise {
  match self.builder.request(self.evaluate(source), List(Int)) {
    Array(items) => {
      let result : Array[Int] = []
      for item in items {
        match item {
          String(value) => result.push(parse_oracle_int(value))
          other => fail("sympy-strategies-int-item:" + other.stringify())
        }
      }
      result
    }
    other => fail("sympy-strategies-int-array:" + other.stringify())
  }
}

///|
fn StrategiesRecipe::request_string_array(
  self : StrategiesRecipe,
  source : String,
) -> Array[String] raise {
  match self.builder.request(self.evaluate(source), List(Str)) {
    Array(items) => {
      let result : Array[String] = []
      for item in items {
        match item {
          String(value) => result.push(value)
          other => fail("sympy-strategies-string-item:" + other.stringify())
        }
      }
      result
    }
    other => fail("sympy-strategies-string-array:" + other.stringify())
  }
}

///|
/// Core oracles
pub fn core_null_safe(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    "sympy.strategies.core.null_safe(lambda value: 2 if value == 1 else None)(x)",
  )
}

///|
pub fn core_exhaust_posdec(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    "sympy.strategies.core.exhaust(lambda value: value - 1 if value > 0 else value)(x)",
  )
}

///|
pub fn core_memoize_posdec(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    "sympy.strategies.core.memoize(lambda value: value - 1 if value > 0 else value)(x)",
  )
}

///|
pub fn core_condition_posdec(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda rule: sympy.strategies.core.condition(
      #|    lambda value: value % 2 == 0, rule)(x))(
      #|  lambda value: value - 1 if value > 0 else value)
    ),
  )
}

///|
pub fn core_chain_posdec(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda rule: sympy.strategies.core.chain(rule, rule)(x))(
      #|  lambda value: value - 1 if value > 0 else value)
    ),
  )
}

///|
pub fn core_tryit_assertion(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|sympy.strategies.core.tryit(
      #|  lambda value: (_ for _ in ()).throw(AssertionError()),
      #|  AssertionError)(x)
    ),
  )
}

///|
pub fn core_do_one_posdec(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda rule: sympy.strategies.core.do_one(rule, rule)(x))(
      #|  lambda value: value - 1 if value > 0 else value)
    ),
  )
}

///|
pub fn core_do_one_pair(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|sympy.strategies.core.do_one(
      #|  lambda value: 2 if value == 1 else value,
      #|  lambda value: 3 if value == 2 else value)(x)
    ),
  )
}

///|
pub fn core_switch_mod3(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|sympy.strategies.core.switch(
      #|  lambda value: value % 3,
      #|  {0: lambda value: value + 1, 1: lambda value: value - 1})(x)
    ),
  )
}

///|
pub fn core_minimize(x : Int, maximize? : Bool = false) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.bind_bool("maximize", maximize)
  recipe.request_int(
    (
      #|((sympy.strategies.core.minimize(
      #|    lambda value: value + 1,
      #|    lambda value: value - 1,
      #|    objective=lambda value: -value)
      #|  if maximize else sympy.strategies.core.minimize(
      #|    lambda value: value + 1,
      #|    lambda value: value - 1))(x))
    ),
  )
}

///|
pub fn core_debug_log_posdec(x : Int) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_str(
    (
      #|(lambda io: (lambda rule, buffer: (
      #|  sympy.strategies.core.debug(rule, buffer)(x),
      #|  buffer.getvalue())[1])(
      #|    (lambda function: (
      #|      setattr(function, '__name__', 'posdec') or function))(
      #|        lambda value: value - 1 if value > 0 else value),
      #|    io.StringIO()))(__import__('io'))
    ),
  )
}

///|
/// RL oracles
pub fn rl_rm_id(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    "sympy.strategies.rl.rm_id(lambda value: value == 0)(expr)",
  )
}

///|
pub fn rl_glom(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|sympy.strategies.rl.glom(
      #|  lambda term: term.as_coeff_Mul()[1],
      #|  lambda term: term.as_coeff_Mul()[0],
      #|  lambda count, argument: count * argument)(expr)
    ),
  )
}

///|
pub fn rl_flatten(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str("sympy.strategies.rl.flatten(expr)")
}

///|
pub fn rl_unpack(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str("sympy.strategies.rl.unpack(expr)")
}

///|
pub fn rl_sort(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str("sympy.strategies.rl.sort(lambda value: str(value))(expr)")
}

///|
pub fn rl_distribute_custom() -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_str(
    (
      #|(lambda T1, T2: sympy.strategies.rl.distribute(T1, T2)(
      #|  T1(1, 2, T2(3, 4), 5)))(
      #|    type('T1', (sympy.core.basic.Basic,), {}),
      #|    type('T2', (sympy.core.basic.Basic,), {}))
    ),
  )
}

///|
pub fn rl_distribute_add_mul(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    "sympy.strategies.rl.distribute(sympy.Mul, sympy.Add)(expr)",
  )
}

///|
pub fn rl_subs(
  expr : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.bind_expr("a", a)
  recipe.bind_expr("b", b)
  recipe.request_str("sympy.strategies.rl.subs(a, b)(expr)")
}

///|
pub fn rl_rebuild(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str("sympy.strategies.rl.rebuild(expr)")
}

///|
/// Traverse oracles
pub fn traverse_sall_zero_symbols(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|sympy.strategies.traverse.sall(
      #|  lambda value: sympy.S.Zero
      #|    if isinstance(value, sympy.Symbol) else value)(expr)
    ),
  )
}

///|
pub fn traverse_top_down_zero_symbols(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|sympy.strategies.traverse.top_down(
      #|  lambda value: sympy.S.Zero
      #|    if isinstance(value, sympy.Symbol) else value)(expr)
    ),
  )
}

///|
pub fn traverse_bottom_up_zero_symbols(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|sympy.strategies.traverse.bottom_up(
      #|  lambda value: sympy.S.Zero
      #|    if isinstance(value, sympy.Symbol) else value)(expr)
    ),
  )
}

///|
pub fn traverse_top_down_once(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|(lambda Basic2: sympy.strategies.traverse.top_down_once(
      #|  lambda value: Basic2(*value.args)
      #|    if value.args and not isinstance(value.args[0], sympy.Integer)
      #|    else value)(expr))(
      #|  type('Basic2', (sympy.core.basic.Basic,), {}))
    ),
  )
}

///|
pub fn traverse_bottom_up_once(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|(lambda Basic2: sympy.strategies.traverse.bottom_up_once(
      #|  lambda value: Basic2(*value.args)
      #|    if value.args and not isinstance(value.args[0], sympy.Integer)
      #|    else value)(expr))(
      #|  type('Basic2', (sympy.core.basic.Basic,), {}))
    ),
  )
}

///|
pub fn traverse_expr_fns(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|sympy.strategies.traverse.bottom_up(
      #|  lambda value: value + 1,
      #|  sympy.strategies.util.expr_fns)(expr)
    ),
  )
}

///|
/// Tools oracles
pub fn tools_subs(
  expr : @symcore.Expr,
  mapping : Map[@symcore.Expr, @symcore.Expr],
) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.bind_expr_map("mapping", mapping)
  recipe.request_str("sympy.strategies.tools.subs(mapping)(expr)")
}

///|
pub fn tools_subs_empty(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str("sympy.strategies.tools.subs({})(expr)")
}

///|
pub fn tools_typed(expr : @symcore.Expr) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_str(
    (
      #|(lambda A, B: (lambda value:
      #|  sympy.strategies.tools.typed({
      #|    A: sympy.strategies.rl.rm_id(lambda item: item == sympy.S(0)),
      #|    B: sympy.strategies.rl.rm_id(lambda item: item == sympy.S(1)),
      #|  })(value))(
      #|    ({'A': A, 'B': B}.get(expr.func.__name__, expr.func))(*expr.args)))(
      #|  type('A', (sympy.core.basic.Basic,), {}),
      #|  type('B', (sympy.core.basic.Basic,), {}))
    ),
  )
}

///|
/// Tree oracles
pub fn tree_treeapply_minmax() -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_int(
    "sympy.strategies.tree.treeapply(([3, 3], [4, 1], 2), {list: min, tuple: max})",
  )
}

///|
pub fn tree_treeapply_addmul() -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_int(
    (
      #|sympy.strategies.tree.treeapply(
      #|  ([3, 3], [4, 1], 2),
      #|  {list: lambda *args: sum(args),
      #|   tuple: lambda *args: __import__('functools').reduce(
      #|     lambda left, right: left * right, args, 1)})
    ),
  )
}

///|
pub fn tree_treeapply_leaf_square() -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_int(
    "sympy.strategies.tree.treeapply(3, {}, leaf=lambda value: value ** 2)",
  )
}

///|
pub fn tree_treeapply_strategies_1() -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_int(
    (
      #|(lambda inc, dec: sympy.strategies.tree.treeapply(
      #|  (inc, dec),
      #|  {list: sympy.strategies.chain,
      #|   tuple: sympy.strategies.minimize})(5))(
      #|  lambda value: value + 1, lambda value: value - 1)
    ),
  )
}

///|
pub fn tree_treeapply_strategies_2() -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_int(
    (
      #|(lambda inc, dec, double: sympy.strategies.tree.treeapply(
      #|  (inc, [dec, double]),
      #|  {list: sympy.strategies.chain,
      #|   tuple: sympy.strategies.minimize})(1))(
      #|  lambda value: value + 1,
      #|  lambda value: value - 1,
      #|  lambda value: 2 * value)
    ),
  )
}

///|
pub fn tree_treeapply_maximize(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda inc, dec, double: sympy.strategies.tree.treeapply(
      #|  (inc, [dec, double]),
      #|  {list: sympy.strategies.chain,
      #|   tuple: lambda *rules: sympy.strategies.minimize(
      #|     *rules, objective=lambda value: -value)})(x))(
      #|  lambda value: value + 1,
      #|  lambda value: value - 1,
      #|  lambda value: 2 * value)
    ),
  )
}

///|
pub fn tree_greedy_max(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda inc, dec, double: sympy.strategies.tree.greedy(
      #|  [inc, (dec, double)], objective=lambda value: -value)(x))(
      #|  lambda value: value + 1,
      #|  lambda value: value - 1,
      #|  lambda value: 2 * value)
    ),
  )
}

///|
pub fn tree_greedy_chain(x : Int, maximize? : Bool = false) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.bind_bool("maximize", maximize)
  recipe.request_int(
    (
      #|(lambda inc, dec: (
      #|  sympy.strategies.tree.greedy(
      #|    [inc, dec, [inc, dec, [(inc, inc), (dec, dec)]]],
      #|    objective=lambda value: -value)
      #|  if maximize else sympy.strategies.tree.greedy(
      #|    [inc, dec, [inc, dec, [(inc, inc), (dec, dec)]]]))(x))(
      #|  lambda value: value + 1, lambda value: value - 1)
    ),
  )
}

///|
pub fn tree_allresults_1(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda inc, dec, double: list(sympy.strategies.tree.allresults(
      #|  [inc, (dec, double)])(x)))(
      #|  lambda value: value + 1,
      #|  lambda value: value - 1,
      #|  lambda value: 2 * value)
    ),
  )
}

///|
pub fn tree_allresults_2(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda inc, dec: list(sympy.strategies.tree.allresults(
      #|  [inc, dec])(x)))(
      #|  lambda value: value + 1, lambda value: value - 1)
    ),
  )
}

///|
pub fn tree_allresults_3(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda inc, dec: list(sympy.strategies.tree.allresults(
      #|  (inc, dec))(x)))(
      #|  lambda value: value + 1, lambda value: value - 1)
    ),
  )
}

///|
pub fn tree_allresults_single(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda inc: list(sympy.strategies.tree.allresults(inc)(x)))(
      #|  lambda value: value + 1)
    ),
  )
}

///|
pub fn tree_brute(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda inc, dec, square: sympy.strategies.tree.brute(
      #|  ([inc, dec], square), lambda value: -value)(x))(
      #|  lambda value: value + 1,
      #|  lambda value: value - 1,
      #|  lambda value: value ** 2)
    ),
  )
}

///|
pub fn tree_brute_inc(x : Int) -> Int raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int(
    (
      #|(lambda inc: sympy.strategies.tree.brute(inc)(x))(
      #|  lambda value: value + 1)
    ),
  )
}

///|
/// Branch core oracles
pub fn branch_exhaust_branch5(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda branch5: list(sympy.strategies.branch.core.exhaust(
      #|  branch5)(x)))(lambda value:
      #|    [value - 1] if 0 < value < 5 else
      #|    ([value + 1] if 5 < value < 10 else
      #|     ([value + 1, value - 1] if value == 5 else [value])))
    ),
  )
}

///|
pub fn branch_debug_posdec(x : Int) -> String raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_str(
    (
      #|(lambda io: (lambda rule, buffer: (
      #|  list(sympy.strategies.branch.core.debug(rule, buffer)(x)),
      #|  buffer.getvalue())[1])(
      #|    (lambda function: (
      #|      setattr(function, '__name__', 'posdec') or function))(
      #|        lambda value: [value - 1] if value > 0 else [value]),
      #|    io.StringIO()))(__import__('io'))
    ),
  )
}

///|
pub fn branch_multiplex_posdec_branch5(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda posdec, branch5: list(
      #|  sympy.strategies.branch.core.multiplex(posdec, branch5)(x)))(
      #|    lambda value: [value - 1] if value > 0 else [value],
      #|    lambda value:
      #|      [value - 1] if 0 < value < 5 else
      #|      ([value + 1] if 5 < value < 10 else
      #|       ([value + 1, value - 1] if value == 5 else [value])))
    ),
  )
}

///|
pub fn branch_condition_even_branch5(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|(lambda branch5: list(sympy.strategies.branch.core.condition(
      #|  lambda value: value % 2 == 0, branch5)(x)))(lambda value:
      #|    [value - 1] if 0 < value < 5 else
      #|    ([value + 1] if 5 < value < 10 else
      #|     ([value + 1, value - 1] if value == 5 else [value])))
    ),
  )
}

///|
pub fn branch_sfilter_even_one_to_n(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|list(sympy.strategies.branch.core.sfilter(
      #|  lambda value: value % 2 == 0,
      #|  lambda value: list(range(value)))(x))
    ),
  )
}

///|
pub fn branch_notempty_even_only(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|list(sympy.strategies.branch.core.notempty(
      #|  lambda value: [value] if value % 2 == 0 else [])(x))
    ),
  )
}

///|
pub fn branch_chain_examples(x : Int, kind : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.bind_int("kind", kind)
  recipe.request_int_array(
    (
      #|(lambda inc, branch5: list(sympy.strategies.branch.core.chain(*{
      #|  0: (),
      #|  1: (inc, inc),
      #|  2: (branch5, inc),
      #|  3: (branch5, inc),
      #|  4: (inc, branch5),
      #|}.get(kind, ()))(x)))(
      #|  lambda value: [value + 1],
      #|  lambda value:
      #|    [value - 1] if 0 < value < 5 else
      #|    ([value + 1] if 5 < value < 10 else
      #|     ([value + 1, value - 1] if value == 5 else [value])))
    ),
  )
}

///|
pub fn branch_onaction_inc() -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.request_string_array(
    (
      #|(lambda records: (
      #|  list(sympy.strategies.branch.core.onaction(
      #|    lambda value: [value + 1],
      #|    lambda function, input_value, output_value:
      #|      records.append((input_value, output_value)))(2)),
      #|  records)[1])([])
    ),
  )
}

///|
pub fn branch_yieldify_inc(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|list(sympy.strategies.branch.core.yieldify(
      #|  lambda value: value + 1)(x))
    ),
  )
}

///|
pub fn branch_do_one_inc_posdec(x : Int) -> Array[Int] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_int("x", x)
  recipe.request_int_array(
    (
      #|list(sympy.strategies.branch.core.do_one(
      #|  lambda value: [value + 1],
      #|  lambda value: [value - 1] if value > 0 else [value])(x))
    ),
  )
}

///|
/// Branch traverse oracles
pub fn branch_traverse_top_down_inc(
  expr : @symcore.Expr,
) -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_string_array(
    (
      #|list(sympy.strategies.branch.traverse.top_down(
      #|  lambda value: [value + 1]
      #|    if isinstance(value, sympy.Integer) else [])(expr))
    ),
  )
}

///|
pub fn branch_traverse_top_down_split5(
  expr : @symcore.Expr,
) -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_string_array(
    (
      #|list(sympy.strategies.branch.traverse.top_down(
      #|  lambda value: [value - 1, value + 1]
      #|    if value == 5 else [])(expr))
    ),
  )
}

///|
pub fn branch_traverse_sall_inc(expr : @symcore.Expr) -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_string_array(
    (
      #|list(sympy.strategies.branch.traverse.sall(
      #|  lambda value: [value + 1]
      #|    if isinstance(value, sympy.Integer) else [])(expr))
    ),
  )
}

///|
pub fn branch_traverse_sall_do_one(expr : @symcore.Expr) -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_string_array(
    (
      #|list(sympy.strategies.branch.traverse.sall(
      #|  sympy.strategies.branch.core.do_one(
      #|    lambda value: [value + 1]
      #|      if isinstance(value, sympy.Integer) else [],
      #|    sympy.strategies.branch.core.identity))(expr))
    ),
  )
}

///|
/// Branch tools oracles
pub fn branch_canon_branch5(expr : @symcore.Expr) -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_string_array(
    (
      #|list(sympy.strategies.branch.tools.canon(lambda value:
      #|  [value - 1]
      #|    if isinstance(value, sympy.Integer) and 0 < value < 5 else
      #|  ([value + 1]
      #|    if isinstance(value, sympy.Integer) and 5 < value < 10 else
      #|   ([value + 1, value - 1]
      #|    if isinstance(value, sympy.Integer) and value == 5 else
      #|    ([value] if isinstance(value, sympy.Integer) else []))))(expr))
    ),
  )
}

///|
pub fn branch_canon_posdec(expr : @symcore.Expr) -> Array[String] raise {
  let recipe = StrategiesRecipe::new()
  recipe.bind_expr("expr", expr)
  recipe.request_string_array(
    (
      #|list(sympy.strategies.branch.tools.canon(lambda value:
      #|  [value - 1]
      #|    if isinstance(value, sympy.Integer) and value > 0 else
      #|  ([value] if isinstance(value, sympy.Integer) else []))(expr))
    ),
  )
}
