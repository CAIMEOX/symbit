///|
priv enum HolonomicArg {
  Text(String)
  Integer(Int)
  TextList(Array[String])
}

///|
fn HolonomicArg::materialize(
  self : HolonomicArg,
  builder : @recipe.Builder,
) -> @recipe.RecipeArg raise {
  match self {
    Text(value) => Str(value)
    Integer(value) => DecimalInt(value.to_string())
    TextList(values) => {
      let items : Array[@recipe.RecipeArg] = values.map(value => Str(value))
      Ref(builder.list(items))
    }
  }
}

///|
fn holonomic_call_str(
  callable_source : String,
  args : Array[HolonomicArg],
) -> String raise {
  let builder = @recipe.Builder::new()
  let builtins = builder.import_module("builtins")
  let scope = builder.dict([(Str("__builtins__"), Ref(builtins))])
  let callable = builder.eval(scope, callable_source)
  let call_args : Array[@recipe.RecipeArg] = []
  for argument in args {
    call_args.push(argument.materialize(builder))
  }
  let result = builder.call(callable, call_args)
  builder.request_str(result)
}

///|
pub fn recurrence_str(
  coeffs : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = "lambda coeffs, var, gen: (lambda sp, rec: (lambda n: (lambda pair: str(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in coeffs], pair[0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))"
  holonomic_call_str(fn_op, [TextList(coeffs), Text(var_name), Text(generator)])
}

///|
pub fn recurrence_srepr(
  coeffs : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = "lambda coeffs, var, gen: (lambda sp, rec: (lambda n: (lambda pair: sp.srepr(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in coeffs], pair[0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))"
  holonomic_call_str(fn_op, [TextList(coeffs), Text(var_name), Text(generator)])
}

///|
pub fn recurrence_mul_srepr(
  coeffs_a : Array[String],
  coeffs_b : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = "lambda a, b, var, gen: (lambda sp, rec: (lambda n: (lambda pair: sp.srepr(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in a], pair[0]) * rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in b], pair[0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))"
  holonomic_call_str(fn_op, [
    TextList(coeffs_a),
    TextList(coeffs_b),
    Text(var_name),
    Text(generator),
  ])
}

///|
pub fn recurrence_pow_srepr(
  coeffs : Array[String],
  exp : Int,
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = "lambda a, e, var, gen: (lambda sp, rec: (lambda n: (lambda pair: sp.srepr(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in a], pair[0]) ** e))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))"
  holonomic_call_str(fn_op, [
    TextList(coeffs),
    Integer(exp),
    Text(var_name),
    Text(generator),
  ])
}

///|
pub fn recurrence_expr_srepr(
  expr : String,
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = "lambda expr, var, gen: (lambda sp, rec: (lambda n, pair: sp.srepr(eval(expr, {'__builtins__': {}}, {var: n, gen: pair[1]})))(sp.symbols(var, integer=True), rec.RecurrenceOperators(sp.QQ.old_poly_ring(sp.symbols(var, integer=True)), gen)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperators']))"
  holonomic_call_str(fn_op, [Text(expr), Text(var_name), Text(generator)])
}

///|
pub fn differential_str(
  coeffs : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = "lambda coeffs, var, gen: str((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))"
  holonomic_call_str(fn_op, [TextList(coeffs), Text(var_name), Text(generator)])
}

///|
pub fn differential_srepr(
  coeffs : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = "lambda coeffs, var, gen: __import__('sympy').srepr((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))"
  holonomic_call_str(fn_op, [TextList(coeffs), Text(var_name), Text(generator)])
}

///|
pub fn differential_mul_srepr(
  coeffs_a : Array[String],
  coeffs_b : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = "lambda a, b, var, gen: __import__('sympy').srepr((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in a], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]) * hol.DifferentialOperator([sp.sympify(c) for c in b], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))"
  holonomic_call_str(fn_op, [
    TextList(coeffs_a),
    TextList(coeffs_b),
    Text(var_name),
    Text(generator),
  ])
}

///|
pub fn differential_pow_srepr(
  coeffs : Array[String],
  exp : Int,
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = "lambda a, e, var, gen: __import__('sympy').srepr((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in a], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]) ** e)(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))"
  holonomic_call_str(fn_op, [
    TextList(coeffs),
    Integer(exp),
    Text(var_name),
    Text(generator),
  ])
}

///|
pub fn differential_expr_srepr(
  expr : String,
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = "lambda expr, var, gen: (lambda sp, hol: (lambda x, pair: sp.srepr(eval(expr, {'__builtins__': {}}, {var: x, gen: pair[1]})))(sp.symbols(var), hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperators']))"
  holonomic_call_str(fn_op, [Text(expr), Text(var_name), Text(generator)])
}

///|
pub fn holonomic_str(
  coeffs : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
  x0? : String = "0",
  y0? : Array[String] = [],
) -> String raise {
  let fn_hf = "lambda coeffs, var, gen, x0, y0: (lambda sp, hol: str(hol.HolonomicFunction(hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]), sp.symbols(var), sp.sympify(x0), [sp.sympify(v) for v in y0])) if len(y0) > 0 else str(hol.HolonomicFunction(hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]), sp.symbols(var))))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['HolonomicFunction', 'DifferentialOperator', 'DifferentialOperators']))"
  holonomic_call_str(fn_hf, [
    TextList(coeffs),
    Text(var_name),
    Text(generator),
    Text(x0),
    TextList(y0),
  ])
}

///|
pub fn sequence_str(
  coeffs : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
  u0? : Array[String] = [],
) -> String raise {
  let fn_seq = "lambda coeffs, var, gen, u0: (lambda sp, rec: (lambda n: (lambda pair: str(rec.HolonomicSequence(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in coeffs], pair[0]), [eval(v, {'__builtins__': {}}, {var: n}) for v in u0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['HolonomicSequence', 'RecurrenceOperator', 'RecurrenceOperators']))"
  holonomic_call_str(fn_seq, [
    TextList(coeffs),
    Text(var_name),
    Text(generator),
    TextList(u0),
  ])
}

///|
pub fn expr_to_holonomic_str(
  expr_str : String,
  var_name? : String = "x",
) -> String raise {
  let fn_expr = "lambda expr, var: str((lambda sp, hol: hol.expr_to_holonomic(sp.sympify(expr), sp.symbols(var)))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['expr_to_holonomic'])))"
  holonomic_call_str(fn_expr, [Text(expr_str), Text(var_name)])
}

///|
pub fn sympy_equiv_str(a : String, b : String) -> Bool raise {
  let fn_eq = "lambda a, b: str(__import__('sympy').simplify(__import__('sympy').sympify(a) - __import__('sympy').sympify(b)) == 0)"
  holonomic_call_str(fn_eq, [Text(a), Text(b)]) == "True"
}
