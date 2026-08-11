///|
/// Tensor operators (minimal).

///|
pub struct PartialDerivative {
  expr : TensorExpr
  variables : Array[TensorExpr]
}

///|
pub fn partial_derivative(
  expr : TensorExpr,
  variables : Array[TensorExpr],
) -> PartialDerivative {
  { expr, variables }
}

///|
pub impl Show for PartialDerivative with fn to_string(self) -> String {
  let args : Array[String] = Array::new()
  args.push(Show::to_string(self.expr))
  for v in self.variables {
    args.push(Show::to_string(v))
  }
  "PartialDerivative(" + args.join(", ") + ")"
}

///|
pub impl Show for PartialDerivative with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
