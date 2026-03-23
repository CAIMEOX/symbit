///|
test "dps precision helpers follow mpmath formulas" {
  assert_eq(dps_to_prec(15), 53)
  assert_eq(prec_to_dps(53), 15)
  assert_eq(repr_dps(53), 17)
  assert_eq(giant_steps(50, 1000), [66, 128, 253, 502, 1000])
}

///|
test "rational and float conversions roundtrip" {
  let three_eighths = from_rational(3N, 8N, 80)
  assert_eq(to_rational(three_eighths), (3N, 8N))
  let eighth = from_float(0.125)
  assert_eq(to_rational(eighth), (1N, 8N))
  assert_eq(to_float(eighth), 0.125)
}

///|
test "to_int honors directed rounding" {
  let x = from_rational(7N, 2N, 80)
  assert_eq(to_int(x), 3N)
  assert_eq(to_int(x, rnd=round_ceiling), 4N)
  let y = from_rational(-7N, 2N, 80)
  assert_eq(to_int(y), -3N)
  assert_eq(to_int(y, rnd=round_floor), -4N)
}

///|
test "context wrappers expose root finding and integration" {
  let root = findroot(
    x => {
      mpf_sub(
        mpf_mul(x, x, 120, round_nearest),
        from_int(2),
        120,
        round_nearest,
      )
    },
    from_int(1),
    x1=from_int(2),
    prec=100,
  )
  let root_sq = mpf_mul(root, root, 100, round_nearest)
  let diff0 = mpf_abs(
    mpf_sub(root_sq, from_int(2), 100, round_nearest),
    100,
    round_nearest,
  )
  assert_true(
    mpf_lt(diff0, from_str("1e-20", prec=100) catch { _ => fail("tol") }),
  )

  let area = quadts(x => x, from_int(0), from_int(1), prec=100)
  assert_eq(to_rational(area), (1N, 2N))
}

///|
test "interval context parses and combines intervals" {
  let ictx = interval_context(80)
  let a = ictx.make_float("[1.0, 2.0]")
  let b = ictx.make_interval(from_int(2), from_int(3))
  let c = ictx.add(a, b)
  let text = ictx.to_string(c, dps=20)
  assert_true(text.contains("[3.0"))
}
