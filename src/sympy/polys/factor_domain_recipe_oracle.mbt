///|
fn polys_factor_domain_foundation_source() -> String {
  (
    #|def _symbit_polys_p5a4_default_gens(expressions):
    #|    symbols = set()
    #|    for expression in expressions:
    #|        symbols.update(expression.free_symbols)
    #|    return sorted(symbols, key=lambda symbol: symbol.name)
    #|
    #|def _symbit_polys_p5a4_poly(expr, gens, domain, modulus,
    #|                             use_domain, use_modulus):
    #|    kwargs = {}
    #|    if use_domain:
    #|        kwargs["domain"] = domain
    #|    if use_modulus:
    #|        kwargs["modulus"] = modulus
    #|    return sympy.Poly(expr, *gens, **kwargs)
    #|
    #|def _symbit_polys_p5a4_mod_text(value, modulus):
    #|    if isinstance(value, sympy.Poly):
    #|        value = value.as_expr()
    #|    polynomial = sympy.Poly(value, modulus=modulus)
    #|    result = sympy.Integer(0)
    #|    for monomial, coefficient in polynomial.terms():
    #|        term = sympy.Integer(int(coefficient) % modulus)
    #|        for generator, exponent in zip(polynomial.gens, monomial):
    #|            if exponent:
    #|                term *= generator ** int(exponent)
    #|        result += term
    #|    return str(sympy.expand(result))
    #|
    #|def _symbit_polys_p5a4_factor_text(result, modulus, use_modulus):
    #|    if result is None or len(result) < 2:
    #|        raise ValueError("factor_list tuple")
    #|    content, factors = result[0], result[1]
    #|    entries = []
    #|    for pair in factors:
    #|        if len(pair) < 2:
    #|            continue
    #|        factor, exponent = pair[0], pair[1]
    #|        if use_modulus:
    #|            factor_text = _symbit_polys_p5a4_mod_text(factor, modulus)
    #|        elif isinstance(factor, sympy.Poly):
    #|            factor_text = str(factor.as_expr())
    #|        else:
    #|            factor_text = str(sympy.Poly(factor).as_expr())
    #|        if factor_text != "1":
    #|            entries.append((factor_text, int(exponent)))
    #|    entries.sort(key=lambda item: (item[0], item[1]))
    #|    body = ",".join(
    #|        "(" + factor + ", " + str(exponent) + ")"
    #|        for factor, exponent in entries
    #|    )
    #|    return "(" + str(content) + ", [" + body + "])"
    #|
    #|def _symbit_polys_p5a4_pair_text(result):
    #|    if result is None or len(result) < 2:
    #|        raise ValueError("div result tuple")
    #|    values = []
    #|    for value in result[:2]:
    #|        if value is None:
    #|            raise ValueError("div result item is None")
    #|        if isinstance(value, sympy.Poly):
    #|            value = value.as_expr()
    #|        values.append(str(value))
    #|    return values[0] + "||" + values[1]
    #|
    #|def _symbit_polys_p5a4_finite_extension(modulus, coefficients,
    #|                                          generator):
    #|    if modulus == 0:
    #|        raise ValueError("gfext-modulus-missing")
    #|    if modulus <= 1:
    #|        raise ValueError("gfext-modulus")
    #|    expression = sympy.Add(*(
    #|        sympy.Integer(coefficient) * generator ** index
    #|        for index, coefficient in enumerate(coefficients)
    #|    ))
    #|    polynomial = sympy.Poly(expression, generator, modulus=modulus)
    #|    return sympy.polys.agca.extensions.FiniteExtension(polynomial)
    #|
    #|def _symbit_polys_p5a4_resultant(p, q, variable, gens, domain,
    #|                                  modulus, gfext_coefficients,
    #|                                  gfext_generator, use_domain,
    #|                                  use_modulus, use_gfext):
    #|    gens = list(gens)
    #|    if variable is not None and gens:
    #|        variable_name = str(variable)
    #|        for index, generator in enumerate(gens):
    #|            if str(generator) == variable_name:
    #|                if index:
    #|                    gens = [gens[index]] + gens[:index] + gens[index + 1:]
    #|                break
    #|    if gens and (use_domain or use_modulus or use_gfext):
    #|        kwargs = {}
    #|        if use_gfext:
    #|            kwargs["domain"] = _symbit_polys_p5a4_finite_extension(
    #|                modulus, gfext_coefficients, gfext_generator
    #|            )
    #|        else:
    #|            if use_domain:
    #|                kwargs["domain"] = domain
    #|            if use_modulus:
    #|                kwargs["modulus"] = modulus
    #|        p_poly = sympy.Poly(p, *gens, **kwargs)
    #|        q_poly = sympy.Poly(q, *gens, **kwargs)
    #|        return p_poly.resultant(q_poly)
    #|    if variable is None:
    #|        if not gens:
    #|            raise ValueError("resultant requires a variable")
    #|        variable = gens[0]
    #|    kwargs = {"modulus": modulus} if use_modulus else {}
    #|    return sympy.resultant(p, q, variable, **kwargs)
    #|
    #|def _symbit_polys_p5a4_terms_gcd(polynomial):
    #|    content = polynomial.content()
    #|    exponents = polynomial.terms_gcd()[0]
    #|    result = content
    #|    for generator, exponent in zip(polynomial.gens, exponents):
    #|        if exponent:
    #|            result *= generator ** int(exponent)
    #|    return result
  )
}

