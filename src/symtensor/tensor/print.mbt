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
pub impl Show for TensorIndexType with to_string(self) -> String {
  self.name
}

///|
pub impl Show for TensorIndexType with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for TensorHead with to_string(self) -> String {
  self.name
}

///|
pub impl Show for TensorHead with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn format_expr(expr : TensorExpr, parent_prec : Int) -> String {
  let prec = match expr {
    TensorExpr::Add(_) => 1
    TensorExpr::Mul(_) => 2
    _ => 3
  }
  let body = match expr {
    TensorExpr::Scalar(e) => @symprint.pretty_string(e)
    TensorExpr::Tensor(head, indices) => {
      let args = indices.map(index_to_string).join(", ")
      head.to_string() + "(" + args + ")"
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
pub impl Show for TensorExpr with to_string(self) -> String {
  format_expr(self, 0)
}

///|
pub impl Show for TensorExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
