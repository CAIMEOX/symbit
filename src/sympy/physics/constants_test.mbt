///|
test "physics.quantum.constants: hbar alias" {
  assert_eq(@symprint.pretty_string(hbar), "hbar")
}

///|
test "physics.quantum.constants: hbar parity" {
  assert_eq(@symprint.pretty_string(hbar), physics_eval_str("hbar"))
}
