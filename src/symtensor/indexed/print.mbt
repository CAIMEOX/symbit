///|
/// Printers for indexed types.

///|
fn index_to_string(index : Index) -> String {
  match index {
    Expr(expr) => @symprint.pretty_string(expr)
    Idx(item) => item.name
  }
}

///|
pub impl Show for Idx with fn to_string(self) -> String {
  self.name
}

///|
pub impl Show for Idx with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Show for IndexedBase with fn to_string(self) -> String {
  self.name
}

///|
pub impl Show for IndexedBase with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
pub impl Show for Indexed with fn to_string(self) -> String {
  let base_str = Show::to_string(self.base)
  let indices = self.indices.map(index_to_string)
  base_str + "[" + indices.join(", ") + "]"
}

///|
pub impl Show for Indexed with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}

///|
fn format_expr(expr : IndexedExpr, parent_prec : Int) -> String {
  let prec = match expr {
    Add(_) => 1
    Mul(_) => 2
    _ => 3
  }
  let body = match expr {
    Scalar(e) => @symprint.pretty_string(e)
    Atom(i) => Show::to_string(i)
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
pub impl Show for IndexedExpr with fn to_string(self) -> String {
  format_expr(self, 0)
}

///|
pub impl Show for IndexedExpr with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
