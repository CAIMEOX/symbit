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

///|
test "polys domain conversion rendering falls back to the raw value" {
  let recipe = DomainRecipe::new()
  let scope = recipe.builder.exec(
    recipe.scope,
    (
      #|class _SymbitBrokenToSympy:
      #|    def to_sympy(self, value):
      #|        raise ValueError("intentional to_sympy failure")
      #|_symbit_broken_to_sympy = _SymbitBrokenToSympy()
    ),
  )
  let domain = recipe.builder.getitem(scope, Str("_symbit_broken_to_sympy"))
  let raw = recipe.builder.value(Str("raw-value"))
  assert_eq(recipe.request_domain_str(domain, raw), "raw-value")
}

///|
test "polys domain half gcdex falls back to gcdex fields zero and two" {
  let recipe = DomainRecipe::new()
  let scope = recipe.builder.exec(
    recipe.scope,
    (
      #|class _SymbitHalfGcdexFallback:
      #|    def half_gcdex(self, left, right):
      #|        raise ValueError("intentional half_gcdex failure")
      #|    def gcdex(self, left, right):
      #|        return (left, "ignored", right)
      #|    def to_sympy(self, value):
      #|        return value
      #|_symbit_half_gcdex_fallback = _SymbitHalfGcdexFallback()
    ),
  )
  let domain = recipe.builder.getitem(scope, Str("_symbit_half_gcdex_fallback"))
  let left = recipe.builder.value(DecimalInt("3"))
  let right = recipe.builder.value(DecimalInt("5"))
  let result = recipe.half_gcdex(domain, left, right)
  assert_eq(recipe.builder.request_str(result), "(3,5)")
}

///|
test "polys domain evalf keeps nsimplify strict and worker recovery" {
  let recipe = DomainRecipe::new()
  let scope = recipe.builder.exec(
    recipe.scope,
    (
      #|class _SymbitUnsimplifiableEvalf:
      #|    def evalf(self, value):
      #|        return object()
      #|_symbit_unsimplifiable_evalf = _SymbitUnsimplifiableEvalf()
    ),
  )
  let domain = recipe.builder.getitem(
    scope,
    Str("_symbit_unsimplifiable_evalf"),
  )
  let element = recipe.builder.value(DecimalInt("1"))
  let result = recipe.evalf(domain, element)
  let rejected = try {
    recipe.builder.request_str(result) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(domain_evalf_expr("QQ", "1/2"), "1/2")
}
