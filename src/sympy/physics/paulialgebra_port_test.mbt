///|
fn pauli_port_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = physics_srepr(@symprint.to_string(lhs))
  assert_eq(ours, rhs)
}

///|
test "physics.paulialgebra: delta and epsilon parity" {
  for case in [(1, 1, 1), (2, 3, 0)] {
    assert_eq(delta(case.0, case.1), paulialgebra_delta(case.0, case.1))
  }
  for case in [(1, 2, 3, 1), (1, 3, 2, -1), (1, 1, 2, 0)] {
    assert_eq(
      epsilon(case.0, case.1, case.2),
      paulialgebra_epsilon(case.0, case.1, case.2),
    )
  }
}

///|
test "physics.paulialgebra: evaluate parity" {
  let i = @symcore.Expr::NumberSymbol(@symcore.NumberSymbolKind::ImaginaryUnit)
  let sigma1 = pauli(1)
  let sigma2 = pauli(2)
  let sigma3 = pauli(3)
  let tau1 = pauli(1, label="tau")
  let tau2 = pauli(2, label="tau")

  for
    case in [
      (pauli_mul(sigma1, sigma2), "sigma1*sigma2"),
      (pauli_mul(sigma3, sigma1), "sigma3*sigma1"),
      (pauli_mul(sigma1, tau2), "sigma1*tau2"),
      (pauli_mul(tau1, tau2), "tau1*tau2"),
      (
        evaluate_pauli_product(pauli_product([sigma1, sigma2, sigma3])),
        "sigma1*sigma2*sigma3",
      ),
      (evaluate_pauli_product(pauli_power(sigma3, 4)), "sigma3**4"),
      (
        evaluate_pauli_product(pauli_product([i, sigma2, sigma3])),
        "I*sigma2*sigma3",
      ),
      (
        evaluate_pauli_product(
          pauli_product([@symcore.int(-4), i, sigma1, sigma2]),
        ),
        "-4*I*sigma1*sigma2",
      ),
      (
        evaluate_pauli_product(
          tensor_product([
            pauli_product([i, sigma1, sigma2, sigma1, sigma2]),
            @symcore.int(1),
          ]),
        ),
        "TensorProduct(I*sigma1*sigma2*sigma1*sigma2, 1)",
      ),
    ] {
    pauli_port_assert_expr_equal(
      case.0,
      paulialgebra_evaluate_srepr(case.1),
      case.1,
    )
  }
}
