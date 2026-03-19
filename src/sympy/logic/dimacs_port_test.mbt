///|
test "dimacs load parity" {
  let expr1 = dimacs_load("1")
  assert_eq(to_string(expr1), dimacs_load_str("1"))
  let expr2 = dimacs_load("1 2")
  assert_eq(to_string(expr2), dimacs_load_str("1 2"))
  let expr3 = dimacs_load("1\n2")
  assert_eq(to_string(expr3), dimacs_load_str("1\n2"))
  let expr4 = dimacs_load("1 2\n3")
  assert_eq(to_string(expr4), dimacs_load_str("1 2\n3"))
}
