///|
test "recipe preserves escaped Unicode string constants" {
  let builder = @recipe.Builder::new()
  let expected = "alpha α中文😀 \" \\ \n \u{0000} tail"
  let value = builder.value(Str(expected))
  assert_eq(builder.request_str(value), expected)
}

///|
test "recipe preserves arbitrary precision decimal integer constants" {
  let builder = @recipe.Builder::new()
  let expected = "12345678901234567890123456789012345678901234567890"
  let value = builder.value(DecimalInt(expected))
  assert_eq(builder.request_int(value), expected)
}

///|
test "recipe preserves decimal float constants" {
  let builder = @recipe.Builder::new()
  let value = builder.value(DecimalFloat("1.25"))
  assert_eq(builder.request_float(value), "1.25")
}

///|
test "recipe imports gets an attribute and calls it" {
  let builder = @recipe.Builder::new()
  let operator = builder.import_module("operator")
  let add = builder.getattr(operator, "add")
  let answer = builder.call(add, [DecimalInt("40"), DecimalInt("2")])
  assert_eq(builder.request_int(answer), "42")
}

///|
test "recipe getattr or leaves a crashing fallback unreachable when the attribute exists" {
  let builder = @recipe.Builder::new()
  let operator = builder.import_module("operator")
  let truediv = builder.getattr(operator, "truediv")
  let crashing = builder.call(truediv, [DecimalInt("1"), DecimalInt("0")])
  let builtins = builder.import_module("builtins")
  let value = builder.getattr_or(builtins, "len", crashing)
  assert_eq(builder.request_repr(value), "<built-in function len>")
}

///|
test "recipe getattr or returns the fallback when the attribute is missing" {
  let builder = @recipe.Builder::new()
  let fallback = builder.value(Str("fallback"))
  let builtins = builder.import_module("builtins")
  let value = builder.getattr_or(
    builtins, "__symbit_recipe_missing__", fallback,
  )
  assert_eq(builder.request_str(value), "fallback")
}

///|
test "recipe getattr or treats a None attribute as present" {
  let builder = @recipe.Builder::new()
  let operator = builder.import_module("operator")
  let truediv = builder.getattr(operator, "truediv")
  let crashing = builder.call(truediv, [DecimalInt("1"), DecimalInt("0")])
  let builtins = builder.import_module("builtins")
  let value = builder.getattr_or(builtins, "None", crashing)
  builder.request_none(value)
}

///|
test "recipe indexes an earlier value" {
  let builder = @recipe.Builder::new()
  let values = builder.list([Str("zero"), Str("one")])
  let selected = builder.getitem(values, DecimalInt("1"))
  assert_eq(builder.request_str(selected), "one")
}

///|
test "recipe scope bind and eval share one fixed SymPy scope" {
  let builder = @recipe.Builder::new()
  let scope = builder.sympy_scope()
  let bound = builder.bind(scope, "base", DecimalInt("40"))
  let answer = builder.eval(bound, "sympy.Integer(base + 2)")
  assert_eq(builder.request_int(answer), "42")
}

///|
test "recipe scope exec and eval chain through the returned scope" {
  let builder = @recipe.Builder::new()
  let scope = builder.sympy_scope()
  let executed = builder.exec(scope, "answer = sympy.Integer(6 * 7)")
  let answer = builder.eval(executed, "answer")
  assert_eq(builder.request_int(answer), "42")
}

///|
test "recipe call supports keyword arguments" {
  let builder = @recipe.Builder::new()
  let sympy = builder.import_module("sympy")
  let symbol = builder.getattr(sympy, "Symbol")
  let x = builder.call(symbol, [Str("x")], kwargs={ "positive": Bool(true) })
  let is_positive = builder.getattr(x, "is_positive")
  assert_true(builder.request_bool(is_positive))
}

///|
fn collection_length(kind : String) -> String raise {
  let builder = @recipe.Builder::new()
  let one : @recipe.RecipeArg = DecimalInt("1")
  let two : @recipe.RecipeArg = DecimalInt("2")
  let collection = match kind {
    "list" => builder.list([one, two])
    "tuple" => builder.tuple([one, two])
    "set" => builder.set([one, two])
    "frozenset" => builder.frozenset([one, two])
    _ => fail("unknown collection kind")
  }
  let builtins = builder.import_module("builtins")
  let len = builder.getattr(builtins, "len")
  let length = builder.call(len, [Ref(collection)])
  builder.request_int(length)
}

///|
test "recipe constructs sequence and set collection kinds" {
  assert_eq(collection_length("list"), "2")
  assert_eq(collection_length("tuple"), "2")
  assert_eq(collection_length("set"), "2")
  assert_eq(collection_length("frozenset"), "2")
}

///|
test "recipe constructs dictionaries" {
  let builder = @recipe.Builder::new()
  let dictionary = builder.dict([(Str("answer"), DecimalInt("42"))])
  let builtins = builder.import_module("builtins")
  let len = builder.getattr(builtins, "len")
  let length = builder.call(len, [Ref(dictionary)])
  assert_eq(builder.request_int(length), "1")
}

