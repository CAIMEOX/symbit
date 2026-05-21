///|
fn polyconfig_port_repr(value : @sympolys.PolyConfigValue?) -> String {
  match value {
    Some(@sympolys.PolyConfigValue::Bool(value)) =>
      if value {
        "True"
      } else {
        "False"
      }
    Some(@sympolys.PolyConfigValue::Int(value)) => value.to_string()
    Some(@sympolys.PolyConfigValue::Text(value)) => value
    None => "None"
  }
}

///|
test "polyconfig: query setup configure parity" {
  @sympolys.configure()
  ignore(polyconfig_configure())
  assert_eq(
    polyconfig_port_repr(@sympolys.query("USE_HEU_GCD")),
    polyconfig_query("USE_HEU_GCD"),
  )
  assert_eq(
    polyconfig_port_repr(@sympolys.query("groebner")),
    polyconfig_query("groebner"),
  )
  assert_eq(
    polyconfig_port_repr(@sympolys.query("missing")),
    polyconfig_query("missing"),
  )
  @sympolys.setup("USE_HEU_GCD", value=@sympolys.PolyConfigValue::Bool(false))
  ignore(polyconfig_setup_bool("USE_HEU_GCD", false))
  assert_eq(
    polyconfig_port_repr(@sympolys.query("USE_HEU_GCD")),
    polyconfig_query("USE_HEU_GCD"),
  )
  @sympolys.setup("USE_HEU_GCD")
  ignore(polyconfig_setup_default("USE_HEU_GCD"))
  assert_eq(
    polyconfig_port_repr(@sympolys.query("USE_HEU_GCD")),
    polyconfig_query("USE_HEU_GCD"),
  )
  @sympolys.setup("LOCAL_ONLY", value=@sympolys.PolyConfigValue::Int(7))
  ignore(polyconfig_setup_int("LOCAL_ONLY", 7))
  assert_eq(
    polyconfig_port_repr(@sympolys.query("LOCAL_ONLY")),
    polyconfig_query("LOCAL_ONLY"),
  )
  @sympolys.configure()
  ignore(polyconfig_configure())
  ignore(polyconfig_setup_text("GROEBNER", "f5b"))
  let scoped_values : Array[String] = []
  @sympolys.polyconfig_using(
    [("GROEBNER", @sympolys.PolyConfigValue::Text("f5b"))],
    fn() {
      scoped_values.push(polyconfig_port_repr(@sympolys.query("GROEBNER")))
    },
  )
  assert_eq(scoped_values.join(","), polyconfig_query("GROEBNER"))
  ignore(polyconfig_setup_default("GROEBNER"))
  assert_eq(
    polyconfig_port_repr(@sympolys.query("GROEBNER")),
    polyconfig_query("GROEBNER"),
  )
}
