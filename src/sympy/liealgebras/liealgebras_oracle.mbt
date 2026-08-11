///|
fn call_method(
  builder : @recipe.Builder,
  object : @recipe.ValueRef,
  name : String,
  args : Array[@recipe.RecipeArg],
) -> @recipe.ValueRef raise {
  let callable = builder.getattr(object, name)
  builder.call(callable, args)
}

///|
fn construct(
  builder : @recipe.Builder,
  module_name : String,
  class_name : String,
  value : String,
) -> @recipe.ValueRef raise {
  let module_obj = builder.import_module(module_name)
  let class_ = builder.getattr(module_obj, class_name)
  builder.call(class_, [Str(value)])
}

///|
fn cartan_type(
  builder : @recipe.Builder,
  ct : String,
) -> @recipe.ValueRef raise {
  construct(builder, "sympy.liealgebras.cartan_type", "CartanType", ct)
}

///|
fn root_system(
  builder : @recipe.Builder,
  ct : String,
) -> @recipe.ValueRef raise {
  construct(builder, "sympy.liealgebras.root_system", "RootSystem", ct)
}

///|
fn weyl_group(builder : @recipe.Builder, ct : String) -> @recipe.ValueRef raise {
  construct(builder, "sympy.liealgebras.weyl_group", "WeylGroup", ct)
}

///|
fn formatter(
  builder : @recipe.Builder,
  name : String,
) -> @recipe.ValueRef raise {
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let source =
    #|def _symbit_list_string(items):
    #|    return '[' + ', '.join(str(item) for item in items) + ']'
    #|
    #|def _symbit_matrix_string(rows):
    #|    return '[' + ', '.join(_symbit_list_string(row) for row in rows) + ']'
    #|
    #|def _symbit_roots_map_string(roots):
    #|    entries = (
    #|        str(key) + ': [' + ', '.join(str(item) for item in roots[key]) + ']'
    #|        for key in sorted(roots)
    #|    )
    #|    return '{' + ', '.join(entries) + '}'
  let populated = builder.exec(scope, source)
  builder.getitem(populated, Str(name))
}

///|
fn format_list(
  builder : @recipe.Builder,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let format = formatter(builder, "_symbit_list_string")
  builder.call(format, [Ref(value)])
}

///|
fn format_matrix(
  builder : @recipe.Builder,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let format = formatter(builder, "_symbit_matrix_string")
  builder.call(format, [Ref(value)])
}

///|
fn format_roots_map(
  builder : @recipe.Builder,
  value : @recipe.ValueRef,
) -> @recipe.ValueRef raise {
  let format = formatter(builder, "_symbit_roots_map_string")
  builder.call(format, [Ref(value)])
}

///|
fn int_arg(value : Int) -> @recipe.RecipeArg {
  DecimalInt(Show::to_string(value))
}

///|
fn int_list(
  builder : @recipe.Builder,
  values : Array[Int],
) -> @recipe.ValueRef raise {
  let items : Array[@recipe.RecipeArg] = []
  for value in values {
    items.push(int_arg(value))
  }
  builder.list(items)
}

///|
/// Return the rank of a Cartan type using SymPy's canonical string form.
pub fn cartan_type_rank_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let rank = call_method(builder, object, "rank", [])
  builder.request_str(rank)
}

///|
/// Return the series letter of a Cartan type.
pub fn cartan_type_series_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let series = builder.getattr(object, "series")
  builder.request_str(series)
}

///|
/// Return a Cartan matrix as the legacy unquoted nested-list string.
pub fn cartan_matrix_list_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = construct(
    builder, "sympy.liealgebras.cartan_matrix", "CartanMatrix", ct,
  )
  let rows = call_method(builder, object, "tolist", [])
  let result = format_matrix(builder, rows)
  builder.request_str(result)
}

///|
/// Return SymPy's textual Dynkin diagram for a Cartan type.
pub fn dynkin_diagram_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let diagram = construct(
    builder, "sympy.liealgebras.dynkin_diagram", "DynkinDiagram", ct,
  )
  builder.request_str(diagram)
}

///|
/// Return the dimension of a Cartan type.
pub fn cartan_type_dimension_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let dimension = call_method(builder, object, "dimension", [])
  builder.request_str(dimension)
}

///|
/// Return the number of roots of a Cartan type.
pub fn cartan_type_roots_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let roots = call_method(builder, object, "roots", [])
  builder.request_str(roots)
}

///|
/// Return the basis size after preserving the legacy Python integer coercion.
pub fn cartan_type_basis_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let basis = call_method(builder, object, "basis", [])
  let builtins = builder.import_module("builtins")
  let int_ = builder.getattr(builtins, "int")
  let coerced = builder.call(int_, [Ref(basis)])
  builder.request_str(coerced)
}

