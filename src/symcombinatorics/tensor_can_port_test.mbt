///|
fn range_array(start : Int, end : Int) -> Array[Int] {
  let out : Array[Int] = Array::new()
  let mut i = start
  while i < end {
    out.push(i)
    i = i + 1
  }
  out
}

///|
test "tensor_can dummy_sgs parity" {
  let dummies = [2, 3, 4, 5, 6, 7]
  let res = dummy_sgs(dummies, Some(0), 8)
  assert_oracle(try? @sympy_combinatorics.tensor_can_dummy_sgs_equiv(
    dummies,
    Some(0),
    8,
    res,
  ))
}

///|
test "tensor_can min_dummies parity" {
  let dummies = [[2, 3, 4, 5, 6, 7]]
  let sym = [Some(0)]
  let indices = range_array(0, 10)
  let res = _min_dummies(dummies, sym, indices)
  assert_oracle(try? @sympy_combinatorics.tensor_can_min_dummies_equiv(
    dummies,
    sym,
    indices,
    res,
  ))
}

///|
test "tensor_can symmetric group sgs parity" {
  let (base0, gens0) = get_symmetric_group_sgs(3)
  assert_oracle(try? @sympy_combinatorics.tensor_can_symmetric_group_equiv(
    3,
    false,
    base0,
    array_forms(gens0),
  ))
  let (base1, gens1) = get_symmetric_group_sgs(3, antisym=true)
  assert_oracle(try? @sympy_combinatorics.tensor_can_symmetric_group_equiv(
    3,
    true,
    base1,
    array_forms(gens1),
  ))
}

///|
test "tensor_can perm_af_direct_product parity" {
  let gens1 = [[1, 0, 2, 3], [0, 1, 3, 2]]
  let gens2 = [[1, 0]]
  let res = perm_af_direct_product(gens1, gens2, signed=false)
  assert_oracle(try? @sympy_combinatorics.tensor_can_perm_af_direct_product_equiv(
    gens1,
    gens2,
    false,
    res,
  ))
  let gens1b = [[1, 0, 2, 3, 5, 4], [0, 1, 3, 2, 4, 5]]
  let gens2b = [[1, 0, 2, 3]]
  let res2 = perm_af_direct_product(gens1b, gens2b, signed=true)
  assert_oracle(try? @sympy_combinatorics.tensor_can_perm_af_direct_product_equiv(
    gens1b,
    gens2b,
    true,
    res2,
  ))
}

///|
test "tensor_can bsgs_direct_product parity" {
  let (base1, gens1) = get_symmetric_group_sgs(1)
  let (base2, gens2) = get_symmetric_group_sgs(2)
  let (base, gens) = bsgs_direct_product(base1, gens1, base2, gens2, signed=true)
  assert_oracle(try? @sympy_combinatorics.tensor_can_bsgs_direct_product_equiv(
    base1,
    array_forms(gens1),
    base2,
    array_forms(gens2),
    true,
    base,
    array_forms(gens),
  ))
}

///|
test "tensor_can tensor_gens parity" {
  let (base, gens) = get_symmetric_group_sgs(3)
  let (size0, res_base0, res_gens0) = tensor_gens(base, gens, [[], []], sym=Some(0))
  assert_oracle(try? @sympy_combinatorics.tensor_can_tensor_gens_equiv(
    base,
    array_forms(gens),
    [[], []],
    Some(0),
    size0,
    res_base0,
    array_forms(res_gens0),
  ))
  let (size1, res_base1, res_gens1) = tensor_gens(base, gens, [[1], [0]], sym=Some(0))
  assert_oracle(try? @sympy_combinatorics.tensor_can_tensor_gens_equiv(
    base,
    array_forms(gens),
    [[1], [0]],
    Some(0),
    size1,
    res_base1,
    array_forms(res_gens1),
  ))
  let (base2a, gens2a) = get_symmetric_group_sgs(2, antisym=true)
  let (size2, res_base2, res_gens2) = tensor_gens(base2a, gens2a, [[], []], sym=Some(1))
  assert_oracle(try? @sympy_combinatorics.tensor_can_tensor_gens_equiv(
    base2a,
    array_forms(gens2a),
    [[], []],
    Some(1),
    size2,
    res_base2,
    array_forms(res_gens2),
  ))
}

