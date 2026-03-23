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

///|
test "compat surface exposes sqrt factorial and matrix helpers" {
  let root2 = sqrt(from_int(2), prec=100)
  let root2_sq = mpf_mul(root2, root2, 100, round_nearest)
  let diff0 = mpf_abs(
    mpf_sub(root2_sq, from_int(2), 100, round_nearest),
    100,
    round_nearest,
  )
  assert_true(
    mpf_lt(diff0, from_str("1e-20", prec=100) catch { _ => fail("tol") }),
  )

  let fac5 = fac(from_int(5), prec=120) catch { _ => fail("fac") }
  assert_eq(to_rational(fac5), (120N, 1N))

  let (ch, sh) = mpf_cosh_sinh(fzero, 80, round_nearest)
  assert_eq(ch, fone)
  assert_eq(sh, fzero)

  let mat = _matrix([[from_int(1), from_int(2)], [from_int(3), from_int(4)]]) catch {
    _ => fail("matrix")
  }
  inspect(
    mat
    .tolist()
    .map(row => row.map(x => to_rational(x) catch { _ => fail("rat") })),
    content="[[(1, 1), (2, 1)], [(3, 1), (4, 1)]]",
  )
}

///|
test "fixed constants reconstruct high precision values" {
  let prec = 80
  let phi_bits = phi_fixed(prec) catch { _ => fail("phi_fixed") }
  let phi = from_man_exp(phi_bits, -prec)
  let sqrt5 = sqrt(from_int(5), prec=120) catch { _ => fail("sqrt5") }
  let expected_phi = mpf_shift(
    mpf_add(sqrt5, from_int(1), 120, round_nearest),
    -1,
  )
  let phi_err = mpf_abs(
    mpf_sub(phi, expected_phi, 120, round_nearest),
    120,
    round_nearest,
  )
  assert_true(
    mpf_lt(phi_err, from_str("1e-20", prec=120) catch { _ => fail("tol") }),
  )

  let euler_bits = euler_fixed(prec) catch { _ => fail("euler_fixed") }
  let catalan_bits = catalan_fixed(prec) catch { _ => fail("catalan_fixed") }
  assert_true(euler_bits > 0N)
  assert_true(catalan_bits > 0N)
}
