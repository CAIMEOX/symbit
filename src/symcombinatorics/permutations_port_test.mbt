///|
test "combinatorics permutation basic parity" {
  let p = Permutation::from_array([2, 0, 3, 1])
  assert_oracle(try? @sympy_combinatorics.perm_cyclic_form_equiv_from_array(
    [2, 0, 3, 1],
    p.cyclic_form(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_full_cyclic_form_equiv_from_array(
    [2, 0, 3, 1],
    p.full_cyclic_form(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_cycle_structure_equiv_from_array(
    [2, 0, 3, 1],
    p.cycle_structure_pairs(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_parity_equiv_from_array(
    [2, 0, 3, 1],
    p.parity(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_order_equiv_from_array(
    [2, 0, 3, 1],
    p.order(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_rank_equiv_from_array(
    [2, 0, 3, 1],
    p.rank(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_inversion_vector_equiv_from_array(
    [2, 0, 3, 1],
    p.inversion_vector(),
  ))
  assert_oracle(try? @sympy_combinatorics.perm_transpositions_equiv_from_array(
    [2, 0, 3, 1],
    p.transpositions(),
  ))
}

///|
test "combinatorics permutation from cycles and array form" {
  let p = Permutation::from_cycles([[1, 2], [2, 3]])
  assert_oracle(try? @sympy_combinatorics.perm_array_form_equiv_from_cycles(
    [[1, 2], [2, 3]],
    p.array_form(),
  ))
  let q = Permutation::from_array([1, 0], size=4)
  assert_oracle(try? @sympy_combinatorics.perm_array_form_equiv_from_array(
    [1, 0],
    q.array_form(),
    size=4,
  ))
}

///|
test "combinatorics permutation rank/unrank/next" {
  let p = Permutation::unrank_lex(5, 10)
  assert_oracle(try? @sympy_combinatorics.perm_unrank_lex_equiv(5, 10, p.array_form()))
  assert_oracle(try? @sympy_combinatorics.perm_rank_equiv_from_array(p.array_form(), p.rank()))
  match p.next_lex() {
    Some(nxt) =>
      assert_oracle(try? @sympy_combinatorics.perm_next_lex_equiv(
        p.array_form(),
        true,
        nxt.array_form(),
      ))
    None =>
      assert_oracle(try? @sympy_combinatorics.perm_next_lex_equiv(
        p.array_form(),
        false,
        [],
      ))
  }
}

///|
test "combinatorics permutation apply array and from_sequence" {
  let p = Permutation::from_array([1, 0, 2])
  let values : Array[String] = ["zero", "one", "two"]
  let applied = p.apply_array(values)
  assert_oracle(try? @sympy_combinatorics.perm_apply_array_equiv([1, 0, 2], values, applied))
  let seq_perm = Permutation::from_sequence_string("SymPy")
  assert_oracle(try? @sympy_combinatorics.perm_from_sequence_string_equiv(
    "SymPy",
    seq_perm.array_form(),
  ))
}
