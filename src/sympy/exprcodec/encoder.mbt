///|
/// Stateful encoder for placing one or more Symbit expressions into a single
/// recipe. Keeping the encoder alive preserves Python identity for repeated
/// `Dummy` and structurally identical `Wild` atoms.
pub struct Encoder {
  builder : @recipe.Builder
  sympy : @recipe.ValueRef
  dummy_cache : Map[Int, (String, @recipe.ValueRef)]
  wild_cache : Map[@symcore.Expr, @recipe.ValueRef]
}

///|
/// Expression encoding failures detected before a worker request is sent.
pub(all) suberror ExprCodecError {
  DummyIdConflict(Int, String, String)
}

///|
/// Create an expression encoder tied to `builder`.
pub fn Encoder::new(builder : @recipe.Builder) -> Encoder raise {
  {
    builder,
    sympy: builder.import_module("sympy"),
    dummy_cache: Map([]),
    wild_cache: Map([]),
  }
}

///|
/// Encode one Symbit expression as a value in `builder`'s recipe.
///
/// Use a shared `Encoder` when several expressions must share `Dummy` or
/// `Wild` identity. For a single expression, `encode_expr` is the compact
/// front door.
pub fn Encoder::encode(
  self : Encoder,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  // Re-validating a cached request-owned reference is allocation-free, and
  // makes cached atom hits reject a builder that has already been sealed.
  self.builder.value(Ref(self.sympy)) |> ignore
  self.encode_normalized(@symcore.normalize_legacy_expr(expression))
}

///|
/// Encode one Symbit expression into a recipe value.
pub fn encode_expr(
  builder : @recipe.Builder,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  Encoder::new(builder).encode(expression)
}

///|
fn Encoder::sympy_attr(self : Encoder, name : String) -> @recipe.ValueRef raise {
  self.builder.getattr(self.sympy, name)
}

///|
fn Encoder::sympy_call(
  self : Encoder,
  name : String,
  arguments : Array[@recipe.RecipeArg],
  kwargs? : Map[String, @recipe.RecipeArg] = {},
) -> @recipe.ValueRef raise {
  let callable = self.sympy_attr(name)
  self.builder.call(callable, arguments, kwargs~)
}

///|
fn Encoder::singleton(self : Encoder, name : String) -> @recipe.ValueRef raise {
  let registry = self.sympy_attr("S")
  self.builder.getattr(registry, name)
}

///|
fn decimal_digits(precision : Int) -> Int {
  let digits = (precision.to_double() / 3.3219280948873626 - 0.5).to_int()
  if digits > 1 {
    digits
  } else {
    1
  }
}

///|
fn Encoder::encode_number(
  self : Encoder,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  match @symcore.exact_number_num_den(expression) {
    Some((numerator, denominator)) => {
      let numerator = Show::to_string(numerator)
      let denominator = Show::to_string(denominator)
      if denominator == "1" {
        self.sympy_call("Integer", [Str(numerator)])
      } else {
        self.sympy_call("Rational", [Str(numerator), Str(denominator)])
      }
    }
    None => fail("exprcodec-number-parts")
  }
}

///|
fn Encoder::encode_float(
  self : Encoder,
  value : @symcore.Float,
) -> @recipe.ValueRef raise {
  let dps = decimal_digits(value.precision())
  self.sympy_call("Float", [
    Str(value.format(dps~)),
    DecimalInt(Show::to_string(dps)),
  ])
}

///|
fn Encoder::encode_complex_float(
  self : Encoder,
  value : @symcore.ComplexFloat,
) -> @recipe.ValueRef raise {
  let real = value.real_part()
  let imaginary = value.imag_part()
  let zero = @symcore.Float::from_int(0, prec=value.precision())
  if imaginary == zero {
    return self.encode_float(real)
  }
  let imaginary_value = self.encode_float(imaginary)
  let imaginary_unit = self.singleton("ImaginaryUnit")
  let imaginary_term = self.sympy_call("Mul", [
    Ref(imaginary_value),
    Ref(imaginary_unit),
  ])
  if real == zero {
    imaginary_term
  } else {
    let real_value = self.encode_float(real)
    self.sympy_call("Add", [Ref(real_value), Ref(imaginary_term)])
  }
}

