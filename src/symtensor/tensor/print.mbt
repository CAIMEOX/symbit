///|
/// Printers for tensor expressions.

///|
fn index_to_string(index : TensorIndex) -> String {
  if index.is_up {
    index.name
  } else {
    "-" + index.name
  }
}

///|
pub fn index_type_to_string(index_type : TensorIndexType) -> String {
  index_type.name
}

///|
pub fn head_to_string(head : TensorHead) -> String {
  head.name
}

///|
fn format_expr(expr : TensorExpr, parent_prec : Int) -> String {
  let prec = match expr {
    TensorExpr::Add(_) => 1
    TensorExpr::Mul(_) => 2
    _ => 3
  }
  let body = match expr {
    TensorExpr::Scalar(e) => @symprint.to_string(e)
    TensorExpr::Tensor(head, indices) => {
      let args = indices.map(index_to_string).join(", ")
      head_to_string(head) + "(" + args + ")"
    }
    TensorExpr::Add(items) =>
      items.map(item => format_expr(item, prec)).join(" + ")
    TensorExpr::Mul(items) =>
      items.map(item => format_expr(item, prec)).join("*")
  }
  if prec < parent_prec {
    "(" + body + ")"
  } else {
    body
  }
}

///|
pub fn to_string(expr : TensorExpr) -> String {
  format_expr(expr, 0)
}
