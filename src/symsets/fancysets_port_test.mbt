///|
fn sympy_contains_str_fancy(set : Set, elem : @symcore.Expr) -> String {
  try! @sympy_sets.contains_str(set, elem)
}

///|
fn setbool_str_fancy(val : SetBool) -> String {
  setbool_to_string(val)
}

///|
test "symsets fancy sets contains parity" {
  let one = @symcore.int(1)
  let zero = @symcore.int(0)
  let half = try! @symcore.rational_from_ints(1, 2)

  let nset = naturals()
  assert_eq(setbool_str_fancy(contains(nset, one)), sympy_contains_str_fancy(nset, one))
  assert_eq(setbool_str_fancy(contains(nset, zero)), sympy_contains_str_fancy(nset, zero))

  let n0set = naturals0()
  assert_eq(setbool_str_fancy(contains(n0set, zero)), sympy_contains_str_fancy(n0set, zero))

  let iset = integers()
  assert_eq(setbool_str_fancy(contains(iset, one)), sympy_contains_str_fancy(iset, one))
  assert_eq(setbool_str_fancy(contains(iset, half)), sympy_contains_str_fancy(iset, half))

  let qset = rationals()
  assert_eq(setbool_str_fancy(contains(qset, half)), sympy_contains_str_fancy(qset, half))

  let rset = reals()
  assert_eq(setbool_str_fancy(contains(rset, half)), sympy_contains_str_fancy(rset, half))
}

///|
test "symsets complement with fancy sets" {
  let res = complement(reals(), integers())
  let sympy = try! @sympy_sets.complement_str(reals(), integers())
  assert_eq(to_string(res), sympy)
}
