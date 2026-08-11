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
  assert_eq(
    remove_spaces(Repr(@sympolys.python_gcdex(0, 0)).to_string()),
    python_gcdex(0, 0),
  )
}
