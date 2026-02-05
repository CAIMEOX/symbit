///|
test "combinatorics galois group constructors parity" {
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "four_group",
    array_forms(four_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "M20",
    array_forms(m20().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "S3_in_S6",
    array_forms(s3_in_s6().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "A4_in_S6",
    array_forms(a4_in_s6().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "S4m",
    array_forms(s4m().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "S4p",
    array_forms(s4p().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "A4xC2",
    array_forms(a4xc2().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "S4xC2",
    array_forms(s4xc2().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "G18",
    array_forms(g18().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "G36m",
    array_forms(g36m().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "G36p",
    array_forms(g36p().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "G72",
    array_forms(g72().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "PSL2F5",
    array_forms(psl2f5().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_group_elements_equiv(
    "PGL2F5",
    array_forms(pgl2f5().elements()),
  ))
}

///|
test "combinatorics galois enum parity (S4/S5)" {
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S4TransitiveSubgroups",
    "C4",
    array_forms(S4TransitiveSubgroups::C4.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S4TransitiveSubgroups",
    "V",
    array_forms(S4TransitiveSubgroups::V.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S4TransitiveSubgroups",
    "D4",
    array_forms(S4TransitiveSubgroups::D4.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S4TransitiveSubgroups",
    "A4",
    array_forms(S4TransitiveSubgroups::A4.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S4TransitiveSubgroups",
    "S4",
    array_forms(S4TransitiveSubgroups::S4.get_perm_group().elements()),
  ))

  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S5TransitiveSubgroups",
    "C5",
    array_forms(S5TransitiveSubgroups::C5.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S5TransitiveSubgroups",
    "D5",
    array_forms(S5TransitiveSubgroups::D5.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S5TransitiveSubgroups",
    "M20",
    array_forms(S5TransitiveSubgroups::M20.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S5TransitiveSubgroups",
    "A5",
    array_forms(S5TransitiveSubgroups::A5.get_perm_group().elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S5TransitiveSubgroups",
    "S5",
    array_forms(S5TransitiveSubgroups::S5.get_perm_group().elements()),
  ))
}

///|
test "combinatorics galois enum parity (S6 subset)" {
  let variants : Array[(String, S6TransitiveSubgroups)] = [
    ("C6", S6TransitiveSubgroups::C6),
    ("S3", S6TransitiveSubgroups::S3),
    ("D6", S6TransitiveSubgroups::D6),
    ("A4", S6TransitiveSubgroups::A4),
    ("G18", S6TransitiveSubgroups::G18),
    ("A4xC2", S6TransitiveSubgroups::A4xC2),
    ("S4m", S6TransitiveSubgroups::S4m),
    ("S4p", S6TransitiveSubgroups::S4p),
    ("G36m", S6TransitiveSubgroups::G36m),
    ("G36p", S6TransitiveSubgroups::G36p),
    ("S4xC2", S6TransitiveSubgroups::S4xC2),
    ("PSL2F5", S6TransitiveSubgroups::PSL2F5),
    ("G72", S6TransitiveSubgroups::G72),
    ("PGL2F5", S6TransitiveSubgroups::PGL2F5),
    ("A6", S6TransitiveSubgroups::A6),
    ("S6", S6TransitiveSubgroups::S6),
  ]
  for pair in variants {
    let (name, variant) = pair
    assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
      "S6TransitiveSubgroups",
      name,
      array_forms(variant.get_perm_group().elements()),
    ))
  }
}

///|
test "combinatorics galois find_transitive_subgroups_of_S6 basic" {
  let found = find_transitive_subgroups_of_S6([S6TransitiveSubgroups::C6, S6TransitiveSubgroups::S3])
  assert_eq(found.length(), 2)
  let (_, g1) = found[0]
  let (_, g2) = found[1]
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S6TransitiveSubgroups",
    "C6",
    array_forms(g1.elements()),
  ))
  assert_oracle(try? @sympy_combinatorics.galois_enum_group_elements_equiv(
    "S6TransitiveSubgroups",
    "S3",
    array_forms(g2.elements()),
  ))
}
