///|
fn dense_foundation_source() -> String {
  (
    #|def _symbit_dense_text(value):
    #|    if isinstance(value, list):
    #|        return "[" + ",".join(_symbit_dense_text(item) for item in value) + "]"
    #|    if isinstance(value, tuple):
    #|        return "(" + ",".join(_symbit_dense_text(item) for item in value) + ")"
    #|    return str(value).replace(" ", "")
    #|
    #|def _symbit_dense_repr_text(value):
    #|    if isinstance(value, list):
    #|        return "[" + ",".join(_symbit_dense_repr_text(item) for item in value) + "]"
    #|    if isinstance(value, tuple):
    #|        return "(" + ",".join(_symbit_dense_repr_text(item) for item in value) + ")"
    #|    return repr(value).replace(" ", "")
    #|
    #|def _symbit_algebraic_dense_text(value, domain):
    #|    if isinstance(value, list):
    #|        return "[" + ",".join(
    #|            _symbit_algebraic_dense_text(item, domain) for item in value
    #|        ) + "]"
    #|    if isinstance(value, tuple):
    #|        return "(" + ",".join(
    #|            _symbit_algebraic_dense_text(item, domain) for item in value
    #|        ) + ")"
    #|    try:
    #|        value = domain.to_sympy(value)
    #|    except (AttributeError, TypeError, ValueError):
    #|        pass
    #|    return str(value).replace(" ", "")
    #|
    #|def _symbit_ext_factor_shape(value):
    #|    coefficient, factor_pairs = value
    #|    parts = [
    #|        "(" + str(len(factor)) + "," + str(multiplicity) + ")"
    #|        for factor, multiplicity in factor_pairs
    #|    ]
    #|    return (
    #|        "(" + str(coefficient).replace(" ", "") + ",[" +
    #|        ",".join(parts) + "])"
    #|    )
  )
}

///|
priv enum DenseCallArg {
  DomainNumber(@symnum.BigRational)
  RawNumber(@symnum.BigRational)
  DupCoeffs(Array[@symnum.BigRational])
  RawDupCoeffs(Array[@symnum.BigRational])
  DenseValue(DenseData)
  RawDenseValue(DenseData)
  DupCollection(Array[Array[@symnum.BigRational]])
  DenseCollection(Array[DenseData])
  DenseFactorPairs(Array[(DenseData, Int)])
  DomainIntCoeffs(Array[Int])
  CallIntDict(Map[Int, Int])
  CallIntMatrix(Array[Array[Int]])
  FactorPowersWithLeadingCoefficient(Array[(Array[Int], Int)], Int)
  CallInt(Int)
  CallIntList(Array[Int])
  CallStr(String)
  CallBool(Bool)
  FromSympyExprs(Array[String])
  DomainObject
}

///|
priv enum DenseResultKind {
  DenseResult
  ScalarResult
  DenseReprResult
  AlgebraicDenseResult
  ExtFactorShapeResult
}

///|
priv struct DenseRecipe {
  builder : @recipe.Builder
  sympy : @recipe.ValueRef
  domain : @recipe.ValueRef
  domain_convert : @recipe.ValueRef
  render_dense : @recipe.ValueRef
  render_dense_repr : @recipe.ValueRef
  render_algebraic_dense : @recipe.ValueRef
  render_ext_factor_shape : @recipe.ValueRef
}

///|
fn DenseRecipe::new(domain_spec : String) -> DenseRecipe raise {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let scope = builder.exec(builder.sympy_scope(), domain_foundation_source())
  let scope = builder.exec(scope, dense_foundation_source())
  let parse_domain = builder.getitem(scope, Str("_symbit_domain_spec"))
  let domain = builder.require_non_none(
    builder.call(parse_domain, [Str(domain_spec)]),
    message="sympy-polys-dense-domain-none",
  )
  let domain_convert = builder.getattr(domain, "convert")
  let render_dense = builder.getitem(scope, Str("_symbit_dense_text"))
  let render_dense_repr = builder.getitem(scope, Str("_symbit_dense_repr_text"))
  let render_algebraic_dense = builder.getitem(
    scope,
    Str("_symbit_algebraic_dense_text"),
  )
  let render_ext_factor_shape = builder.getitem(
    scope,
    Str("_symbit_ext_factor_shape"),
  )
  {
    builder,
    sympy,
    domain,
    domain_convert,
    render_dense,
    render_dense_repr,
    render_algebraic_dense,
    render_ext_factor_shape,
  }
}

