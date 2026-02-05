///|
/// Tensor operators (minimal).

///|
pub struct PartialDerivative {
  expr : TensorExpr
  variables : Array[TensorExpr]
}

///|
pub fn partial_derivative(expr : TensorExpr, variables : Array[TensorExpr]) -> PartialDerivative {
  PartialDerivative::{ expr, variables }
}

///|
pub fn partial_to_string(pd : PartialDerivative) -> String {
  let args : Array[String] = Array::new()
  args.push(to_string(pd.expr))
  for v in pd.variables {
    args.push(to_string(v))
  }
  "PartialDerivative(" + args.join(", ") + ")"
}
