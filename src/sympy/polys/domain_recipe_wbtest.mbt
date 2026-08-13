///|
test "polys domain captured calls preserve value error and none outcomes" {
  let none_recipe = DomainRecipe::new()
  let dictionary = none_recipe.builder.dict([])
  let none_result = none_recipe.captured_method_call(dictionary, "clear", [])
  assert_eq(none_recipe.request_captured_str(none_result), "ERROR")

  let error_recipe = DomainRecipe::new()
  let empty = error_recipe.builder.list([])
  let error_result = error_recipe.captured_method_call(empty, "index", [
    DecimalInt("1"),
  ])
  assert_eq(error_recipe.request_captured_str(error_result), "ERROR")

  let value_recipe = DomainRecipe::new()
  let one = value_recipe.builder.list([DecimalInt("1")])
  let value_result = value_recipe.captured_method_call(one, "count", [
    DecimalInt("1"),
  ])
  assert_eq(value_recipe.request_captured_str(value_result), "1")
}
