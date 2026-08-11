///|
test "discrete fft/ifft parity" {
  let seq0 : Array[Expr] = []
  assert_true(fft_equiv(seq0, fft(seq0)))
  assert_true(ifft_equiv(seq0, ifft(seq0)))
  let seq1 = [rat(5, 3)]
  assert_true(fft_equiv(seq1, fft(seq1)))
  assert_true(ifft_equiv(seq1, ifft(seq1)))
  let seq2 = [
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
    @symcore.int(5),
  ]
  assert_true(fft_equiv(seq2, fft(seq2)))
  let seq3 = [
    complex(@symcore.int(1), @symcore.int(2)),
    complex(@symcore.int(3), @symcore.int(4)),
    complex(@symcore.int(5), @symcore.int(6)),
  ]
  assert_true(ifft_equiv(seq3, ifft(seq3)))
  assert_true(fft_equiv(seq3, fft(seq3)))
  let seq4 = [
    @symcore.int(1),
    @symcore.int(7),
    @symcore.int(3),
    @symcore.int(4),
  ]
  assert_true(ifft_equiv(seq4, ifft(seq4, dps=15), dps=15))
  let x = @symcore.Expr::Symbol("x")
  let seq_sym = [
    x,
    @symcore.mul([@symcore.int(2), x]),
    @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(2))]),
    @symcore.mul([@symcore.int(4), @symcore.pow(x, @symcore.int(3))]),
  ]
  expect_error(fn() raise { ifft(seq_sym) })
}

///|
test "discrete ntt/intt parity" {
  let p = 7 * 17 * (1 << 23) + 1
  let q = 2 * 500000003 + 1
  let r = 2 * 3 * 5 * 7
  let seq0 : Array[Expr] = []
  assert_true(ntt_equiv(seq0, ntt(seq0, p), p), msg="ntt-empty")
  let seq1 = [@symcore.int(5)]
  assert_true(ntt_equiv(seq1, ntt(seq1, p), p), msg="ntt-single")
  let seq2 = [
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
    @symcore.int(5),
  ]
  assert_true(ntt_equiv(seq2, ntt(seq2, p), p), msg="ntt-seq2")
  let nls = [
    @symcore.int(15),
    @symcore.int(801133602),
    @symcore.int(738493201),
    @symcore.int(334102277),
    @symcore.int(998244350),
    @symcore.int(849020224),
    @symcore.int(259751156),
    @symcore.int(12232587),
  ]
  assert_true(intt_equiv(nls, intt(nls, p), p), msg="intt-nls")
  let nonint = [sqrt_int(2), @symcore.int(3)]
  expect_error(fn() raise { ntt(nonint, p) })
  expect_error(fn() raise { ntt(seq2, r) })
  expect_error(fn() raise {
    ntt([@symcore.int(3), @symcore.int(5), @symcore.int(6)], q)
  })
}

///|
test "discrete fwht/ifwht parity" {
  let seq1 = [
    @symcore.int(213),
    @symcore.int(321),
    @symcore.int(43235),
    @symcore.int(5325),
    @symcore.int(312),
    @symcore.int(53),
  ]
  assert_true(fwht_equiv(seq1, fwht(seq1)))
  let fw1 = fwht(seq1)
  assert_true(ifwht_equiv(fw1, ifwht(fw1)))
  let seq2 = [
    complex(rat(1, 2), @symcore.int(2)),
    complex(rat(3, 7), @symcore.int(4)),
    complex(rat(5, 6), @symcore.int(6)),
    @symcore.int(7),
    rat(9, 4),
  ]
  assert_true(ifwht_equiv(seq2, ifwht(seq2)))
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let seq3 = [
    x,
    y,
    @symcore.pow(x, @symcore.int(2)),
    @symcore.pow(y, @symcore.int(2)),
    @symcore.mul([x, y]),
  ]
  assert_true(fwht_equiv(seq3, fwht(seq3)))
}

///|
test "discrete mobius parity" {
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let w = @symcore.Expr::Symbol("w")
  let z = @symcore.Expr::Symbol("z")
  let seq1 = [x, y]
  assert_true(mobius_transform_equiv(seq1, mobius_transform(seq1)))
  let seq2 = [w, x, y, z]
  assert_true(mobius_transform_equiv(seq2, mobius_transform(seq2)))
  assert_true(
    mobius_transform_equiv(
      seq2,
      mobius_transform(seq2, subset=false),
      subset=false,
    ),
  )
  let seq3 = [
    rat(2, 3),
    rat(6, 7),
    rat(5, 8),
    @symcore.int(9),
    complex(rat(5, 3), @symcore.int(7)),
  ]
  assert_true(mobius_transform_equiv(seq3, mobius_transform(seq3)))
  let mt = mobius_transform(seq3, subset=false)
  assert_true(
    inverse_mobius_transform_equiv(
      mt,
      inverse_mobius_transform(mt, subset=false),
      subset=false,
    ),
  )
}
