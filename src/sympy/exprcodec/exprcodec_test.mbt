///|
fn encoded_srepr(expr : @symcore.Expr) -> String raise {
  let builder = @recipe.Builder::new()
  let value = encode_expr(builder, expr)
  builder.request_srepr(value)
}

///|
fn encoded_attr_srepr(expr : @symcore.Expr, name : String) -> String raise {
  let builder = @recipe.Builder::new()
  let value = encode_expr(builder, expr)
  let attribute = builder.getattr(value, name)
  builder.request_srepr(attribute)
}

///|
fn encoded_attr_str(expr : @symcore.Expr, name : String) -> String raise {
  let builder = @recipe.Builder::new()
  let value = encode_expr(builder, expr)
  let attribute = builder.getattr(value, name)
  builder.request_str(attribute)
}

///|
fn wild_matches(
  property : @symcore.WildProperty,
  candidate : @symcore.Expr,
) -> Bool raise {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let wild = encoder.encode(Wild("w", [], [property]))
  let candidate = encoder.encode(candidate)
  let matches = builder.getattr(wild, "matches")
  let result = builder.call(matches, [Ref(candidate)])
  let none = builder.value(Null)
  let operator = builder.import_module("operator")
  let is_not = builder.getattr(operator, "is_not")
  let matched = builder.call(is_not, [Ref(result), Ref(none)])
  builder.request_bool(matched)
}

///|
test "expr codec preserves exact numbers floats and complex floats" {
  assert_eq(encoded_srepr(@symcore.int(-42)), "Integer(-42)")
  assert_eq(
    encoded_srepr(@symcore.rational_from_ints(-2, 3)),
    "Rational(-2, 3)",
  )
  let real = @symcore.Float::from_str("1.25")
  assert_eq(encoded_srepr(Float(real)), "Float('1.25', precision=53)")
  let complex = @symcore.ComplexFloat::from_real(
    @symcore.Float::from_str("2.5"),
    imag=@symcore.Float::from_str("-3.75"),
  )
  assert_eq(
    encoded_srepr(ComplexFloat(complex)),
    "Add(Float('2.5', precision=53), Mul(Float('-3.75', precision=53), I))",
  )
  let pure_imaginary = @symcore.ComplexFloat::from_real(
    @symcore.Float::from_str("0"),
    imag=@symcore.Float::from_str("2.5"),
  )
  assert_eq(
    encoded_srepr(ComplexFloat(pure_imaginary)),
    "Mul(Float('2.5', precision=53), I)",
  )
}

///|
test "expr codec maps every number singleton including negative infinity" {
  let cases : Array[(@symcore.NumberSymbolKind, String)] = [
    (ImaginaryUnit, "I"),
    (Pi, "pi"),
    (Exp1, "E"),
    (EulerGamma, "EulerGamma"),
    (GoldenRatio, "GoldenRatio"),
    (Catalan, "Catalan"),
    (Infinity, "oo"),
    (NegativeInfinity, "-oo"),
    (ComplexInfinity, "zoo"),
    (NaN, "nan"),
  ]
  for item in cases {
    assert_eq(encoded_srepr(NumberSymbol(item.0)), item.1)
  }
}

///|
test "expr codec constructs one literal Symbol atom" {
  assert_eq(encoded_srepr(Symbol("x y,z")), "Symbol('x y,z')")
}

///|
test "expr codec preserves the historical singleton set symbol profile" {
  for
    name in [
      "EmptySet", "UniversalSet", "Naturals", "Naturals0", "Integers", "Rationals",
      "Reals", "Complexes",
    ] {
    assert_eq(encoded_srepr(Symbol(name)), name)
  }
}

///|
test "expr codec caches Dummy atoms by id and rejects conflicting names" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let first = encoder.encode(Dummy("d", 7))
  let repeated = encoder.encode(Dummy("d", 7))
  let conflict = try {
    encoder.encode(Dummy("other", 7)) |> ignore
    false
  } catch {
    ExprCodecError::DummyIdConflict(7, "d", "other") => true
    _ => false
  }
  let operator = builder.import_module("operator")
  let is_ = builder.getattr(operator, "is_")
  let same = builder.call(is_, [Ref(first), Ref(repeated)])
  assert_true(conflict)
  assert_true(builder.request_bool(same))
}

///|
test "expr codec uses collision-free structural Wild caching" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let first_expr : @symcore.Expr = Wild("a|sym:x", [], [])
  let colliding_text_expr : @symcore.Expr = Wild("a", [Symbol("x")], [])
  let first = encoder.encode(first_expr)
  let repeated = encoder.encode(first_expr)
  let structurally_distinct = encoder.encode(colliding_text_expr)
  let operator = builder.import_module("operator")
  let is_ = builder.getattr(operator, "is_")
  let is_not = builder.getattr(operator, "is_not")
  let same = builder.call(is_, [Ref(first), Ref(repeated)])
  let distinct = builder.call(is_not, [Ref(first), Ref(structurally_distinct)])
  let and_ = builder.getattr(operator, "and_")
  let result = builder.call(and_, [Ref(same), Ref(distinct)])
  assert_true(builder.request_bool(result))
}

