///|
///\
fn br_posdec(x : Int) -> Array[Int] {
  if x > 0 {
    [x - 1]
  } else {
    [x]
  }
}

///|
fn br_branch5(x : Int) -> Array[Int] {
  if x > 0 && x < 5 {
    [x - 1]
  } else if x > 5 && x < 10 {
    [x + 1]
  } else if x == 5 {
    [x + 1, x - 1]
  } else {
    [x]
  }
}

///|
fn br_inc(x : Int) -> Array[Int] {
  [x + 1]
}

///|
fn br_one_to_n(n : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  for i in 0..<n {
    out.push(i)
  }
  out
}

///|
test "branch core exhaust" {
  let brl = @strategies_branch.exhaust(br_branch5)
  assert_set_int_eq(
    brl(3),
    try! @sympy_strategies.branch_exhaust_branch5(3),
    "exhaust 3",
  )
  assert_set_int_eq(
    brl(7),
    try! @sympy_strategies.branch_exhaust_branch5(7),
    "exhaust 7",
  )
  assert_set_int_eq(
    brl(5),
    try! @sympy_strategies.branch_exhaust_branch5(5),
    "exhaust 5",
  )
}

///|
test "branch core debug" {
  let sb = StringBuilder::new()
  let write = (s : String) => sb.write_string(s)
  let rl = @strategies_branch.debug(br_posdec, name="posdec", write~)
  ignore(rl(5))
  let log = sb.to_string()
  let oracle = try! @sympy_strategies.branch_debug_posdec(5)
  assert_str_eq(log, oracle, "branch debug")
}

///|
test "branch core multiplex" {
  let brl = @strategies_branch.multiplex([br_posdec, br_branch5])
  assert_set_int_eq(
    brl(3),
    try! @sympy_strategies.branch_multiplex_posdec_branch5(3),
    "multiplex 3",
  )
  assert_set_int_eq(
    brl(7),
    try! @sympy_strategies.branch_multiplex_posdec_branch5(7),
    "multiplex 7",
  )
  assert_set_int_eq(
    brl(5),
    try! @sympy_strategies.branch_multiplex_posdec_branch5(5),
    "multiplex 5",
  )
}

///|
test "branch core condition" {
  let brl = @strategies_branch.condition(x => x % 2 == 0, br_branch5)
  assert_set_int_eq(
    brl(4),
    try! @sympy_strategies.branch_condition_even_branch5(4),
    "condition 4",
  )
  assert_set_int_eq(
    brl(5),
    try! @sympy_strategies.branch_condition_even_branch5(5),
    "condition 5",
  )
}

///|
test "branch core sfilter" {
  let brl = @strategies_branch.sfilter(x => x % 2 == 0, br_one_to_n)
  assert_set_int_eq(
    brl(10),
    try! @sympy_strategies.branch_sfilter_even_one_to_n(10),
    "sfilter",
  )
}

///|
test "branch core notempty" {
  let ident_if_even = (x : Int) => if x % 2 == 0 { [x] } else { [] }
  let brl = @strategies_branch.notempty(ident_if_even)
  assert_set_int_eq(
    brl(4),
    try! @sympy_strategies.branch_notempty_even_only(4),
    "notempty even",
  )
  assert_set_int_eq(
    brl(5),
    try! @sympy_strategies.branch_notempty_even_only(5),
    "notempty odd",
  )
}

///|
test "branch core chain" {
  assert_set_int_eq(
    @strategies_branch.chain([])(2),
    try! @sympy_strategies.branch_chain_examples(2, 0),
    "chain empty",
  )
  assert_set_int_eq(
    @strategies_branch.chain([br_inc, br_inc])(2),
    try! @sympy_strategies.branch_chain_examples(2, 1),
    "chain inc inc",
  )
  assert_set_int_eq(
    @strategies_branch.chain([br_branch5, br_inc])(4),
    try! @sympy_strategies.branch_chain_examples(4, 2),
    "chain branch5 inc 4",
  )
  assert_set_int_eq(
    @strategies_branch.chain([br_branch5, br_inc])(5),
    try! @sympy_strategies.branch_chain_examples(5, 3),
    "chain branch5 inc 5",
  )
  assert_set_int_eq(
    @strategies_branch.chain([br_inc, br_branch5])(5),
    try! @sympy_strategies.branch_chain_examples(5, 4),
    "chain inc branch5",
  )
}

///|
test "branch core onaction" {
  let records : Array[(Int, Int)] = Array::new()
  let record = (rule : @strategies_branch.BRule[Int], input : Int, output : Int) => {
    ignore(rule)
    records.push((input, output))
  }
  ignore(@strategies_branch.onaction(br_inc, record)(2))
  let ours : Array[String] = records.map(pair => {
    let (a, b) = pair
    "(\{a}, \{b})"
  })
  let oracle = try! @sympy_strategies.branch_onaction_inc()
  assert_set_str_eq(ours, oracle, "onaction inc")
}

///|
test "branch core yieldify" {
  let yinc = @strategies_branch.yieldify(x => x + 1)
  assert_set_int_eq(
    yinc(3),
    try! @sympy_strategies.branch_yieldify_inc(3),
    "yieldify",
  )
}

///|
test "branch core do_one" {
  let brl = @strategies_branch.do_one([br_inc])
  assert_set_int_eq(
    brl(3),
    try! @sympy_strategies.branch_do_one_inc_posdec(3),
    "do_one inc",
  )
  let brl2 = @strategies_branch.do_one([br_inc, br_posdec])
  assert_set_int_eq(
    brl2(3),
    try! @sympy_strategies.branch_do_one_inc_posdec(3),
    "do_one inc posdec",
  )
}
