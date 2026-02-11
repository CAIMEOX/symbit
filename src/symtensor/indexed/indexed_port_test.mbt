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

///|
test "indexed basic construction" {
  let n = @symcore.symbol("n")
  let i = idx("i", upper=n)
  let j = idx("j")
  let base = indexed_base("A", shape=[n, @symcore.int(3)])
  let item = base.at([index_idx(i), index_idx(j)])
  let s = indexed_to_string(item)
  assert_eq(s, "A[i, j]")
  assert_oracle(try? @sympy_tensor.indexed_str(item), "A[i, j]")
}

///|
test "indexed contraction analysis" {
  let i = idx("i")
  let j = idx("j")
  let a = indexed_name("A", [index_idx(i), index_idx(j)])
  let b = indexed_name("B", [index_idx(j)])
  let expr = mul([indexed_expr(a), indexed_expr(b)])
  let info = get_indices(expr)
  assert_eq(info.free.join(","), "i")
  assert_eq(info.dummy.join(","), "j")
  let structure = get_contraction_structure(expr)
  assert_true(structure.contains("j"))
}