///|
fn PolysRecipe::factor_domain_callable(
  self : PolysRecipe,
  name : String,
) -> @recipe.ValueRef raise {
  let scope = self.builder.exec(
    self.builder.sympy_scope(),
    polys_factor_domain_foundation_source(),
  )
  self.builder.getitem(scope, Str(name))
}

///|
fn PolysRecipe::request_factor_domain_string(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let printable = self.builder.require_non_none(
    self.stringify_legacy_call_result(result),
    message="sympy-polys-factor-domain-render-none",
  )
  self.builder.request_str(printable)
}

///|
fn PolysRecipe::request_factor_list_string(
  self : PolysRecipe,
  result : @recipe.ValueRef,
  modulus : Int,
) -> String raise {
  let renderer = self.factor_domain_callable("_symbit_polys_p5a4_factor_text")
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [
      Ref(result),
      DecimalInt(Show::to_string(modulus)),
      Bool(modulus != 0),
    ]),
    message="sympy-polys-factor-list-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::request_factor_domain_pair(
  self : PolysRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  let renderer = self.factor_domain_callable("_symbit_polys_p5a4_pair_text")
  let rendered = self.builder.require_non_none(
    self.builder.call(renderer, [Ref(result)]),
    message="sympy-polys-div-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn PolysRecipe::factor_domain_default_gens(
  self : PolysRecipe,
  expressions : Array[@recipe.ValueRef],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for expression in expressions {
    items.push(Ref(expression))
  }
  let expression_list = self.builder.list(items)
  let callable = self.factor_domain_callable("_symbit_polys_p5a4_default_gens")
  self.builder.require_non_none(
    self.builder.call(callable, [Ref(expression_list)]),
    message="sympy-polys-default-gens-none",
  )
}

///|
fn PolysRecipe::factor_domain_gens(
  self : PolysRecipe,
  expressions : Array[@recipe.ValueRef],
  gens : Array[String],
) -> @recipe.ValueRef raise {
  if gens.is_empty() {
    self.factor_domain_default_gens(expressions)
  } else {
    self.literal_symbol_list(gens)
  }
}

