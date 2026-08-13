///|
fn polys_f5_fglm_foundation_source() -> String {
  (
    #|def _symbit_polys_p5a7_lbp_text(value):
    #|    if not isinstance(value, tuple) or len(value) != 3:
    #|        raise ValueError("F5 labeled polynomial must be a triple")
    #|    if any(item is None for item in value):
    #|        raise ValueError("F5 labeled polynomial contains None")
    #|    return "|".join(str(item) for item in value)
    #|
    #|def _symbit_polys_p5a7_basis_text(values):
    #|    if not isinstance(values, (list, tuple)):
    #|        raise ValueError("FGLM basis must be a sequence")
    #|    if any(value is None for value in values):
    #|        raise ValueError("FGLM basis contains None")
    #|    parts = sorted(str(value) for value in values)
    #|    return " | ".join(parts)
    #|
  )
}

///|
fn PolysRecipe::f5_fglm_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_f5_fglm_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::request_f5_lbp(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.f5_fglm_callable("_symbit_polys_p5a7_lbp_text")
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-f5-lbp-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_fglm_basis(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.f5_fglm_callable("_symbit_polys_p5a7_basis_text")
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-fglm-basis-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_f5_predicate(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  if self.builder.request_bool(result) {
    "true"
  } else {
    "false"
  }
}

///|
fn PolysRecipe::f5_monomial(
  self : PolysRecipe,
  monomial : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for exponent in monomial {
    items.push(DecimalInt(Show::to_string(exponent)))
  }
  self.builder.tuple(items)
}

///|
fn PolysRecipe::f5_signature(
  self : PolysRecipe,
  monomial : Array[Int],
  index : Int,
) -> @recipe.ValueRef raise {
  self.builder.tuple([
    Ref(self.f5_monomial(monomial)),
    DecimalInt(Show::to_string(index)),
  ])
}

///|
fn PolysRecipe::f5_lbp(
  self : PolysRecipe,
  monomial : Array[Int],
  index : Int,
  polynomial : @recipe.ValueRef,
  number : Int,
) -> @recipe.ValueRef raise {
  self.builder.tuple([
    Ref(self.f5_signature(monomial, index)),
    Ref(polynomial),
    DecimalInt(Show::to_string(number)),
  ])
}

///|
fn PolysRecipe::f5_term(
  self : PolysRecipe,
  ring : @recipe.ValueRef,
  monomial : Array[Int],
  coefficient : Int,
) -> @recipe.ValueRef raise {
  let domain = self.builder.getattr(ring, "domain")
  let convert = self.builder.getattr(domain, "convert")
  let converted = self.builder.require_non_none(
    self.builder.call(convert, [DecimalInt(Show::to_string(coefficient))]),
    message="sympy-call-none:QQ.convert",
  )
  self.builder.tuple([Ref(self.f5_monomial(monomial)), Ref(converted)])
}

///|
fn PolysRecipe::f5_polynomial_list(
  self : PolysRecipe,
  polynomials : Array[@recipe.ValueRef],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for polynomial in polynomials {
    items.push(Ref(polynomial))
  }
  self.builder.list(items)
}

///|
fn PolysRecipe::f5_order(
  self : PolysRecipe,
  order : String,
) -> @recipe.ValueRef raise {
  if order == "" {
    self.call("sympy.polys.orderings.monomial_key", [])
  } else {
    self.call("sympy.polys.orderings.monomial_key", [Str(order)])
  }
}

///|
pub fn matrix_fglm(
  exprs : Array[@symcore.Expr],
  gens? : Array[String] = ["x", "y"],
  source_order? : String = "grlex",
  target_order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, polynomials) = recipe.groebner_basic_ring_polys(
    exprs, gens, source_order,
  )
  let source = recipe.call("sympy.polys.groebnertools.groebner", [
    Ref(recipe.f5_polynomial_list(polynomials)),
    Ref(ring),
  ])
  let target_order_object = recipe.f5_order(target_order)
  let result = recipe.call("sympy.polys.fglmtools.matrix_fglm", [
    Ref(source),
    Ref(ring),
    Ref(target_order_object),
  ])
  recipe.request_fglm_basis(result)
}

///|
pub fn groebnertools_sig_cmp(
  a_monomial : Array[Int],
  a_index : Int,
  b_monomial : Array[Int],
  b_index : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, _) = recipe.groebner_basic_ring_polys([], gens, order)
  let order_object = recipe.builder.getattr(ring, "order")
  let result = recipe.call("sympy.polys.groebnertools.sig_cmp", [
    Ref(recipe.f5_signature(a_monomial, a_index)),
    Ref(recipe.f5_signature(b_monomial, b_index)),
    Ref(order_object),
  ])
  recipe.builder.request_str(result)
}

///|
pub fn groebnertools_sig_mult(
  monomial : Array[Int],
  index : Int,
  multiplier : Array[Int],
) -> String raise {
  let recipe = PolysRecipe::new()
  let result = recipe.call("sympy.polys.groebnertools.sig_mult", [
    Ref(recipe.f5_signature(monomial, index)),
    Ref(recipe.f5_monomial(multiplier)),
  ])
  recipe.builder.request_str(result)
}