///|
fn DenseRecipe::raw_number(
  self : DenseRecipe,
  value : @symnum.BigRational,
) -> @recipe.ValueRef raise {
  if value.is_integral() {
    let integer = self.builder.getattr(self.sympy, "Integer")
    self.builder.require_non_none(
      self.builder.call(integer, [Str(value.numerator().to_string())]),
      message="sympy-polys-dense-integer-none",
    )
  } else {
    let rational = self.builder.getattr(self.sympy, "Rational")
    self.builder.require_non_none(
      self.builder.call(rational, [
        Str(value.numerator().to_string()),
        Str(value.denominator().to_string()),
      ]),
      message="sympy-polys-dense-rational-none",
    )
  }
}

///|
fn DenseRecipe::domain_number(
  self : DenseRecipe,
  value : @symnum.BigRational,
) -> @recipe.ValueRef raise {
  let raw = self.raw_number(value)
  self.builder.require_non_none(
    self.builder.call(self.domain_convert, [Ref(raw)]),
    message="sympy-polys-dense-domain-convert-none",
  )
}

///|
fn DenseRecipe::dup_coeffs(
  self : DenseRecipe,
  coeffs : Array[@symnum.BigRational],
  raw : Bool,
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for coefficient in coeffs {
    let value = if raw {
      self.raw_number(coefficient)
    } else {
      self.domain_number(coefficient)
    }
    items.push(Ref(value))
  }
  self.builder.list(items)
}

///|
fn DenseRecipe::dense_value(
  self : DenseRecipe,
  value : DenseData,
  raw? : Bool = false,
) -> @recipe.ValueRef raise {
  match value {
    Coef(coefficient) =>
      if raw {
        self.raw_number(coefficient)
      } else {
        self.domain_number(coefficient)
      }
    Poly(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for item in values {
        items.push(Ref(self.dense_value(item, raw~)))
      }
      self.builder.list(items)
    }
  }
}

///|
fn DenseRecipe::from_sympy_exprs(
  self : DenseRecipe,
  expressions : Array[String],
) -> @recipe.ValueRef raise {
  let sympify = self.builder.getattr(self.sympy, "sympify")
  let from_sympy = self.builder.getattr(self.domain, "from_sympy")
  let items : Array[@recipe.RecipeArg] = []
  for source in expressions {
    let expression = self.builder.require_non_none(
      self.builder.call(sympify, [Str(source)]),
      message="sympy-polys-dense-sympify-none",
    )
    let coefficient = self.builder.require_non_none(
      self.builder.call(from_sympy, [Ref(expression)]),
      message="sympy-polys-dense-from-sympy-none",
    )
    items.push(Ref(coefficient))
  }
  self.builder.list(items)
}

