///|
test "combinatorics graycode parity" {
  let g = GrayCode::new(3)
  let seq = g.generate_gray()
  assert_oracle(try? @sympy_combinatorics.graycode_generate_equiv(3, seq))

  let seq2 = GrayCode::new(4, rank=4).generate_gray()
  assert_oracle(try? @sympy_combinatorics.graycode_generate_equiv(4, seq2, rank=4))

  let seq3 = GrayCode::new(4, start="0011").generate_gray()
  assert_oracle(try? @sympy_combinatorics.graycode_generate_equiv(4, seq3, start="0011"))

  assert_oracle(try? @sympy_combinatorics.graycode_rank_equiv(3, "100", GrayCode::new(3, start="100").rank()))
  assert_oracle(try? @sympy_combinatorics.gray_to_bin_equiv("100", gray_to_bin("100")))
  assert_oracle(try? @sympy_combinatorics.bin_to_gray_equiv("111", bin_to_gray("111")))

  let subset_items = [1, 2, 3]
  let subsets = graycode_subsets(subset_items)
  assert_oracle(try? @sympy_combinatorics.graycode_subsets_equiv(subset_items, subsets))
}
