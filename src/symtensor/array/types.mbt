///|
/// Array types for symtensor.

///|
pub(all) struct DenseArray {
  shape : Array[Int]
  data : Array[@symcore.Expr]
}

///|
pub(all) struct SparseArray {
  shape : Array[Int]
  data : Map[String, @symcore.Expr]
}

///|
pub enum NDimArray {
  Dense(DenseArray)
  Sparse(SparseArray)
}
