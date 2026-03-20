///|
test "physics.quantum.hilbert: parity" {
  inspect(physics_eval_str("HilbertSpace()"), content="H")
  inspect(
    physics_srepr("HilbertSpace()"),
    content="HilbertSpace()",
  )
  inspect(physics_eval_str("ComplexSpace(2)"), content="C(2)")
  inspect(
    physics_srepr("ComplexSpace(2)"),
    content="ComplexSpace(Integer(2))",
  )
  inspect(
    physics_eval_str(
      "TensorProductHilbertSpace(ComplexSpace(2), ComplexSpace(n))",
    ),
    content="C(2)*C(n)",
  )
  inspect(
    physics_eval_str(
      "TensorProductHilbertSpace(ComplexSpace(2), ComplexSpace(n)).dimension",
    ),
    content="2*n",
  )
  inspect(
    physics_eval_str(
      "DirectSumHilbertSpace(ComplexSpace(2), FockSpace(), ComplexSpace(n)).dimension",
    ),
    content="oo",
  )
  inspect(
    physics_eval_str(
      "TensorPowerHilbertSpace(ComplexSpace(n), 2).dimension",
    ),
    content="n**2",
  )
}