///|
/// Return the conventional Lie algebra name of a Cartan type.
pub fn cartan_type_lie_algebra_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let algebra = call_method(builder, object, "lie_algebra", [])
  builder.request_str(algebra)
}

///|
/// Return a simple root as the legacy unquoted list string.
pub fn cartan_type_simple_root_list_str(
  ct : String,
  index : Int,
) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let root = call_method(builder, object, "simple_root", [int_arg(index)])
  let result = format_list(builder, root)
  builder.request_str(result)
}

///|
/// Return the highest root as the legacy unquoted list string.
pub fn cartan_type_highest_root_list_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let root = call_method(builder, object, "highest_root", [])
  let result = format_list(builder, root)
  builder.request_str(result)
}

///|
/// Return positive roots in deterministic key order.
pub fn cartan_type_positive_roots_map_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = cartan_type(builder, ct)
  let roots = call_method(builder, object, "positive_roots", [])
  let result = format_roots_map(builder, roots)
  builder.request_str(result)
}

///|
/// Return the simple roots of a root system in deterministic key order.
pub fn root_system_simple_roots_map_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = root_system(builder, ct)
  let roots = call_method(builder, object, "simple_roots", [])
  let result = format_roots_map(builder, roots)
  builder.request_str(result)
}

///|
/// Return every root of a root system in deterministic key order.
pub fn root_system_all_roots_map_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = root_system(builder, ct)
  let roots = call_method(builder, object, "all_roots", [])
  let result = format_roots_map(builder, roots)
  builder.request_str(result)
}

///|
/// Return SymPy's textual description of a root space.
pub fn root_system_root_space_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = root_system(builder, ct)
  let space = call_method(builder, object, "root_space", [])
  builder.request_str(space)
}

///|
/// Add two indexed simple roots and return the legacy unquoted list string.
pub fn root_system_add_simple_roots_list_str(
  ct : String,
  root1 : Int,
  root2 : Int,
) -> String raise {
  let builder = @recipe.Builder::new()
  let object = root_system(builder, ct)
  let root = call_method(builder, object, "add_simple_roots", [
    int_arg(root1),
    int_arg(root2),
  ])
  let result = format_list(builder, root)
  builder.request_str(result)
}

///|
/// Add two root vectors and return SymPy's canonical result string.
pub fn root_system_add_as_roots_str(
  ct : String,
  root1 : Array[Int],
  root2 : Array[Int],
) -> String raise {
  let builder = @recipe.Builder::new()
  let object = root_system(builder, ct)
  let left = int_list(builder, root1)
  let right = int_list(builder, root2)
  let result = call_method(builder, object, "add_as_roots", [
    Ref(left),
    Ref(right),
  ])
  builder.request_str(result)
}

///|
/// Return Weyl-group generators as the legacy unquoted list string.
pub fn weyl_group_generators_list_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = weyl_group(builder, ct)
  let generators = call_method(builder, object, "generators", [])
  let result = format_list(builder, generators)
  builder.request_str(result)
}

///|
/// Return the Weyl-group order after preserving legacy integer coercion.
pub fn weyl_group_group_order_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = weyl_group(builder, ct)
  let order = call_method(builder, object, "group_order", [])
  let builtins = builder.import_module("builtins")
  let int_ = builder.getattr(builtins, "int")
  let coerced = builder.call(int_, [Ref(order)])
  builder.request_str(coerced)
}

///|
/// Return SymPy's conventional Weyl-group name.
pub fn weyl_group_group_name_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = weyl_group(builder, ct)
  let name = call_method(builder, object, "group_name", [])
  builder.request_str(name)
}

///|
/// Return the order of a Weyl-group element.
pub fn weyl_group_element_order_str(ct : String, elt : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = weyl_group(builder, ct)
  let order = call_method(builder, object, "element_order", [Str(elt)])
  let builtins = builder.import_module("builtins")
  let int_ = builder.getattr(builtins, "int")
  let coerced = builder.call(int_, [Ref(order)])
  builder.request_str(coerced)
}

///|
/// Return the matrix form of a Weyl-group element as a nested-list string.
pub fn weyl_group_matrix_form_list_str(
  ct : String,
  elt : String,
) -> String raise {
  let builder = @recipe.Builder::new()
  let object = weyl_group(builder, ct)
  let matrix = call_method(builder, object, "matrix_form", [Str(elt)])
  let rows = call_method(builder, matrix, "tolist", [])
  let result = format_matrix(builder, rows)
  builder.request_str(result)
}

///|
/// Return SymPy's textual Coxeter diagram for a Weyl group.
pub fn weyl_group_coxeter_diagram_str(ct : String) -> String raise {
  let builder = @recipe.Builder::new()
  let object = weyl_group(builder, ct)
  let diagram = call_method(builder, object, "coxeter_diagram", [])
  builder.request_str(diagram)
}
