///|
test "polys P6g DomainScalar renderer rejects a short result" {
  let recipe = PolysTailRecipe::new()
  let malformed = recipe.polys.builder.tuple([DecimalInt("1")])
  let rejected = try {
    recipe.request_domain_scalar(malformed) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys P6g matrix renderer rejects None" {
  let recipe = PolysTailRecipe::new()
  let malformed = recipe.polys.builder.value(Null)
  let rejected = try {
    recipe.request_matrix(malformed) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys P6g factor sort renderers reject malformed items" {
  let single_recipe = PolysTailRecipe::new()
  let bad_single = single_recipe.polys.builder.list([Null])
  let single_rejected = try {
    single_recipe.request_sorted_factors(bad_single, multiple=false) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(single_rejected)
  let multiple_recipe = PolysTailRecipe::new()
  let bad_pair = multiple_recipe.polys.builder.tuple([Null, DecimalInt("1")])
  let bad_multiple = multiple_recipe.polys.builder.list([Ref(bad_pair)])
  let multiple_rejected = try {
    multiple_recipe.request_sorted_factors(bad_multiple, multiple=true)
    |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(multiple_rejected)
}

///|
test "polys P6g ANP renderer rejects None" {
  let recipe = PolysTailRecipe::new()
  let malformed = recipe.polys.builder.value(Null)
  let rejected = try {
    recipe.request_anp(malformed) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys P6g factor repr renderer rejects None content" {
  let recipe = PolysTailRecipe::new()
  let factors = recipe.polys.builder.list([])
  let malformed = recipe.polys.builder.tuple([Null, Ref(factors)])
  let rejected = try {
    recipe.request_factor_repr(malformed) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
