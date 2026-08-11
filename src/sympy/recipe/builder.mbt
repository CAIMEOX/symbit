///|
/// Create an empty, open recipe builder.
pub fn Builder::new() -> Builder {
  { owner: { val: () }, nodes: [], closed: false }
}

///|
fn Builder::ensure_open(self : Builder) -> Unit raise RecipeError {
  if self.closed {
    raise BuilderClosed
  }
}

///|
fn Builder::ensure_ref(
  self : Builder,
  value : ValueRef,
) -> Unit raise RecipeError {
  self.ensure_open()
  if !physical_equal(self.owner, value.owner) {
    raise ForeignReference
  }
}

///|
fn Builder::validate_arg(
  self : Builder,
  argument : RecipeArg,
) -> Unit raise RecipeError {
  match argument {
    Ref(value) => self.ensure_ref(value)
    _ => self.ensure_open()
  }
}

///|
fn Builder::push_node(
  self : Builder,
  fields : Map[String, Json],
) -> ValueRef raise RecipeError {
  self.ensure_open()
  let id = self.nodes.length()
  fields["id"] = Json::number(id.to_double())
  self.nodes.push(Json::object(fields))
  { id, owner: self.owner }
}

///|
fn ValueRef::to_json(self : ValueRef) -> Json {
  Json::object({ "ref": Json::number(self.id.to_double()) })
}

///|
fn Builder::materialize(
  self : Builder,
  argument : RecipeArg,
) -> ValueRef raise RecipeError {
  match argument {
    Ref(value) => {
      self.ensure_ref(value)
      value
    }
    Null =>
      self.push_node({
        "op": Json::string("const"),
        "codec": Json::string("none"),
      })
    Bool(value) =>
      self.push_node({
        "op": Json::string("const"),
        "codec": Json::string("bool"),
        "value": Json::boolean(value),
      })
    Str(value) =>
      self.push_node({
        "op": Json::string("const"),
        "codec": Json::string("str"),
        "value": Json::string(value),
      })
    DecimalInt(value) =>
      self.push_node({
        "op": Json::string("const"),
        "codec": Json::string("int"),
        "value": Json::string(value),
      })
    DecimalFloat(value) =>
      self.push_node({
        "op": Json::string("const"),
        "codec": Json::string("float"),
        "value": Json::string(value),
      })
  }
}

///|
/// Add a scalar constant or reuse a value from this builder.
pub fn Builder::value(
  self : Builder,
  argument : RecipeArg,
) -> ValueRef raise RecipeError {
  self.materialize(argument)
}

///|
/// Import one Python module inside this request.
pub fn Builder::import_module(
  self : Builder,
  module_name : String,
) -> ValueRef raise RecipeError {
  self.push_node({
    "op": Json::string("import"),
    "module": Json::string(module_name),
  })
}

///|
/// Read one Python attribute from an earlier recipe value.
pub fn Builder::getattr(
  self : Builder,
  object : ValueRef,
  name : String,
) -> ValueRef raise RecipeError {
  self.ensure_ref(object)
  self.push_node({
    "op": Json::string("getattr"),
    "object": object.to_json(),
    "name": Json::string(name),
  })
}

///|
/// Read a Python attribute or lazily use an earlier fallback value when the
/// attribute is missing.
pub fn Builder::getattr_or(
  self : Builder,
  object : ValueRef,
  name : String,
  fallback : ValueRef,
) -> ValueRef raise RecipeError {
  self.ensure_ref(object)
  self.ensure_ref(fallback)
  self.push_node({
    "op": Json::string("getattr_or"),
    "object": object.to_json(),
    "name": Json::string(name),
    "fallback": fallback.to_json(),
  })
}

///|
/// Index an earlier Python value with a scalar or earlier recipe value.
pub fn Builder::getitem(
  self : Builder,
  object : ValueRef,
  key : RecipeArg,
) -> ValueRef raise RecipeError {
  self.ensure_ref(object)
  self.validate_arg(key)
  let key = self.materialize(key)
  self.push_node({
    "op": Json::string("getitem"),
    "object": object.to_json(),
    "key": key.to_json(),
  })
}

