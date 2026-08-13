///|
priv struct SimplifyRecipe {
  builder : @recipe.Builder
  encoder : @exprcodec.Encoder
}

///|
fn SimplifyRecipe::new() -> SimplifyRecipe raise {
  let builder = @recipe.Builder::new()
  { builder, encoder: @exprcodec.Encoder::new(builder) }
}

///|
fn recipe_callable(
  builder : @recipe.Builder,
  path : String,
) -> @recipe.ValueRef raise {
  let parts : Array[String] = []
  for part in path.trim().split(".") {
    parts.push(part.to_owned())
  }
  guard parts.length() >= 2 && parts[0] == "sympy" else {
    fail("sympy-call-invalid:\{path}")
  }
  let module_name = parts[0:parts.length() - 1].join(".")
  let module_obj = builder.import_module(module_name)
  builder.getattr(module_obj, parts[parts.length() - 1])
}

///|
fn SimplifyRecipe::call(
  self : SimplifyRecipe,
  path : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = recipe_callable(self.builder, path)
  let result = self.builder.call(callable, args, kwargs~)
  self.builder.require_non_none(result, message="sympy-call-none:\{path}")
}

///|
fn SimplifyRecipe::expr(
  self : SimplifyRecipe,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  self.encoder.encode(expression)
}

///|
fn SimplifyRecipe::expr_list(
  self : SimplifyRecipe,
  expressions : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for expression in expressions {
    items.push(Ref(self.expr(expression)))
  }
  self.builder.list(items)
}

///|
fn SimplifyRecipe::unary(
  self : SimplifyRecipe,
  path : String,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  self.call(path, [Ref(self.expr(expression))])
}

///|
fn unary_simplify_srepr(
  path : String,
  expression : @symcore.Expr,
) -> String raise {
  let recipe = SimplifyRecipe::new()
  let result = recipe.unary(path, expression)
  recipe.builder.request_srepr(result)
}

///|
fn SimplifyRecipe::equivalent_result(
  self : SimplifyRecipe,
  oracle : @recipe.ValueRef,
  candidate : @symcore.Expr,
) -> @recipe.ValueRef raise {
  let candidate = self.expr(candidate)
  let negative = self.call("sympy.Mul", [DecimalInt("-1"), Ref(oracle)])
  let difference = self.call("sympy.Add", [Ref(candidate), Ref(negative)])
  self.call("sympy.simplify", [Ref(difference)])
}

///|
fn unary_equivalent(
  path : String,
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  let recipe = SimplifyRecipe::new()
  let oracle = recipe.unary(path, input_expr)
  let result = recipe.equivalent_result(oracle, candidate)
  recipe.builder.request_srepr(result) == "Integer(0)"
}

///|
fn SimplifyRecipe::ratsimpmodprime_result(
  self : SimplifyRecipe,
  expression : @symcore.Expr,
  basis : Array[@symcore.Expr],
  gens : Array[@symcore.Expr],
  quick : Bool,
  polynomial : Bool,
) -> @recipe.ValueRef raise {
  let args : Array[@recipe.RecipeArg] = [
    Ref(self.expr(expression)),
    Ref(self.expr_list(basis)),
  ]
  for gen in gens {
    args.push(Ref(self.expr(gen)))
  }
  self.call("sympy.ratsimpmodprime", args, kwargs={
    "quick": Bool(quick),
    "polynomial": Bool(polynomial),
  })
}

///|
fn SimplifyRecipe::nsimplify_with_constants_result(
  self : SimplifyRecipe,
  expression : @symcore.Expr,
  constants : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  self.call("sympy.nsimplify", [
    Ref(self.expr(expression)),
    Ref(self.expr_list(constants)),
  ])
}

///|
pub fn expr_srepr(expr : @symcore.Expr) -> String raise {
  let recipe = SimplifyRecipe::new()
  let expression = recipe.expr(expr)
  recipe.builder.request_srepr(expression)
}

///|
pub fn simplify_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify", expr)
}

///|
pub fn powsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.powsimp", expr)
}

///|
pub fn trigsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.trigsimp", expr)
}

///|
pub fn signsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.signsimp", expr)
}

///|
pub fn radsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.radsimp", expr)
}

///|
pub fn ratsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.ratsimp", expr)
}

///|
pub fn ratsimpmodprime_srepr(
  expr : @symcore.Expr,
  basis : Array[@symcore.Expr],
  gens : Array[@symcore.Expr],
  quick? : Bool = true,
  polynomial? : Bool = false,
) -> String raise {
  let recipe = SimplifyRecipe::new()
  let result = recipe.ratsimpmodprime_result(
    expr, basis, gens, quick, polynomial,
  )
  recipe.builder.request_srepr(result)
}

///|
pub fn sqrtdenest_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.sqrtdenest", expr)
}

///|
pub fn combsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.combsimp", expr)
}

///|
pub fn hyperexpand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.hyperexpand", expr)
}

///|
pub fn radsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.radsimp", input_expr, candidate)
}

///|
pub fn ratsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.ratsimp", input_expr, candidate)
}

///|
pub fn ratsimpmodprime_equivalent(
  input_expr : @symcore.Expr,
  basis : Array[@symcore.Expr],
  gens : Array[@symcore.Expr],
  candidate : @symcore.Expr,
  quick? : Bool = true,
  polynomial? : Bool = false,
) -> Bool raise {
  let recipe = SimplifyRecipe::new()
  let oracle = recipe.ratsimpmodprime_result(
    input_expr, basis, gens, quick, polynomial,
  )
  let result = recipe.equivalent_result(oracle, candidate)
  recipe.builder.request_srepr(result) == "Integer(0)"
}

