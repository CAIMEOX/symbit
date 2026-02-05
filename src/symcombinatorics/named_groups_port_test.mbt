///|
test "combinatorics named groups parity (symmetric/alternating/dihedral/cyclic)" {
  let sym = symmetric_group(4)
  let sym_elems = array_forms(sym.elements())
  assert_oracle(try? @sympy_combinatorics.named_group_elements_equiv("SymmetricGroup", 4, sym_elems))
  assert_oracle(try? @sympy_combinatorics.named_group_order_equiv("SymmetricGroup", 4, sym.order()))

  let alt = alternating_group(4)
  let alt_elems = array_forms(alt.elements())
  assert_oracle(try? @sympy_combinatorics.named_group_elements_equiv("AlternatingGroup", 4, alt_elems))
  assert_oracle(try? @sympy_combinatorics.named_group_order_equiv("AlternatingGroup", 4, alt.order()))

  let dih = dihedral_group(5)
  let dih_elems = array_forms(dih.elements())
  assert_oracle(try? @sympy_combinatorics.named_group_elements_equiv("DihedralGroup", 5, dih_elems))
  assert_oracle(try? @sympy_combinatorics.named_group_order_equiv("DihedralGroup", 5, dih.order()))

  let cyc = cyclic_group(5)
  let cyc_elems = array_forms(cyc.elements())
  assert_oracle(try? @sympy_combinatorics.named_group_elements_equiv("CyclicGroup", 5, cyc_elems))
  assert_oracle(try? @sympy_combinatorics.named_group_order_equiv("CyclicGroup", 5, cyc.order()))
}

///|
test "combinatorics named groups parity (abelian)" {
  let ab = abelian_group([2, 3])
  let ab_elems = array_forms(ab.elements())
  assert_oracle(try? @sympy_combinatorics.abelian_group_elements_equiv([2, 3], ab_elems))
  assert_oracle(try? @sympy_combinatorics.perm_group_order_equiv_from_gens(
    array_forms(ab.generators()),
    ab.order(),
  ))
}
