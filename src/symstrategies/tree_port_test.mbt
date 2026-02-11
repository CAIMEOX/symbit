///|
///\
fn leaf_int(v : Int) -> @strategies_tree.Tree[Int] {
  @strategies_tree.Tree::Leaf(v)
}

///|
fn choice_int(
  items : Array[@strategies_tree.Tree[Int]],
) -> @strategies_tree.Tree[Int] {
  @strategies_tree.Tree::Choice(items)
}

///|
fn seq_int(
  items : Array[@strategies_tree.Tree[Int]],
) -> @strategies_tree.Tree[Int] {
  @strategies_tree.Tree::Seq(items)
}

///|
fn leaf_rule(rule : (Int) -> Int) -> @strategies_tree.Tree[(Int) -> Int] {
  @strategies_tree.Tree::Leaf(rule)
}

///|
fn choice_rule(
  items : Array[@strategies_tree.Tree[(Int) -> Int]],
) -> @strategies_tree.Tree[(Int) -> Int] {
  @strategies_tree.Tree::Choice(items)
}

///|
fn seq_rule(
  items : Array[@strategies_tree.Tree[(Int) -> Int]],
) -> @strategies_tree.Tree[(Int) -> Int] {
  @strategies_tree.Tree::Seq(items)
}

///|
fn tree_inc(x : Int) -> Int {
  x + 1
}

///|
fn tree_dec(x : Int) -> Int {
  x - 1
}

///|
fn tree_double(x : Int) -> Int {
  2 * x
}

///|
fn tree_square(x : Int) -> Int {
  x * x
}

///|
fn arr_min(xs : Array[Int]) -> Int {
  let mut m = xs[0]
  for v in xs {
    if v < m {
      m = v
    }
  }
  m
}

///|
fn arr_max(xs : Array[Int]) -> Int {
  let mut m = xs[0]
  for v in xs {
    if v > m {
      m = v
    }
  }
  m
}

///|
fn arr_sum(xs : Array[Int]) -> Int {
  let mut acc = 0
  for v in xs {
    acc += v
  }
  acc
}

///|
fn arr_prod(xs : Array[Int]) -> Int {
  let mut acc = 1
  for v in xs {
    acc *= v
  }
  acc
}

///|
test "treeapply basic" {
  let tree = seq_int([
    choice_int([leaf_int(3), leaf_int(3)]),
    choice_int([leaf_int(4), leaf_int(1)]),
    leaf_int(2),
  ])
  let join_minmax : @strategies_tree.TreeJoin[Int] = {
    choice: xs => arr_min(xs),
    seq: xs => arr_max(xs),
  }
  let join_addmul : @strategies_tree.TreeJoin[Int] = {
    choice: xs => arr_sum(xs),
    seq: xs => arr_prod(xs),
  }
  assert_eq(
    @strategies_tree.treeapply(tree, join_minmax),
    try! @sympy_strategies.tree_treeapply_minmax(),
  )
  assert_eq(
    @strategies_tree.treeapply(tree, join_addmul),
    try! @sympy_strategies.tree_treeapply_addmul(),
  )
}

///|
test "treeapply leaf" {
  let join : @strategies_tree.TreeJoin[Int] = {
    choice: xs => arr_min(xs),
    seq: xs => arr_max(xs),
  }
  let res = @strategies_tree.treeapply(leaf_int(3), join, leaf=x => x * x)
  assert_eq(res, try! @sympy_strategies.tree_treeapply_leaf_square())
}

///|
test "treeapply strategies" {
  let join : @strategies_tree.TreeJoin[(Int) -> Int] = {
    choice: rules => @strategies_core.chain(rules),
    seq: rules => @strategies_core.minimize(rules),
  }
  let rule_tree = seq_rule([leaf_rule(tree_inc), leaf_rule(tree_dec)])
  let r = @strategies_tree.treeapply(rule_tree, join)
  assert_eq(r(5), try! @sympy_strategies.tree_treeapply_strategies_1())
  let tree = seq_rule([
    leaf_rule(tree_inc),
    choice_rule([leaf_rule(tree_dec), leaf_rule(tree_double)]),
  ])
  let r2 = @strategies_tree.treeapply(tree, join)
  assert_eq(r2(1), try! @sympy_strategies.tree_treeapply_strategies_2())
}

