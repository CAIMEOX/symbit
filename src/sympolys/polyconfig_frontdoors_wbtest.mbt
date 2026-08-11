///|
fn polyconfig_wb_repr(value : PolyConfigValue?) -> String {
  match value {
    Some(PolyConfigValue::Bool(value)) => if value { "True" } else { "False" }
    Some(PolyConfigValue::Int(value)) => value.to_string()
    Some(PolyConfigValue::Text(value)) => value
    None => "None"
  }
}

///|
test "polyconfig frontdoors: query setup configure using" {
  configure()
  inspect(polyconfig_wb_repr(query("USE_HEU_GCD")), content="True")
  inspect(polyconfig_wb_repr(query("groebner")), content="buchberger")
  inspect(polyconfig_wb_repr(query("missing")), content="None")
  setup("USE_HEU_GCD", value=PolyConfigValue::Bool(false))
  inspect(polyconfig_wb_repr(query("use_heu_gcd")), content="False")
  setup("USE_HEU_GCD")
  inspect(polyconfig_wb_repr(query("USE_HEU_GCD")), content="True")
  setup("LOCAL_ONLY", value=PolyConfigValue::Int(7))
  inspect(polyconfig_wb_repr(query("local_only")), content="7")
  configure()
  inspect(polyconfig_wb_repr(query("LOCAL_ONLY")), content="None")
  let scoped_values : Array[String] = []
  polyconfig_using([("GROEBNER", PolyConfigValue::Text("f5b"))], fn() {
    scoped_values.push(polyconfig_wb_repr(query("GROEBNER")))
  })
  inspect(scoped_values.join(","), content="f5b")
  inspect(polyconfig_wb_repr(query("GROEBNER")), content="buchberger")
  sympolys_assert_error(
    fn() raise PolyError { setup("LOCAL_ONLY") },
    "BadGenerator",
  )
}