///|
fn PolysRecipe::finite_extension_domain(
  self : PolysRecipe,
  modulus : Int,
  coefficients : Array[Int],
  gen : String,
) -> @recipe.ValueRef raise {
  if modulus == 0 {
    fail("gfext-modulus-missing")
  }
  if modulus <= 1 {
    fail("gfext-modulus")
  }
  let generator = self.literal_symbol(gen)
  let terms : Array[@recipe.RecipeArg] = []
  for index in 0..<coefficients.length() {
    let coefficient = self.call("sympy.Integer", [
      DecimalInt(Show::to_string(coefficients[index])),
    ])
    if index == 0 {
      terms.push(Ref(coefficient))
    } else {
      let power = self.call("sympy.Pow", [
        Ref(generator),
        DecimalInt(Show::to_string(index)),
      ])
      let term = self.call("sympy.Mul", [Ref(coefficient), Ref(power)])
      terms.push(Ref(term))
    }
  }
  let expression = self.call("sympy.Add", terms)
  let modulus_poly = self.call(
    "sympy.Poly",
    [Ref(expression), Ref(generator)],
    kwargs={ "modulus": DecimalInt(Show::to_string(modulus)) },
  )
  self.call("sympy.polys.agca.extensions.FiniteExtension", [Ref(modulus_poly)])
}

///|
fn PolysRecipe::factor_domain_poly(
  self : PolysRecipe,
  expression : @recipe.ValueRef,
  gens : @recipe.ValueRef,
  domain : @recipe.RecipeArg,
  modulus : Int,
  use_domain : Bool,
  use_modulus : Bool,
) -> @recipe.ValueRef raise {
  let callable = self.factor_domain_callable("_symbit_polys_p5a4_poly")
  self.builder.require_non_none(
    self.builder.call(callable, [
      Ref(expression),
      Ref(gens),
      domain,
      DecimalInt(Show::to_string(modulus)),
      Bool(use_domain),
      Bool(use_modulus),
    ]),
    message="sympy-call-none:sympy.Poly",
  )
}

///|
fn PolysRecipe::factor_domain_options(
  self : PolysRecipe,
  domain : String,
  modulus : Int,
  gfext_modulus : Array[Int],
  gfext_gen : String,
) -> (@recipe.RecipeArg, Bool, Bool) raise {
  if gfext_modulus.is_empty() {
    (Str(domain), domain != "", modulus != 0)
  } else {
    (
      Ref(self.finite_extension_domain(modulus, gfext_modulus, gfext_gen)),
      true,
      false,
    )
  }
}

///|
pub fn factor_list(
  expr : @symcore.Expr,
  modulus? : Int = 0,
  extension? : Array[String] = [],
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let recipe = PolysRecipe::new()
  let expression = recipe.expr(expr)
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if gfext_modulus.is_empty() {
    if modulus != 0 {
      kwargs["modulus"] = DecimalInt(Show::to_string(modulus))
    }
  } else {
    kwargs["domain"] = Ref(
      recipe.finite_extension_domain(modulus, gfext_modulus, gfext_gen),
    )
  }
  if !extension.is_empty() {
    let items : Array[@recipe.RecipeArg] = []
    for item in extension {
      items.push(Ref(recipe.call("sympy.sympify", [Str(item)])))
    }
    kwargs["extension"] = Ref(recipe.builder.list(items))
  }
  let result = recipe.call("sympy.factor_list", [Ref(expression)], kwargs~)
  recipe.request_factor_list_string(result, modulus)
}

///|
fn PolysRecipe::factor_domain_auto_poly(
  self : PolysRecipe,
  expression : @recipe.ValueRef,
  modulus : Int,
  domain? : @recipe.RecipeArg = Null,
  use_domain? : Bool = false,
) -> @recipe.ValueRef raise {
  let no_gens = self.builder.list([])
  self.factor_domain_poly(
    expression,
    no_gens,
    domain,
    modulus,
    use_domain,
    !use_domain && modulus != 0,
  )
}

///|
pub fn monic(expr : @symcore.Expr, modulus? : Int = 0) -> String raise {
  let recipe = PolysRecipe::new()
  let expression = recipe.expr(expr)
  let polynomial = recipe.factor_domain_auto_poly(expression, modulus)
  let monic_callable = recipe.builder.getattr(polynomial, "monic")
  let monic_poly = recipe.builder.require_non_none(
    recipe.builder.call(monic_callable, []),
    message="sympy-call-none:Poly.monic",
  )
  let as_expr = recipe.builder.getattr(monic_poly, "as_expr")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(as_expr, []),
    message="sympy-call-none:Poly.as_expr",
  )
  recipe.request_factor_domain_string(result)
}

