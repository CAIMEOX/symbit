///|
test "physics.quantum.constants: hbar alias" {
  guard @symprint.to_string(hbar) == "hbar" else { fail("quantum hbar string") }
}

///|
test "physics.quantum.constants: hbar parity" {
  guard @symprint.to_string(hbar) ==
    (try! @sympy_physics.physics_eval_str("hbar")) else {
    fail("quantum hbar parity")
  }
}
