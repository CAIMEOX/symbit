///|
test "oracle recipe evaluates a decimal integer constant" {
  let input = Json::object({
    "schema": Json::number(1),
    "nodes": Json::array([
      Json::object({
        "id": Json::number(0),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("42"),
      }),
    ]),
    "result": Json::object({
      "ref": Json::number(0),
      "codec": Json::string("int"),
    }),
  })
  assert_eq(@runtime.request("oracle.recipe.v1", input), Json::string("42"))
}

///|
fn recipe_ref(id : Int) -> Json {
  Json::object({ "ref": Json::number(id.to_double()) })
}

///|
fn recipe_input(nodes : Array[Json], result_ref : Int, codec : Json) -> Json {
  Json::object({
    "schema": Json::number(1),
    "nodes": Json::array(nodes),
    "result": Json::object({
      "ref": Json::number(result_ref.to_double()),
      "codec": codec,
    }),
  })
}

///|
test "oracle recipe imports gets an attribute and calls it" {
  let input = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("import"),
        "module": Json::string("operator"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("getattr"),
        "object": recipe_ref(0),
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
        "callable": recipe_ref(1),
        "args": Json::array([recipe_ref(2), recipe_ref(3)]),
        "kwargs": Json::object({}),
      }),
    ],
    4,
    Json::string("int"),
  )
  assert_eq(@runtime.request("oracle.recipe.v1", input), Json::string("42"))
}

///|
fn collection_length_input(kind : String) -> Json {
  let collection = if kind == "dict" {
    Json::object({
      "id": Json::number(4),
      "op": Json::string("collection"),
      "kind": Json::string(kind),
      "items": Json::array([Json::array([recipe_ref(2), recipe_ref(3)])]),
    })
  } else {
    Json::object({
      "id": Json::number(4),
      "op": Json::string("collection"),
      "kind": Json::string(kind),
      "items": Json::array([recipe_ref(2), recipe_ref(3)]),
    })
  }
  recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("import"),
        "module": Json::string("builtins"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("getattr"),
        "object": recipe_ref(0),
        "name": Json::string("len"),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("1"),
      }),
      Json::object({
        "id": Json::number(3),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("2"),
      }),
      collection,
      Json::object({
        "id": Json::number(5),
        "op": Json::string("call"),
        "callable": recipe_ref(1),
        "args": Json::array([recipe_ref(4)]),
        "kwargs": Json::object({}),
      }),
    ],
    5,
    Json::string("int"),
  )
}

///|
test "oracle recipe constructs every collection kind" {
  for kind in ["list", "tuple", "set", "frozenset"] {
    assert_eq(
      @runtime.request("oracle.recipe.v1", collection_length_input(kind)),
      Json::string("2"),
    )
  }
  assert_eq(
    @runtime.request("oracle.recipe.v1", collection_length_input("dict")),
    Json::string("1"),
  )
}

///|
test "oracle recipe evaluates one call node once and preserves identity" {
  let input = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("import"),
        "module": Json::string("builtins"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("getattr"),
        "object": recipe_ref(0),
        "name": Json::string("list"),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("call"),
        "callable": recipe_ref(1),
        "args": Json::array([]),
        "kwargs": Json::object({}),
      }),
      Json::object({
        "id": Json::number(3),
        "op": Json::string("collection"),
        "kind": Json::string("list"),
        "items": Json::array([recipe_ref(2), recipe_ref(2)]),
      }),
      Json::object({
        "id": Json::number(4),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("0"),
      }),
      Json::object({
        "id": Json::number(5),
        "op": Json::string("getitem"),
        "object": recipe_ref(3),
        "key": recipe_ref(4),
      }),
      Json::object({
        "id": Json::number(6),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("1"),
      }),
      Json::object({
        "id": Json::number(7),
        "op": Json::string("getitem"),
        "object": recipe_ref(3),
        "key": recipe_ref(6),
      }),
      Json::object({
        "id": Json::number(8),
        "op": Json::string("import"),
        "module": Json::string("operator"),
      }),
      Json::object({
        "id": Json::number(9),
        "op": Json::string("getattr"),
        "object": recipe_ref(8),
        "name": Json::string("is_"),
      }),
      Json::object({
        "id": Json::number(10),
        "op": Json::string("call"),
        "callable": recipe_ref(9),
        "args": Json::array([recipe_ref(5), recipe_ref(7)]),
        "kwargs": Json::object({}),
      }),
    ],
    10,
    Json::string("int"),
  )
  assert_eq(@runtime.request("oracle.recipe.v1", input), Json::string("1"))
}

