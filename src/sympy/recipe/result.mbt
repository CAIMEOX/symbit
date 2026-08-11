///|
fn ResultCodec::to_json(self : ResultCodec) -> Json raise RecipeError {
  self.to_json_with([], 0)
}

///|
fn ResultCodec::to_json_with(
  self : ResultCodec,
  active_tuples : Array[Array[ResultCodec]],
  depth : Int,
) -> Json raise RecipeError {
  if depth > 64 {
    raise CodecTooDeep
  }
  match self {
    Discard => Json::string("discard")
    NoneValue => Json::string("none")
    Str => Json::string("str")
    Repr => Json::string("repr")
    Srepr => Json::string("srepr")
    Bool => Json::string("bool")
    Int => Json::string("int")
    Float => Json::string("float")
    Json => Json::string("json")
    Optional(item) =>
      Json::object({
        "kind": Json::string("optional"),
        "item": item.to_json_with(active_tuples, depth + 1),
      })
    List(item) =>
      Json::object({
        "kind": Json::string("list"),
        "item": item.to_json_with(active_tuples, depth + 1),
      })
    Tuple(items) => {
      for active in active_tuples {
        if physical_equal(active, items) {
          raise RecursiveCodec
        }
      }
      let nested_active = active_tuples.copy()
      nested_active.push(items)
      Json::object({
        "kind": Json::string("tuple"),
        "items": Json::array(
          [
            for item in items => item.to_json_with(nested_active, depth + 1)
          ],
        ),
      })
    }
    DictPairs(key, value) =>
      Json::object({
        "kind": Json::string("dict_pairs"),
        "key": key.to_json_with(active_tuples, depth + 1),
        "value": value.to_json_with(active_tuples, depth + 1),
      })
  }
}

///|
fn Builder::build_request(
  self : Builder,
  result : ValueRef,
  codec : ResultCodec,
) -> Json raise RecipeError {
  self.ensure_ref(result)
  Json::object({
    "schema": Json::number(1),
    "nodes": Json::array(self.nodes.copy()),
    "result": Json::object({
      "ref": Json::number(result.id.to_double()),
      "codec": codec.to_json(),
    }),
  })
}

///|
/// Seal this builder and execute its one worker request.
pub fn Builder::request(
  self : Builder,
  result : ValueRef,
  codec : ResultCodec,
) -> Json raise {
  let input = self.build_request(result, codec) catch {
    error => {
      self.closed = true
      raise error
    }
  }
  self.closed = true
  @runtime.request("oracle.recipe.v1", input)
}

///|
fn unexpected(expected : String, actual : Json) -> RecipeError {
  UnexpectedResult("expected " + expected + ", received " + actual.stringify())
}

///|
/// Execute the recipe and decode a Python `str` result.
pub fn Builder::request_str(self : Builder, result : ValueRef) -> String raise {
  match self.request(result, Str) {
    String(value) => value
    other => raise unexpected("a JSON string", other)
  }
}

///|
/// Execute the recipe and decode a Python `repr` result.
pub fn Builder::request_repr(self : Builder, result : ValueRef) -> String raise {
  match self.request(result, Repr) {
    String(value) => value
    other => raise unexpected("a JSON string", other)
  }
}

///|
/// Execute the recipe and decode a SymPy `srepr` result.
pub fn Builder::request_srepr(
  self : Builder,
  result : ValueRef,
) -> String raise {
  match self.request(result, Srepr) {
    String(value) => value
    other => raise unexpected("a JSON string", other)
  }
}

///|
/// Execute the recipe and decode a boolean result.
pub fn Builder::request_bool(self : Builder, result : ValueRef) -> Bool raise {
  match self.request(result, Bool) {
    True => true
    False => false
    other => raise unexpected("a JSON boolean", other)
  }
}

///|
/// Execute the recipe and decode an arbitrary precision integer as text.
pub fn Builder::request_int(self : Builder, result : ValueRef) -> String raise {
  match self.request(result, Int) {
    String(value) => value
    other => raise unexpected("a decimal integer string", other)
  }
}

///|
/// Execute the recipe and decode a Python float as text.
pub fn Builder::request_float(
  self : Builder,
  result : ValueRef,
) -> String raise {
  match self.request(result, Float) {
    String(value) => value
    other => raise unexpected("a float string", other)
  }
}

///|
/// Execute the recipe and return a JSON-compatible Python value.
pub fn Builder::request_json(self : Builder, result : ValueRef) -> Json raise {
  self.request(result, Json)
}

///|
/// Execute the recipe and require Python `None` as its result.
pub fn Builder::request_none(self : Builder, result : ValueRef) -> Unit raise {
  match self.request(result, NoneValue) {
    Null => ()
    other => raise unexpected("JSON null", other)
  }
}

///|
/// Execute the recipe and discard its result.
pub fn Builder::request_discard(
  self : Builder,
  result : ValueRef,
) -> Unit raise {
  match self.request(result, Discard) {
    Null => ()
    other => raise unexpected("JSON null", other)
  }
}
