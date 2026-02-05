///|
/// Constructors for tensor types.

///|
pub fn tensor_index_type(
  name : String,
  dim? : @symcore.Expr,
  dummy_name? : String = "L",
  metric_symmetry? : Int = 1,
) -> TensorIndexType {
  TensorIndexType::{ name, dim, dummy_name, metric_symmetry }
}

///|
pub fn tensor_index(
  name : String,
  index_type : TensorIndexType,
  is_up? : Bool = true,
) -> TensorIndex {
  TensorIndex::{ name, index_type, is_up }
}

///|
pub fn neg_index(index : TensorIndex) -> TensorIndex {
  TensorIndex::{ name: index.name, index_type: index.index_type, is_up: !index.is_up }
}

///|
pub fn tensor_indices(names : Array[String], index_type : TensorIndexType) -> Array[TensorIndex] {
  let out : Array[TensorIndex] = Array::new()
  for name in names {
    out.push(tensor_index(name, index_type))
  }
  out
}

///|
pub fn tensor_symmetry(
  rank : Int,
  generators : Array[@symcombinatorics.Permutation],
  sign? : Int,
) -> TensorSymmetry {
  TensorSymmetry::{ rank, generators, sign }
}

///|
pub fn tensor_head(
  name : String,
  index_types : Array[TensorIndexType],
  symmetry? : TensorSymmetry,
) -> TensorHead {
  TensorHead::{ name, index_types, symmetry }
}

///|
pub fn apply_head(head : TensorHead, indices : Array[TensorIndex]) -> TensorExpr raise {
  if indices.length() != head.index_types.length() {
    fail("tensor head indices length mismatch")
  }
  TensorExpr::Tensor(head, indices)
}

///|
pub fn scalar_expr(expr : @symcore.Expr) -> TensorExpr {
  TensorExpr::Scalar(expr)
}

///|
pub fn tensor_expr(head : TensorHead, indices : Array[TensorIndex]) -> TensorExpr raise {
  apply_head(head, indices)
}

///|
pub fn TensorHead::call(self : TensorHead, indices : Array[TensorIndex]) -> TensorExpr raise {
  apply_head(self, indices)
}
