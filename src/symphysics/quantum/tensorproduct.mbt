///|
/// Tensor-product helpers aligned with the matrix and symbolic subset of
/// `sympy.physics.quantum.tensorproduct`.

///|
pub struct TensorProductExpr {
  args : Array[@symcore.Expr]
} derive(Eq)

///|
pub fn tensor_product(args : Array[@symcore.Expr]) -> TensorProductExpr {
  TensorProductExpr::{ args }
}

///|
pub fn TensorProductExpr::as_expr(self : TensorProductExpr) -> @symcore.Expr {
  @symcore.function("TensorProduct", self.args)
}

///|
fn tensor_product_needs_parens(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Add(_) | @symcore.Expr::Mul(_) | @symcore.Expr::Pow(_, _) => true
    _ => false
  }
}

///|
pub fn TensorProductExpr::to_string(self : TensorProductExpr) -> String {
  let out : Array[String] = Array::new()
  for arg in self.args {
    let rendered = @symprint.to_string(arg)
    if tensor_product_needs_parens(arg) {
      out.push("(\{rendered})")
    } else {
      out.push(rendered)
    }
  }
  out.join("x")
}

///|
pub fn TensorProductExpr::dagger(self : TensorProductExpr) -> TensorProductExpr {
  tensor_product(self.args.map(arg => dagger(arg)))
}

///|
pub fn tensor_product_matrix(
  product : Array[@symphysics.ExplicitMatrix],
) -> @symphysics.ExplicitMatrix raise @symphysics.PhysicsError {
  matrix_tensor_product(product)
}
