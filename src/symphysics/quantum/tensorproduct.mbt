///|
/// Tensor-product helpers aligned with the matrix and symbolic subset of
/// `sympy.physics.quantum.tensorproduct`.

///|
pub struct TensorProductExpr {
  args : Array[@symcore.Expr]
} derive(Eq)

///|
fn tensor_product_scalar_body(
  expr : @symcore.Expr,
) -> (@symcore.Expr, @symcore.Expr?) {
  let (scalar, body) = quantum_split_scalar_factors(expr)
  match body {
    Some(@symcore.Expr::Function("TensorProduct", inner)) => {
      let scalar_factors : Array[@symcore.Expr] = [scalar]
      let items : Array[@symcore.Expr] = []
      for item in inner {
        let (item_scalar, item_body) = tensor_product_scalar_body(item)
        if item_scalar != @symcore.int(1) {
          scalar_factors.push(item_scalar)
        }
        items.push(item_body.unwrap_or(@symcore.int(1)))
      }
      (
        quantum_mul_from_args_preserve(scalar_factors),
        Some(tensor_product(items).as_expr()),
      )
    }
    _ => (scalar, body)
  }
}

///|
fn tensor_product_as_expr(args : Array[@symcore.Expr]) -> @symcore.Expr {
  if args.is_empty() {
    return @symcore.int(1)
  }
  let scalar_factors : Array[@symcore.Expr] = []
  let normalized : Array[@symcore.Expr] = []
  for arg in args {
    let (scalar, body) = tensor_product_scalar_body(arg)
    if scalar != @symcore.int(1) {
      scalar_factors.push(scalar)
    }
    match body {
      Some(@symcore.Expr::Function("TensorProduct", inner)) =>
        for item in inner {
          normalized.push(item)
        }
      Some(core) => normalized.push(core)
      None => normalized.push(@symcore.int(1))
    }
  }
  let scalar = quantum_mul_from_args_preserve(scalar_factors)
  if normalized.all(item => item == @symcore.int(1)) {
    return scalar
  }
  if args.length() == 1 && normalized.length() == 1 {
    return scalar * normalized[0]
  }
  let body = if normalized.length() == 1 {
    normalized[0]
  } else {
    @symcore.function("TensorProduct", normalized)
  }
  scalar * body
}

///|
pub fn tensor_product(args : Array[@symcore.Expr]) -> TensorProductExpr {
  TensorProductExpr::{ args, }
}

///|
pub fn TensorProductExpr::as_expr(self : TensorProductExpr) -> @symcore.Expr {
  tensor_product_as_expr(self.args)
}

///|
pub fn tensor_product_expand(expr : @symcore.Expr) -> @symcore.Expr {
  match expr {
    @symcore.Expr::Function("TensorProduct", args) => {
      for idx in 0..<args.length() {
        match args[idx] {
          @symcore.Expr::Add(terms) => {
            let expanded : Array[@symcore.Expr] = []
            for term in terms {
              let rebuilt = args.copy()
              rebuilt[idx] = term
              expanded.push(
                tensor_product_expand(tensor_product(rebuilt).as_expr()),
              )
            }
            return quantum_add_from_args_preserve(expanded)
          }
          _ => ()
        }
      }
      tensor_product(args).as_expr()
    }
    @symcore.Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(arg => tensor_product_expand(arg)),
      )
    _ => expr
  }
}

///|
fn tensor_product_needs_parens(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Add(_) | @symcore.Expr::Mul(_) | @symcore.Expr::Pow(_, _) =>
      true
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
