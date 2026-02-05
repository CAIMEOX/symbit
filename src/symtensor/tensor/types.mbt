///|
/// Tensor algebra types.

///|
pub(all) struct TensorIndexType {
  name : String
  dummy_name : String
  dim : @symcore.Expr?
  metric_symmetry : Int
}

///|
pub(all) struct TensorIndex {
  name : String
  index_type : TensorIndexType
  is_up : Bool
}

///|
pub(all) struct TensorSymmetry {
  rank : Int
  generators : Array[@symcombinatorics.Permutation]
  sign : Int?
}

///|
pub(all) struct TensorHead {
  name : String
  index_types : Array[TensorIndexType]
  symmetry : TensorSymmetry?
}

///|
pub enum TensorExpr {
  Scalar(@symcore.Expr)
  Tensor(TensorHead, Array[TensorIndex])
  Add(Array[TensorExpr])
  Mul(Array[TensorExpr])
}
