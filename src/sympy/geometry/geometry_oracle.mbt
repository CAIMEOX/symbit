///|
/// Oracle helpers for SymPy geometry.

///|
fn geometry_scope(builder : @recipe.Builder) -> @recipe.ValueRef raise {
  let builtins = builder.import_module("builtins")
  let sympy = builder.import_module("sympy")
  let scope = builder.dict([
    (Str("__builtins__"), Ref(builtins)),
    (Str("sympy"), Ref(sympy)),
  ])
  let setup = "import sympy.geometry as _geometry\n" +
    "for _name in (\n" +
    "    'Point', 'Point2D', 'Point3D', 'Line', 'Line2D', 'Line3D',\n" +
    "    'Ray', 'Ray2D', 'Ray3D', 'Segment', 'Segment2D', 'Segment3D',\n" +
    "    'Plane', 'intersection', 'are_coplanar', 'centroid', 'Ellipse',\n" +
    "    'Circle', 'Polygon', 'RegularPolygon', 'Triangle', 'Parabola',\n" +
    "    'Curve', 'convex_hull', 'closest_points', 'farthest_points',\n" +
    "):\n" +
    "    if hasattr(_geometry, _name):\n" +
    "        globals()[_name] = getattr(_geometry, _name)\n" +
    "for _name in ('pi', 'oo', 'E', 'I'):\n" +
    "    if hasattr(sympy, _name):\n" +
    "        globals()[_name] = getattr(sympy, _name)\n" +
    "for _name in ('a', 'b', 'c', 'x', 'y', 'z', 't', 'u', 'v'):\n" +
    "    globals()[_name] = sympy.symbols(_name)\n" +
    "del _geometry, _name\n"
  builder.exec(scope, setup)
}

///|
fn geometry_eval_value(
  builder : @recipe.Builder,
  expression : String,
) -> @recipe.ValueRef raise {
  let scope = geometry_scope(builder)
  let builtins = builder.import_module("builtins")
  let evaluate = builder.getattr(builtins, "eval")
  let value = builder.call(evaluate, [Str(expression), Ref(scope), Ref(scope)])
  builder.require_non_none(value, message="python-eval-none")
}

///|
/// Evaluate a Python expression in the fixed geometry scope and stringify it.
pub fn geometry_eval_str(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let value = geometry_eval_value(builder, expr)
  builder.request_str(value)
}

///|
/// Evaluate a Python expression in the fixed geometry scope and return its repr.
pub fn geometry_eval_repr(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let value = geometry_eval_value(builder, expr)
  builder.request_repr(value)
}

///|
/// Evaluate and recursively summarize a geometry expression in one request.
pub fn geometry_summary(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let public_scope = geometry_scope(builder)
  let builtins = builder.import_module("builtins")
  let evaluate = builder.getattr(builtins, "eval")
  let value = builder.call(evaluate, [
    Str(expr),
    Ref(public_scope),
    Ref(public_scope),
  ])
  let summary_setup = "def _symbit_geometry_summary(obj):\n" +
    "    if isinstance(obj, list):\n" +
    "        return '[' + ', '.join(_symbit_geometry_summary(x) for x in obj) + ']'\n" +
    "    if isinstance(obj, tuple):\n" +
    "        return '(' + ', '.join(_symbit_geometry_summary(x) for x in obj) + ')'\n" +
    "    if isinstance(obj, (set, frozenset)):\n" +
    "        parts = sorted((_symbit_geometry_summary(x) for x in obj))\n" +
    "        return '{' + ', '.join(parts) + '}'\n" +
    "    return repr(obj)\n"
  let helper_scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let with_summary = builder.exec(helper_scope, summary_setup)
  let summarize = builder.getitem(with_summary, Str("_symbit_geometry_summary"))
  let result = builder.call(summarize, [Ref(value)])
  builder.request_str(result)
}

///|
/// Compare two geometry expressions using SymPy equality and simplification.
pub fn geometry_expr_equal(lhs : String, rhs : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let scope = geometry_scope(builder)
  let sympy = builder.getitem(scope, Str("sympy"))
  let sympify = builder.getattr(sympy, "sympify")
  let lhs_obj = builder.require_non_none(
    builder.call(sympify, [Str(lhs)], kwargs={ "locals": Ref(scope) }),
    message="sympy-call-none:sympy.sympify",
  )
  let rhs_obj = builder.require_non_none(
    builder.call(sympify, [Str(rhs)], kwargs={ "locals": Ref(scope) }),
    message="sympy-call-none:sympy.sympify",
  )
  let eq = builder.getattr(sympy, "Eq")
  let equality = builder.require_non_none(
    builder.call(eq, [Ref(lhs_obj), Ref(rhs_obj)]),
    message="sympy-call-none:sympy.Eq",
  )
  let simplify = builder.getattr(sympy, "simplify")
  let simplified = builder.require_non_none(
    builder.call(simplify, [Ref(equality)]),
    message="sympy-call-none:sympy.simplify",
  )
  builder.request_str(simplified) == "True"
}