///|
fn DenseRecipe::materialize(
  self : DenseRecipe,
  argument : DenseCallArg,
) -> @recipe.RecipeArg raise {
  match argument {
    DomainNumber(value) => Ref(self.domain_number(value))
    RawNumber(value) => Ref(self.raw_number(value))
    DupCoeffs(values) => Ref(self.dup_coeffs(values, false))
    RawDupCoeffs(values) => Ref(self.dup_coeffs(values, true))
    DenseValue(value) => Ref(self.dense_value(value))
    RawDenseValue(value) => Ref(self.dense_value(value, raw=true))
    DupCollection(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(Ref(self.dup_coeffs(value, false)))
      }
      Ref(self.builder.list(items))
    }
    DenseCollection(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(Ref(self.dense_value(value)))
      }
      Ref(self.builder.list(items))
    }
    DenseFactorPairs(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        let pair = self.builder.tuple([
          Ref(self.dense_value(value.0)),
          DecimalInt(Show::to_string(value.1)),
        ])
        items.push(Ref(pair))
      }
      Ref(self.builder.list(items))
    }
    DomainIntCoeffs(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(
          Ref(self.domain_number(@symnum.BigRational::from_int(value))),
        )
      }
      Ref(self.builder.list(items))
    }
    CallIntDict(values) => {
      let items : Array[(@recipe.RecipeArg, @recipe.RecipeArg)] = []
      for key, value in values {
        items.push(
          (DecimalInt(Show::to_string(key)), DecimalInt(Show::to_string(value))),
        )
      }
      Ref(self.builder.dict(items))
    }
    CallIntMatrix(values) => {
      let rows : Array[@recipe.RecipeArg] = []
      for row in values {
        let items : Array[@recipe.RecipeArg] = []
        for value in row {
          items.push(DecimalInt(Show::to_string(value)))
        }
        rows.push(Ref(self.builder.list(items)))
      }
      Ref(self.builder.list(rows))
    }
    FactorPowersWithLeadingCoefficient(values, leading_coefficient) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        let coefficients : Array[@recipe.RecipeArg] = []
        for coefficient in value.0 {
          coefficients.push(DecimalInt(Show::to_string(coefficient)))
        }
        let pair = self.builder.tuple([
          Ref(self.builder.list(coefficients)),
          DecimalInt(Show::to_string(value.1)),
        ])
        items.push(Ref(pair))
      }
      let factors = self.builder.list(items)
      if leading_coefficient == 1 {
        Ref(factors)
      } else {
        Ref(
          self.builder.tuple([
            DecimalInt(Show::to_string(leading_coefficient)),
            Ref(factors),
          ]),
        )
      }
    }
    CallInt(value) => DecimalInt(Show::to_string(value))
    CallIntList(values) => {
      let items : Array[@recipe.RecipeArg] = []
      for value in values {
        items.push(DecimalInt(Show::to_string(value)))
      }
      Ref(self.builder.list(items))
    }
    CallStr(value) => Str(value)
    CallBool(value) => Bool(value)
    FromSympyExprs(values) => Ref(self.from_sympy_exprs(values))
    DomainObject => Ref(self.domain)
  }
}

///|
fn DenseRecipe::call(
  self : DenseRecipe,
  path : String,
  args : Array[DenseCallArg],
  kwargs? : Map[String, DenseCallArg] = {},
) -> @recipe.ValueRef raise {
  let materialized : Array[@recipe.RecipeArg] = []
  for argument in args {
    materialized.push(self.materialize(argument))
  }
  let materialized_kwargs : Map[String, @recipe.RecipeArg] = Map([])
  for name, argument in kwargs {
    materialized_kwargs[name] = self.materialize(argument)
  }
  let callable = recipe_sympy_callable(self.builder, path)
  self.builder.require_non_none(
    self.builder.call(callable, materialized, kwargs=materialized_kwargs),
    message="sympy-call-none:" + path,
  )
}

///|
fn DenseRecipe::request_dense(
  self : DenseRecipe,
  value : @recipe.ValueRef,
) -> String raise {
  let rendered = self.builder.require_non_none(
    self.builder.call(self.render_dense, [Ref(value)]),
    message="sympy-polys-dense-render-none",
  )
  self.builder.request_str(rendered)
}

///|
fn dense_recipe_call(
  path : String,
  args : Array[DenseCallArg],
  domain : String,
  kwargs? : Map[String, DenseCallArg] = {},
  result_kind? : DenseResultKind = DenseResult,
) -> String raise {
  let recipe = DenseRecipe::new(domain)
  let result = recipe.call(path, args, kwargs~)
  match result_kind {
    DenseResult => recipe.request_dense(result)
    ScalarResult => recipe.builder.request_str(result)
    DenseReprResult => {
      let rendered = recipe.builder.require_non_none(
        recipe.builder.call(recipe.render_dense_repr, [Ref(result)]),
        message="sympy-polys-dense-repr-render-none",
      )
      recipe.builder.request_str(rendered)
    }
    AlgebraicDenseResult => {
      let rendered = recipe.builder.require_non_none(
        recipe.builder.call(recipe.render_algebraic_dense, [
          Ref(result),
          Ref(recipe.domain),
        ]),
        message="sympy-polys-algebraic-dense-render-none",
      )
      recipe.builder.request_str(rendered)
    }
    ExtFactorShapeResult => {
      let rendered = recipe.builder.require_non_none(
        recipe.builder.call(recipe.render_ext_factor_shape, [Ref(result)]),
        message="sympy-polys-ext-factor-render-none",
      )
      recipe.builder.request_str(rendered)
    }
  }
}

///|
fn dense_recipe_bool_call(
  path : String,
  args : Array[DenseCallArg],
  domain : String,
) -> Bool raise {
  let recipe = DenseRecipe::new(domain)
  let result = recipe.call(path, args)
  recipe.builder.request_bool(result)
}
