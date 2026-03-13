///|
test "physics.quantum.piab: local Hamiltonian, overlaps, and wavefunction" {
  let n = @symcore.symbol("n")
  let i = @symcore.symbol("i")
  let j = @symcore.symbol("j")

  try! quantum_test_assert_expr_equal(
    qapply(@symcore.raw_mul([piab_hamiltonian(), piab_ket(n)])),
    "n**2*pi**2*hbar**2/(2*m*L**2)*PIABKet(n)",
    "PIAB Hamiltonian action",
  )
  try! quantum_test_assert_expr_equal(
    inner_product(piab_bra(i), piab_ket(j)),
    "KroneckerDelta(i, j)",
    "PIAB overlaps",
  )
  match represent(piab_ket(n)) {
    MatrixScalarValue::Scalar(expr) =>
      try! quantum_test_assert_expr_equal(
        expr, "sqrt(2/L)*sin(n*pi*x/L)", "PIAB wavefunction",
      )
    _ => fail("expected scalar PIAB wavefunction")
  }
}
