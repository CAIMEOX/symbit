///|
fn linsolve_recipe_source() -> String {
  (
    #|def _symbit_linsolve_dict_summary(value, syms):
    #|    values = {str(key): str(item) for key, item in value.items()}
    #|    return ",".join(
    #|        name + ":" + values[name] for name in syms if name in values
    #|    )
    #|
    #|def _symbit_linsolve_dense_summary(matrix):
    #|    if matrix is None:
    #|        raise ValueError("linsolve-sympy-dict-to-dm-none")
    #|    dense = matrix.to_ddm()
    #|    if dense is None:
    #|        raise ValueError("linsolve-sympy-dict-to-dm-dense-none")
    #|    return str(dense) + "@" + str(matrix.domain) + "|sparse"
    #|
    #|def _symbit_solvers_matrix_summary(matrix):
    #|    if matrix is None:
    #|        raise ValueError("solvers-eqs-to-matrix-none")
    #|    dense = matrix.to_Matrix()
    #|    if dense is None:
    #|        raise ValueError("solvers-eqs-to-matrix-dense-none")
    #|    return str(dense) + "@" + str(matrix.domain)
    #|
    #|def _symbit_linsolve_tuple(value, message):
    #|    if not isinstance(value, (list, tuple)) or len(value) < 2:
    #|        raise ValueError(message)
    #|    return value
    #|
    #|def _symbit_solvers_ring_summary(value):
    #|    result = _symbit_linsolve_tuple(
    #|        value, "solvers-sympy-eqs-to-ring"
    #|    )
    #|    return str(result[0]) + "||" + str(result[1])
    #|
    #|def _symbit_linsolve_linear_dict_summary(value, syms):
    #|    result = _symbit_linsolve_tuple(
    #|        value, "linsolve-linear-eq-to-dict"
    #|    )
    #|    coefficients = result[0]
    #|    independent = result[1]
    #|    return "|".join(
    #|        _symbit_linsolve_dict_summary(row, syms)
    #|        + "||"
    #|        + str(independent[index])
    #|        for index, row in enumerate(coefficients)
    #|    )
    #|
    #|def _symbit_linsolve_internal_summary(value, syms):
    #|    if value is None:
    #|        return "None"
    #|    present = _symbit_linsolve_dict_summary(value, syms)
    #|    if not present:
    #|        return "|".join(name + ":0" for name in syms)
    #|    values = {str(key): str(item) for key, item in value.items()}
    #|    return "|".join(
    #|        name + ":" + values.get(name, "0") for name in syms
    #|    )
    #|
    #|def _symbit_solvers_solve_summary(value, syms):
    #|    if value is None:
    #|        return "None"
    #|    return _symbit_linsolve_dict_summary(value, syms)
  )
}

///|
priv struct LinSolveRecipe {
  domain_recipe : DomainRecipe
  linsolve_module : @recipe.ValueRef
  solvers_module : @recipe.ValueRef
  dense_renderer : @recipe.ValueRef
  matrix_renderer : @recipe.ValueRef
  pair_checker : @recipe.ValueRef
  ring_renderer : @recipe.ValueRef
  linear_dict_renderer : @recipe.ValueRef
  internal_renderer : @recipe.ValueRef
  solve_renderer : @recipe.ValueRef
}

///|
fn LinSolveRecipe::new() -> LinSolveRecipe raise {
  let domain_recipe = DomainRecipe::new()
  let builder = domain_recipe.builder
  let linsolve_module = builder.import_module("sympy.polys.matrices.linsolve")
  let solvers_module = builder.import_module("sympy.polys.solvers")
  let scope = builder.exec(domain_recipe.scope, linsolve_recipe_source())
  {
    domain_recipe,
    linsolve_module,
    solvers_module,
    dense_renderer: builder.getitem(
      scope,
      Str("_symbit_linsolve_dense_summary"),
    ),
    matrix_renderer: builder.getitem(
      scope,
      Str("_symbit_solvers_matrix_summary"),
    ),
    pair_checker: builder.getitem(scope, Str("_symbit_linsolve_tuple")),
    ring_renderer: builder.getitem(scope, Str("_symbit_solvers_ring_summary")),
    linear_dict_renderer: builder.getitem(
      scope,
      Str("_symbit_linsolve_linear_dict_summary"),
    ),
    internal_renderer: builder.getitem(
      scope,
      Str("_symbit_linsolve_internal_summary"),
    ),
    solve_renderer: builder.getitem(scope, Str("_symbit_solvers_solve_summary")),
  }
}

///|
fn LinSolveRecipe::require_pair(
  self : LinSolveRecipe,
  value : @recipe.ValueRef,
  message : String,
) -> @recipe.ValueRef raise {
  self.domain_recipe.builder.call(self.pair_checker, [Ref(value), Str(message)])
}

