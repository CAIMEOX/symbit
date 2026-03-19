///|
fn units_assert_expr_equal(
  lhs : @symcore.Expr,
  rhs : String,
  context : String,
) -> Unit raise {
  let ours = @symprint.to_string(lhs)
  guard (try! @sympy_physics.expr_equal(ours, rhs)) else {
    fail("\{context}: ours=\{ours}; oracle=\{rhs}")
  }
}

///|
test "physics.units: prefix arithmetic and quantity derivation" {
  guard prefix_value_to_string(milli.mul_prefix(kilo)) == "1" else {
    fail("milli*kilo")
  }
  guard prefix_value_to_string(kilo.mul_prefix(kilo)) == "M" else {
    fail("kilo*kilo")
  }
  guard prefix_value_to_string(milli.rdiv_one()) == "k" else { fail("1/milli") }
  guard prefix_value_to_string(kilo.div_prefix(milli)) == "M" else {
    fail("kilo/milli")
  }

  let dodeca = prefix("dodeca", "dd", 1, base=12)
  guard prefix_value_to_string(dodeca.mul_prefix(dodeca)) == "144" else {
    fail("dodeca*dodeca")
  }
  guard prefix_value_to_string(dodeca.rdiv_one()) == "1/12" else {
    fail("1/dodeca")
  }

  units_assert_expr_equal(milli.mul_quantity(watt), "watt/1000", "milli*watt")
  units_assert_expr_equal(
    dodeca.mul_quantity(meter),
    "12*meter",
    "dodeca*meter",
  )

  let fake_meter = quantity("fake_meter", abbrev="m", dimension=length)
  let pref : Map[String, Prefix] = { "m": milli, "c": centi, "d": deci }
  let derived = prefix_unit(fake_meter, pref)
  guard derived.length() == 3 else { fail("prefix_unit length") }
  guard derived[0].name == "millifake_meter" &&
    derived[1].name == "centifake_meter" &&
    derived[2].name == "decifake_meter" else {
    fail("prefix_unit names")
  }
  guard derived[0].abbrev == "mm" &&
    derived[1].abbrev == "cm" &&
    derived[2].abbrev == "dm" else {
    fail("prefix_unit abbrevs")
  }
}

///|
test "physics.units: constants and dimensions" {
  guard kilo.base == 10 else { fail("kilo.base") }
  guard kibi.base == 2 else { fail("kibi.base") }
  let doubled_length = length.add(length)
  guard doubled_length == length else { fail("length+length") }
  let velocity = length.div(time_dimension)
  inspect(@symprint.to_string(velocity.name), content="time**-1*length")
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
