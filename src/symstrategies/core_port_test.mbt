///|
///\
fn posdec(x : Int) -> Int {
  if x > 0 {
    x - 1
  } else {
    x
  }
}

///|
fn inc(x : Int) -> Int {
  x + 1
}

///|
fn dec(x : Int) -> Int {
  x - 1
}

///|
test "core null_safe" {
  let rl = (x : Int) => if x == 1 { Some(2) } else { None }
  let safe = @strategies_core.null_safe(rl)
  assert_eq(safe(1), try! @sympy_strategies.core_null_safe(1))
  assert_eq(safe(3), try! @sympy_strategies.core_null_safe(3))
}

///|
test "core exhaust" {
  let sink = @strategies_core.exhaust(posdec)
  assert_eq(sink(5), try! @sympy_strategies.core_exhaust_posdec(5))
  assert_eq(sink(10), try! @sympy_strategies.core_exhaust_posdec(10))
}

///|
test "core memoize" {
  let rl = @strategies_core.memoize(posdec)
  assert_eq(rl(5), try! @sympy_strategies.core_memoize_posdec(5))
  assert_eq(rl(5), try! @sympy_strategies.core_memoize_posdec(5))
  assert_eq(rl(-2), try! @sympy_strategies.core_memoize_posdec(-2))
}

///|
test "core condition" {
  let rl = @strategies_core.condition(x => x % 2 == 0, posdec)
  assert_eq(rl(5), try! @sympy_strategies.core_condition_posdec(5))
  assert_eq(rl(4), try! @sympy_strategies.core_condition_posdec(4))
}

///|
test "core chain" {
  let rl = @strategies_core.chain([posdec, posdec])
  assert_eq(rl(5), try! @sympy_strategies.core_chain_posdec(5))
  assert_eq(rl(1), try! @sympy_strategies.core_chain_posdec(1))
}

///|
test "core tryit" {
  let rl : (Int) -> Int raise = (x : Int) => {
    ignore(x)
    fail("boom")
  }
  let safe = @strategies_core.tryit(rl)
  assert_eq(safe(1), try! @sympy_strategies.core_tryit_assertion(1))
}

///|
test "core do_one" {
  let rl = @strategies_core.do_one([posdec, posdec])
  assert_eq(rl(5), try! @sympy_strategies.core_do_one_posdec(5))
  let rl1 = (x : Int) => if x == 1 { 2 } else { x }
  let rl2 = (x : Int) => if x == 2 { 3 } else { x }
  let rule = @strategies_core.do_one([rl1, rl2])
  assert_eq(rule(1), try! @sympy_strategies.core_do_one_pair(1))
  assert_eq(rule(rule(1)), try! @sympy_strategies.core_do_one_pair(2))
}

///|
test "core debug" {
  let sb = StringBuilder::new()
  let write = (s : String) => sb.write_string(s)
  let rl = @strategies_core.debug(posdec, name="posdec", write~)
  ignore(rl(5))
  let log = sb.to_string()
  let oracle = try! @sympy_strategies.core_debug_log_posdec(5)
  assert_str_eq(log, oracle, "debug")
}

///|
test "core switch" {
  let key = (x : Int) => x % 3
  let ruledict : Map[Int, (Int) -> Int] = Map::new()
  ruledict[0] = inc
  ruledict[1] = dec
  let rl = @strategies_core.switch(key, ruledict)
  assert_eq(rl(3), try! @sympy_strategies.core_switch_mod3(3))
  assert_eq(rl(4), try! @sympy_strategies.core_switch_mod3(4))
  assert_eq(rl(5), try! @sympy_strategies.core_switch_mod3(5))
}

///|
test "core minimize" {
  let rl = @strategies_core.minimize([inc, dec])
  assert_eq(rl(4), try! @sympy_strategies.core_minimize(4))
  let rl_max = @strategies_core.minimize([inc, dec], objective=x => -x)
  assert_eq(rl_max(4), try! @sympy_strategies.core_minimize(4, maximize=true))
}