///|
fn Encoder::encode_number_symbol(
  self : Encoder,
  kind : @symcore.NumberSymbolKind,
) -> @recipe.ValueRef raise {
  let singleton_name = match kind {
    ImaginaryUnit => "ImaginaryUnit"
    Pi => "Pi"
    Exp1 => "Exp1"
    EulerGamma => "EulerGamma"
    GoldenRatio => "GoldenRatio"
    Catalan => "Catalan"
    Infinity => "Infinity"
    NegativeInfinity => "NegativeInfinity"
    ComplexInfinity => "ComplexInfinity"
    NaN => "NaN"
  }
  self.singleton(singleton_name)
}

///|
fn is_singleton_set_name(name : String) -> Bool {
  match name {
    "EmptySet"
    | "UniversalSet"
    | "Naturals"
    | "Naturals0"
    | "Integers"
    | "Rationals"
    | "Reals"
    | "Complexes" => true
    _ => false
  }
}

///|
fn Encoder::encode_symbol(
  self : Encoder,
  name : String,
) -> @recipe.ValueRef raise {
  let symbol = self.sympy_call("Symbol", [Str(name)])
  if is_singleton_set_name(name) {
    self.builder.getattr_or(self.sympy, name, symbol)
  } else {
    symbol
  }
}

///|
fn Encoder::encode_dummy(
  self : Encoder,
  name : String,
  id : Int,
) -> @recipe.ValueRef raise {
  match self.dummy_cache.get(id) {
    Some((cached_name, value)) =>
      if cached_name == name {
        value
      } else {
        raise ExprCodecError::DummyIdConflict(id, cached_name, name)
      }
    None => {
      let value = self.sympy_call("Dummy", [Str(name)])
      self.dummy_cache[id] = (name, value)
      value
    }
  }
}

///|
fn wild_property_attr(property : @symcore.WildProperty) -> String {
  match property {
    Symbol => "is_Symbol"
    Integer => "is_integer"
    Rational => "is_rational"
    Real => "is_real"
    Positive => "is_positive"
    Negative => "is_negative"
    Finite => "is_finite"
    Nonzero => "is_nonzero"
  }
}

///|
fn Encoder::encode_wild_property(
  self : Encoder,
  property : @symcore.WildProperty,
) -> @recipe.ValueRef raise {
  let builtins = self.builder.import_module("builtins")
  let scope = self.builder.dict([(Str("__builtins__"), Ref(builtins))])
  let factory = self.builder.eval(
    scope, "lambda attribute: lambda candidate: getattr(candidate, attribute, None)",
  )
  self.builder.call(factory, [Str(wild_property_attr(property))])
}

///|
fn normalize_wild_cache_expression(expression : @symcore.Expr) -> @symcore.Expr {
  normalize_wild_cache_expression_normalized(
    @symcore.normalize_legacy_expr(expression),
  )
}

///|
fn normalize_wild_cache_expression_normalized(
  expression : @symcore.Expr,
) -> @symcore.Expr {
  match @symcore.expr_form(expression) {
    Wild(name, exclude, properties) => {
      let normalized = exclude.map(normalize_wild_cache_expression)
      Wild(name, normalized, properties)
    }
    Apply(head, arguments) =>
      Apply(
        normalize_wild_cache_expression_normalized(head),
        arguments.map(normalize_wild_cache_expression_normalized),
      )
    Add(arguments) =>
      Add(arguments.map(normalize_wild_cache_expression_normalized))
    Mul(arguments) =>
      Mul(arguments.map(normalize_wild_cache_expression_normalized))
    Pow(base, exponent) =>
      Pow(
        normalize_wild_cache_expression_normalized(base),
        normalize_wild_cache_expression_normalized(exponent),
      )
    Mod(lhs, rhs) =>
      Mod(
        normalize_wild_cache_expression_normalized(lhs),
        normalize_wild_cache_expression_normalized(rhs),
      )
    Tuple(items) => Tuple(items.map(normalize_wild_cache_expression_normalized))
    Dict(items) => {
      let normalized : Array[(@symcore.Expr, @symcore.Expr)] = []
      for item in items {
        normalized.push(
          (
            normalize_wild_cache_expression_normalized(item.0),
            normalize_wild_cache_expression_normalized(item.1),
          ),
        )
      }
      Dict(normalized)
    }
    Relational(operator, lhs, rhs) =>
      Relational(
        operator,
        normalize_wild_cache_expression_normalized(lhs),
        normalize_wild_cache_expression_normalized(rhs),
      )
    Derivative(inner, arguments) =>
      Derivative(
        normalize_wild_cache_expression_normalized(inner),
        arguments.map(normalize_wild_cache_expression_normalized),
      )
    Subs(inner, variable, value) =>
      Subs(
        normalize_wild_cache_expression_normalized(inner),
        normalize_wild_cache_expression_normalized(variable),
        normalize_wild_cache_expression_normalized(value),
      )
    Lambda(variables, body) =>
      Lambda(
        normalize_wild_cache_expression_normalized(variables),
        normalize_wild_cache_expression_normalized(body),
      )
    _ => expression
  }
}

