///|
test "fuzzy logic helpers follow SymPy core.logic semantics" {
  assert_true(torf([Some(true), Some(true)]) == Some(true))
  assert_true(torf([Some(false), Some(false)]) == Some(false))
  assert_true(torf([Some(true), Some(false)]) == None)
  assert_true(
    fuzzy_group([Some(false), Some(false), Some(true)]) == Some(false),
  )
  assert_true(
    fuzzy_group([Some(false), Some(false), Some(true)], quick_exit=true) == None,
  )
  assert_true(fuzzy_and([Some(true), None, Some(true)]) == None)
  assert_true(fuzzy_or([Some(false), None, Some(false)]) == None)
  assert_true(fuzzy_xor([Some(true), Some(false), Some(true)]) == Some(false))
  assert_true(fuzzy_nand([Some(true), Some(true)]) == Some(false))
}
