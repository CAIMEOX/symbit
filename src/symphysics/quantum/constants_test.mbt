///|
test "physics.quantum.constants: hbar alias" {
  assert_eq(@symprint.to_string(hbar), "hbar")
}

///|
test "physics.quantum.constants: hbar parity" {
  assert_eq(@symprint.to_string(hbar), @sympy_physics.physics_eval_str("hbar"))
}