///|
fn groebnertools_binary_lbp(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens : Array[String],
  order : String,
  path : String,
  render_lbp : Bool,
) -> String raise {
  let recipe = PolysRecipe::new()
  let (_, polynomials) = recipe.groebner_basic_ring_polys(
    [f_expr, g_expr],
    gens,
    order,
  )
  guard polynomials is [f_polynomial, g_polynomial] else {
    fail("groebner-ring-polynomials")
  }
  let f = recipe.f5_lbp(f_monomial, f_index, f_polynomial, f_number)
  let g = recipe.f5_lbp(g_monomial, g_index, g_polynomial, g_number)
  let result = recipe.call(path, [Ref(f), Ref(g)])
  if render_lbp {
    recipe.request_f5_lbp(result)
  } else {
    recipe.builder.request_str(result)
  }
}

///|
pub fn groebnertools_lbp_cmp(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  groebnertools_binary_lbp(
    f_monomial, f_index, f_expr, f_number, g_monomial, g_index, g_expr, g_number,
    gens, order, "sympy.polys.groebnertools.lbp_cmp", false,
  )
}

///|
pub fn groebnertools_lbp_sub(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  groebnertools_binary_lbp(
    f_monomial, f_index, f_expr, f_number, g_monomial, g_index, g_expr, g_number,
    gens, order, "sympy.polys.groebnertools.lbp_sub", true,
  )
}

///|
pub fn groebnertools_lbp_mul_term(
  monomial : Array[Int],
  index : Int,
  expr : @symcore.Expr,
  number : Int,
  term_monomial : Array[Int],
  term_coeff : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, polynomials) = recipe.groebner_basic_ring_polys(
    [expr],
    gens,
    order,
  )
  guard polynomials is [polynomial] else { fail("groebner-ring-polynomials") }
  let f = recipe.f5_lbp(monomial, index, polynomial, number)
  let term = recipe.f5_term(ring, term_monomial, term_coeff)
  let result = recipe.call("sympy.polys.groebnertools.lbp_mul_term", [
    Ref(f),
    Ref(term),
  ])
  recipe.request_f5_lbp(result)
}

///|
pub fn groebnertools_critical_s_poly(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  g_monomial : Array[Int],
  g_index : Int,
  g_expr : @symcore.Expr,
  g_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (ring, polynomials) = recipe.groebner_basic_ring_polys(
    [f_expr, g_expr],
    gens,
    order,
  )
  guard polynomials is [f_polynomial, g_polynomial] else {
    fail("groebner-ring-polynomials")
  }
  let f = recipe.f5_lbp(f_monomial, f_index, f_polynomial, f_number)
  let g = recipe.f5_lbp(g_monomial, g_index, g_polynomial, g_number)
  let critical_pair = recipe.call("sympy.polys.groebnertools.critical_pair", [
    Ref(f),
    Ref(g),
    Ref(ring),
  ])
  let result = recipe.call("sympy.polys.groebnertools.s_poly", [
    Ref(critical_pair),
  ])
  recipe.request_f5_lbp(result)
}

///|
pub fn groebnertools_is_rewritable_or_comparable_one(
  sign_monomial : Array[Int],
  sign_index : Int,
  number : Int,
  h_monomial : Array[Int],
  h_index : Int,
  h_expr : @symcore.Expr,
  h_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (_, polynomials) = recipe.groebner_basic_ring_polys([h_expr], gens, order)
  guard polynomials is [h_polynomial] else { fail("groebner-ring-polynomials") }
  let h = recipe.f5_lbp(h_monomial, h_index, h_polynomial, h_number)
  let result = recipe.call(
    "sympy.polys.groebnertools.is_rewritable_or_comparable",
    [
      Ref(recipe.f5_signature(sign_monomial, sign_index)),
      DecimalInt(Show::to_string(number)),
      Ref(recipe.builder.list([Ref(h)])),
    ],
  )
  recipe.request_f5_predicate(result)
}

///|
pub fn groebnertools_f5_reduce_one(
  f_monomial : Array[Int],
  f_index : Int,
  f_expr : @symcore.Expr,
  f_number : Int,
  h_monomial : Array[Int],
  h_index : Int,
  h_expr : @symcore.Expr,
  h_number : Int,
  gens? : Array[String] = ["x", "y"],
  order? : String = "lex",
) -> String raise {
  let recipe = PolysRecipe::new()
  let (_, polynomials) = recipe.groebner_basic_ring_polys(
    [f_expr, h_expr],
    gens,
    order,
  )
  guard polynomials is [f_polynomial, h_polynomial] else {
    fail("groebner-ring-polynomials")
  }
  let f = recipe.f5_lbp(f_monomial, f_index, f_polynomial, f_number)
  let h = recipe.f5_lbp(h_monomial, h_index, h_polynomial, h_number)
  let result = recipe.call("sympy.polys.groebnertools.f5_reduce", [
    Ref(f),
    Ref(recipe.builder.list([Ref(h)])),
  ])
  recipe.request_f5_lbp(result)
}
