///|
/// Tensor-product helpers aligned with the matrix and symbolic subset of
/// `sympy.physics.quantum.tensorproduct`.

///|
pub struct TensorProductExpr {
  args : Array[Expr]
} derive(Eq)

///|
fn tensor_product_scalar_body(
  expr : Expr,
) -> (Expr, Expr?) {
  let (scalar, body) = quantum_split_scalar_factors(expr)
  match body {
    Some(Expr::Function("TensorProduct", inner)) => {
      let scalar_factors : Array[Expr] = [scalar]
      let items : Array[Expr] = []
      for item in inner {
        let (item_scalar, item_body) = tensor_product_scalar_body(item)
        if item_scalar != int(1) {
          scalar_factors.push(item_scalar)
        }
        items.push(item_body.unwrap_or(int(1)))
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
fn tensor_product_as_expr(args : Array[Expr]) -> Expr {
  if args.is_empty() {
    return int(1)
  }
  let scalar_factors : Array[Expr] = []
  let normalized : Array[Expr] = []
  for arg in args {
    let (scalar, body) = tensor_product_scalar_body(arg)
    if scalar != int(1) {
      scalar_factors.push(scalar)
    }
    match body {
      Some(Expr::Function("TensorProduct", inner)) =>
        for item in inner {
          normalized.push(item)
        }
      Some(core) => normalized.push(core)
      None => normalized.push(int(1))
    }
  }
  let scalar = quantum_mul_from_args_preserve(scalar_factors)
  if normalized.all(item => item == int(1)) {
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
pub fn tensor_product(args : Array[Expr]) -> TensorProductExpr {
  TensorProductExpr::{ args, }
}

///|
pub fn TensorProductExpr::as_expr(self : TensorProductExpr) -> Expr {
  tensor_product_as_expr(self.args)
}

///|
pub fn tensor_product_expand(expr : Expr) -> Expr {
  match expr {
    Expr::Function("TensorProduct", args) => {
      for idx in 0..<args.length() {
        match args[idx] {
          Expr::Add(terms) => {
            let expanded : Array[Expr] = []
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
    Expr::Add(args) =>
      quantum_add_from_args_preserve(
        args.map(arg => tensor_product_expand(arg)),
      )
    _ => expr
  }
}

///|
fn tensor_product_items(expr : Expr) -> Array[Expr]? {
  match expr {
    Expr::Function("TensorProduct", args) => Some(args.copy())
    _ => None
  }
}

///|
fn tensor_product_pow_items(expr : Expr) -> Array[Expr]? {
  match expr {
    Expr::Pow(base, exp) =>
      match tensor_product_items(base) {
        Some(items) =>
          Some(
            items.map(item => @symcore.raw_pow(tensor_product_simp(item), exp)),
          )
        None => None
      }
    _ => tensor_product_items(expr)
  }
}

///|
fn tensor_product_merge_factors(
  factors : Array[Expr],
) -> Expr {
  let mut saw_other = false
  let simplified_factors : Array[Expr] = []
  let scalar_factors : Array[Expr] = []
  let mut merged_items : Array[Expr]? = None
  for factor in factors {
    let simplified = tensor_product_simp(factor)
    simplified_factors.push(simplified)
    let (scalar, body) = quantum_split_scalar_factors(simplified)
    if scalar != int(1) {
      scalar_factors.push(scalar)
    }
    match body {
      Some(core) =>
        match tensor_product_pow_items(core) {
          Some(items) =>
            match merged_items {
              None => merged_items = Some(items)
              Some(current) if current.length() == items.length() => {
                let next : Array[Expr] = []
                for idx in 0..<current.length() {
                  next.push(
                    quantum_mul_from_args_preserve([current[idx], items[idx]]),
                  )
                }
                merged_items = Some(next)
              }
              Some(_) => saw_other = true
            }
          None => saw_other = true
        }
      None => ()
    }
  }
  if saw_other {
    quantum_mul_from_args_preserve(simplified_factors)
  } else {
    let out = scalar_factors.copy()
    match merged_items {
      Some(items) => out.push(tensor_product(items).as_expr())
      None => ()
    }
    quantum_mul_from_args_preserve(out)
  }
}

///|
pub fn tensor_product_simp(expr : Expr) -> Expr {
  match expr {
    Expr::Add(args) =>
      quantum_add_from_args_preserve(args.map(arg => tensor_product_simp(arg)))
    Expr::Mul(args) => tensor_product_merge_factors(args)
    Expr::Pow(base, exp) =>
      match tensor_product_items(tensor_product_simp(base)) {
        Some(items) =>
          tensor_product(
            items.map(item => @symcore.raw_pow(tensor_product_simp(item), exp)),
          ).as_expr()
        None => @symcore.raw_pow(tensor_product_simp(base), exp)
      }
    _ => expr
  }
}

///|
fn tensor_product_needs_parens(expr : Expr) -> Bool {
  match expr {
    Expr::Add(_) | Expr::Mul(_) | Expr::Pow(_, _) =>
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
