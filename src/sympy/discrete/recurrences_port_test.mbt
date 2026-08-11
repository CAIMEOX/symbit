///|
test "discrete linrec parity" {
  let res0 = linrec(
    [@symcore.int(1), @symcore.int(1)],
    [@symcore.int(1), @symcore.int(1)],
    20,
  )
  assert_true(
    linrec_equiv(
      [@symcore.int(1), @symcore.int(1)],
      [@symcore.int(1), @symcore.int(1)],
      20,
      res0,
    ),
  )
  let res1 = linrec(
    [
      @symcore.int(1),
      @symcore.int(2),
      @symcore.int(3),
      @symcore.int(4),
      @symcore.int(5),
    ],
    [@symcore.int(1), @symcore.int(1), @symcore.int(0), @symcore.int(2)],
    10,
  )
  assert_true(
    linrec_equiv(
      [
        @symcore.int(1),
        @symcore.int(2),
        @symcore.int(3),
        @symcore.int(4),
        @symcore.int(5),
      ],
      [@symcore.int(1), @symcore.int(1), @symcore.int(0), @symcore.int(2)],
      10,
      res1,
    ),
  )
  let a = [
    rat(1, 2),
    rat(3, 4),
    rat(5, 6),
    @symcore.int(7),
    rat(8, 9),
    rat(3, 5),
  ]
  let b = [
    @symcore.int(1),
    @symcore.int(2),
    @symcore.int(8),
    rat(5, 7),
    rat(3, 7),
    rat(2, 9),
    @symcore.int(6),
  ]
  let a5 = a[:5].to_owned()
  let b4 = b[:4].to_owned()
  let res2 = linrec(a5, b4, 80)
  assert_true(linrec_equiv(a5, b4, 80, res2))
  let x = @symcore.Expr::Symbol("x")
  let y = @symcore.Expr::Symbol("y")
  let z = @symcore.Expr::Symbol("z")
  let res3 = linrec(
    [x, y, z],
    [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
    4,
  )
  assert_true(
    linrec_equiv(
      [x, y, z],
      [@symcore.int(1), @symcore.int(1), @symcore.int(1)],
      4,
      res3,
    ),
  )
  let res4 = linrec(
    [@symcore.int(1), @symcore.int(2), @symcore.int(1)],
    [x, y, z],
    20,
  )
  assert_true(
    linrec_equiv(
      [@symcore.int(1), @symcore.int(2), @symcore.int(1)],
      [x, y, z],
      20,
      res4,
    ),
  )
  let res5 = linrec(
    [@symcore.int(11), @symcore.int(13), @symcore.int(15), @symcore.int(17)],
    [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(4)],
    2000,
  )
  assert_true(
    linrec_equiv(
      [@symcore.int(11), @symcore.int(13), @symcore.int(15), @symcore.int(17)],
      [@symcore.int(1), @symcore.int(2), @symcore.int(3), @symcore.int(4)],
      2000,
      res5,
    ),
  )
  let res6 = linrec([], [@symcore.int(1), @symcore.int(1)], 20)
  assert_true(linrec_equiv([], [@symcore.int(1), @symcore.int(1)], 20, res6))
}

///|
test "discrete linrec errors" {
  let coeffs = [@symcore.int(1), @symcore.int(1)]
  let init = [@symcore.int(1), @symcore.int(2), @symcore.int(3)]
  expect_error(fn() raise { linrec(coeffs, init, 1) })
  expect_error(fn() raise {
    linrec(coeffs, [@symcore.int(1), @symcore.int(2)], -5)
  })
}
