///|
fn pauli_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  let eq : Result[Bool, Error] = try? @sympy_physics.expr_equal(ours, rhs)
  let ok = match eq {
    Ok(value) => value
    Err(err) => fail("\{context}: expr_equal error: \{err}")
  }
  guard ok else {
    fail("\{context}: ours=\{ours}; oracle=\{rhs}")
  }
}

///|
test "physics.paulialgebra: delta and epsilon" {
  guard delta(1, 1) == 1 else { fail("delta(1,1)") }
  guard delta(2, 3) == 0 else { fail("delta(2,3)") }
  guard epsilon(1, 2, 3) == 1 else { fail("epsilon(1,2,3)") }
  guard epsilon(1, 3, 2) == -1 else { fail("epsilon(1,3,2)") }
  guard epsilon(1, 1, 2) == 0 else { fail("epsilon(1,1,2)") }
}

///|
test "physics.paulialgebra: core multiplication rules" {
  let sigma1 = try! pauli(1)
  let sigma2 = try! pauli(2)
  let sigma3 = try! pauli(3)
  let tau1 = try! pauli(1, label="tau")
  let tau2 = try! pauli(2, label="tau")

  try! pauli_assert_expr_equal(pauli_mul(sigma1, sigma2), "I*sigma3", "sigma1*sigma2")
  try! pauli_assert_expr_equal(pauli_mul(sigma3, sigma1), "I*sigma2", "sigma3*sigma1")
  try! pauli_assert_expr_equal(pauli_mul(sigma1, sigma1), "1", "sigma1*sigma1")
  try! pauli_assert_expr_equal(pauli_mul(sigma1, tau2), "sigma1*tau2", "sigma1*tau2")
  try! pauli_assert_expr_equal(pauli_mul(tau1, tau2), "I*tau3", "tau1*tau2")
}

///|
test "physics.paulialgebra: evaluate ordered products" {
  let i = @symcore.symbol("I")
  let sigma1 = try! pauli(1)
  let sigma2 = try! pauli(2)
  let sigma3 = try! pauli(3)

  try! pauli_assert_expr_equal(
    evaluate_pauli_product(pauli_product([sigma1, sigma2, sigma3])),
    "I",
    "sigma1*sigma2*sigma3",
  )
  try! pauli_assert_expr_equal(
    evaluate_pauli_product(pauli_power(sigma3, 4)),
    "1",
    "sigma3**4",
  )
  try! pauli_assert_expr_equal(
    evaluate_pauli_product(pauli_product([i, sigma2, sigma3])),
    "-sigma1",
    "I*sigma2*sigma3",
  )
  try! pauli_assert_expr_equal(
    evaluate_pauli_product(pauli_product([@symcore.int(-4), i, sigma1, sigma2])),
    "4*sigma3",
    "-4*I*sigma1*sigma2",
  )
}

///|
test "physics.paulialgebra: evaluate additive and tensor expressions" {
  let i = @symcore.symbol("I")
  let sigma1 = try! pauli(1)
  let sigma2 = try! pauli(2)
  let sigma3 = try! pauli(3)
  let q = ncsymbol("q")

  let add_expr = @symcore.add([
    @symcore.int(1),
    pauli_product([i, sigma1, sigma2, sigma1, sigma2]),
  ])
  try! pauli_assert_expr_equal(
    evaluate_pauli_product(add_expr),
    "1 - I",
    "1 + I*sigma1*sigma2*sigma1*sigma2",
  )

  let tensor_expr = tensor_product([
    pauli_product([i, sigma1, sigma2, sigma1, sigma2]),
    @symcore.int(1),
  ])
  try! pauli_assert_expr_equal(
    evaluate_pauli_product(tensor_expr),
    "-I*TensorProduct(1, 1)",
    "tensor recursion",
  )

  let boundary_expr = pauli_product([i, sigma1, sigma2, q, sigma1, sigma3])
  try! pauli_assert_expr_equal(
    evaluate_pauli_product(boundary_expr),
    "I*sigma3*q*sigma2",
    "noncommutative boundary",
  )
}
