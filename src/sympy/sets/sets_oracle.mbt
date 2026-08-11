///|
/// Oracle helpers for SymPy sets.

///|
fn sympy_set_singleton(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  name : String,
) -> @recipe.ValueRef raise {
  let singletons = builder.getattr(sympy, "S")
  builder.getattr(singletons, name)
}

///|
fn sympy_set_call(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let callable = builder.getattr(sympy, name)
  builder.require_non_none(
    builder.call(callable, args),
    message="sympy-call-none:sympy.\{name}",
  )
}

///|
fn bool_expr_to_recipe(
  builder : @recipe.Builder,
  sympy : @recipe.ValueRef,
  expr : @symlogic.BoolExpr,
) -> @recipe.ValueRef raise {
  let sympify = builder.getattr(sympy, "sympify")
  builder.require_non_none(
    builder.call(sympify, [Str(@symlogic.to_string(expr))]),
    message="sympy-call-none:sympy.sympify",
  )
}

///|
fn set_to_recipe(
  builder : @recipe.Builder,
  encoder : @exprcodec.Encoder,
  sympy : @recipe.ValueRef,
  set : @symsets.Set,
) -> @recipe.ValueRef raise {
  match set {
    EmptySet => sympy_set_singleton(builder, sympy, "EmptySet")
    UniversalSet => sympy_set_singleton(builder, sympy, "UniversalSet")
    Naturals => sympy_set_singleton(builder, sympy, "Naturals")
    Naturals0 => sympy_set_singleton(builder, sympy, "Naturals0")
    Integers => sympy_set_singleton(builder, sympy, "Integers")
    Rationals => sympy_set_singleton(builder, sympy, "Rationals")
    Reals => sympy_set_singleton(builder, sympy, "Reals")
    Complexes => sympy_set_singleton(builder, sympy, "Complexes")
    FiniteSet(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(encoder.encode(item)))
      }
      sympy_set_call(builder, sympy, "FiniteSet", args)
    }
    Interval(left~, right~, left_open~, right_open~) =>
      sympy_set_call(builder, sympy, "Interval", [
        Ref(encoder.encode(left)),
        Ref(encoder.encode(right)),
        Bool(left_open),
        Bool(right_open),
      ])
    ConditionSet(symbol~, condition~, base~) =>
      sympy_set_call(builder, sympy, "ConditionSet", [
        Ref(encoder.encode(symbol)),
        Ref(bool_expr_to_recipe(builder, sympy, condition)),
        Ref(set_to_recipe(builder, encoder, sympy, base)),
      ])
    ImageSet(symbol~, expr~, base~) => {
      let lambda = sympy_set_call(builder, sympy, "Lambda", [
        Ref(encoder.encode(symbol)),
        Ref(encoder.encode(expr)),
      ])
      sympy_set_call(builder, sympy, "ImageSet", [
        Ref(lambda),
        Ref(set_to_recipe(builder, encoder, sympy, base)),
      ])
    }
    ProductSet(items) => {
      let args : Array[@recipe.RecipeArg] = []
      for item in items {
        args.push(Ref(set_to_recipe(builder, encoder, sympy, item)))
      }
      sympy_set_call(builder, sympy, "ProductSet", args)
    }
    Union(items) =>
      if items.is_empty() {
        sympy_set_singleton(builder, sympy, "EmptySet")
      } else {
        let args : Array[@recipe.RecipeArg] = []
        for item in items {
          args.push(Ref(set_to_recipe(builder, encoder, sympy, item)))
        }
        sympy_set_call(builder, sympy, "Union", args)
      }
    Intersection(items) =>
      if items.is_empty() {
        sympy_set_singleton(builder, sympy, "UniversalSet")
      } else {
        let args : Array[@recipe.RecipeArg] = []
        for item in items {
          args.push(Ref(set_to_recipe(builder, encoder, sympy, item)))
        }
        sympy_set_call(builder, sympy, "Intersection", args)
      }
    Complement(a, b) =>
      sympy_set_call(builder, sympy, "Complement", [
        Ref(set_to_recipe(builder, encoder, sympy, a)),
        Ref(set_to_recipe(builder, encoder, sympy, b)),
      ])
  }
}

///|
fn set_request_str(
  operation : String,
  sets : Array[@symsets.Set],
) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = if sets.is_empty() {
    let singleton = if operation == "Union" {
      "EmptySet"
    } else {
      "UniversalSet"
    }
    sympy_set_singleton(builder, sympy, singleton)
  } else {
    let args : Array[@recipe.RecipeArg] = []
    for set in sets {
      args.push(Ref(set_to_recipe(builder, encoder, sympy, set)))
    }
    sympy_set_call(builder, sympy, operation, args)
  }
  builder.request_str(value)
}

///|
pub fn set_str(set : @symsets.Set) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = set_to_recipe(builder, encoder, sympy, set)
  builder.request_str(value)
}

///|
pub fn union_str(sets : Array[@symsets.Set]) -> String raise {
  set_request_str("Union", sets)
}

///|
pub fn intersection_str(sets : Array[@symsets.Set]) -> String raise {
  set_request_str("Intersection", sets)
}

///|
pub fn complement_str(a : @symsets.Set, b : @symsets.Set) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = sympy_set_call(builder, sympy, "Complement", [
    Ref(set_to_recipe(builder, encoder, sympy, a)),
    Ref(set_to_recipe(builder, encoder, sympy, b)),
  ])
  builder.request_str(value)
}

///|
pub fn contains_str(set : @symsets.Set, elem : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let encoder = @exprcodec.Encoder::new(builder)
  let sympy = builder.import_module("sympy")
  let value = sympy_set_call(builder, sympy, "Contains", [
    Ref(encoder.encode(elem)),
    Ref(set_to_recipe(builder, encoder, sympy, set)),
  ])
  builder.request_str(value)
}
