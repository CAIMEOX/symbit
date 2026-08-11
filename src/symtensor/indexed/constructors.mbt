///|
/// Constructors for indexed types.

///|
pub fn idx(
  name : String,
  upper? : @symcore.Expr,
  lower? : @symcore.Expr = @symcore.int(0),
) -> Idx {
  { name, lower, upper }
}

///|
pub fn indexed_base(
  name : String,
  shape? : Array[@symcore.Expr] = [],
) -> IndexedBase {
  let shape_opt : Array[@symcore.Expr]? = if shape.is_empty() {
    None
  } else {
    Some(shape)
  }
  { name, shape: shape_opt }
}

///|
pub fn indexed(base : IndexedBase, indices : Array[Index]) -> Indexed raise {
  if indices.is_empty() {
    fail("Indexed needs at least one index")
  }
  { base, indices }
}

///|
pub fn indexed_name(name : String, indices : Array[Index]) -> Indexed raise {
  indexed(indexed_base(name), indices)
}

///|
pub fn index_expr(expr : @symcore.Expr) -> Index {
  Expr(expr)
}

///|
pub fn index_idx(item : Idx) -> Index {
  Idx(item)
}

///|
pub fn idx_expr(item : Idx) -> @symcore.Expr {
  Symbol(item.name)
}

///|
pub fn indexed_expr(item : Indexed) -> IndexedExpr {
  Atom(item)
}

///|
pub fn scalar_expr(expr : @symcore.Expr) -> IndexedExpr {
  Scalar(expr)
}

///|
pub fn IndexedBase::at(
  self : IndexedBase,
  indices : Array[Index],
) -> Indexed raise {
  indexed(self, indices)
}