///|
test "recipe terminal string repr and srepr codecs" {
  let string_builder = @recipe.Builder::new()
  let string_value = string_builder.value(Str("α"))
  assert_eq(string_builder.request_str(string_value), "α")
  let repr_builder = @recipe.Builder::new()
  let repr_value = repr_builder.value(Str("α"))
  assert_eq(repr_builder.request_repr(repr_value), "'α'")
  let srepr_builder = @recipe.Builder::new()
  let sympy = srepr_builder.import_module("sympy")
  let integer = srepr_builder.getattr(sympy, "Integer")
  let value = srepr_builder.call(integer, [DecimalInt("42")])
  assert_eq(srepr_builder.request_srepr(value), "Integer(42)")
}

///|
test "recipe terminal bool codec" {
  let builder = @recipe.Builder::new()
  let value = builder.value(Bool(true))
  assert_true(builder.request_bool(value))
}

///|
test "recipe terminal JSON codec" {
  let builder = @recipe.Builder::new()
  let json = builder.import_module("json")
  let loads = builder.getattr(json, "loads")
  let value = builder.call(loads, [Str("{\"ok\":[1,null,true]}")])
  assert_eq(
    builder.request_json(value),
    Json::object({
      "ok": Json::array([Json::number(1), Json::null(), Json::boolean(true)]),
    }),
  )
}

///|
test "recipe terminal None codec" {
  let builder = @recipe.Builder::new()
  let value = builder.value(Null)
  builder.request_none(value)
}

///|
test "recipe terminal discard codec" {
  let builder = @recipe.Builder::new()
  let value = builder.value(Str("ignored"))
  builder.request_discard(value)
}

///|
test "recipe composite result codecs preserve shape" {
  let list_builder = @recipe.Builder::new()
  let list_value = list_builder.list([DecimalInt("1"), DecimalInt("2")])
  assert_eq(
    list_builder.request(list_value, List(Int)),
    Json::array([Json::string("1"), Json::string("2")]),
  )
  let optional_builder = @recipe.Builder::new()
  let optional_value = optional_builder.value(Null)
  assert_eq(
    optional_builder.request(optional_value, Optional(Str)),
    Json::null(),
  )
  let tuple_builder = @recipe.Builder::new()
  let tuple_value = tuple_builder.tuple([DecimalInt("1"), Str("two")])
  assert_eq(
    tuple_builder.request(tuple_value, Tuple([Int, Str])),
    Json::array([Json::string("1"), Json::string("two")]),
  )
}

///|
test "recipe dictionary result codec returns ordered pairs" {
  let builder = @recipe.Builder::new()
  let value = builder.dict([(Str("a"), DecimalInt("2"))])
  assert_eq(
    builder.request(value, DictPairs(Str, Int)),
    Json::array([Json::array([Json::string("a"), Json::string("2")])]),
  )
}

///|
test "recipe require non None preserves legacy must-call semantics" {
  let present_builder = @recipe.Builder::new()
  let present = present_builder.value(Str("present"))
  let required = present_builder.require_non_none(
    present,
    message="sympy-call-none:sympy.sympify",
  )
  assert_eq(present_builder.request_str(required), "present")
  let absent_builder = @recipe.Builder::new()
  let absent = absent_builder.value(Null)
  let missing = absent_builder.require_non_none(
    absent,
    message="sympy-call-none:sympy.sympify",
  )
  let rejected = try {
    absent_builder.request_str(missing) |> ignore
    false
  } catch {
    @runtime.OracleError::PythonException(type_name, message, _) =>
      type_name == "ValueError" && message == "sympy-call-none:sympy.sympify"
    _ => false
  }
  assert_true(rejected)
}

///|
test "recipe rejects references from another builder" {
  let first = @recipe.Builder::new()
  let foreign = first.value(Str("foreign"))
  let second = @recipe.Builder::new()
  let rejected = try {
    second.list([Ref(foreign)]) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "recipe rejects a foreign scope before binding" {
  let first = @recipe.Builder::new()
  let foreign_scope = first.sympy_scope()
  let second = @recipe.Builder::new()
  let rejected = try {
    second.bind(foreign_scope, "value", DecimalInt("42")) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "recipe rejects a foreign binding value" {
  let first = @recipe.Builder::new()
  let foreign_value = first.value(DecimalInt("42"))
  let second = @recipe.Builder::new()
  let scope = second.sympy_scope()
  let rejected = try {
    second.bind(scope, "value", Ref(foreign_value)) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "recipe seals a builder after a terminal request" {
  let builder = @recipe.Builder::new()
  let value = builder.value(Str("done"))
  assert_eq(builder.request_str(value), "done")
  let rejected = try {
    builder.value(Str("too late")) |> ignore
    false
  } catch {
    BuilderClosed => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "recipe stays sealed when the terminal request raises" {
  let builder = @recipe.Builder::new()
  let operator = builder.import_module("operator")
  let truediv = builder.getattr(operator, "truediv")
  let division = builder.call(truediv, [DecimalInt("1"), DecimalInt("0")])
  let failed = try {
    builder.request_int(division) |> ignore
    false
  } catch {
    _ => true
  }
  assert_true(failed)
  let closed = try {
    builder.request_int(division) |> ignore
    false
  } catch {
    @recipe.RecipeError::BuilderClosed => true
    _ => false
  }
  assert_true(closed)
}
