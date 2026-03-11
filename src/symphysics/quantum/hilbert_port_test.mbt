///|
test "physics.quantum.hilbert: parity" {
  inspect(try! @sympy_physics.physics_eval_str("HilbertSpace()"), content="H")
  inspect(try! @sympy_physics.physics_srepr("HilbertSpace()"), content="HilbertSpace()")
  inspect(try! @sympy_physics.physics_eval_str("ComplexSpace(2)"), content="C(2)")
  inspect(
    try! @sympy_physics.physics_srepr("ComplexSpace(2)"),
    content="ComplexSpace(Integer(2))",
  )
  inspect(
    try! @sympy_physics.physics_eval_str("TensorProductHilbertSpace(ComplexSpace(2), ComplexSpace(n))"),
    content="C(2)*C(n)",
  )
  inspect(
    try! @sympy_physics.physics_eval_str("TensorProductHilbertSpace(ComplexSpace(2), ComplexSpace(n)).dimension"),
    content="2*n",
  )
  inspect(
    try! @sympy_physics.physics_eval_str("DirectSumHilbertSpace(ComplexSpace(2), FockSpace(), ComplexSpace(n)).dimension"),
    content="oo",
  )
  inspect(
    try! @sympy_physics.physics_eval_str("TensorPowerHilbertSpace(ComplexSpace(n), 2).dimension"),
    content="n**2",
  )
}