///|
pub fn sqf_list(
  expr : @symcore.Expr,
  modulus? : Int = 0,
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let recipe = PolysRecipe::new()
  let expression = recipe.expr(expr)
  let result = if gfext_modulus.is_empty() {
    if modulus == 0 {
      recipe.call("sympy.sqf_list", [Ref(expression)])
    } else {
      let polynomial = recipe.factor_domain_auto_poly(expression, modulus)
      let sqf_callable = recipe.builder.getattr(polynomial, "sqf_list")
      recipe.builder.require_non_none(
        recipe.builder.call(sqf_callable, []),
        message="sympy-call-none:Poly.sqf_list",
      )
    }
  } else {
    let domain = recipe.finite_extension_domain(
      modulus, gfext_modulus, gfext_gen,
    )
    let polynomial = recipe.factor_domain_auto_poly(
      expression,
      modulus,
      domain=Ref(domain),
      use_domain=true,
    )
    let sqf_callable = recipe.builder.getattr(polynomial, "sqf_list")
    recipe.builder.require_non_none(
      recipe.builder.call(sqf_callable, []),
      message="sympy-call-none:Poly.sqf_list",
    )
  }
  recipe.request_factor_list_string(result, modulus)
}

///|
pub fn sqf_part(expr : @symcore.Expr) -> String raise {
  let recipe = PolysRecipe::new()
  let expression = recipe.expr(expr)
  let polynomial = recipe.factor_domain_auto_poly(expression, 0)
  let sqf_callable = recipe.builder.getattr(polynomial, "sqf_part")
  let sqf_poly = recipe.builder.require_non_none(
    recipe.builder.call(sqf_callable, []),
    message="sympy-call-none:Poly.sqf_part",
  )
  let as_expr = recipe.builder.getattr(sqf_poly, "as_expr")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(as_expr, []),
    message="sympy-call-none:Poly.as_expr",
  )
  recipe.request_factor_domain_string(result)
}

///|
pub fn gcd(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let recipe = PolysRecipe::new()
  let p_value = recipe.expr(p)
  let q_value = recipe.expr(q)
  let use_poly = !gens.is_empty() ||
    domain != "" ||
    modulus != 0 ||
    !gfext_modulus.is_empty()
  let result = if use_poly {
    let generator_list = recipe.factor_domain_gens([p_value, q_value], gens)
    let (domain_arg, use_domain, use_modulus) = recipe.factor_domain_options(
      domain, modulus, gfext_modulus, gfext_gen,
    )
    let p_poly = recipe.factor_domain_poly(
      p_value, generator_list, domain_arg, modulus, use_domain, use_modulus,
    )
    let q_poly = recipe.factor_domain_poly(
      q_value, generator_list, domain_arg, modulus, use_domain, use_modulus,
    )
    let gcd_callable = recipe.builder.getattr(p_poly, "gcd")
    recipe.builder.require_non_none(
      recipe.builder.call(gcd_callable, [Ref(q_poly)]),
      message="sympy-call-none:Poly.gcd",
    )
  } else {
    recipe.call("sympy.gcd", [Ref(p_value), Ref(q_value)])
  }
  recipe.request_factor_domain_string(result)
}

///|
pub fn resultant(
  p : @symcore.Expr,
  q : @symcore.Expr,
  x? : String = "",
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let recipe = PolysRecipe::new()
  let p_value = recipe.expr(p)
  let q_value = recipe.expr(q)
  let variable : @recipe.RecipeArg = if x == "" {
    Null
  } else {
    Ref(recipe.literal_symbol(x))
  }
  let generator_list = recipe.factor_domain_gens(
    if x == "" {
      [p_value, q_value]
    } else {
      let x_value = match variable {
        Ref(value) => value
        _ => fail("resultant-variable")
      }
      [p_value, q_value, x_value]
    },
    gens,
  )
  let gfext_coefficients : Array[@recipe.RecipeArg] = []
  for coefficient in gfext_modulus {
    gfext_coefficients.push(DecimalInt(Show::to_string(coefficient)))
  }
  let gfext_coefficients = recipe.builder.list(gfext_coefficients)
  let gfext_generator : @recipe.RecipeArg = if gfext_modulus.is_empty() {
    Null
  } else {
    Ref(recipe.literal_symbol(gfext_gen))
  }
  let callable = recipe.factor_domain_callable("_symbit_polys_p5a4_resultant")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(callable, [
      Ref(p_value),
      Ref(q_value),
      variable,
      Ref(generator_list),
      Str(domain),
      DecimalInt(Show::to_string(modulus)),
      Ref(gfext_coefficients),
      gfext_generator,
      Bool(domain != ""),
      Bool(modulus != 0),
      Bool(!gfext_modulus.is_empty()),
    ]),
    message="sympy-call-none:resultant",
  )
  recipe.request_factor_domain_string(result)
}