///|
/// Call an earlier Python callable.
pub fn Builder::call(
  self : Builder,
  callable : ValueRef,
  args : Array[RecipeArg],
  kwargs? : Map[String, RecipeArg] = {},
) -> ValueRef raise RecipeError {
  self.ensure_ref(callable)
  for argument in args {
    self.validate_arg(argument)
  }
  for _, argument in kwargs {
    self.validate_arg(argument)
  }
  let encoded_args : Array[Json] = []
  for argument in args {
    encoded_args.push(self.materialize(argument).to_json())
  }
  let encoded_kwargs : Map[String, Json] = Map([])
  for name, argument in kwargs {
    encoded_kwargs[name] = self.materialize(argument).to_json()
  }
  self.push_node({
    "op": Json::string("call"),
    "callable": callable.to_json(),
    "args": Json::array(encoded_args),
    "kwargs": Json::object(encoded_kwargs),
  })
}

///|
fn Builder::collection(
  self : Builder,
  kind : String,
  items : Array[RecipeArg],
) -> ValueRef raise RecipeError {
  self.ensure_open()
  for item in items {
    self.validate_arg(item)
  }
  let encoded : Array[Json] = []
  for item in items {
    encoded.push(self.materialize(item).to_json())
  }
  self.push_node({
    "op": Json::string("collection"),
    "kind": Json::string(kind),
    "items": Json::array(encoded),
  })
}

///|
/// Construct a Python list.
pub fn Builder::list(
  self : Builder,
  items : Array[RecipeArg],
) -> ValueRef raise RecipeError {
  self.collection("list", items)
}

///|
/// Construct a Python tuple.
pub fn Builder::tuple(
  self : Builder,
  items : Array[RecipeArg],
) -> ValueRef raise RecipeError {
  self.collection("tuple", items)
}

///|
/// Construct a Python set.
pub fn Builder::set(
  self : Builder,
  items : Array[RecipeArg],
) -> ValueRef raise RecipeError {
  self.collection("set", items)
}

///|
/// Construct a Python frozenset.
pub fn Builder::frozenset(
  self : Builder,
  items : Array[RecipeArg],
) -> ValueRef raise RecipeError {
  self.collection("frozenset", items)
}

///|
/// Construct a Python dictionary from key-value pairs.
pub fn Builder::dict(
  self : Builder,
  items : Array[(RecipeArg, RecipeArg)],
) -> ValueRef raise RecipeError {
  self.ensure_open()
  for item in items {
    let (key, value) = item
    self.validate_arg(key)
    self.validate_arg(value)
  }
  let encoded : Array[Json] = []
  for item in items {
    let (key, value) = item
    encoded.push(
      Json::array([
        self.materialize(key).to_json(),
        self.materialize(value).to_json(),
      ]),
    )
  }
  self.push_node({
    "op": Json::string("collection"),
    "kind": Json::string("dict"),
    "items": Json::array(encoded),
  })
}

///|
/// Create a fresh request-local scope with the fixed `sympy.base` profile.
pub fn Builder::sympy_scope(self : Builder) -> ValueRef raise RecipeError {
  self.push_node({
    "op": Json::string("scope"),
    "profile": Json::string("sympy.base"),
  })
}

///|
/// Bind a value into a request-local scope and return the resulting scope.
pub fn Builder::bind(
  self : Builder,
  scope : ValueRef,
  name : String,
  value : RecipeArg,
) -> ValueRef raise RecipeError {
  self.ensure_ref(scope)
  self.validate_arg(value)
  let value = self.materialize(value)
  self.push_node({
    "op": Json::string("bind"),
    "scope": scope.to_json(),
    "name": Json::string(name),
    "value": value.to_json(),
  })
}

///|
/// Execute statements in a request-local scope and return that scope.
pub fn Builder::exec(
  self : Builder,
  scope : ValueRef,
  code : String,
) -> ValueRef raise RecipeError {
  self.ensure_ref(scope)
  self.push_node({
    "op": Json::string("exec"),
    "scope": scope.to_json(),
    "code": Json::string(code),
  })
}

///|
/// Evaluate an expression in a request-local scope.
pub fn Builder::eval(
  self : Builder,
  scope : ValueRef,
  code : String,
) -> ValueRef raise RecipeError {
  self.ensure_ref(scope)
  self.push_node({
    "op": Json::string("eval"),
    "scope": scope.to_json(),
    "code": Json::string(code),
  })
}

///|
/// Require an earlier value to be different from Python `None`.
pub fn Builder::require_non_none(
  self : Builder,
  value : ValueRef,
  message? : String = "recipe value must not be None",
) -> ValueRef raise RecipeError {
  self.ensure_ref(value)
  self.push_node({
    "op": Json::string("require_non_none"),
    "value": value.to_json(),
    "message": Json::string(message),
  })
}