///|
test "expr codec caches Wild atoms with legacy Function exclusions safely" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let first = encoder.encode(Wild("w", [Function("sin", [Symbol("x")])], []))
  let repeated = encoder.encode(Wild("w", [Function("sin", [Symbol("x")])], []))
  let nested = encoder.encode(
    Wild("outer", [Wild("inner", [Function("cos", [Symbol("x")])], [])], []),
  )
  let operator = builder.import_module("operator")
  let is_ = builder.getattr(operator, "is_")
  let identical = builder.call(is_, [Ref(first), Ref(repeated)])
  let srepr = builder.getattr(encoder.sympy, "srepr")
  let nested_repr = builder.call(srepr, [Ref(nested)])
  let builtins = builder.import_module("builtins")
  let tuple = builder.getattr(builtins, "tuple")
  let result = builder.call(tuple, [
    Ref(builder.list([Ref(identical), Ref(nested_repr)])),
  ])
  assert_eq(
    builder.request(result, Tuple([Bool, Str])),
    Json::array([Json::boolean(true), Json::string("Wild('outer')")]),
  )
}

///|
test "expr codec maps all Wild property predicates" {
  let pi : @symcore.Expr = NumberSymbol(Pi)
  let imaginary : @symcore.Expr = NumberSymbol(ImaginaryUnit)
  let infinity : @symcore.Expr = NumberSymbol(Infinity)
  let cases : Array[(@symcore.WildProperty, @symcore.Expr, @symcore.Expr)] = [
    (Symbol, Symbol("x"), @symcore.int(2)),
    (Integer, @symcore.int(2), @symcore.rational_from_ints(1, 2)),
    (Rational, @symcore.rational_from_ints(1, 2), pi),
    (Real, @symcore.rational_from_ints(1, 2), imaginary),
    (Positive, @symcore.int(2), @symcore.int(-2)),
    (Negative, @symcore.int(-2), @symcore.int(2)),
    (Finite, @symcore.int(2), infinity),
    (Nonzero, @symcore.int(2), @symcore.int(0)),
  ]
  for item in cases {
    assert_true(wild_matches(item.0, item.1))
    assert_false(wild_matches(item.0, item.2))
  }
}

///|
test "expr codec Wild properties return None for missing attributes" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let wild = encoder.encode(Wild("w", [], [Integer]))
  let properties = builder.getattr(wild, "properties")
  let predicate = builder.getitem(properties, DecimalInt("0"))
  let builtins = builder.import_module("builtins")
  let object = builder.getattr(builtins, "object")
  let candidate = builder.call(object, [])
  let result = builder.call(predicate, [Ref(candidate)])
  builder.request_none(result)
}

///|
test "expr codec cached atoms reject a sealed Builder" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let dummy = encoder.encode(Dummy("d", 7))
  builder.request_srepr(dummy) |> ignore
  let rejected = try {
    encoder.encode(Dummy("d", 7)) |> ignore
    false
  } catch {
    @recipe.BuilderClosed => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "expr codec preserves Wild exclusions" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let x : @symcore.Expr = Symbol("x")
  let wild = encoder.encode(Wild("w", [x], []))
  let candidate = encoder.encode(Add([x, @symcore.int(1)]))
  let matches = builder.getattr(wild, "matches")
  let result = builder.call(matches, [Ref(candidate)])
  let none = builder.value(Null)
  let operator = builder.import_module("operator")
  let is_ = builder.getattr(operator, "is_")
  let excluded = builder.call(is_, [Ref(result), Ref(none)])
  assert_true(builder.request_bool(excluded))
}

///|
test "expr codec maps WildFunction arity sets" {
  assert_eq(encoded_attr_srepr(WildFunction("f", []), "nargs"), "Naturals0")
  assert_eq(
    encoded_attr_srepr(WildFunction("f", [1]), "nargs"),
    "FiniteSet(Integer(1))",
  )
  assert_eq(
    encoded_attr_srepr(WildFunction("f", [1, 3]), "nargs"),
    "FiniteSet(Integer(1), Integer(3))",
  )
}

///|
test "expr codec maps every canonical FunctionHead class" {
  let cases : Array[(String, String)] = [
    ("Zero", "Zero"),
    ("One", "One"),
    ("NegativeOne", "NegativeOne"),
    ("Half", "Half"),
    ("Pi", "Pi"),
    ("Exp1", "Exp1"),
    ("ImaginaryUnit", "ImaginaryUnit"),
    ("Infinity", "Infinity"),
    ("NegativeInfinity", "NegativeInfinity"),
    ("ComplexInfinity", "ComplexInfinity"),
    ("NaN", "NaN"),
    ("BooleanTrue", "BooleanTrue"),
    ("BooleanFalse", "BooleanFalse"),
  ]
  for item in cases {
    assert_eq(encoded_attr_str(FunctionHead(item.0), "__name__"), item.1)
  }
}

