///|
fn units_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  _context : String,
) -> Unit raise {
  let ours = @symprint.pretty_string(lhs)
  assert_true(expr_equal(ours, rhs))
}

///|
test "physics.units: prefix arithmetic and quantity derivation" {
  assert_eq(milli.mul_prefix(kilo).to_string(), "1")
  assert_eq(kilo.mul_prefix(kilo).to_string(), "M")
  assert_eq(milli.rdiv_one().to_string(), "k")
  assert_eq(kilo.div_prefix(milli).to_string(), "M")

  let dodeca = prefix("dodeca", "dd", 1, base=12)
  assert_eq(dodeca.mul_prefix(dodeca).to_string(), "144")
  assert_eq(dodeca.rdiv_one().to_string(), "1/12")

  units_assert_expr_equal(milli.mul_quantity(watt), "watt/1000", "milli*watt")
  units_assert_expr_equal(
    dodeca.mul_quantity(meter),
    "12*meter",
    "dodeca*meter",
  )

  let fake_meter = quantity("fake_meter", abbrev="m", dimension=length)
  let pref : Map[String, Prefix] = { "m": milli, "c": centi, "d": deci }
  let derived = prefix_unit(fake_meter, pref)
  assert_eq(derived.length(), 3)
  assert_true(
    derived[0].name == "millifake_meter" &&
    derived[1].name == "centifake_meter" &&
    derived[2].name == "decifake_meter",
  )
  assert_true(
    derived[0].abbrev == "mm" &&
    derived[1].abbrev == "cm" &&
    derived[2].abbrev == "dm",
  )
}

///|
test "physics.units: constants and dimensions" {
  assert_eq(kilo.base, 10)
  assert_eq(kibi.base, 2)
  let doubled_length = length.add(length)
  assert_true(doubled_length == length)
  let velocity = length.div(time_dimension)
  inspect(@symprint.pretty_string(velocity.name), content="time**-1*length")
  units_assert_expr_equal(
    speed_of_light, "299792458*meter/second", "speed_of_light",
  )
  units_assert_expr_equal(
    u0, "pi*kilogram*meter/(2500000*ampere**2*second**2)", "u0",
  )
  units_assert_expr_equal(
    e0, "625000*ampere**2*second**4/(22468879468420441*pi*kilogram*meter**3)", "e0",
  )
}