///|
test "oracle recipe caches a None result without executing its call twice" {
  let input = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("import"),
        "module": Json::string("builtins"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("getattr"),
        "object": recipe_ref(0),
        "name": Json::string("list"),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("call"),
        "callable": recipe_ref(1),
        "args": Json::array([]),
        "kwargs": Json::object({}),
      }),
      Json::object({
        "id": Json::number(3),
        "op": Json::string("getattr"),
        "object": recipe_ref(2),
        "name": Json::string("append"),
      }),
      Json::object({
        "id": Json::number(4),
        "op": Json::string("const"),
        "codec": Json::string("none"),
      }),
      Json::object({
        "id": Json::number(5),
        "op": Json::string("call"),
        "callable": recipe_ref(3),
        "args": Json::array([recipe_ref(4)]),
        "kwargs": Json::object({}),
      }),
      Json::object({
        "id": Json::number(6),
        "op": Json::string("collection"),
        "kind": Json::string("list"),
        "items": Json::array([recipe_ref(5), recipe_ref(5), recipe_ref(2)]),
      }),
      Json::object({
        "id": Json::number(7),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("2"),
      }),
      Json::object({
        "id": Json::number(8),
        "op": Json::string("getitem"),
        "object": recipe_ref(6),
        "key": recipe_ref(7),
      }),
      Json::object({
        "id": Json::number(9),
        "op": Json::string("getattr"),
        "object": recipe_ref(8),
        "name": Json::string("__len__"),
      }),
      Json::object({
        "id": Json::number(10),
        "op": Json::string("call"),
        "callable": recipe_ref(9),
        "args": Json::array([]),
        "kwargs": Json::object({}),
      }),
    ],
    10,
    Json::string("int"),
  )
  assert_eq(@runtime.request("oracle.recipe.v1", input), Json::string("1"))
}

///|
test "oracle recipe exec and eval share one scope but requests stay isolated" {
  let first = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("40"),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("bind"),
        "scope": recipe_ref(0),
        "name": Json::string("base"),
        "value": recipe_ref(1),
      }),
      Json::object({
        "id": Json::number(3),
        "op": Json::string("exec"),
        "scope": recipe_ref(2),
        "code": Json::string("answer = sympy.Integer(base + 2)"),
      }),
      Json::object({
        "id": Json::number(4),
        "op": Json::string("eval"),
        "scope": recipe_ref(3),
        "code": Json::string("answer"),
      }),
    ],
    4,
    Json::string("int"),
  )
  assert_eq(@runtime.request("oracle.recipe.v1", first), Json::string("42"))
  let second = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("eval"),
        "scope": recipe_ref(0),
        "code": Json::string("answer"),
      }),
    ],
    1,
    Json::string("int"),
  )
  let isolated = try {
    @runtime.request("oracle.recipe.v1", second) |> ignore
    false
  } catch {
    PythonException(type_name, _, _) => type_name == "NameError"
    _ => false
  }
  assert_true(isolated)
}

