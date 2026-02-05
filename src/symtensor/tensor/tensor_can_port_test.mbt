///|
test "tensor canonicalize symmetric" {
  let l = tensor_index_type("L")
  let perm = @symcombinatorics.Permutation::from_array([1, 0])
  let sym = tensor_symmetry(2, [perm], sign=0)
  let head = tensor_head("A", [l, l], symmetry=sym)
  let i = tensor_index("i", l)
  let j = tensor_index("j", l)
  let expr = head.call([j, i])
  let canon = canonicalize(expr)
  assert_eq(to_string(canon), "A(i, j)")
}
