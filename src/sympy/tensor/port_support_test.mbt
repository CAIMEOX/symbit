///|
using @symtensor_array {
  array_contraction,
  array_element,
  array_symbol,
  array_tensor_product,
  dense,
  eye,
  permutedims,
  reshape,
  tensorcontraction,
  tensorproduct,
}

///|
using @symtensor_indexed {
  index_idx,
  indexed_base,
  indexed_expr,
  indexed_name,
  idx,
  get_contraction_structure,
}

///|
using @symtensor_tensor {
  canonicalize,
  neg_index,
  partial_derivative,
  tensor_head,
  tensor_index,
  tensor_index_type,
  tensor_symmetry,
}

///|
fn assert_oracle(result : String, expected : String) -> Unit raise {
  assert_eq(result, expected)
}