///|
test "oracle recipe keeps its builtins mapping request local" {
  let mutate = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("exec"),
        "scope": recipe_ref(0),
        "code": Json::string(
          "__builtins__['SYMBIT_RECIPE_BUILTIN_PROBE'] = 'dirty'",
        ),
      }),
    ],
    1,
    Json::string("discard"),
  )
  @runtime.request("oracle.recipe.v1", mutate) |> ignore
  let observe = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("eval"),
        "scope": recipe_ref(0),
        "code": Json::string("'SYMBIT_RECIPE_BUILTIN_PROBE' in __builtins__"),
      }),
    ],
    1,
    Json::string("bool"),
  )
  let leaked = @runtime.request("oracle.recipe.v1", observe)
  @runtime.eval_str(
    "runtime.eval_str", "__builtins__.pop('SYMBIT_RECIPE_BUILTIN_PROBE', None)",
  )
  |> ignore
  assert_eq(leaked, Json::boolean(false))
}

///|
test "oracle recipe distinguishes None from exceptions and recovers" {
  let before = @runtime.worker_info()
  let none_recipe = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("const"),
        "codec": Json::string("none"),
      }),
    ],
    0,
    Json::string("none"),
  )
  assert_eq(@runtime.request("oracle.recipe.v1", none_recipe), Json::null())
  let exception_recipe = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("eval"),
        "scope": recipe_ref(0),
        "code": Json::string("1 / 0"),
      }),
    ],
    1,
    Json::string("int"),
  )
  let raised = try {
    @runtime.request("oracle.recipe.v1", exception_recipe) |> ignore
    false
  } catch {
    PythonException(type_name, message, _) =>
      type_name == "ZeroDivisionError" && message.contains("division by zero")
    _ => false
  }
  assert_true(raised)
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input(
        [
          Json::object({
            "id": Json::number(0),
            "op": Json::string("const"),
            "codec": Json::string("int"),
            "value": Json::string("7"),
          }),
        ],
        0,
        Json::string("int"),
      ),
    ),
    Json::string("7"),
  )
  assert_eq(@runtime.worker_info().pid, before.pid)
}

///|
fn scalar_const_input(codec : String, value : Json) -> Json {
  recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("const"),
        "codec": Json::string(codec),
        "value": value,
      }),
    ],
    0,
    Json::string(codec),
  )
}

///|
test "oracle recipe supports every scalar constant codec" {
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      scalar_const_input("bool", Json::boolean(true)),
    ),
    Json::boolean(true),
  )
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      scalar_const_input("str", Json::string("α中")),
    ),
    Json::string("α中"),
  )
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      scalar_const_input("float", Json::string("1.25")),
    ),
    Json::string("1.25"),
  )
}

///|
test "oracle recipe supports discard repr srepr and optional result codecs" {
  let int_node = Json::object({
    "id": Json::number(0),
    "op": Json::string("const"),
    "codec": Json::string("int"),
    "value": Json::string("42"),
  })
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input([int_node], 0, Json::string("discard")),
    ),
    Json::null(),
  )
  let str_node = Json::object({
    "id": Json::number(0),
    "op": Json::string("const"),
    "codec": Json::string("str"),
    "value": Json::string("α"),
  })
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input([str_node], 0, Json::string("repr")),
    ),
    Json::string("'α'"),
  )
  let srepr_recipe = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("eval"),
        "scope": recipe_ref(0),
        "code": Json::string("sympy.Symbol('x') + 1"),
      }),
    ],
    1,
    Json::string("srepr"),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", srepr_recipe),
    Json::string("Add(Integer(1), Symbol('x'))"),
  )
  let optional_str = Json::object({
    "kind": Json::string("optional"),
    "item": Json::string("str"),
  })
  let none_node = Json::object({
    "id": Json::number(0),
    "op": Json::string("const"),
    "codec": Json::string("none"),
  })
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input([none_node], 0, optional_str),
    ),
    Json::null(),
  )
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input([str_node], 0, optional_str),
    ),
    Json::string("α"),
  )
}

