///|\
test "boolalg atoms" {
  let x = bool_symbol("x")
  assert_eq(to_string(x), try! @sympy_logic.boolalg_str("x"))
  assert_eq(to_string(bool_true()), try! @sympy_logic.boolalg_str("True"))
  assert_eq(to_string(bool_false()), try! @sympy_logic.boolalg_str("False"))
}

///|
test "boolalg not" {
  let x = bool_symbol("x")
  let expr = bool_not(x)
  assert_eq(to_string(expr), try! @sympy_logic.boolalg_str("~x"))

  let expr2 = bool_not(bool_or([x, bool_symbol("y")]))
  assert_eq(to_string(expr2), try! @sympy_logic.boolalg_str("~(x | y)"))
}

///|
test "boolalg and/or canonicalize" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")

  let expr = bool_and([y, x, bool_true(), x])
  assert_eq(to_string(expr), try! @sympy_logic.boolalg_str("y & x & True & x"))

  let expr2 = bool_or([x, bool_or([y, z]), bool_false()])
  assert_eq(to_string(expr2), try! @sympy_logic.boolalg_str("x | (y | z) | False"))
}

///|
test "boolalg precedence" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")

  let expr = bool_and([x, bool_or([y, z])])
  assert_eq(to_string(expr), try! @sympy_logic.boolalg_str("x & (y | z)"))

  let expr2 = bool_or([x, bool_and([y, z])])
  assert_eq(to_string(expr2), try! @sympy_logic.boolalg_str("x | (y & z)"))
}

///|
test "boolalg xor" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")

  let expr = bool_xor([y, x, bool_true(), x])
  assert_eq(to_string(expr), try! @sympy_logic.boolalg_str("Xor(y, x, True, x)"))

  let expr2 = bool_xor([x, bool_and([y, z])])
  assert_eq(to_string(expr2), try! @sympy_logic.boolalg_str("Xor(x, y & z)"))
}

///|
test "boolalg implies" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  assert_eq(to_string(bool_implies(x, y)), try! @sympy_logic.boolalg_str("Implies(x, y)"))
  assert_eq(to_string(bool_implies(bool_true(), x)), try! @sympy_logic.boolalg_str("Implies(True, x)"))
  assert_eq(to_string(bool_implies(x, bool_false())), try! @sympy_logic.boolalg_str("Implies(x, False)"))
}

///|
test "boolalg equivalent" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")

  let expr = bool_equivalent([y, x, x])
  assert_eq(to_string(expr), try! @sympy_logic.boolalg_str("Equivalent(y, x, x)"))

  let expr2 = bool_equivalent([bool_true(), x, y])
  assert_eq(to_string(expr2), try! @sympy_logic.boolalg_str("Equivalent(True, x, y)"))

  let expr3 = bool_equivalent([bool_false(), x, y])
  assert_eq(to_string(expr3), try! @sympy_logic.boolalg_str("Equivalent(False, x, y)"))

  let expr4 = bool_equivalent([x])
  assert_eq(to_string(expr4), try! @sympy_logic.boolalg_str("Equivalent(x)"))

  let expr5 = bool_equivalent([bool_true(), bool_false()])
  assert_eq(to_string(expr5), try! @sympy_logic.boolalg_str("Equivalent(True, False)"))
}

///|
test "boolalg nand/nor/ite" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")

  let nand_expr = bool_nand([x, y])
  assert_eq(to_string(nand_expr), try! @sympy_logic.boolalg_str("Nand(x, y)"))

  let nor_expr = bool_nor([x, y])
  assert_eq(to_string(nor_expr), try! @sympy_logic.boolalg_str("Nor(x, y)"))

  let ite_expr = bool_ite(x, y, bool_true())
  assert_eq(to_string(ite_expr), try! @sympy_logic.boolalg_str("ITE(x, y, True)"))
}
