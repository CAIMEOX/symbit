///|
test "source get_mod_func parity" {
  assert_eq(
    get_mod_func("sympy.core.basic.Basic"),
    ("sympy.core.basic", "Basic"),
  )
}

///|
test "source get_class uses explicit registry" {
  let registry : Map[String, Int] = {}
  registry["demo.Value"] = 42
  assert_eq(get_class("demo.Value", registry), 42)
}