///|
fn Encoder::encode_wild(
  self : Encoder,
  name : String,
  exclude : Array[@symcore.Expr],
  properties : Array[@symcore.WildProperty],
) -> @recipe.ValueRef raise {
  // normalize_legacy_expr does not descend into Wild exclusions. Normalize
  // those recursively before using Expr's canonical hash/equality contract.
  let cache_key : @symcore.Expr = Wild(
    name,
    exclude.map(normalize_wild_cache_expression),
    properties,
  )
  match self.wild_cache.get(cache_key) {
    Some(value) => return value
    None => ()
  }
  let excluded : Array[@recipe.RecipeArg] = []
  match @symcore.expr_form(cache_key) {
    Wild(_, normalized_exclude, _) =>
      for item in normalized_exclude {
        excluded.push(Ref(self.encode_normalized(item)))
      }
    _ => fail("exprcodec-wild-cache-key")
  }
  let predicates : Array[@recipe.RecipeArg] = []
  for property in properties {
    predicates.push(Ref(self.encode_wild_property(property)))
  }
  let excluded = self.builder.list(excluded)
  let predicates = self.builder.list(predicates)
  let value = self.sympy_call("Wild", [Str(name)], kwargs={
    "exclude": Ref(excluded),
    "properties": Ref(predicates),
  })
  self.wild_cache[cache_key] = value
  value
}

///|
fn Encoder::encode_wild_function(
  self : Encoder,
  name : String,
  nargs : Array[Int],
) -> @recipe.ValueRef raise {
  let kwargs : Map[String, @recipe.RecipeArg] = Map([])
  match nargs {
    [] => ()
    [arity] => kwargs["nargs"] = DecimalInt(Show::to_string(arity))
    _ => {
      let arities : Array[@recipe.RecipeArg] = []
      for arity in nargs {
        arities.push(DecimalInt(Show::to_string(arity)))
      }
      kwargs["nargs"] = Ref(self.builder.list(arities))
    }
  }
  self.sympy_call("WildFunction", [Str(name)], kwargs~)
}

///|
fn canonical_head_singleton(name : String) -> String? {
  match name {
    "Zero" => Some("Zero")
    "One" => Some("One")
    "NegativeOne" => Some("NegativeOne")
    "Half" => Some("Half")
    "Pi" => Some("Pi")
    "Exp1" => Some("Exp1")
    "ImaginaryUnit" => Some("ImaginaryUnit")
    "Infinity" => Some("Infinity")
    "NegativeInfinity" => Some("NegativeInfinity")
    "ComplexInfinity" => Some("ComplexInfinity")
    "NaN" => Some("NaN")
    "BooleanTrue" => Some("true")
    "BooleanFalse" => Some("false")
    _ => None
  }
}

///|
fn Encoder::encode_function_head(
  self : Encoder,
  name : String,
) -> @recipe.ValueRef raise {
  match canonical_head_singleton(name) {
    Some(singleton_name) => {
      let singleton = self.singleton(singleton_name)
      self.builder.getattr(singleton, "func")
    }
    None => {
      let fallback = self.sympy_call("Function", [Str(name)])
      self.builder.getattr_or(self.sympy, name, fallback)
    }
  }
}

///|
fn Encoder::encode_undefined_function(
  self : Encoder,
  name : String,
) -> @recipe.ValueRef raise {
  self.sympy_call("Function", [Str(name)])
}

///|
fn Encoder::encode_arguments(
  self : Encoder,
  arguments : Array[@symcore.Expr],
) -> Array[@recipe.RecipeArg] raise {
  let encoded : Array[@recipe.RecipeArg] = []
  for argument in arguments {
    encoded.push(Ref(self.encode_normalized(argument)))
  }
  encoded
}

