///|
test "discrete convolution parity" {
  let a = [@symcore.int(1), rat(5, 3), sqrt_int(3), rat(7, 5)]
  let b = [@symcore.int(9), @symcore.int(5), @symcore.int(5), @symcore.int(4), @symcore.int(3), @symcore.int(2)]
  let d = [@symcore.int(1422), @symcore.int(6572), @symcore.int(3213), @symcore.int(5552)]

  let ours0 = convolution(a, b)
  assert_oracle_named("convolution-default", try? @sympy_discrete.convolution_equiv(a, b, ours0))

  let ours1 = convolution(a, b, dps=9)
  assert_oracle_named("convolution-dps9", try? @sympy_discrete.convolution_equiv(a, b, ours1, dps=9))

  let ours2 = convolution(a, d, dps=7)
  assert_oracle_named("convolution-dps7", try? @sympy_discrete.convolution_equiv(a, d, ours2, dps=7))

  let d_tail = d[1:].to_array()
  let ours3 = convolution(a, d_tail, dps=3)
  assert_oracle_named("convolution-dps3", try? @sympy_discrete.convolution_equiv(a, d_tail, ours3, dps=3))
  let q = 19 * (1 << 10) + 1
  let d_int = [@symcore.int(111), @symcore.int(777)]
  let b_int = [@symcore.int(888), @symcore.int(444)]
  let ours4 = convolution(d_int, b_int, prime=q)
  assert_oracle_named("convolution-prime", try? @sympy_discrete.convolution_equiv(d_int, b_int, ours4, prime=q))

  let ours5 = convolution(a, b, dyadic=true)
  assert_oracle_named("convolution-dyadic", try? @sympy_discrete.convolution_equiv(a, b, ours5, dyadic=true))

  let ours6 = convolution(a, b, subset=true)
  assert_oracle_named("convolution-subset", try? @sympy_discrete.convolution_equiv(a, b, ours6, subset=true))

  let cyc = convolution([@symcore.int(1), @symcore.int(2), @symcore.int(3)], [@symcore.int(4), @symcore.int(5), @symcore.int(6)], cycle=3)
  assert_oracle_named("convolution-cycle", try? @sympy_discrete.convolution_equiv([@symcore.int(1), @symcore.int(2), @symcore.int(3)], [@symcore.int(4), @symcore.int(5), @symcore.int(6)], cyc, cycle=3))

  let bad0 : Result[Array[Expr], Error] = try? convolution(b, d, dps=5, prime=q)
  guard bad0 is Err(_) else { fail("expected ambiguous hint error") }
}

///|
test "discrete convolution functions parity" {
  let a = [@symcore.int(1), @symcore.int(2), @symcore.int(3)]
  let b = [@symcore.int(4), @symcore.int(5), @symcore.int(6)]
  let ours_fft = convolution_fft(a, b)
  assert_oracle_named("convolution_fft", try? @sympy_discrete.convolution_fft_equiv(a, b, ours_fft))

  let p = 19 * (1 << 10) + 1
  let ours_ntt = convolution_ntt([@symcore.int(2313), @symcore.int(5323532)], [@symcore.int(888), @symcore.int(444)], p)
  assert_oracle_named("convolution_ntt", try? @sympy_discrete.convolution_ntt_equiv([@symcore.int(2313), @symcore.int(5323532)], [@symcore.int(888), @symcore.int(444)], ours_ntt, p))

  let u = @symcore.symbol("u")
  let v = @symcore.symbol("v")
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let ours_fwht = convolution_fwht([u, v], [x, y])
  assert_oracle_named("convolution_fwht", try? @sympy_discrete.convolution_fwht_equiv([u, v], [x, y], ours_fwht))

  let ours_subset = convolution_subset([u, v, x], [y, @symcore.symbol("z")])
  assert_oracle_named("convolution_subset", try? @sympy_discrete.convolution_subset_equiv([u, v, x], [y, @symcore.symbol("z")], ours_subset))

  let ours_cover = covering_product([u, v, x], [y, @symcore.symbol("z")])
  assert_oracle_named("covering_product", try? @sympy_discrete.covering_product_equiv([u, v, x], [y, @symcore.symbol("z")], ours_cover))

  let ours_inter = intersecting_product([u, v, x], [y, @symcore.symbol("z")])
  assert_oracle_named("intersecting_product", try? @sympy_discrete.intersecting_product_equiv([u, v, x], [y, @symcore.symbol("z")], ours_inter))
}

///|
test "discrete convolution_int parity" {
  let a = [1, 2, 3]
  let b = [4, 5, 6]
  let ours = convolution_int(a, b)
  assert_oracle_named("convolution_int", try? @sympy_discrete.convolution_int_equiv(a, b, ours))
}
