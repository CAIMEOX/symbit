///|
test "physics.quantum.qasm: helper functions" {
  assert_eq(flip_index(0, 2), 1)
  assert_eq(flip_index(1, 2), 0)
  assert_eq(trim("something #comment"), "something ")
  assert_eq(fixcommand("Def"), "qdef")
  assert_eq(fixcommand("c-phase"), "cphase")
  let single = stripquotes("'S'")
  assert_eq(single, "S")
  let double = stripquotes("\"T\"")
  assert_eq(double, "T")
  assert_eq(get_index("q0", ["q0", "q1"]), 1)
  assert_eq(get_indices(["q0", "q1"], ["q0", "q1"]), [1, 0])
}

///|
test "physics.quantum.qasm: builtin circuits and labels" {
  let parser = qasm(["qubit q0", "qubit q1", "h q0", "cnot q0,q1"])
  quantum_test_assert_expr_equal(
    parser.get_circuit(),
    "CNOT(1,0)*H(1)",
    "example circuit",
  )
  assert_eq(parser.get_labels(), ["q1", "q0"])

  let swap = read_qasm("qubit q0\nqubit q1\ncnot q0,q1\ncnot q1,q0\ncnot q0,q1")
  quantum_test_assert_expr_equal(
    swap.get_circuit(),
    "CNOT(1,0)*CNOT(0,1)*CNOT(1,0)",
    "swap circuit",
  )
}

///|
test "physics.quantum.qasm: qdef custom gates" {
  let parser = qasm(["qubit q0", "qdef foo,0,'G'", "foo q0"])
  let one_qubit = @symprint.to_string(parser.get_circuit())
  assert_eq(one_qubit, "G(0)")

  let controlled = qasm(["qubit q0", "qubit q1", "qdef foo,1,'G'", "foo q0,q1"])
  let controlled_circuit = @symprint.to_string(controlled.get_circuit())
  assert_eq(controlled_circuit, "CGate(Tuple(1), G(0))")
}
