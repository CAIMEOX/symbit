///|
test "physics.quantum.trace: parity" {
  let a = @symcore.symbol("a")
  let a_op = @symcore.symbol("A")
  let b_op = @symcore.symbol("B")
  let c_op = @symcore.symbol("C")
  let d_op = @symcore.symbol("D")

  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(tr(@symcore.raw_mul([a, a_op]))),
    ),
    quantum_eval_str("Tr(a*A)"),
    "trace scalar parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(tr(@symcore.raw_mul([a_op, b_op]), indices=[2])),
    ),
    quantum_eval_str("Tr(A*B, (2,))"),
    "trace tuple parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tr_permute(tr(@symcore.raw_mul([a_op, b_op, c_op, d_op])), 2),
      ),
    ),
    quantum_trace_permute_str("Tr(A*B*C*D)", 2),
    "trace permute parity",
  )

  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tr_doit(
          tr(
            @symquant.tensor_product([
              outer_product(qubit("0").as_expr(), qubit("0").dual().as_expr()),
              outer_product(qubit("1").as_expr(), qubit("1").dual().as_expr()),
            ]).as_expr(),
          ),
        ),
      ),
    ),
    quantum_eval_str(
      "Tr(TensorProduct(OuterProduct(Qubit(0), QubitBra(0)), OuterProduct(Qubit(1), QubitBra(1)))).doit()",
    ),
    "trace tensor product parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tr_doit(
          tr(
            @symquant.tensor_product([
              outer_product(qubit("0").as_expr(), qubit("0").dual().as_expr()),
              outer_product(qubit("1").as_expr(), qubit("1").dual().as_expr()),
            ]).as_expr(),
            indices=[1],
          ),
        ),
      ),
    ),
    quantum_doit_str(
      "Tr(TensorProduct(OuterProduct(Qubit(0), QubitBra(0)), OuterProduct(Qubit(1), QubitBra(1))), [1])",
    ),
    "trace tensor product partial parity",
  )

  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tr_doit(
          tr(
            density([
              (
                jz_ket(quantum_test_frac(1, 2), quantum_test_frac(1, 2)).as_expr(),
                quantum_test_frac(1, 2),
              ),
              (
                jz_ket(
                  quantum_test_frac(1, 2),
                  @symcore.int(-1) * quantum_test_frac(1, 2),
                ).as_expr(),
                quantum_test_frac(1, 2),
              ),
            ]).as_expr(),
          ),
        ),
      ),
    ),
    quantum_eval_str(
      "Tr(Density((JzKet(Rational(1, 2), Rational(1, 2)), Rational(1, 2)), (JzKet(Rational(1, 2), Rational(-1, 2)), Rational(1, 2)))).doit()",
    ),
    "trace density parity",
  )
  quantum_test_assert_string_equal(
    quantum_eval_str(
      @symprint.to_string(
        tr_doit(
          tr(
            density([
              (
                @symquant.tensor_product([qubit("0").as_expr(), qubit("1").as_expr()]).as_expr(),
                @symcore.int(1),
              ),
            ]).as_expr(),
            indices=[1],
          ),
        ),
      ),
    ),
    quantum_doit_str(
      "Tr(Density((TensorProduct(Qubit(0), Qubit(1)), 1)), [1])",
    ),
    "trace density partial parity",
  )
}
