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
  Symbol(name, shape)
}

///|
pub fn array_element(
  base : ArrayExpr,
  indices : Array[@symcore.Expr],
) -> ArrayExpr {
  Element(base, indices)
}

///|
pub fn array_tensor_product(items : Array[ArrayExpr]) -> ArrayExpr {
  TensorProduct(items)
}

///|
pub fn array_contraction(
  base : ArrayExpr,
  axes : Array[(Int, Int)],
) -> ArrayExpr {
  Contraction(base, axes)
}

///|
pub fn array_add(items : Array[ArrayExpr]) -> ArrayExpr {
  Add(items)
}

///|
pub fn array_mul(items : Array[ArrayExpr]) -> ArrayExpr {
  Mul(items)
}

///|
fn expr_list_to_string(items : Array[@symcore.Expr]) -> String {
  items.map(@symprint.pretty_string).join(", ")
}

///|
pub impl Show for ArrayExpr with fn to_string(self) -> String {
  match self {
    Symbol(name, shape) =>
      match shape {
        None => name
        Some(shp) => name + "(" + expr_list_to_string(shp) + ")"
      }
    Element(base, indices) =>
      Show::to_string(base) + "[" + expr_list_to_string(indices) + "]"
    TensorProduct(items) =>
      "ArrayTensorProduct(" +
      items.map(item => Show::to_string(item)).join(", ") +
      ")"
    Contraction(base, axes) => {
      let pairs = axes.map(pair => {
        "(" + pair.0.to_string() + ", " + pair.1.to_string() + ")"
      })
      "ArrayContraction(" +
      Show::to_string(base) +
      ", " +
      "[" +
      pairs.join(", ") +
      "]" +
      ")"
    }
    Add(items) => items.map(item => Show::to_string(item)).join(" + ")
    Mul(items) => items.map(item => Show::to_string(item)).join("*")
  }
}

///|
pub impl Show for ArrayExpr with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
