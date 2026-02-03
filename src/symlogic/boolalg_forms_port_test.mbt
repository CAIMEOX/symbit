///|
fn bool_str(b : Bool) -> String {
  if b { "True" } else { "False" }
}

///|
test "boolalg eliminate_implications/to_nnf/to_cnf/to_dnf" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")

  let impl_expr = bool_implies(x, y)
  assert_eq(
    to_string(eliminate_implications(impl_expr)),
    try! @sympy_logic.boolalg_eliminate_implications("Implies(x, y)"),
  )

  let nnf_expr = bool_not(bool_or([x, bool_and([y, z])]))
  assert_eq(
    to_string(to_nnf(nnf_expr)),
    try! @sympy_logic.boolalg_to_nnf("~(x | (y & z))"),
  )

  let xor_expr = bool_xor([x, y, z])
  assert_eq(
    to_string(to_nnf(xor_expr)),
    try! @sympy_logic.boolalg_to_nnf("Xor(x, y, z)"),
  )

  let cnf_expr = bool_or([bool_not(bool_or([x, y])), z])
  assert_eq(
    to_string(to_cnf(cnf_expr)),
    try! @sympy_logic.boolalg_to_cnf("~(x | y) | z"),
  )

  let dnf_expr = bool_and([y, bool_or([x, z])])
  assert_eq(
    to_string(to_dnf(dnf_expr)),
    try! @sympy_logic.boolalg_to_dnf("y & (x | z)"),
  )
}

///|
test "boolalg to_anf and is_* forms" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")

  let anf1 = to_anf(bool_not(x))
  assert_eq(
    to_string(anf1),
    try! @sympy_logic.boolalg_to_anf("~x"),
  )

  let anf2 = to_anf(bool_and([bool_or([x, y]), bool_not(z)]))
  assert_eq(
    to_string(anf2),
    try! @sympy_logic.boolalg_to_anf("(x | y) & ~z"),
  )

  let ite = bool_ite(x, y, z)
  assert_eq(
    to_string(to_anf(ite)),
    try! @sympy_logic.boolalg_to_anf("ITE(x, y, z)"),
  )

  assert_eq(
    bool_str(is_cnf(bool_and([bool_or([x, bool_not(y)]), z]))),
    try! @sympy_logic.boolalg_is_cnf("(x | ~y) & z"),
  )

  assert_eq(
    bool_str(is_dnf(bool_or([bool_and([x, y]), z]))),
    try! @sympy_logic.boolalg_is_dnf("(x & y) | z"),
  )

  assert_eq(
    bool_str(is_nnf(bool_or([x, bool_not(y)]))),
    try! @sympy_logic.boolalg_is_nnf("x | ~y"),
  )

  assert_eq(bool_str(is_anf(anf2)), "True")
}

///|
test "boolalg distribute helpers" {
  let x = bool_symbol("x")
  let y = bool_symbol("y")
  let z = bool_symbol("z")

  let dist1 = distribute_and_over_or(bool_or([x, bool_and([bool_not(y), bool_not(z)])]))
  assert_eq(
    to_string(dist1),
    try! @sympy_logic.boolalg_distribute_and_over_or("x | (~y & ~z)"),
  )

  let dist2 = distribute_or_over_and(bool_and([bool_or([bool_not(x), y]), z]))
  assert_eq(
    to_string(dist2),
    try! @sympy_logic.boolalg_distribute_or_over_and("(~x | y) & z"),
  )

  let dist3 = distribute_xor_over_and(bool_and([bool_xor([bool_not(x), y]), z]))
  assert_eq(
    to_string(dist3),
    try! @sympy_logic.boolalg_distribute_xor_over_and("Xor(~x, y) & z"),
  )
}
