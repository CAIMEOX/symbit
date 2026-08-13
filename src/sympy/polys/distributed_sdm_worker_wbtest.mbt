///|
test "polys distributed SDM worker preserves monomial codecs" {
  let recipe = DistributedSdmRecipe::new()
  let result = recipe.call("sdm_monomial_mul", [
    Ref(recipe.monomial([1, 1, 0])),
    Ref(recipe.monomial([1, 3])),
  ])
  assert_eq(recipe.request_compact(result), "(1,2,3)")
}

///|
test "polys distributed SDM worker preserves domain order and dict codecs" {
  let recipe = DistributedSdmRecipe::new()
  let domain = recipe.domain("QQ")
  let dictionary = recipe.term_dict(
    [([1, 0], 1), ([1, 0], 3), ([0, 1], 0), ([2, 0], 2)],
    domain,
  )
  let result = recipe.call("sdm_from_dict", [
    Ref(dictionary),
    Ref(recipe.order("lex")),
  ])
  assert_eq(recipe.request_compact(result), "[((2,0),2),((1,0),3)]")
}

///|
test "polys distributed SDM worker preserves order callbacks" {
  let terms = [([1, 2, 0], 1), ([1, 1, 5], 2)]
  assert_eq(sdm_sort(terms, order="lex"), "[((1,2,0),1),((1,1,5),2)]")
  assert_eq(sdm_sort(terms, order="grlex"), "[((1,1,5),2),((1,2,0),1)]")
}

///|
test "polys distributed SDM worker preserves Python dict repr" {
  let recipe = DistributedSdmRecipe::new()
  let domain = recipe.domain("QQ")
  let terms = recipe.terms([([1], 1), ([2], 2)], domain)
  let result = recipe.call("sdm_to_dict", [Ref(terms)])
  assert_eq(recipe.request_compact(result), "{(1,):MPQ(1,1),(2,):MPQ(2,1)}")
}

///|
test "polys distributed SDM worker preserves vector codecs" {
  let from_recipe = DistributedSdmRecipe::new()
  let from_domain = from_recipe.domain("QQ")
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  kwargs["gens"] = Ref(from_recipe.symbols(["x", "y", "z"]))
  let from_result = from_recipe.call(
    "sdm_from_vector",
    [
      Ref(from_recipe.expressions(["x**2 + y**2", "2*z"])),
      Ref(from_recipe.order("lex")),
      Ref(from_domain),
    ],
    kwargs~,
  )
  assert_eq(
    from_recipe.request_compact(from_result),
    "[((1,0,0,1),2),((0,2,0,0),1),((0,0,2,0),1)]",
  )
  let to_recipe = DistributedSdmRecipe::new()
  let to_domain = to_recipe.domain("QQ")
  let to_result = to_recipe.call("sdm_to_vector", [
    Ref(to_recipe.terms([([1, 0, 1], 2)], to_domain)),
    Ref(to_recipe.symbols(["x", "y"])),
    Ref(to_domain),
    DecimalInt("3"),
  ])
  assert_eq(to_recipe.request_compact(to_result), "[0,2*y,0]")
}

///|
test "polys distributed SDM worker preserves normal form selection" {
  for
    pair in [
      ("buchberger", "sdm_nf_buchberger"),
      ("reduced", "sdm_nf_buchberger_reduced"),
      ("buchberger_reduced", "sdm_nf_buchberger_reduced"),
      ("mora", "sdm_nf_mora"),
      ("unknown", "sdm_nf_mora"),
    ] {
    let (name, expected) = pair
    let recipe = DistributedSdmRecipe::new()
    let function = recipe.normal_form(name)
    let function_name = recipe.domain_recipe.builder.getattr(
      function, "__name__",
    )
    assert_eq(recipe.domain_recipe.builder.request_str(function_name), expected)
  }
}

///|
test "polys distributed SDM worker uses strict scalar terminals" {
  let degree_recipe = DistributedSdmRecipe::new()
  let degree = degree_recipe.call("sdm_monomial_deg", [
    Ref(degree_recipe.monomial([5, 2, 1])),
  ])
  assert_eq(degree_recipe.request_int(degree), 3)
  let divides_recipe = DistributedSdmRecipe::new()
  let divides = divides_recipe.call("sdm_monomial_divides", [
    Ref(divides_recipe.monomial([5, 1, 1])),
    Ref(divides_recipe.monomial([5, 2, 1])),
  ])
  assert_true(divides_recipe.request_bool(divides))
}

///|
test "polys distributed SDM worker rejects None" {
  let recipe = DistributedSdmRecipe::new()
  let none = recipe.domain_recipe.builder.value(Null)
  let rejected = try {
    recipe.request_compact(none) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
}

///|
test "polys distributed SDM worker recovers after invalid order" {
  let rejected = try {
    sdm_sort([([1, 0], 1)], order="does_not_exist") |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(rejected)
  assert_eq(sdm_zero(), "[]")
}
