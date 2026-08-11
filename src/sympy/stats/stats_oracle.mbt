///|
/// Oracle helpers for SymPy stats.

///|
fn stats_scope(builder : @recipe.Builder) -> @recipe.ValueRef raise {
  let builtins = builder.import_module("builtins")
  let sympy = builder.import_module("sympy")
  let stats = builder.import_module("sympy.stats")
  let scope = builder.dict([
    (Str("__builtins__"), Ref(builtins)),
    (Str("sympy"), Ref(sympy)),
    (Str("stats"), Ref(stats)),
  ])
  let setup = "for _name in (\n" +
    "    'symbols', 'Symbol', 'Integer', 'Rational', 'Eq', 'Ne', 'Lt', 'Le',\n" +
    "    'Gt', 'Ge', 'And', 'Or', 'Not', 'exp', 'log', 'sqrt', 'sin', 'cos',\n" +
    "    'tan', 'Lambda', 'Product', 'Sum', 'Indexed', 'IndexedBase', 'pi',\n" +
    "    'I', 'E', 'erf', 'erfc', 'erfinv', 'erfcinv', 'atan', 'Abs',\n" +
    "    'besseli', 'besselk', 'betaincinv', 'gammaincinv', 'gamma', 'beta',\n" +
    "    'lowergamma', 'EulerGamma', 'factorial', 'binomial', 'simplify',\n" +
    "    'srepr', 'oo', 'S', 'Matrix', 'MatrixSymbol', 'Trace', 'Determinant',\n" +
    "    'Inverse', 'Transpose', 'Identity', 'Integral', 'Piecewise', 'Tuple',\n" +
    "):\n" +
    "    if hasattr(sympy, _name):\n" +
    "        globals()[_name] = getattr(sympy, _name)\n" +
    "for _name in (\n" +
    "    'P', 'E', 'H', 'Probability', 'Expectation', 'Variance', 'Covariance',\n" +
    "    'variance', 'covariance', 'density', 'cdf', 'characteristic_function',\n" +
    "    'moment_generating_function', 'quantile', 'median', 'skewness',\n" +
    "    'kurtosis', 'entropy', 'factorial_moment', 'cmoment', 'smoment',\n" +
    "    'moment', 'correlation', 'dependent', 'given', 'pspace',\n" +
    "    'random_symbols', 'sample_stochastic_process', 'Die', 'Coin',\n" +
    "    'Bernoulli', 'DiscreteUniform', 'Binomial', 'Poisson', 'Geometric',\n" +
    "    'NegativeBinomial', 'Normal', 'Exponential', 'Gamma', 'PoissonProcess',\n" +
    "    'WienerProcess', 'Wishart', 'MatrixNormal', 'MatrixGamma',\n" +
    "    'MatrixStudentT',\n" +
    "):\n" +
    "    if hasattr(stats, _name):\n" +
    "        globals()[_name] = getattr(stats, _name)\n" +
    "for _name in (\n" +
    "    'x', 'y', 'z', 't', 'l', 'k', 'n', 'm', 'A', 'B', 'C', 'D', 'E0',\n" +
    "    'F', 'G', 'H0', 'I0', 'J', 'K', 'L', 'M', 'N', 'O', 'P0', 'Q',\n" +
    "    'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', '_H', '_i', '_j',\n" +
    "    '_k', '_x', '_y', '_z', '_s',\n" +
    "):\n" +
    "    try:\n" +
    "        globals()[_name] = sympy.Symbol(_name)\n" +
    "    except Exception:\n" +
    "        pass\n" +
    "del _name\n"
  builder.exec(scope, setup)
}

///|
fn stats_eval_value(
  builder : @recipe.Builder,
  expression : String,
) -> @recipe.ValueRef raise {
  let scope = stats_scope(builder)
  let builtins = builder.import_module("builtins")
  let evaluate = builder.getattr(builtins, "eval")
  let value = builder.call(evaluate, [Str(expression), Ref(scope), Ref(scope)])
  builder.require_non_none(value, message="python-eval-none")
}

///|
/// Evaluate a Python expression in the stats oracle profile and stringify it.
pub fn stats_eval_str(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let value = stats_eval_value(builder, expr)
  builder.request_str(value)
}

///|
/// Evaluate a stats expression, returning `None` when Python rejects it.
pub fn stats_try_eval_str(expr : String) -> String? {
  Some(stats_eval_str(expr)) catch {
    _ => None
  }
}

///|
/// Evaluate a stats expression and return its SymPy structural representation.
pub fn stats_eval_srepr(expr : String) -> String raise {
  let builder = @recipe.Builder::new()
  let value = stats_eval_value(builder, expr)
  builder.request_srepr(value)
}

///|
/// Test two stats expressions for symbolic or structural equivalence.
pub fn stats_expr_equiv(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let scope = stats_scope(builder)
  let sympy = builder.import_module("sympy")
  let sympify = builder.getattr(sympy, "sympify")
  let left = builder.call(sympify, [Str(a)], kwargs={ "locals": Ref(scope) })
  let left = builder.require_non_none(
    left,
    message="sympy-call-none:sympy.sympify",
  )
  let right = builder.call(sympify, [Str(b)], kwargs={ "locals": Ref(scope) })
  let right = builder.require_non_none(
    right,
    message="sympy-call-none:sympy.sympify",
  )
  let eq = builder.getattr(sympy, "Eq")
  let equality = builder.call(eq, [Ref(left), Ref(right)])
  let equality = builder.require_non_none(
    equality,
    message="sympy-call-none:sympy.Eq",
  )
  let simplify = builder.getattr(sympy, "simplify")
  let simplified = builder.call(simplify, [Ref(equality)])
  let simplified = builder.require_non_none(
    simplified,
    message="sympy-call-none:sympy.simplify",
  )
  let builtins = builder.import_module("builtins")
  let stringify = builder.getattr(builtins, "str")
  let text = builder.call(stringify, [Ref(simplified)])
  let srepr = builder.getattr(sympy, "srepr")
  let left_repr = builder.call(srepr, [Ref(left)])
  let right_repr = builder.call(srepr, [Ref(right)])
  let operator = builder.import_module("operator")
  let equal = builder.getattr(operator, "eq")
  let not_equal = builder.getattr(operator, "ne")
  let and_ = builder.getattr(operator, "and_")
  let or_ = builder.getattr(operator, "or_")
  let definitely_true = builder.call(equal, [Ref(text), Str("True")])
  let not_definitely_false = builder.call(not_equal, [Ref(text), Str("False")])
  let structurally_equal = builder.call(equal, [Ref(left_repr), Ref(right_repr)])
  let fallback = builder.call(and_, [
    Ref(not_definitely_false),
    Ref(structurally_equal),
  ])
  let result = builder.call(or_, [Ref(definitely_true), Ref(fallback)])
  builder.request_bool(result)
}

///|
/// Compare the structural representations of two evaluated stats expressions.
pub fn stats_srepr_eq(a : String, b : String) -> Bool raise {
  let builder = @recipe.Builder::new()
  let left = stats_eval_value(builder, a)
  let right = stats_eval_value(builder, b)
  let sympy = builder.import_module("sympy")
  let srepr = builder.getattr(sympy, "srepr")
  let left_repr = builder.call(srepr, [Ref(left)])
  let right_repr = builder.call(srepr, [Ref(right)])
  let operator = builder.import_module("operator")
  let equal = builder.getattr(operator, "eq")
  let result = builder.call(equal, [Ref(left_repr), Ref(right_repr)])
  builder.request_bool(result)
}
