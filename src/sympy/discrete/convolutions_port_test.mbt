///|
test "discrete convolution parity" {
  let a = [@symcore.int(1), rat(5, 3), sqrt_int(3), rat(7, 5)]
  let b = [
    @symcore.int(9),
    @symcore.int(5),
    @symcore.int(5),
    @symcore.int(4),
    @symcore.int(3),
    @symcore.int(2),
  ]
  let d = [
    @symcore.int(1422),
    @symcore.int(6572),
    @symcore.int(3213),
    @symcore.int(5552),
  ]
  let ours0 = convolution(a, b)
  assert_true(convolution_equiv(a, b, ours0), msg="convolution-default")
  let ours1 = convolution(a, b, dps=9)
  assert_true(convolution_equiv(a, b, ours1, dps=9), msg="convolution-dps9")
  let ours2 = convolution(a, d, dps=7)
  assert_true(convolution_equiv(a, d, ours2, dps=7), msg="convolution-dps7")
  let d_tail = d[1:].to_owned()
  let ours3 = convolution(a, d_tail, dps=3)
  assert_true(
    convolution_equiv(a, d_tail, ours3, dps=3),
    msg="convolution-dps3",
  )
  let q = 19 * (1 << 10) + 1
  let d_int = [@symcore.int(111), @symcore.int(777)]
  let b_int = [@symcore.int(888), @symcore.int(444)]
  let ours4 = convolution(d_int, b_int, prime=q)
  assert_true(
    convolution_equiv(d_int, b_int, ours4, prime=q),
    msg="convolution-prime",
  )
  let ours5 = convolution(a, b, dyadic=true)
  assert_true(
    convolution_equiv(a, b, ours5, dyadic=true),
    msg="convolution-dyadic",
  )
  let ours6 = convolution(a, b, subset=true)
  assert_true(
    convolution_equiv(a, b, ours6, subset=true),
    msg="convolution-subset",
  )
  let cyc = convolution(
    [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
    [@symcore.int(4), @symcore.int(5), @symcore.int(6)],
    cycle=3,
  )
  assert_true(
    convolution_equiv(
      [@symcore.int(1), @symcore.int(2), @symcore.int(3)],
      [@symcore.int(4), @symcore.int(5), @symcore.int(6)],
      cyc,
      cycle=3,
    ),
    msg="convolution-cycle",
  )
  expect_error(fn() raise { convolution(b, d, dps=5, prime=q) })
}

///|
test "discrete convolution functions parity" {
  let a = [@symcore.int(1), @symcore.int(2), @symcore.int(3)]
  let b = [@symcore.int(4), @symcore.int(5), @symcore.int(6)]
  let ours_fft = convolution_fft(a, b)
  assert_true(convolution_fft_equiv(a, b, ours_fft), msg="convolution_fft")
  let p = 19 * (1 << 10) + 1
  let ours_ntt = convolution_ntt(
    [@symcore.int(2313), @symcore.int(5323532)],
    [@symcore.int(888), @symcore.int(444)],
    p,
  )
  assert_true(
    convolution_ntt_equiv(
      [@symcore.int(2313), @symcore.int(5323532)],
      [@symcore.int(888), @symcore.int(444)],
      ours_ntt,
      p,
    ),
    msg="convolution_ntt",
  )
  let u = @symcore.Expr::Symbol("u")
  let v = @symcore.Expr::Symbol("v")
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let ours_fwht = convolution_fwht([u, v], [x, y])
  assert_true(
    convolution_fwht_equiv([u, v], [x, y], ours_fwht),
    msg="convolution_fwht",
  )
  let ours_subset = convolution_subset([u, v, x], [y, Symbol("z")])
  assert_true(
    convolution_subset_equiv([u, v, x], [y, Symbol("z")], ours_subset),
    msg="convolution_subset",
  )
  let ours_cover = covering_product([u, v, x], [y, Symbol("z")])
  assert_true(
    covering_product_equiv([u, v, x], [y, Symbol("z")], ours_cover),
    msg="covering_product",
  )
  let ours_inter = intersecting_product([u, v, x], [y, Symbol("z")])
  assert_true(
    intersecting_product_equiv([u, v, x], [y, Symbol("z")], ours_inter),
    msg="intersecting_product",
  )
}

///|
test "discrete convolution_int parity" {
  let a = [1, 2, 3]
  let b = [4, 5, 6]
  let ours = convolution_int(a, b)
  assert_true(convolution_int_equiv(a, b, ours), msg="convolution_int")
}