///|
fn LinSolveRecipe::string_list(
  self : LinSolveRecipe,
  values : Array[String],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(Str(value))
  }
  self.domain_recipe.builder.list(items)
}

///|
fn LinSolveRecipe::expressions(
  self : LinSolveRecipe,
  sources : Array[String],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for source in sources {
    items.push(Ref(self.domain_recipe.sympify(source)))
  }
  self.domain_recipe.builder.list(items)
}

///|
fn LinSolveRecipe::symbols(
  self : LinSolveRecipe,
  names : Array[String],
) -> (@recipe.ValueRef, @recipe.ValueRef) raise {
  let list_items : Array[@recipe.RecipeArg] = []
  let lookup_items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
  for name in names {
    let symbol = self.domain_recipe.symbol(name)
    list_items.push(Ref(symbol))
    lookup_items.push((Str(name), Ref(symbol)))
  }
  (
    self.domain_recipe.builder.list(list_items),
    self.domain_recipe.builder.dict(lookup_items),
  )
}

///|
fn LinSolveRecipe::sympified_rows(
  self : LinSolveRecipe,
  rows : Array[Map[String, String]],
) -> @recipe.ValueRef raise {
  let result : Array[@recipe.RecipeArg] = []
  for row in rows {
    let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
    for symbol, coefficient in row {
      items.push((Str(symbol), Ref(self.domain_recipe.sympify(coefficient))))
    }
    result.push(Ref(self.domain_recipe.builder.dict(items)))
  }
  self.domain_recipe.builder.list(result)
}

///|
fn LinSolveRecipe::converted(
  self : LinSolveRecipe,
  convert : @recipe.ValueRef,
  source : String,
) -> @recipe.ValueRef raise {
  let expression = self.domain_recipe.sympify(source)
  let result = self.domain_recipe.builder.call(convert, [Ref(expression)])
  self.domain_recipe.builder.require_non_none(
    result,
    message="solvers-eqs-to-matrix-convert-none",
  )
}

///|
fn LinSolveRecipe::converted_rows(
  self : LinSolveRecipe,
  rows : Array[Map[String, String]],
  symbol_lookup : @recipe.ValueRef,
  convert : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let result : Array[@recipe.RecipeArg] = []
  for row in rows {
    let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
    for symbol, coefficient in row {
      let symbol_ref = self.domain_recipe.builder.getitem(
        symbol_lookup,
        Str(symbol),
      )
      items.push((Ref(symbol_ref), Ref(self.converted(convert, coefficient))))
    }
    result.push(Ref(self.domain_recipe.builder.dict(items)))
  }
  self.domain_recipe.builder.list(result)
}

///|
fn LinSolveRecipe::converted_values(
  self : LinSolveRecipe,
  values : Array[String],
  convert : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let result : Array[@recipe.RecipeArg] = []
  for value in values {
    result.push(Ref(self.converted(convert, value)))
  }
  self.domain_recipe.builder.list(result)
}

///|
fn LinSolveRecipe::call_linsolve(
  self : LinSolveRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
  allow_none? : Bool = false,
) -> @recipe.ValueRef raise {
  let callable = self.domain_recipe.builder.getattr(self.linsolve_module, name)
  let result = self.domain_recipe.builder.call(callable, args)
  if allow_none {
    result
  } else {
    self.domain_recipe.builder.require_non_none(
      result,
      message="linsolve-call-none:" + name,
    )
  }
}

///|
fn LinSolveRecipe::call_solvers(
  self : LinSolveRecipe,
  name : String,
  args : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
  allow_none? : Bool = false,
) -> @recipe.ValueRef raise {
  let callable = self.domain_recipe.builder.getattr(self.solvers_module, name)
  let result = self.domain_recipe.builder.call(callable, args, kwargs~)
  if allow_none {
    result
  } else {
    self.domain_recipe.builder.require_non_none(
      result,
      message="solvers-call-none:" + name,
    )
  }
}

///|
fn LinSolveRecipe::render(
  self : LinSolveRecipe,
  renderer : @recipe.ValueRef,
  value : @recipe.ValueRef,
  syms? : Array[String] = [],
  with_syms? : Bool = false,
) -> @recipe.ValueRef raise {
  if with_syms {
    let names = self.string_list(syms)
    self.domain_recipe.builder.call(renderer, [Ref(value), Ref(names)])
  } else {
    self.domain_recipe.builder.call(renderer, [Ref(value)])
  }
}

///|
fn LinSolveRecipe::request_str(
  self : LinSolveRecipe,
  result : @recipe.ValueRef,
) -> String raise {
  self.domain_recipe.builder.request_str(result)
}