///|
pub fn div(
  p : @symcore.Expr,
  q : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
  gfext_modulus? : Array[Int] = [],
  gfext_gen? : String = "a",
) -> String raise {
  let recipe = PolysRecipe::new()
  let p_value = recipe.expr(p)
  let q_value = recipe.expr(q)
  let use_poly = !gens.is_empty() ||
    domain != "" ||
    modulus != 0 ||
    !gfext_modulus.is_empty()
  let result = if use_poly {
    let generator_list = recipe.factor_domain_gens([p_value, q_value], gens)
    let (domain_arg, use_domain, use_modulus) = recipe.factor_domain_options(
      domain, modulus, gfext_modulus, gfext_gen,
    )
    let p_poly = recipe.factor_domain_poly(
      p_value, generator_list, domain_arg, modulus, use_domain, use_modulus,
    )
    let q_poly = recipe.factor_domain_poly(
      q_value, generator_list, domain_arg, modulus, use_domain, use_modulus,
    )
    let div_callable = recipe.builder.getattr(p_poly, "div")
    recipe.builder.require_non_none(
      recipe.builder.call(div_callable, [Ref(q_poly)]),
      message="sympy-call-none:Poly.div",
    )
  } else {
    recipe.call("sympy.div", [Ref(p_value), Ref(q_value)])
  }
  recipe.request_factor_domain_pair(result)
}

///|
fn factor_domain_list_front(
  polys : Array[@symcore.Expr],
  gens : Array[String],
  domain : String,
  modulus : Int,
  path : String,
) -> String raise {
  let recipe = PolysRecipe::new()
  let args : Array[@recipe.RecipeArg] = [Ref(recipe.expression_list(polys))]
  for generator in recipe.literal_symbols(gens) {
    args.push(generator)
  }
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  if domain != "" {
    kwargs["domain"] = Str(domain)
  }
  if modulus != 0 {
    kwargs["modulus"] = DecimalInt(Show::to_string(modulus))
  }
  let result = recipe.call(path, args, kwargs~)
  recipe.request_factor_domain_string(result)
}

///|
pub fn gcd_list(
  polys : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  factor_domain_list_front(
    polys, gens, domain, modulus, "sympy.polys.polytools.gcd_list",
  )
}

///|
pub fn lcm_list(
  polys : Array[@symcore.Expr],
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  factor_domain_list_front(
    polys, gens, domain, modulus, "sympy.polys.polytools.lcm_list",
  )
}

///|
pub fn terms_gcd(
  expr : @symcore.Expr,
  gens? : Array[String] = [],
  domain? : String = "",
  modulus? : Int = 0,
) -> String raise {
  let recipe = PolysRecipe::new()
  let expression = recipe.expr(expr)
  let generator_list = recipe.factor_domain_gens([expression], gens)
  let polynomial = recipe.factor_domain_poly(
    expression,
    generator_list,
    Str(domain),
    modulus,
    domain != "",
    modulus != 0,
  )
  let callable = recipe.factor_domain_callable("_symbit_polys_p5a4_terms_gcd")
  let result = recipe.builder.require_non_none(
    recipe.builder.call(callable, [Ref(polynomial)]),
    message="sympy-call-none:Poly.terms_gcd",
  )
  recipe.request_factor_domain_string(result)
}
