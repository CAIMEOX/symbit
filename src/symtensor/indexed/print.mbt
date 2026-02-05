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
pub fn idx_to_string(item : Idx) -> String {
  item.name
}

///|
pub fn indexed_base_to_string(base : IndexedBase) -> String {
  base.name
}

///|
pub fn indexed_to_string(item : Indexed) -> String {
  let base_str = indexed_base_to_string(item.base)
  let indices = item.indices.map(index_to_string)
  base_str + "[" + indices.join(", ") + "]"
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
    IndexedExpr::Atom(i) => indexed_to_string(i)
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
pub fn indexed_expr_to_string(expr : IndexedExpr) -> String {
  format_expr(expr, 0)
}
