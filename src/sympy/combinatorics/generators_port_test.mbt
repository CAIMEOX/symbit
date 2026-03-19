///|
test "combinatorics generators symmetric/cyclic/alternating/dihedral parity" {
  let sym = array_forms(symmetric(4))
  assert_oracle(try? generators_symmetric_equiv(4, sym))
  let cyc = array_forms(cyclic(5))
  assert_oracle(try? generators_cyclic_equiv(5, cyc))
  let alt = array_forms(alternating(4))
  assert_oracle(try? generators_alternating_equiv(4, alt))
  let dih = array_forms(dihedral(5))
  assert_oracle(try? generators_dihedral_equiv(5, dih))
}
