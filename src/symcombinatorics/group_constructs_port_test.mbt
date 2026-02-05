///|
test "combinatorics direct_product parity" {
  let g1 = cyclic_group(2)
  let g2 = cyclic_group(3)
  let product = direct_product([g1, g2])
  let gens = array_forms(product.generators())
  let elems = array_forms(product.elements())
  assert_oracle(
    try? @sympy_combinatorics.perm_group_elements_equiv_from_gens(gens, elems),
  )
  assert_oracle(
    try? @sympy_combinatorics.perm_group_order_equiv_from_gens(
      gens,
      product.order(),
    ),
  )
}
