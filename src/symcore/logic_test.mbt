///|
test "fuzzy logic helpers follow SymPy core.logic semantics" {
  assert_eq(torf([Some(true), Some(true)]), Some(true))
  assert_eq(torf([Some(false), Some(false)]), Some(false))
  assert_eq(torf([Some(true), Some(false)]), None)
  assert_eq(fuzzy_group([Some(false), Some(false), Some(true)]), Some(false))
  assert_eq(
    fuzzy_group([Some(false), Some(false), Some(true)], quick_exit=true),
    None,
  )
  assert_eq(fuzzy_and([Some(true), None, Some(true)]), None)
  assert_eq(fuzzy_or([Some(false), None, Some(false)]), None)
  assert_eq(fuzzy_xor([Some(true), Some(false), Some(true)]), Some(false))
  assert_eq(fuzzy_nand([Some(true), Some(true)]), Some(false))
}
