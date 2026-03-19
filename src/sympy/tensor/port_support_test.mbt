///|
using @symtensor_array {
  array_contraction,
  array_element,
  array_expr_to_string,
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
  indexed_to_string,
  idx,
  get_contraction_structure,
}

///|
using @symtensor_tensor {
  canonicalize,
  neg_index,
  partial_derivative,
  partial_to_string,
  tensor_head,
  tensor_index,
  tensor_index_type,
  tensor_symmetry,
}

///|
fn assert_oracle(
  result : Result[String, Error],
  expected : String,
) -> Unit raise {
  match result {
    Ok(value) => assert_eq(value, expected)
    Err(e) => raise e
  }
}
