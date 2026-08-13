///|
test "polys P5a7 recipe shares Dummy identity" {
  let recipe = PolysRecipe::new()
  let dummy = @symcore.Expr::Dummy("d", 2101)
  let first = recipe.expr(dummy)
  let repeated = recipe.expr(dummy)
  let operator = recipe.builder.import_module("operator")
  let is_same = recipe.builder.getattr(operator, "is_")
  let result = recipe.builder.call(is_same, [Ref(first), Ref(repeated)])
  assert_true(recipe.builder.request_bool(result))
}

///|
test "polys P5a7 LBP renderer rejects non-triples" {
  let recipe = PolysRecipe::new()
  let short = recipe.builder.tuple([DecimalInt("1"), DecimalInt("2")])
  let rejected = try {
    recipe.request_f5_lbp(short) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys P5a7 predicate codec rejects integers" {
  let recipe = PolysRecipe::new()
  let integer = recipe.builder.value(DecimalInt("1"))
  let rejected = try {
    recipe.request_f5_predicate(integer) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
