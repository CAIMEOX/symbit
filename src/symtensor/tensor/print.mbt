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
pub impl Show for TensorIndexType with fn to_string(self) -> String {
  self.name
}

///|
pub impl Show for TensorIndexType with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Show for TensorHead with fn to_string(self) -> String {
  self.name
}

///|
pub impl Show for TensorHead with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
fn format_expr(expr : TensorExpr, parent_prec : Int) -> String {
  let prec = match expr {
    Add(_) => 1
    Mul(_) => 2
    _ => 3
  }
  let body = match expr {
    Scalar(e) => @symprint.pretty_string(e)
    Tensor(head, indices) => {
      let args = indices.map(index_to_string).join(", ")
      Show::to_string(head) + "(" + args + ")"
    }
    Add(items) => items.map(item => format_expr(item, prec)).join(" + ")
    Mul(items) => items.map(item => format_expr(item, prec)).join("*")
  }
  if prec < parent_prec {
    "(" + body + ")"
  } else {
    body
  }
}

///|
pub impl Show for TensorExpr with fn to_string(self) -> String {
  format_expr(self, 0)
}

///|
pub impl Show for TensorExpr with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
