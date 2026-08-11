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
  PartialDerivative::{ expr, variables }
}

///|
pub impl Show for PartialDerivative with fn to_string(self) -> String {
  let args : Array[String] = Array::new()
  args.push(self.expr.to_string())
  for v in self.variables {
    args.push(v.to_string())
  }
  "PartialDerivative(" + args.join(", ") + ")"
}

///|
pub impl Show for PartialDerivative with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