///|
fn Encoder::encode_apply(
  self : Encoder,
  head : @symcore.Expr,
  arguments : Array[@symcore.Expr],
) -> @recipe.ValueRef raise {
  match @symcore.function_head_name(head) {
    Some("Piecewise") if arguments.length() % 2 == 0 => {
      let pairs : Array[@recipe.RecipeArg] = []
      let mut index = 0
      while index + 1 < arguments.length() {
        let pair = self.sympy_call("Tuple", [
          Ref(self.encode_normalized(arguments[index])),
          Ref(self.encode_normalized(arguments[index + 1])),
        ])
        pairs.push(Ref(pair))
        index += 2
      }
      let callable = self.encode_normalized(head)
      self.builder.call(callable, pairs)
    }
    Some("Union") | Some("Intersection") | Some("Complement") => {
      let name = match @symcore.function_head_name(head) {
        Some(name) => name
        None => fail("exprcodec-set-head")
      }
      self.sympy_call(name, self.encode_arguments(arguments), kwargs={
        "evaluate": Bool(false),
      })
    }
    _ => {
      let encoded_arguments = self.encode_arguments(arguments)
      let callable = self.encode_normalized(head)
      self.builder.call(callable, encoded_arguments)
    }
  }
}

///|
fn Encoder::encode_nary(
  self : Encoder,
  name : String,
  arguments : Array[@symcore.Expr],
  identity : String,
) -> @recipe.ValueRef raise {
  if arguments.is_empty() {
    return self.sympy_call("Integer", [Str(identity)])
  }
  self.sympy_call(name, self.encode_arguments(arguments), kwargs={
    "evaluate": Bool(false),
  })
}

///|
fn relational_name(operator : @symcore.RelOp) -> String {
  match operator {
    Eq => "Eq"
    Ne => "Ne"
    Lt => "Lt"
    Le => "Le"
    Gt => "Gt"
    Ge => "Ge"
  }
}

///|
fn Encoder::encode_normalized(
  self : Encoder,
  expression : @symcore.Expr,
) -> @recipe.ValueRef raise {
  match @symcore.expr_form(expression) {
    Number(_) => self.encode_number(expression)
    Float(value) => self.encode_float(value)
    ComplexFloat(value) => self.encode_complex_float(value)
    NumberSymbol(kind) => self.encode_number_symbol(kind)
    Symbol(name) => self.encode_symbol(name)
    Dummy(name, id) => self.encode_dummy(name, id)
    Wild(name, exclude, properties) =>
      self.encode_wild(name, exclude, properties)
    WildFunction(name, nargs) => self.encode_wild_function(name, nargs)
    FunctionHead(name) => self.encode_function_head(name)
    UndefinedFunction(name) => self.encode_undefined_function(name)
    Apply(head, arguments) => self.encode_apply(head, arguments)
    Boolean(value) => self.singleton(if value { "true" } else { "false" })
    IdentityFunction => self.singleton("IdentityFunction")
    Add(arguments) => self.encode_nary("Add", arguments, "0")
    Mul(arguments) => self.encode_nary("Mul", arguments, "1")
    Pow(base, exponent) =>
      self.sympy_call(
        "Pow",
        [
          Ref(self.encode_normalized(base)),
          Ref(self.encode_normalized(exponent)),
        ],
        kwargs={ "evaluate": Bool(false) },
      )
    Mod(lhs, rhs) =>
      self.sympy_call("Mod", [
        Ref(self.encode_normalized(lhs)),
        Ref(self.encode_normalized(rhs)),
      ])
    Tuple(items) => self.sympy_call("Tuple", self.encode_arguments(items))
    Dict(items) => {
      let pairs : Array[@recipe.RecipeArg] = []
      for item in items {
        let (key, value) = item
        let pair = self.sympy_call("Tuple", [
          Ref(self.encode_normalized(key)),
          Ref(self.encode_normalized(value)),
        ])
        pairs.push(Ref(pair))
      }
      self.sympy_call("Dict", pairs)
    }
    Relational(operator, lhs, rhs) =>
      self.sympy_call(relational_name(operator), [
        Ref(self.encode_normalized(lhs)),
        Ref(self.encode_normalized(rhs)),
      ])
    Derivative(inner, arguments) => {
      let encoded : Array[@recipe.RecipeArg] = [
        Ref(self.encode_normalized(inner)),
      ]
      for argument in arguments {
        encoded.push(Ref(self.encode_normalized(argument)))
      }
      self.sympy_call("Derivative", encoded)
    }
    Subs(inner, variable, value) =>
      self.sympy_call("Subs", [
        Ref(self.encode_normalized(inner)),
        Ref(self.encode_normalized(variable)),
        Ref(self.encode_normalized(value)),
      ])
    Lambda(variables, body) =>
      self.sympy_call("Lambda", [
        Ref(self.encode_normalized(variables)),
        Ref(self.encode_normalized(body)),
      ])
  }
}
