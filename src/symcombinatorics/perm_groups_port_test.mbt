///|
test "combinatorics permutation group elements/order parity (S3)" {
  let gen1 = Permutation::from_array([1, 0, 2])
  let gen2 = Permutation::from_array([1, 2, 0])
  let group = PermutationGroup::new([gen1, gen2])
  let gens = array_forms(group.generators())
  let elems = array_forms(group.elements())
  assert_oracle(try? @sympy_combinatorics.perm_group_elements_equiv_from_gens(gens, elems))
  assert_oracle(try? @sympy_combinatorics.perm_group_order_equiv_from_gens(gens, group.order()))
}

///|
test "combinatorics permutation group elements/order parity (cyclic)" {
  let gen = Permutation::from_array([1, 2, 3, 0])
  let group = PermutationGroup::new([gen])
  let gens = array_forms(group.generators())
  let elems = array_forms(group.elements())
  assert_oracle(try? @sympy_combinatorics.perm_group_elements_equiv_from_gens(gens, elems))
  assert_oracle(try? @sympy_combinatorics.perm_group_order_equiv_from_gens(gens, group.order()))
}
