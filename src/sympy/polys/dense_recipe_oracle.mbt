///|
fn dense_foundation_source() -> String {
  (
    #|def _symbit_dense_text(value):
    #|    if isinstance(value, list):
    #|        return "[" + ",".join(_symbit_dense_text(item) for item in value) + "]"
    #|    if isinstance(value, tuple):
    #|        return "(" + ",".join(_symbit_dense_text(item) for item in value) + ")"
    #|    return str(value).replace(" ", "")
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
}

///|
priv struct DenseRecipe {
  builder : @recipe.Builder
  sympy : @recipe.ValueRef
  domain : @recipe.ValueRef
  domain_convert : @recipe.ValueRef
  render_dense : @recipe.ValueRef
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
  { builder, sympy, domain, domain_convert, render_dense }
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
  }
}
