///|
test "utilities worker profile exposes the legacy evaluation aliases" {
  let expression =
    #|str(all((
    #|  getattr(__builtins__, '__name__', None) == 'builtins',
    #|  sympy.__name__ == 'sympy',
    #|  json.loads('[1]') == [1],
    #|  all(getattr(sympy, name) is globals()[name] for name in (
    #|    'Eq', 'Function', 'I', 'Integral', 'Pow', 'S', 'Symbol',
    #|    'acos', 'cos', 'cosh', 'exp', 'log', 'sin', 'sinh', 'sqrt')),
    #|  tuple(str(globals()[name]) for name in (
    #|    'x', 'y', 'z', 'C1', 'C2', 'C3', 'u2', '_a'))
    #|    == ('x', 'y', 'z', 'C1', 'C2', 'C3', 'u2', '_a'),
    #|  tuple(globals()[name].__name__ for name in ('f', 'g', 'h', 'u', 'X', 'Y'))
    #|    == ('f', 'g', 'h', 'u', 'X', 'Y'),
    #|)))
  assert_eq(@runtime.eval_str("utilities.eval_str", expression), "True")
}

///|
test "utilities worker profile scopes globals to each request" {
  assert_eq(
    @runtime.eval_str("utilities.eval_str", "globals().__setitem__('x', None)"),
    "None",
  )
  assert_eq(@runtime.eval_str("utilities.eval_str", "x"), "x")
}