///|
test "oracle recipe encodes list tuple dict pairs and JSON results" {
  let int_one = Json::object({
    "id": Json::number(0),
    "op": Json::string("const"),
    "codec": Json::string("int"),
    "value": Json::string("1"),
  })
  let int_two = Json::object({
    "id": Json::number(1),
    "op": Json::string("const"),
    "codec": Json::string("int"),
    "value": Json::string("2"),
  })
  let list_node = Json::object({
    "id": Json::number(2),
    "op": Json::string("collection"),
    "kind": Json::string("list"),
    "items": Json::array([recipe_ref(0), recipe_ref(1)]),
  })
  let list_codec = Json::object({
    "kind": Json::string("list"),
    "item": Json::string("int"),
  })
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input([int_one, int_two, list_node], 2, list_codec),
    ),
    Json::array([Json::string("1"), Json::string("2")]),
  )
  let tuple_recipe = recipe_input(
    [
      int_one,
      Json::object({
        "id": Json::number(1),
        "op": Json::string("const"),
        "codec": Json::string("str"),
        "value": Json::string("two"),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("collection"),
        "kind": Json::string("tuple"),
        "items": Json::array([recipe_ref(0), recipe_ref(1)]),
      }),
    ],
    2,
    Json::object({
      "kind": Json::string("tuple"),
      "items": Json::array([Json::string("int"), Json::string("str")]),
    }),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", tuple_recipe),
    Json::array([Json::string("1"), Json::string("two")]),
  )
  let dict_recipe = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("const"),
        "codec": Json::string("str"),
        "value": Json::string("a"),
      }),
      int_two,
      Json::object({
        "id": Json::number(2),
        "op": Json::string("collection"),
        "kind": Json::string("dict"),
        "items": Json::array([Json::array([recipe_ref(0), recipe_ref(1)])]),
      }),
    ],
    2,
    Json::object({
      "kind": Json::string("dict_pairs"),
      "key": Json::string("str"),
      "value": Json::string("int"),
    }),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", dict_recipe),
    Json::array([Json::array([Json::string("a"), Json::string("2")])]),
  )
  let json_recipe = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("eval"),
        "scope": recipe_ref(0),
        "code": Json::string("{'ok': [1, None, True]}"),
      }),
    ],
    1,
    Json::string("json"),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", json_recipe),
    Json::object({
      "ok": Json::array([Json::number(1), Json::null(), Json::boolean(true)]),
    }),
  )
}

///|
test "oracle recipe JSON codec rejects recursively unsafe integers" {
  let make_json = fn(code : String) -> Json {
    recipe_input(
      [
        Json::object({
          "id": Json::number(0),
          "op": Json::string("scope"),
          "profile": Json::string("sympy.base"),
        }),
        Json::object({
          "id": Json::number(1),
          "op": Json::string("eval"),
          "scope": recipe_ref(0),
          "code": Json::string(code),
        }),
      ],
      1,
      Json::string("json"),
    )
  }
  let safe = make_json("{'nested': [(9007199254740991, True)]}")
  let expected = Json::object({
    "nested": Json::array([
      Json::array([Json::number(9007199254740991.0), Json::boolean(true)]),
    ]),
  })
  assert_eq(@runtime.request("oracle.recipe.v1", safe), expected)
  let before = @runtime.worker_info()
  for
    code in [
      "{'nested': [(9007199254740992,)]}", "{'nested': [(-9007199254740992,)]}",
      "{'nested': [__import__('enum').IntEnum('Huge', {'VALUE': 9007199254740992}).VALUE]}",
    ] {
    let rejected = try {
      @runtime.request("oracle.recipe.v1", make_json(code)) |> ignore
      false
    } catch {
      ProtocolError(message) => message.contains("JSON-safe integer range")
      _ => false
    }
    assert_true(rejected)
  }
  assert_eq(@runtime.request("oracle.recipe.v1", safe), expected)
  assert_eq(@runtime.worker_info().pid, before.pid)
}

