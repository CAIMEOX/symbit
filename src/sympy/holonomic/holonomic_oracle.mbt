///|
pub type OracleArg = @sympy.OracleArg

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
}

///|
fn py_str_obj(obj : @py.PyObject) -> String {
  let state = py_gil_ensure()
  let s = obj.to_string()
  py_gil_release(state)
  s
}

///|
fn py_str_enum(obj : @py.PyObjectEnum) -> String {
  py_str_obj(objenum_to_obj(obj))
}

///|
fn py_eval(expr : String) -> @py.PyObjectEnum raise {
  let state = py_gil_ensure()
  let res = try {
    let builtins = match @py.pyimport("builtins") {
      Some(mod) => mod
      None => fail("py-builtins-missing")
    }
    let eval_obj = match builtins.get_attr("eval", print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-missing")
    }
    let eval_callable = match eval_obj {
      PyCallable(callable) => callable
      PyClass(obj0) =>
        @py.PyCallable::create(obj0) catch {
          _ => fail("py-callable")
        }
      other =>
        @py.PyCallable::create(objenum_to_obj(other)) catch {
          _ => fail("py-callable")
        }
    }
    let globals = @py.PyDict::new()
    globals.set("__builtins__", builtins.obj())
    let args = @sympy.py_pack_args([
      OracleArg::Str(expr),
      OracleArg::PyObj(globals.obj()),
      OracleArg::PyObj(globals.obj()),
    ])
    match @sympy.py_call_object(eval_callable, args, print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-none")
    }
  } catch {
    e => {
      py_gil_release(state)
      raise e
    }
  }
  py_gil_release(state)
  res
}

///|
fn py_eval_callable(expr : String) -> @py.PyCallable raise {
  match py_eval(expr) {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("py-callable")
      }
  }
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  match @sympy.py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("py-call-none")
  }
}

///|
pub fn recurrence_str(
  coeffs : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda coeffs, var, gen: (lambda sp, rec: (lambda n: (lambda pair: str(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in coeffs], pair[0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn recurrence_srepr(
  coeffs : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda coeffs, var, gen: (lambda sp, rec: (lambda n: (lambda pair: sp.srepr(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in coeffs], pair[0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn recurrence_mul_srepr(
  coeffs_a : Array[String],
  coeffs_b : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda a, b, var, gen: (lambda sp, rec: (lambda n: (lambda pair: sp.srepr(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in a], pair[0]) * rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in b], pair[0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs_a),
      OracleArg::StrList(coeffs_b),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn recurrence_pow_srepr(
  coeffs : Array[String],
  exp : Int,
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda a, e, var, gen: (lambda sp, rec: (lambda n: (lambda pair: sp.srepr(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in a], pair[0]) ** e))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperator', 'RecurrenceOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs),
      OracleArg::Int(exp),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn recurrence_expr_srepr(
  expr : String,
  var_name? : String = "n",
  generator? : String = "Sn",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda expr, var, gen: (lambda sp, rec: (lambda n, pair: sp.srepr(eval(expr, {'__builtins__': {}}, {var: n, gen: pair[1]})))(sp.symbols(var, integer=True), rec.RecurrenceOperators(sp.QQ.old_poly_ring(sp.symbols(var, integer=True)), gen)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['RecurrenceOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::Str(expr),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn differential_str(
  coeffs : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda coeffs, var, gen: str((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn differential_srepr(
  coeffs : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda coeffs, var, gen: __import__('sympy').srepr((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn differential_mul_srepr(
  coeffs_a : Array[String],
  coeffs_b : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda a, b, var, gen: __import__('sympy').srepr((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in a], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]) * hol.DifferentialOperator([sp.sympify(c) for c in b], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs_a),
      OracleArg::StrList(coeffs_b),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn differential_pow_srepr(
  coeffs : Array[String],
  exp : Int,
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda a, e, var, gen: __import__('sympy').srepr((lambda sp, hol: hol.DifferentialOperator([sp.sympify(c) for c in a], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]) ** e)(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperator', 'DifferentialOperators'])))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::StrList(coeffs),
      OracleArg::Int(exp),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn differential_expr_srepr(
  expr : String,
  var_name? : String = "x",
  generator? : String = "Dx",
) -> String raise {
  let fn_op = py_eval_callable(
    "lambda expr, var, gen: (lambda sp, hol: (lambda x, pair: sp.srepr(eval(expr, {'__builtins__': {}}, {var: x, gen: pair[1]})))(sp.symbols(var), hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['DifferentialOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_op, [
      OracleArg::Str(expr),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
    ]),
  )
}

///|
pub fn holonomic_str(
  coeffs : Array[String],
  var_name? : String = "x",
  generator? : String = "Dx",
  x0? : String = "0",
  y0? : Array[String] = [],
) -> String raise {
  let fn_hf = py_eval_callable(
    "lambda coeffs, var, gen, x0, y0: (lambda sp, hol: str(hol.HolonomicFunction(hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]), sp.symbols(var), sp.sympify(x0), [sp.sympify(v) for v in y0])) if len(y0) > 0 else str(hol.HolonomicFunction(hol.DifferentialOperator([sp.sympify(c) for c in coeffs], hol.DifferentialOperators(sp.QQ.old_poly_ring(sp.symbols(var)), gen)[0]), sp.symbols(var))))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['HolonomicFunction', 'DifferentialOperator', 'DifferentialOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_hf, [
      OracleArg::StrList(coeffs),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
      OracleArg::Str(x0),
      OracleArg::StrList(y0),
    ]),
  )
}

///|
pub fn sequence_str(
  coeffs : Array[String],
  var_name? : String = "n",
  generator? : String = "Sn",
  u0? : Array[String] = [],
) -> String raise {
  let fn_seq = py_eval_callable(
    "lambda coeffs, var, gen, u0: (lambda sp, rec: (lambda n: (lambda pair: str(rec.HolonomicSequence(rec.RecurrenceOperator([eval(c, {'__builtins__': {}}, {var: n}) for c in coeffs], pair[0]), [eval(v, {'__builtins__': {}}, {var: n}) for v in u0])))(rec.RecurrenceOperators(sp.QQ.old_poly_ring(n), gen)))(sp.symbols(var, integer=True)))(__import__('sympy'), __import__('sympy.holonomic.recurrence', fromlist=['HolonomicSequence', 'RecurrenceOperator', 'RecurrenceOperators']))",
  )
  py_str_enum(
    py_call_with_args(fn_seq, [
      OracleArg::StrList(coeffs),
      OracleArg::Str(var_name),
      OracleArg::Str(generator),
      OracleArg::StrList(u0),
    ]),
  )
}

///|
pub fn expr_to_holonomic_str(
  expr_str : String,
  var_name? : String = "x",
) -> String raise {
  let fn_expr = py_eval_callable(
    "lambda expr, var: str((lambda sp, hol: hol.expr_to_holonomic(sp.sympify(expr), sp.symbols(var)))(__import__('sympy'), __import__('sympy.holonomic.holonomic', fromlist=['expr_to_holonomic'])))",
  )
  py_str_enum(
    py_call_with_args(fn_expr, [
      OracleArg::Str(expr_str),
      OracleArg::Str(var_name),
    ]),
  )
}

///|
pub fn sympy_equiv_str(a : String, b : String) -> Bool raise {
  let fn_eq = py_eval_callable(
    "lambda a, b: str(__import__('sympy').simplify(__import__('sympy').sympify(a) - __import__('sympy').sympify(b)) == 0)",
  )
  py_str_enum(py_call_with_args(fn_eq, [OracleArg::Str(a), OracleArg::Str(b)])) ==
  "True"
}
