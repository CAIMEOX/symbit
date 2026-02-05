///|
test "discrete fft/ifft parity" {
  let seq0 : Array[Expr] = []
  assert_oracle(try? @sympy_discrete.fft_equiv(seq0, fft(seq0)))
  assert_oracle(try? @sympy_discrete.ifft_equiv(seq0, ifft(seq0)))
  let seq1 = [rat(5, 3)]
  assert_oracle(try? @sympy_discrete.fft_equiv(seq1, fft(seq1)))
  assert_oracle(try? @sympy_discrete.ifft_equiv(seq1, ifft(seq1)))
  let seq2 = [
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
    @symcore.int(5),
  ]
  assert_oracle(try? @sympy_discrete.fft_equiv(seq2, fft(seq2)))
  let seq3 = [
    complex(@symcore.int(1), @symcore.int(2)),
    complex(@symcore.int(3), @symcore.int(4)),
    complex(@symcore.int(5), @symcore.int(6)),
  ]
  assert_oracle(try? @sympy_discrete.ifft_equiv(seq3, ifft(seq3)))
  assert_oracle(try? @sympy_discrete.fft_equiv(seq3, fft(seq3)))
  let seq4 = [
    @symcore.int(1),
    @symcore.int(7),
    @symcore.int(3),
    @symcore.int(4),
  ]
  assert_oracle(
    try? @sympy_discrete.ifft_equiv(seq4, ifft(seq4, dps=15), dps=15),
  )
  let x = @symcore.symbol("x")
  let seq_sym = [
    x,
    @symcore.mul([@symcore.int(2), x]),
    @symcore.mul([@symcore.int(3), @symcore.pow(x, @symcore.int(2))]),
    @symcore.mul([@symcore.int(4), @symcore.pow(x, @symcore.int(3))]),
  ]
  let bad : Result[Array[Expr], Error] = try? ifft(seq_sym)
  guard bad is Err(_) else { fail("expected fft symbol error") }
}

///|
test "discrete ntt/intt parity" {
  let p = 7 * 17 * (1 << 23) + 1
  let q = 2 * 500000003 + 1
  let r = 2 * 3 * 5 * 7
  let seq0 : Array[Expr] = []
  assert_oracle_named(
    "ntt-empty",
    try? @sympy_discrete.ntt_equiv(seq0, ntt(seq0, p), p),
  )
  let seq1 = [@symcore.int(5)]
  assert_oracle_named(
    "ntt-single",
    try? @sympy_discrete.ntt_equiv(seq1, ntt(seq1, p), p),
  )
  let seq2 = [
    @symcore.int(0),
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(3),
    @symcore.int(4),
    @symcore.int(5),
  ]
  assert_oracle_named(
    "ntt-seq2",
    try? @sympy_discrete.ntt_equiv(seq2, ntt(seq2, p), p),
  )
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
  assert_oracle_named(
    "intt-nls",
    try? @sympy_discrete.intt_equiv(nls, intt(nls, p), p),
  )
  let nonint = [sqrt_int(2), @symcore.int(3)]
  let bad0 : Result[Array[Expr], Error] = try? ntt(nonint, p)
  guard bad0 is Err(_) else { fail("expected non-integer error") }
  let bad1 : Result[Array[Expr], Error] = try? ntt(seq2, r)
  guard bad1 is Err(_) else { fail("expected composite modulus error") }
  let bad2 : Result[Array[Expr], Error] = try? ntt(
    [@symcore.int(3), @symcore.int(5), @symcore.int(6)],
    q,
  )
  guard bad2 is Err(_) else { fail("expected invalid modulus error") }
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
  assert_oracle(try? @sympy_discrete.fwht_equiv(seq1, fwht(seq1)))
  let fw1 = fwht(seq1)
  assert_oracle(try? @sympy_discrete.ifwht_equiv(fw1, ifwht(fw1)))
  let seq2 = [
    complex(rat(1, 2), @symcore.int(2)),
    complex(rat(3, 7), @symcore.int(4)),
    complex(rat(5, 6), @symcore.int(6)),
    @symcore.int(7),
    rat(9, 4),
  ]
  assert_oracle(try? @sympy_discrete.ifwht_equiv(seq2, ifwht(seq2)))
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let seq3 = [
    x,
    y,
    @symcore.pow(x, @symcore.int(2)),
    @symcore.pow(y, @symcore.int(2)),
    @symcore.mul([x, y]),
  ]
  assert_oracle(try? @sympy_discrete.fwht_equiv(seq3, fwht(seq3)))
}

///|
test "discrete mobius parity" {
  let x = @symcore.symbol("x")
  let y = @symcore.symbol("y")
  let w = @symcore.symbol("w")
  let z = @symcore.symbol("z")
  let seq1 = [x, y]
  assert_oracle(
    try? @sympy_discrete.mobius_transform_equiv(seq1, mobius_transform(seq1)),
  )
  let seq2 = [w, x, y, z]
  assert_oracle(
    try? @sympy_discrete.mobius_transform_equiv(seq2, mobius_transform(seq2)),
  )
  assert_oracle(
    try? @sympy_discrete.mobius_transform_equiv(
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
  assert_oracle(
    try? @sympy_discrete.mobius_transform_equiv(seq3, mobius_transform(seq3)),
  )
  let mt = mobius_transform(seq3, subset=false)
  assert_oracle(
    try? @sympy_discrete.inverse_mobius_transform_equiv(
      mt,
      inverse_mobius_transform(mt, subset=false),
      subset=false,
    ),
  )
}