///|
test "oracle recipe require_non_none passes values and raises on None" {
  let present = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("const"),
        "codec": Json::string("str"),
        "value": Json::string("present"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("require_non_none"),
        "value": recipe_ref(0),
        "message": Json::string("missing required value"),
      }),
    ],
    1,
    Json::string("str"),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", present),
    Json::string("present"),
  )
  let absent = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("const"),
        "codec": Json::string("none"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("require_non_none"),
        "value": recipe_ref(0),
        "message": Json::string("missing required value"),
      }),
    ],
    1,
    Json::string("str"),
  )
  let raised = try {
    @runtime.request("oracle.recipe.v1", absent) |> ignore
    false
  } catch {
    PythonException(type_name, message, _) =>
      type_name == "ValueError" && message == "missing required value"
    _ => false
  }
  assert_true(raised)
  assert_eq(
    @runtime.request("oracle.recipe.v1", present),
    Json::string("present"),
  )
}

///|
test "oracle recipe bool result accepts only Python and SymPy booleans" {
  let rejected = try {
    @runtime.request(
      "oracle.recipe.v1",
      recipe_input(
        [
          Json::object({
            "id": Json::number(0),
            "op": Json::string("const"),
            "codec": Json::string("int"),
            "value": Json::string("1"),
          }),
        ],
        0,
        Json::string("bool"),
      ),
    )
    |> ignore
    false
  } catch {
    ProtocolError(message) => message.contains("expected a boolean")
    _ => false
  }
  assert_true(rejected)
  for
    pair in [
      ("sympy.true", Json::boolean(true)),
      ("sympy.false", Json::boolean(false)),
    ] {
    let (code, expected) = pair
    let input = recipe_input(
      [
        Json::object({
          "id": Json::number(0),
          "op": Json::string("scope"),
          "profile": Json::string("sympy.base"),
        }),
        Json::object({
          "id": Json::number(1),
          "op": Json::string("eval"),
          "scope": recipe_ref(0),
          "code": Json::string(code),
        }),
      ],
      1,
      Json::string("bool"),
    )
    assert_eq(@runtime.request("oracle.recipe.v1", input), expected)
  }
}

///|
test "oracle recipe int result requires the index protocol" {
  let float_recipe = scalar_const_input("float", Json::string("1.9"))
  let rejected_float = try {
    let fields = match float_recipe {
      Object(fields) => fields
      _ => abort("recipe helper returned non-object")
    }
    fields["result"] = Json::object({
      "ref": Json::number(0),
      "codec": Json::string("int"),
    })
    @runtime.request("oracle.recipe.v1", float_recipe) |> ignore
    false
  } catch {
    ProtocolError(message) => message.contains("index-compatible integer")
    _ => false
  }
  assert_true(rejected_float)
  let make_eval = fn(code : String) -> Json {
    recipe_input(
      [
        Json::object({
          "id": Json::number(0),
          "op": Json::string("scope"),
          "profile": Json::string("sympy.base"),
        }),
        Json::object({
          "id": Json::number(1),
          "op": Json::string("eval"),
          "scope": recipe_ref(0),
          "code": Json::string(code),
        }),
      ],
      1,
      Json::string("int"),
    )
  }
  let rejected_int_only = try {
    @runtime.request(
      "oracle.recipe.v1",
      make_eval("type('OnlyInt', (), {'__int__': lambda self: 7})()"),
    )
    |> ignore
    false
  } catch {
    ProtocolError(message) => message.contains("index-compatible integer")
    _ => false
  }
  assert_true(rejected_int_only)
  assert_eq(
    @runtime.request(
      "oracle.recipe.v1",
      make_eval("type('Indexed', (), {'__index__': lambda self: 7})()"),
    ),
    Json::string("7"),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", make_eval("sympy.Integer(8)")),
    Json::string("8"),
  )
}