///|
test "treeapply maximize" {
  let maximize = (rules : Array[(Int) -> Int]) => {
    @strategies_core.minimize(rules, objective=x => -x)
  }
  let join : @strategies_tree.TreeJoin[(Int) -> Int] = {
    choice: rules => @strategies_core.chain(rules),
    seq: rules => maximize(rules),
  }
  let tree = seq_rule([
    leaf_rule(tree_inc),
    choice_rule([leaf_rule(tree_dec), leaf_rule(tree_double)]),
  ])
  let r = @strategies_tree.treeapply(tree, join)
  assert_eq(r(4), try! @sympy_strategies.tree_treeapply_maximize(4))
  assert_eq(r(1), try! @sympy_strategies.tree_treeapply_maximize(1))
}

///|
test "greedy" {
  let tree = choice_rule([
    leaf_rule(tree_inc),
    seq_rule([leaf_rule(tree_dec), leaf_rule(tree_double)]),
  ])
  let fn_max = @strategies_tree.greedy(tree, objective=x => -x)
  assert_eq(fn_max(4), try! @sympy_strategies.tree_greedy_max(4))
  assert_eq(fn_max(1), try! @sympy_strategies.tree_greedy_max(1))
  let tree2 = choice_rule([
    leaf_rule(tree_inc),
    leaf_rule(tree_dec),
    choice_rule([
      leaf_rule(tree_inc),
      leaf_rule(tree_dec),
      choice_rule([
        seq_rule([leaf_rule(tree_inc), leaf_rule(tree_inc)]),
        seq_rule([leaf_rule(tree_dec), leaf_rule(tree_dec)]),
      ]),
    ]),
  ])
  let lowest = @strategies_tree.greedy(tree2)
  let highest = @strategies_tree.greedy(tree2, objective=x => -x)
  assert_eq(lowest(10), try! @sympy_strategies.tree_greedy_chain(10))
  assert_eq(
    highest(10),
    try! @sympy_strategies.tree_greedy_chain(10, maximize=true),
  )
}

///|
test "allresults" {
  let res1 = @strategies_tree.allresults(leaf_rule(tree_inc))(3)
  let oracle1 = try! @sympy_strategies.tree_allresults_single(3)
  assert_set_int_eq(res1, oracle1, "allresults single")
  let res2 = @strategies_tree.allresults(
    choice_rule([leaf_rule(tree_inc), leaf_rule(tree_dec)]),
  )(3)
  let oracle2 = try! @sympy_strategies.tree_allresults_2(3)
  assert_set_int_eq(res2, oracle2, "allresults choice")
  let res3 = @strategies_tree.allresults(
    seq_rule([leaf_rule(tree_inc), leaf_rule(tree_dec)]),
  )(3)
  let oracle3 = try! @sympy_strategies.tree_allresults_3(3)
  assert_set_int_eq(res3, oracle3, "allresults seq")
  let tree = choice_rule([
    leaf_rule(tree_inc),
    seq_rule([leaf_rule(tree_dec), leaf_rule(tree_double)]),
  ])
  let res4 = @strategies_tree.allresults(tree)(4)
  let oracle4 = try! @sympy_strategies.tree_allresults_1(4)
  assert_set_int_eq(res4, oracle4, "allresults mixed")
}

///|
test "brute" {
  let tree = seq_rule([
    choice_rule([leaf_rule(tree_inc), leaf_rule(tree_dec)]),
    leaf_rule(tree_square),
  ])
  let rule_fn = @strategies_tree.brute(tree, objective=x => -x)
  assert_eq(rule_fn(2), try! @sympy_strategies.tree_brute(2))
  assert_eq(rule_fn(-2), try! @sympy_strategies.tree_brute(-2))
  let rule_fn2 = @strategies_tree.brute(leaf_rule(tree_inc))
  assert_eq(rule_fn2(1), try! @sympy_strategies.tree_brute_inc(1))
}
