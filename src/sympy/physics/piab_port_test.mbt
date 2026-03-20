///|
test "physics.quantum.piab: parity" {
  quantum_test_assert_string_equal(
    quantum_eval_str("n**2*pi**2*hbar**2/(2*m*L**2)*PIABKet(n)"),
    quantum_eval_str(
      @symprint.to_string(
        qapply(
          @symcore.raw_mul([piab_hamiltonian(), piab_ket(@symcore.symbol("n"))]),
        ),
      ),
    ),
    "PIAB Hamiltonian parity",
  )
  quantum_test_assert_expr_equal(
    inner_product(
      piab_bra(@symcore.symbol("i")),
      piab_ket(@symcore.symbol("j")),
    ),
    quantum_doit_str("PIABBra(i)*PIABKet(j)"),
    "PIAB inner product parity",
  )
  match represent(piab_ket(@symcore.symbol("n"))) {
    MatrixScalarValue::Scalar(expr) =>
      quantum_test_assert_expr_equal(
        expr,
        quantum_represent_str("PIABKet(n)"),
        "PIAB represent parity",
      )
    _ => fail("expected scalar PIAB wavefunction")
  }
}
