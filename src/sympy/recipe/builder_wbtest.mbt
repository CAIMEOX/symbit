///|
test "recipe nodes use contiguous ids and backward references" {
  let builder = Builder::new()
  let operator = builder.import_module("operator")
  let add = builder.getattr(operator, "add")
  let answer = builder.call(add, [DecimalInt("40"), DecimalInt("2")])
  assert_eq(
    builder.build_request(answer, Int),
    Json::object({
      "schema": Json::number(1),
      "nodes": Json::array([
        Json::object({
          "id": Json::number(0),
          "op": Json::string("import"),
          "module": Json::string("operator"),
        }),
        Json::object({
          "id": Json::number(1),
          "op": Json::string("getattr"),
          "object": Json::object({ "ref": Json::number(0) }),
          "name": Json::string("add"),
        }),
        Json::object({
          "id": Json::number(2),
          "op": Json::string("const"),
          "codec": Json::string("int"),
          "value": Json::string("40"),
        }),
        Json::object({
          "id": Json::number(3),
          "op": Json::string("const"),
          "codec": Json::string("int"),
          "value": Json::string("2"),
        }),
        Json::object({
          "id": Json::number(4),
          "op": Json::string("call"),
          "callable": Json::object({ "ref": Json::number(1) }),
          "args": Json::array([
            Json::object({ "ref": Json::number(2) }),
            Json::object({ "ref": Json::number(3) }),
          ]),
          "kwargs": Json::object({}),
        }),
      ]),
      "result": Json::object({
        "ref": Json::number(4),
        "codec": Json::string("int"),
      }),
    }),
  )
}

///|
test "getattr or serializes object name and fallback references" {
  let builder = Builder::new()
  let builtins = builder.import_module("builtins")
  let fallback = builder.value(Str("fallback"))
  let value = builder.getattr_or(builtins, "missing", fallback)
  assert_eq(
    builder.build_request(value, Str),
    Json::object({
      "schema": Json::number(1),
      "nodes": Json::array([
        Json::object({
          "id": Json::number(0),
          "op": Json::string("import"),
          "module": Json::string("builtins"),
        }),
        Json::object({
          "id": Json::number(1),
          "op": Json::string("const"),
          "codec": Json::string("str"),
          "value": Json::string("fallback"),
        }),
        Json::object({
          "id": Json::number(2),
          "op": Json::string("getattr_or"),
          "object": Json::object({ "ref": Json::number(0) }),
          "name": Json::string("missing"),
          "fallback": Json::object({ "ref": Json::number(1) }),
        }),
      ]),
      "result": Json::object({
        "ref": Json::number(2),
        "codec": Json::string("str"),
      }),
    }),
  )
}

///|
test "getattr or rejects a foreign object without appending a node" {
  let first = Builder::new()
  let foreign_object = first.import_module("builtins")
  let second = Builder::new()
  let fallback = second.value(Str("fallback"))
  let before = second.nodes.length()
  let rejected = try {
    second.getattr_or(foreign_object, "len", fallback) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(second.nodes.length(), before)
}

///|
test "getattr or rejects a foreign fallback without appending a node" {
  let first = Builder::new()
  let foreign_fallback = first.value(Str("fallback"))
  let second = Builder::new()
  let object = second.import_module("builtins")
  let before = second.nodes.length()
  let rejected = try {
    second.getattr_or(object, "len", foreign_fallback) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(second.nodes.length(), before)
}

///|
test "building request JSON snapshots the node array" {
  let builder = Builder::new()
  let first = builder.value(Str("first"))
  let snapshot = builder.build_request(first, Str)
  builder.value(Str("second")) |> ignore
  assert_eq(
    snapshot,
    Json::object({
      "schema": Json::number(1),
      "nodes": Json::array([
        Json::object({
          "id": Json::number(0),
          "op": Json::string("const"),
          "codec": Json::string("str"),
          "value": Json::string("first"),
        }),
      ]),
      "result": Json::object({
        "ref": Json::number(0),
        "codec": Json::string("str"),
      }),
    }),
  )
}

///|
test "foreign scope failure does not materialize a literal" {
  let first = Builder::new()
  let foreign_scope = first.sympy_scope()
  let second = Builder::new()
  let before = second.nodes.length()
  let rejected = try {
    second.bind(foreign_scope, "value", DecimalInt("42")) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(second.nodes.length(), before)
}

///|
test "foreign binding value failure does not append a node" {
  let first = Builder::new()
  let foreign_value = first.value(DecimalInt("42"))
  let second = Builder::new()
  let scope = second.sympy_scope()
  let before = second.nodes.length()
  let rejected = try {
    second.bind(scope, "value", Ref(foreign_value)) |> ignore
    false
  } catch {
    ForeignReference => true
    _ => false
  }
  assert_true(rejected)
  assert_eq(second.nodes.length(), before)
}

///|
test "SymPy scope serializes the fixed profile" {
  let builder = Builder::new()
  let scope = builder.sympy_scope()
  assert_eq(
    builder.build_request(scope, Discard),
    Json::object({
      "schema": Json::number(1),
      "nodes": Json::array([
        Json::object({
          "id": Json::number(0),
          "op": Json::string("scope"),
          "profile": Json::string("sympy.base"),
        }),
      ]),
      "result": Json::object({
        "ref": Json::number(0),
        "codec": Json::string("discard"),
      }),
    }),
  )
}

///|
test "recursive result codecs are rejected without recursion overflow" {
  let builder = Builder::new()
  let value = builder.value(Str("value"))
  let items : Array[ResultCodec] = []
  let codec = Tuple(items)
  items.push(codec)
  let rejected = try {
    builder.request(value, codec) |> ignore
    false
  } catch {
    RecursiveCodec => true
    _ => false
  }
  assert_true(rejected)
  let closed = try {
    builder.value(Str("too late")) |> ignore
    false
  } catch {
    BuilderClosed => true
    _ => false
  }
  assert_true(closed)
}

///|
test "excessively deep result codecs are rejected" {
  let builder = Builder::new()
  let value = builder.value(Str("value"))
  let mut codec = ResultCodec::Str
  for _ in 0..<65 {
    codec = Optional(codec)
  }
  let rejected = try {
    builder.request(value, codec) |> ignore
    false
  } catch {
    CodecTooDeep => true
    _ => false
  }
  assert_true(rejected)
}