///|
pub fn sqrtdenest_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.sqrtdenest", input_expr, candidate)
}

///|
pub fn combsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.combsimp", input_expr, candidate)
}

///|
pub fn hyperexpand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.hyperexpand", input_expr, candidate)
}

///|
pub fn powdenest_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.powdenest", expr)
}

///|
pub fn exptrigsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.exptrigsimp", expr)
}

///|
pub fn gammasimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.gammasimp", expr)
}

///|
pub fn logcombine_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.logcombine", expr)
}

///|
pub fn besselsimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.besselsimp", expr)
}

///|
pub fn kroneckersimp_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.kroneckersimp", expr)
}

///|
pub fn nsimplify_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.nsimplify", expr)
}

///|
pub fn nsimplify_with_constants_srepr(
  expr : @symcore.Expr,
  constants : Array[@symcore.Expr],
) -> String raise {
  let recipe = SimplifyRecipe::new()
  let result = recipe.nsimplify_with_constants_result(expr, constants)
  recipe.builder.request_srepr(result)
}

///|
pub fn collect_sqrt_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.collect_sqrt", expr)
}

///|
pub fn collect_abs_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.collect_abs", expr)
}

///|
pub fn fraction_expand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.fraction_expand", expr)
}

///|
pub fn numer_expand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.numer_expand", expr)
}

///|
pub fn denom_expand_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.radsimp.denom_expand", expr)
}

///|
pub fn powdenest_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.powdenest", input_expr, candidate)
}

///|
pub fn exptrigsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.exptrigsimp", input_expr, candidate)
}

///|
pub fn gammasimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.gammasimp", input_expr, candidate)
}

///|
pub fn logcombine_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.logcombine", input_expr, candidate)
}

///|
pub fn besselsimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.besselsimp", input_expr, candidate)
}

///|
pub fn kroneckersimp_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.kroneckersimp", input_expr, candidate)
}

///|
pub fn nsimplify_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.nsimplify", input_expr, candidate)
}

///|
pub fn nsimplify_equivalent_with_constants(
  input_expr : @symcore.Expr,
  constants : Array[@symcore.Expr],
  candidate : @symcore.Expr,
) -> Bool raise {
  let recipe = SimplifyRecipe::new()
  let oracle = recipe.nsimplify_with_constants_result(input_expr, constants)
  let result = recipe.equivalent_result(oracle, candidate)
  recipe.builder.request_srepr(result) == "Integer(0)"
}

///|
pub fn collect_sqrt_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.collect_sqrt", input_expr, candidate)
}

///|
pub fn collect_abs_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.collect_abs", input_expr, candidate)
}

///|
pub fn fraction_expand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent(
    "sympy.simplify.radsimp.fraction_expand", input_expr, candidate,
  )
}

///|
pub fn numer_expand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.numer_expand", input_expr, candidate)
}

///|
pub fn denom_expand_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.radsimp.denom_expand", input_expr, candidate)
}

///|
pub fn separatevars_srepr(
  expr : @symcore.Expr,
  force? : Bool = false,
) -> String raise {
  let recipe = SimplifyRecipe::new()
  let result = recipe.call("sympy.separatevars", [Ref(recipe.expr(expr))], kwargs={
    "force": Bool(force),
  })
  recipe.builder.request_srepr(result)
}

///|
pub fn hypersimp_srepr(f : @symcore.Expr, k : @symcore.Expr) -> String raise {
  let recipe = SimplifyRecipe::new()
  let result = recipe.call("sympy.hypersimp", [
    Ref(recipe.expr(f)),
    Ref(recipe.expr(k)),
  ])
  recipe.builder.request_srepr(result)
}

///|
pub fn hypersimilar_bool(
  f : @symcore.Expr,
  g : @symcore.Expr,
  k : @symcore.Expr,
) -> Bool raise {
  let recipe = SimplifyRecipe::new()
  let result = recipe.call("sympy.hypersimilar", [
    Ref(recipe.expr(f)),
    Ref(recipe.expr(g)),
    Ref(recipe.expr(k)),
  ])
  recipe.builder.request_bool(result)
}

///|
pub fn fu_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.fu", expr)
}

///|
pub fn fu_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.fu", input_expr, candidate)
}

///|
pub fn futrig_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.trigsimp.futrig", expr)
}

///|
pub fn futrig_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.trigsimp.futrig", input_expr, candidate)
}

///|
fn fu_rule_path(rule : String) -> String {
  "sympy.simplify.fu.\{rule}"
}

///|
pub fn tr_rule_equivalent(
  rule : String,
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent(fu_rule_path(rule), input_expr, candidate)
}

///|
pub fn sub_pre_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.cse_opts.sub_pre", expr)
}

///|
pub fn sub_post_srepr(expr : @symcore.Expr) -> String raise {
  unary_simplify_srepr("sympy.simplify.cse_opts.sub_post", expr)
}

///|
pub fn sub_pre_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.cse_opts.sub_pre", input_expr, candidate)
}

///|
pub fn sub_post_equivalent(
  input_expr : @symcore.Expr,
  candidate : @symcore.Expr,
) -> Bool raise {
  unary_equivalent("sympy.simplify.cse_opts.sub_post", input_expr, candidate)
}