///|
test "tensor_can canonical_free parity" {
  let gens = [
    Permutation::from_array([1, 0, 2, 3, 5, 4]),
    Permutation::from_array([2, 3, 0, 1, 4, 5]),
    Permutation::from_array([0, 1, 3, 2, 5, 4]),
  ]
  let base = [0, 2]
  let g = Permutation::from_array([2, 1, 0, 3, 4, 5])
  let res = canonical_free(base, gens, g, 4)
  assert_oracle(try? @sympy_combinatorics.tensor_can_canonical_free_equiv(
    base,
    array_forms(gens),
    g.array_form(),
    4,
    res,
  ))
}

///|
test "tensor_can double_coset_can_rep parity" {
  let gens = [
    Permutation::from_array([2, 1, 0, 3, 4, 5, 7, 6]),
    Permutation::from_array([4, 1, 2, 3, 0, 5, 7, 6]),
  ]
  let base = [0, 2]
  let transv = get_transversals(base, gens)
  let dummies = [range_array(0, 6)]
  let sym = [Some(0)]
  let g1 = Permutation::from_array([4, 2, 0, 1, 3, 5, 6, 7])
  let res1 = double_coset_can_rep(dummies, sym, base, gens, transv, g1)
  assert_oracle(try? @sympy_combinatorics.tensor_can_double_coset_can_rep_equiv(
    dummies,
    sym,
    base,
    array_forms(gens),
    g1.array_form(),
    res1,
  ))
  let g2 = Permutation::from_array([4, 1, 3, 0, 5, 2, 6, 7])
  let res2 = double_coset_can_rep(dummies, sym, base, gens, transv, g2)
  assert_oracle(try? @sympy_combinatorics.tensor_can_double_coset_can_rep_equiv(
    dummies,
    sym,
    base,
    array_forms(gens),
    g2.array_form(),
    res2,
  ))
}

///|
test "tensor_can double_coset_can_rep parity (anticommuting canonicalize case)" {
  let (base2a, gens2a) = get_symmetric_group_sgs(2, antisym=true)
  let (size0, base0, gens0) = tensor_gens(base2a, gens2a, [[]], sym=Some(0))
  let (size1, base1, gens1) = tensor_gens(base2a, gens2a, [[], []], sym=Some(1))
  let (sbase, sgens) = bsgs_direct_product(base0, gens0, base1, gens1, signed=true)
  let g = Permutation::from_array([1, 3, 0, 5, 4, 2, 6, 7])
  let dummies = [range_array(0, 6)]
  let sym = [Some(0)]
  let transv = get_transversals(sbase, sgens)
  let res = double_coset_can_rep(dummies, sym, sbase, sgens, transv, g)
  ignore(size0)
  ignore(size1)
  assert_oracle(try? @sympy_combinatorics.tensor_can_double_coset_can_rep_equiv(
    dummies,
    sym,
    sbase,
    array_forms(sgens),
    g.array_form(),
    res,
  ))
}

///|
test "tensor_can canonicalize parity (commuting)" {
  let (base2a, gens2a) = get_symmetric_group_sgs(2, antisym=true)
  let t0 = TensorComponent::{ base: base2a, gens: gens2a, count: 1, sym: Some(0) }
  let t1 = TensorComponent::{ base: base2a, gens: gens2a, count: 2, sym: Some(0) }
  let dummies = [range_array(0, 6)]
  let msym = [Some(0)]
  let g = Permutation::from_array([1, 3, 0, 5, 4, 2, 6, 7])
  let res = canonicalize(g, dummies, msym, [t0, t1])
  assert_oracle(try? @sympy_combinatorics.tensor_can_canonicalize_equiv(
    dummies,
    msym,
    g.array_form(),
    [base2a, base2a],
    [array_forms(gens2a), array_forms(gens2a)],
    [1, 2],
    [Some(0), Some(0)],
    res,
  ))
}

///|
test "tensor_can canonicalize parity (anticommuting)" {
  let (base2a, gens2a) = get_symmetric_group_sgs(2, antisym=true)
  let t0 = TensorComponent::{ base: base2a, gens: gens2a, count: 1, sym: Some(0) }
  let t1a = TensorComponent::{ base: base2a, gens: gens2a, count: 2, sym: Some(1) }
  let dummies = [range_array(0, 6)]
  let msym = [Some(0)]
  let g = Permutation::from_array([1, 3, 0, 5, 4, 2, 6, 7])
  let res2 = canonicalize(g, dummies, msym, [t0, t1a])
  assert_oracle(try? @sympy_combinatorics.tensor_can_canonicalize_equiv(
    dummies,
    msym,
    g.array_form(),
    [base2a, base2a],
    [array_forms(gens2a), array_forms(gens2a)],
    [1, 2],
    [Some(0), Some(1)],
    res2,
  ))
}
