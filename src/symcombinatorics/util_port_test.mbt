///|
test "util base_ordering" {
  let base = [2, 4, 5]
  let ours = _base_ordering(base, 7)
  assert_true(@sympy_combinatorics.util_base_ordering_equiv(base, 7, ours))
}

///|
test "util check_cycles_alt_sym" {
  let perm1 = Permutation::from_cycles([[0, 1, 2, 3, 4, 5, 6], [7], [8], [9]])
  let perm2 = Permutation::from_cycles([[0, 1, 2, 3, 4, 5], [6, 7, 8, 9]])
  let perm3 = Permutation::from_cycles([[0, 1, 2, 3, 4], [5, 6, 7, 8, 9]])
  let res1 = _check_cycles_alt_sym(perm1)
  let res2 = _check_cycles_alt_sym(perm2)
  let res3 = _check_cycles_alt_sym(perm3)
  assert_true(@sympy_combinatorics.util_check_cycles_alt_sym_equiv(perm1.array_form(), res1))
  assert_true(@sympy_combinatorics.util_check_cycles_alt_sym_equiv(perm2.array_form(), res2))
  assert_true(@sympy_combinatorics.util_check_cycles_alt_sym_equiv(perm3.array_form(), res3))
}

///|
test "util distribute_gens_by_base" {
  let base = [0, 1, 2]
  let gens_arrays : Array[Array[Int]] = [
    [0, 1, 2, 3],
    [0, 1, 3, 2],
    [0, 2, 3, 1],
    [3, 2, 1, 0],
  ]
  let gens : Array[Permutation] = Array::new()
  for arr in gens_arrays {
    gens.push(Permutation::from_array(arr))
  }
  let res = _distribute_gens_by_base(base, gens)
  let res_arrays : Array[Array[Array[Int]]] = Array::new()
  for part in res {
    let inner : Array[Array[Int]] = Array::new()
    for g in part {
      inner.push(g.array_form())
    }
    res_arrays.push(inner)
  }
  assert_true(@sympy_combinatorics.util_distribute_gens_by_base_equiv(base, gens_arrays, res_arrays))
}

///|
test "util strong_gens_from_distr" {
  let distr_arrays : Array[Array[Array[Int]]] = [
    [[0, 2, 1], [1, 2, 0], [1, 0, 2]],
    [[0, 2, 1]],
  ]
  let distr : Array[Array[Permutation]] = Array::new()
  for part in distr_arrays {
    let inner : Array[Permutation] = Array::new()
    for arr in part {
      inner.push(Permutation::from_array(arr))
    }
    distr.push(inner)
  }
  let res = _strong_gens_from_distr(distr)
  let res_arrays : Array[Array[Int]] = Array::new()
  for g in res {
    res_arrays.push(g.array_form())
  }
  assert_true(@sympy_combinatorics.util_strong_gens_from_distr_equiv(distr_arrays, res_arrays))
}
