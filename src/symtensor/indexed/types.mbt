///|
/// Indexed types.

///|
pub(all) struct Idx {
  name : String
  lower : @symcore.Expr
  upper : @symcore.Expr?
}

///|
pub enum Index {
  Expr(@symcore.Expr)
  Idx(Idx)
}

///|
pub(all) struct IndexedBase {
  name : String
  shape : Array[@symcore.Expr]?
}

///|
pub(all) struct Indexed {
  base : IndexedBase
  indices : Array[Index]
}

///|
pub enum IndexedExpr {
  Scalar(@symcore.Expr)
  Atom(Indexed)
  Add(Array[IndexedExpr])
  Mul(Array[IndexedExpr])
}
