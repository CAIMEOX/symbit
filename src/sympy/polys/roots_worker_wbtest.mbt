///|
test "polys P5a8 compact roots renderer keeps one object graph" {
  let recipe = RootsRecipe::new()
  let first = recipe.polys.expr(Dummy("d", 2302))
  let repeated = recipe.polys.expr(Dummy("d", 2302))
  let roots = recipe.polys.builder.list([Ref(first), Ref(repeated)])
  let graph = recipe.polys.builder.dict([
    (Str("roots"), Ref(roots)),
    (Ref(first), DecimalInt("1")),
    (Ref(repeated), DecimalInt("2")),
  ])
  assert_eq(recipe.request_compact(graph), "{'roots':[_d,_d],_d:2}")
}

///|
test "polys P5a8 compact roots renderer rejects nested None" {
  let recipe = RootsRecipe::new()
  let roots = recipe.polys.builder.list([DecimalInt("1"), Null])
  let rejected = try {
    recipe.request_compact(roots) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys P5a8 preprocess renderer requires an exact pair" {
  let recipe = RootsRecipe::new()
  let short = recipe.polys.builder.tuple([DecimalInt("1")])
  let rejected = try {
    recipe.request_preprocess(short) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys P5a8 root object renderer rejects None" {
  let recipe = RootsRecipe::new()
  let none = recipe.polys.builder.value(Null)
  let rejected = try {
    recipe.request_object(none) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}
