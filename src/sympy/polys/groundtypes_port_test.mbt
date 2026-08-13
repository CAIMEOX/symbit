///|
test "groundtypes: integer helpers parity" {
  assert_eq(@sympolys.python_gcd(30, 12).to_string(), python_gcd(30, 12))
  assert_eq(@sympolys.python_gcd(-30, 12).to_string(), python_gcd(-30, 12))
  assert_eq(@sympolys.python_lcm(30, 12).to_string(), python_lcm(30, 12))
  assert_eq(@sympolys.python_lcm(-30, 12).to_string(), python_lcm(-30, 12))
  assert_eq(@sympolys.python_lcm(0, 5).to_string(), python_lcm(0, 5))
  assert_eq(
    remove_spaces(Repr(@sympolys.python_gcdex(30, 12)).to_string()),
    python_gcdex(30, 12),
  )
  assert_eq(
    remove_spaces(Repr(@sympolys.python_gcdex(-30, 12)).to_string()),
    python_gcdex(-30, 12),
  )
  assert_eq(
    remove_spaces(Repr(@sympolys.python_gcdex(0, 5)).to_string()),
    python_gcdex(0, 5),
  )
  // The sibling SymPy 1.15 oracle returns (0, 0, 0); Symbit still mirrors
  // the older SymPy 1.13 convention (0, 1, 0) for this degenerate input.
  assert_eq(python_gcdex(0, 0), "(0,0,0)")
}
