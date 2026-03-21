///|
/// Printers for indexed types.

///|
fn index_to_string(index : Index) -> String {
  match index {
    Index::Expr(expr) => @symprint.to_string(expr)
    Index::Idx(item) => item.name
  }
}

///|
pub impl Show for Idx with to_string(self) -> String {
  self.name
}

///|
pub impl Show for Idx with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for IndexedBase with to_string(self) -> String {
  self.name
}

///|
pub impl Show for IndexedBase with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
pub impl Show for Indexed with to_string(self) -> String {
  let base_str = self.base.to_string()
  let indices = self.indices.map(index_to_string)
  base_str + "[" + indices.join(", ") + "]"
}

///|
pub impl Show for Indexed with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}

///|
fn format_expr(expr : IndexedExpr, parent_prec : Int) -> String {
  let prec = match expr {
    IndexedExpr::Add(_) => 1
    IndexedExpr::Mul(_) => 2
    _ => 3
  }
  let body = match expr {
    IndexedExpr::Scalar(e) => @symprint.to_string(e)
    IndexedExpr::Atom(i) => i.to_string()
    IndexedExpr::Add(items) =>
      items.map(item => format_expr(item, prec)).join(" + ")
    IndexedExpr::Mul(items) =>
      items.map(item => format_expr(item, prec)).join("*")
  }
  if prec < parent_prec {
    "(" + body + ")"
  } else {
    body
  }
}

///|
pub impl Show for IndexedExpr with to_string(self) -> String {
  format_expr(self, 0)
}

///|
pub impl Show for IndexedExpr with output(self, logger : &Logger) -> Unit {
  logger.write_string(self.to_string())
}