///|
fn side_effect_recipe(extra_at : String, schema? : Int = 1) -> Json {
  let exec_fields : Map[String, Json] = {
    "id": Json::number(1),
    "op": Json::string("exec"),
    "scope": recipe_ref(0),
    "code": Json::string(
      "__import__('os').environ['SYMBIT_RECIPE_VALIDATION_PROBE'] = 'dirty'",
    ),
  }
  if extra_at == "node" {
    exec_fields["extra"] = Json::boolean(true)
  }
  let result_fields : Map[String, Json] = {
    "ref": Json::number(1),
    "codec": Json::string(
      if extra_at == "codec" {
        "mystery"
      } else {
        "discard"
      },
    ),
  }
  if extra_at == "result" {
    result_fields["extra"] = Json::boolean(true)
  }
  let recipe_fields : Map[String, Json] = {
    "schema": Json::number(schema.to_double()),
    "nodes": Json::array([
      Json::object({
        "id": Json::number(if extra_at == "id" { 1 } else { 0 }),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object(exec_fields),
      Json::object({
        "id": Json::number(2),
        "op": Json::string(if extra_at == "op" { "mystery" } else { "const" }),
        "codec": Json::string("int"),
        "value": Json::string("0"),
      }),
    ]),
    "result": Json::object(result_fields),
  }
  if extra_at == "recipe" {
    recipe_fields["extra"] = Json::boolean(true)
  }
  Json::object(recipe_fields)
}

///|
fn reset_validation_probe() -> Unit raise {
  @runtime.eval_str(
    "runtime.eval_str", "__import__('os').environ.pop('SYMBIT_RECIPE_VALIDATION_PROBE', None)",
  )
  |> ignore
}

///|
fn validation_probe_is_clean() -> Bool raise {
  @runtime.eval_str(
    "runtime.eval_str", "__import__('os').environ.get('SYMBIT_RECIPE_VALIDATION_PROBE', 'clean')",
  ) ==
  "clean"
}

///|
fn assert_rejected_before_side_effect(
  input : Json,
  fragment : String,
) -> Unit raise {
  reset_validation_probe()
  let rejected = try {
    @runtime.request("oracle.recipe.v1", input) |> ignore
    false
  } catch {
    ProtocolError(message) => message.contains(fragment)
    _ => false
  }
  let clean = validation_probe_is_clean()
  reset_validation_probe()
  assert_true(rejected)
  assert_true(clean)
}

///|
test "oracle recipe fully validates before side effects and stays result reachable" {
  assert_rejected_before_side_effect(
    side_effect_recipe("recipe"),
    "invalid fields",
  )
  assert_rejected_before_side_effect(
    side_effect_recipe("result"),
    "invalid fields",
  )
  assert_rejected_before_side_effect(
    side_effect_recipe("node"),
    "invalid fields",
  )
  assert_rejected_before_side_effect(
    side_effect_recipe("", schema=2),
    "schema must be 1",
  )
  assert_rejected_before_side_effect(
    side_effect_recipe("id"),
    "id must equal its array index",
  )
  assert_rejected_before_side_effect(side_effect_recipe("op"), "unknown op")
  assert_rejected_before_side_effect(
    side_effect_recipe("codec"),
    "unknown codec",
  )
  let forward_ref = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("exec"),
        "scope": recipe_ref(0),
        "code": Json::string(
          "__import__('os').environ['SYMBIT_RECIPE_VALIDATION_PROBE'] = 'dirty'",
        ),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("getattr"),
        "object": recipe_ref(3),
        "name": Json::string("missing"),
      }),
      Json::object({
        "id": Json::number(3),
        "op": Json::string("import"),
        "module": Json::string("builtins"),
      }),
    ],
    1,
    Json::string("discard"),
  )
  assert_rejected_before_side_effect(forward_ref, "earlier node")
  reset_validation_probe()
  let reachable_only = recipe_input(
    [
      Json::object({
        "id": Json::number(0),
        "op": Json::string("scope"),
        "profile": Json::string("sympy.base"),
      }),
      Json::object({
        "id": Json::number(1),
        "op": Json::string("exec"),
        "scope": recipe_ref(0),
        "code": Json::string(
          "__import__('os').environ['SYMBIT_RECIPE_VALIDATION_PROBE'] = 'dirty'",
        ),
      }),
      Json::object({
        "id": Json::number(2),
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string("42"),
      }),
    ],
    2,
    Json::string("int"),
  )
  assert_eq(
    @runtime.request("oracle.recipe.v1", reachable_only),
    Json::string("42"),
  )
  assert_true(validation_probe_is_clean())
  reset_validation_probe()
}