///|
test "expr codec resolves known FunctionHead attributes and lazily falls back" {
  let builder = @recipe.Builder::new()
  let encoder = Encoder::new(builder)
  let sin_head = encoder.encode(FunctionHead("sin"))
  let sympy = builder.import_module("sympy")
  let sin = builder.getattr(sympy, "sin")
  let operator = builder.import_module("operator")
  let is_ = builder.getattr(operator, "is_")
  let identical = builder.call(is_, [Ref(sin_head), Ref(sin)])
  assert_true(builder.request_bool(identical))
  assert_eq(
    encoded_attr_str(FunctionHead("fresh_head"), "__name__"),
    "fresh_head",
  )
}

///|
test "expr codec maps undefined functions booleans and identity" {
  assert_eq(encoded_srepr(UndefinedFunction("sin")), "Function('sin')")
  assert_eq(encoded_srepr(Boolean(true)), "true")
  assert_eq(encoded_srepr(Boolean(false)), "false")
  assert_eq(encoded_srepr(IdentityFunction), "IdentityFunction()")
}

///|
test "expr codec preserves unevaluated arithmetic constructors" {
  let x : @symcore.Expr = Symbol("x")
  assert_eq(
    encoded_srepr(Add([@symcore.int(1), @symcore.int(-1)])),
    "Add(Integer(1), Integer(-1))",
  )
  assert_eq(
    encoded_srepr(Mul([@symcore.int(0), x])),
    "Mul(Integer(0), Symbol('x'))",
  )
  assert_eq(
    encoded_srepr(Pow(x, @symcore.int(0))),
    "Pow(Symbol('x'), Integer(0))",
  )
  assert_eq(encoded_srepr(Add([])), "Integer(0)")
  assert_eq(encoded_srepr(Mul([])), "Integer(1)")
}

///|
test "expr codec maps compound core constructors" {
  let x : @symcore.Expr = Symbol("x")
  let sin_x : @symcore.Expr = Apply(FunctionHead("sin"), [x])
  let cases : Array[(@symcore.Expr, String)] = [
    (Mod(x, @symcore.int(2)), "Mod(Symbol('x'), Integer(2))"),
    (Tuple([x, @symcore.int(2)]), "Tuple(Symbol('x'), Integer(2))"),
    (Dict([(x, @symcore.int(2))]), "Dict(Tuple(Symbol('x'), Integer(2)))"),
    (Relational(Eq, x, @symcore.int(2)), "Equality(Symbol('x'), Integer(2))"),
    (
      Derivative(sin_x, [x, @symcore.int(2)]),
      "Derivative(sin(Symbol('x')), Tuple(Symbol('x'), Integer(2)))",
    ),
    (
      Subs(sin_x, x, @symcore.int(2)),
      "Subs(sin(Symbol('x')), Tuple(Symbol('x')), Tuple(Integer(2)))",
    ),
    (Lambda(x, sin_x), "Lambda(Tuple(Symbol('x')), sin(Symbol('x')))"),
    (Apply(UndefinedFunction("f"), [x]), "Function('f')(Symbol('x'))"),
    (Function("sin", [x]), "sin(Symbol('x'))"),
  ]
  for item in cases {
    assert_eq(encoded_srepr(item.0), item.1)
  }
}

///|
test "expr codec maps all relational operators" {
  let x : @symcore.Expr = Symbol("x")
  let cases : Array[(@symcore.RelOp, String)] = [
    (Eq, "Equality"),
    (Ne, "Unequality"),
    (Lt, "StrictLessThan"),
    (Le, "LessThan"),
    (Gt, "StrictGreaterThan"),
    (Ge, "GreaterThan"),
  ]
  for item in cases {
    assert_eq(
      encoded_srepr(Relational(item.0, x, @symcore.int(2))),
      item.1 + "(Symbol('x'), Integer(2))",
    )
  }
}

///|
test "expr codec packs Piecewise pairs" {
  let x : @symcore.Expr = Symbol("x")
  let piecewise : @symcore.Expr = Apply(FunctionHead("Piecewise"), [
    x,
    Relational(Gt, x, @symcore.int(0)),
    @symcore.int(0),
    Boolean(true),
  ])
  assert_eq(
    encoded_srepr(piecewise),
    "Piecewise(ExprCondPair(Symbol('x'), StrictGreaterThan(Symbol('x'), Integer(0))), ExprCondPair(Integer(0), true))",
  )
}

///|
test "expr codec keeps set operation applications unevaluated" {
  let one_set : @symcore.Expr = Apply(FunctionHead("FiniteSet"), [
    @symcore.int(1),
  ])
  let cases : Array[(@symcore.Expr, String)] = [
    (
      Apply(FunctionHead("Union"), [Symbol("EmptySet"), one_set]),
      "Union(FiniteSet(Integer(1)), EmptySet)",
    ),
    (
      Apply(FunctionHead("Intersection"), [Symbol("Reals"), one_set]),
      "Intersection(Reals, FiniteSet(Integer(1)))",
    ),
    (
      Apply(FunctionHead("Complement"), [Symbol("Reals"), Symbol("Integers")]),
      "Complement(Reals, Integers)",
    ),
  ]
  for item in cases {
    assert_eq(encoded_srepr(item.0), item.1)
  }
}
