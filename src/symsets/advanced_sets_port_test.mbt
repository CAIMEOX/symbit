///|
fn sympy_set_str_adv(set : Set) -> String {
  try! @sympy_sets.set_str(set)
}

///|
fn sympy_contains_str_adv(set : Set, elem : @symcore.Expr) -> String {
  try! @sympy_sets.contains_str(set, elem)
}

///|
fn setbool_str_adv(val : SetBool) -> String {
  setbool_to_string(val)
}

///|
test "symsets conditionset parity" {
  let x = @symcore.symbol("x")
  let base = integers()
  let cs_true = condition_set(x, @symlogic.bool_true(), base~)
  assert_eq(to_string(cs_true), sympy_set_str_adv(cs_true))
  let cs_false = condition_set(x, @symlogic.bool_false(), base~)
  assert_eq(to_string(cs_false), sympy_set_str_adv(cs_false))
  let constraint = @symlogic.linear_constraint_from_ints(
    [("x", 1)],
    0,
    @symlogic.RelOp::Gt,
  )
  let cond = @symlogic.BoolExpr::LRA(constraint)
  let cs = condition_set(x, cond, base~)
  assert_eq(to_string(cs), sympy_set_str_adv(cs))
  let res1 = contains(cs, @symcore.int(1))
  let sympy1 = sympy_contains_str_adv(cs, @symcore.int(1))
  assert_eq(setbool_str_adv(res1), sympy1)
  let res2 = contains(cs, @symcore.int(-1))
  let sympy2 = sympy_contains_str_adv(cs, @symcore.int(-1))
  assert_eq(setbool_str_adv(res2), sympy2)
}

///|
test "symsets imageset parity" {
  let x = @symcore.symbol("x")
  let base = integers()
  let img_id = image_set(x, x, base~)
  assert_eq(to_string(img_id), sympy_set_str_adv(img_id))
  let img_const = image_set(x, @symcore.int(2), base~)
  assert_eq(to_string(img_const), sympy_set_str_adv(img_const))
  let expr = @symcore.add([x, @symcore.int(1)])
  let finite_base = finite_set([@symcore.int(1), @symcore.int(2)])
  let img = image_set(x, expr, base=finite_base)
  assert_eq(to_string(img), sympy_set_str_adv(img))
  let res1 = contains(img, @symcore.int(2))
  let sympy1 = sympy_contains_str_adv(img, @symcore.int(2))
  assert_eq(setbool_str_adv(res1), sympy1)
  let res2 = contains(img, @symcore.int(3))
  let sympy2 = sympy_contains_str_adv(img, @symcore.int(3))
  assert_eq(setbool_str_adv(res2), sympy2)
  let res3 = contains(img, @symcore.int(4))
  let sympy3 = sympy_contains_str_adv(img, @symcore.int(4))
  assert_eq(setbool_str_adv(res3), sympy3)
}

///|
test "symsets productset parity" {
  let prod = product_set([integers(), reals()])
  assert_eq(to_string(prod), sympy_set_str_adv(prod))
  let prod_empty = product_set([empty_set(), integers()])
  assert_eq(to_string(prod_empty), sympy_set_str_adv(prod_empty))
  let tuple = @symcore.function("Tuple", [@symcore.int(1), @symcore.int(2)])
  let prod_int = product_set([integers(), integers()])
  let res1 = contains(prod_int, tuple)
  let sympy1 = sympy_contains_str_adv(prod_int, tuple)
  assert_eq(setbool_str_adv(res1), sympy1)
  let half = try! @symcore.rational_from_ints(1, 2)
  let tuple2 = @symcore.function("Tuple", [@symcore.int(1), half])
  let res2 = contains(prod_int, tuple2)
  let sympy2 = sympy_contains_str_adv(prod_int, tuple2)
  assert_eq(setbool_str_adv(res2), sympy2)
  let res3 = contains(prod_int, @symcore.int(1))
  let sympy3 = sympy_contains_str_adv(prod_int, @symcore.int(1))
  assert_eq(setbool_str_adv(res3), sympy3)
}
