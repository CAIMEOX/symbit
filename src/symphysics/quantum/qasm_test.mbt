///|
test "physics.quantum.qasm: helper functions" {
  guard flip_index(0, 2) == 1 else { fail("flip_index left") }
  guard flip_index(1, 2) == 0 else { fail("flip_index right") }
  guard trim("something #comment") == "something " else { fail("trim") }
  guard fixcommand("Def") == "qdef" else { fail("fixcommand def") }
  guard fixcommand("c-phase") == "cphase" else { fail("fixcommand hyphen") }
  let single = stripquotes("'S'")
  guard single == "S" else { fail("stripquotes single: \{single}") }
  let double = stripquotes("\"T\"")
  guard double == "T" else { fail("stripquotes double: \{double}") }
  guard get_index("q0", ["q0", "q1"]) == 1 else { fail("get_index q0") }
  guard get_indices(["q0", "q1"], ["q0", "q1"]) == [1, 0] else {
    fail("get_indices")
  }
}

///|
test "physics.quantum.qasm: builtin circuits and labels" {
  let parser = qasm(["qubit q0", "qubit q1", "h q0", "cnot q0,q1"])
  quantum_test_assert_expr_equal(
    parser.get_circuit(),
    "CNOT(1,0)*H(1)",
    "example circuit",
  )
  guard parser.get_labels() == ["q1", "q0"] else { fail("example labels") }

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
  guard one_qubit == "G(0)" else { fail("qdef one-qubit: \{one_qubit}") }

  let controlled = qasm(["qubit q0", "qubit q1", "qdef foo,1,'G'", "foo q0,q1"])
  let controlled_circuit = @symprint.to_string(controlled.get_circuit())
  guard controlled_circuit == "CGate(Tuple(1), G(0))" else {
    fail("qdef controlled: \{controlled_circuit}")
  }
}
