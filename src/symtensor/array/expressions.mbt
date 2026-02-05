///|
/// Array expression trees (minimal).

///|
pub enum ArrayExpr {
  Symbol(String, Array[@symcore.Expr]?)
  Element(ArrayExpr, Array[@symcore.Expr])
  TensorProduct(Array[ArrayExpr])
  Contraction(ArrayExpr, Array[(Int, Int)])
  Add(Array[ArrayExpr])
  Mul(Array[ArrayExpr])
}

///|
pub fn array_symbol(name : String, shape? : Array[@symcore.Expr]) -> ArrayExpr {
  ArrayExpr::Symbol(name, shape)
}

///|
pub fn array_element(base : ArrayExpr, indices : Array[@symcore.Expr]) -> ArrayExpr {
  ArrayExpr::Element(base, indices)
}

///|
pub fn array_tensor_product(items : Array[ArrayExpr]) -> ArrayExpr {
  ArrayExpr::TensorProduct(items)
}

///|
pub fn array_contraction(base : ArrayExpr, axes : Array[(Int, Int)]) -> ArrayExpr {
  ArrayExpr::Contraction(base, axes)
}

///|
pub fn array_add(items : Array[ArrayExpr]) -> ArrayExpr {
  ArrayExpr::Add(items)
}

///|
pub fn array_mul(items : Array[ArrayExpr]) -> ArrayExpr {
  ArrayExpr::Mul(items)
}

///|
fn expr_list_to_string(items : Array[@symcore.Expr]) -> String {
  items.map(@symprint.to_string).join(", ")
}

///|
pub fn array_expr_to_string(expr : ArrayExpr) -> String {
  match expr {
    ArrayExpr::Symbol(name, shape) =>
      match shape {
        None => name
        Some(shp) => name + "(" + expr_list_to_string(shp) + ")"
      }
    ArrayExpr::Element(base, indices) =>
      array_expr_to_string(base) + "[" + expr_list_to_string(indices) + "]"
    ArrayExpr::TensorProduct(items) =>
      "ArrayTensorProduct(" + items.map(array_expr_to_string).join(", ") + ")"
    ArrayExpr::Contraction(base, axes) => {
      let pairs = axes.map(pair => "(" + pair.0.to_string() + ", " + pair.1.to_string() + ")")
      "ArrayContraction(" + array_expr_to_string(base) + ", " + "[" + pairs.join(", ") + "]" + ")"
    }
    ArrayExpr::Add(items) =>
      items.map(array_expr_to_string).join(" + ")
    ArrayExpr::Mul(items) =>
      items.map(array_expr_to_string).join("*")
  }
}
