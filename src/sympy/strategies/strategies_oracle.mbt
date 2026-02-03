///|
pub type OracleArg = @sympy.OracleArg

///|
fn sympy_call(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum? raise {
  @sympy.sympy_call(path, args, kwargs~)
}

///|
fn sympy_call_must(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObjectEnum raise {
  match sympy_call(path, args, kwargs~) {
    Some(obj) => obj
    None => fail("sympy-call-none:\{path}")
  }
}

///|
fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object(callable, args, print_err~)
}

///|
fn py_call_object_kwargs(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  kwargs? : @py.PyDict = @py.PyDict::new(),
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  @sympy.py_call_object_kwargs(callable, args, kwargs~, print_err~)
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
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
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
fn py_int_enum(obj : @py.PyObjectEnum) -> Int raise {
  match obj {
    PyInteger(v) => v.to_int64().to_int()
    _ => fail("py-int-expected")
  }
}

///|
fn py_list_from_objects(values : Array[@py.PyObject]) -> @py.PyList {
  let state = py_gil_ensure()
  let list = @py.PyList::new()
  for v in values {
    list.append(v)
  }
  py_gil_release(state)
  list
}

///|
fn py_list_to_pyobjects(value : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let state = py_gil_ensure()
  let out : Array[@py.PyObject] = Array::new()
  let res = try {
    match value {
      PyList(list) => {
        let len = list.len()
        for i in 0..<len {
          match list.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      PyTuple(tup) => {
        let len = tup.len().to_int()
        for i in 0..<len {
          match tup.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
        out
      }
      _ => fail("expected list/tuple")
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
fn py_list_to_strings(value : @py.PyObjectEnum) -> Array[String] raise {
  let items = py_list_to_pyobjects(value)
  let out : Array[String] = Array::new()
  for item in items {
    out.push(py_str_obj(item))
  }
  out
}

///|
fn py_list_to_ints(value : @py.PyObjectEnum) -> Array[Int] raise {
  let items = py_list_to_pyobjects(value)
  let out : Array[Int] = Array::new()
  for item in items {
    out.push(py_int_enum(@py.PyObjectEnum::create(item)))
  }
  out
}

///|
fn py_callable_from_enum(obj : @py.PyObjectEnum) -> @py.PyCallable raise {
  match obj {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-callable")
      }
    _ =>
      @py.PyCallable::create(objenum_to_obj(obj)) catch {
        _ => fail("py-callable")
      }
  }
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
    let eval_callable = py_callable_from_enum(eval_obj)
    let globals = @py.PyDict::new()
    globals.set("__builtins__", builtins.obj())
    let args = @sympy.py_pack_args([
      OracleArg::Str(expr),
      OracleArg::PyObj(globals.obj()),
      OracleArg::PyObj(globals.obj()),
    ])
    match py_call_object(eval_callable, args, print_err=true) {
      Some(obj) => obj
      None => fail("py-eval-none")
    }
  } catch {
    err => {
      py_gil_release(state)
      raise err
    }
  } noraise {
    v => v
  }
  py_gil_release(state)
  res
}

///|
fn py_eval_obj(expr : String) -> @py.PyObject raise {
  objenum_to_obj(py_eval(expr))
}

///|
fn py_eval_callable(expr : String) -> @py.PyCallable raise {
  py_callable_from_enum(py_eval(expr))
}

///|
fn py_call_with_args(
  callable : @py.PyCallable,
  args : Array[OracleArg],
) -> @py.PyObjectEnum raise {
  let tup = @sympy.py_pack_args(args)
  match py_call_object(callable, tup, print_err=true) {
    Some(obj) => obj
    None => fail("py-call-none")
  }
}

///|
fn py_eval_int(expr : String) -> Int raise {
  py_int_enum(py_eval(expr))
}

///|
fn py_eval_str(expr : String) -> String raise {
  py_str_enum(py_eval(expr))
}

///|
fn py_eval_list_int(expr : String) -> Array[Int] raise {
  py_list_to_ints(py_eval(expr))
}

///|
fn py_eval_list_str(expr : String) -> Array[String] raise {
  py_list_to_strings(py_eval(expr))
}

let sym : String = "__import__('sympy')"

///|
/// Core oracles
pub fn core_null_safe(x : Int) -> Int raise {
  py_eval_int("\{sym}.strategies.core.null_safe(lambda x: 2 if x==1 else None)(\{x})")
}

///|
pub fn core_exhaust_posdec(x : Int) -> Int raise {
  py_eval_int("\{sym}.strategies.core.exhaust(lambda x: x-1 if x>0 else x)(\{x})")
}

///|
pub fn core_memoize_posdec(x : Int) -> Int raise {
  py_eval_int("\{sym}.strategies.core.memoize(lambda x: x-1 if x>0 else x)(\{x})")
}

///|
pub fn core_condition_posdec(x : Int) -> Int raise {
  py_eval_int("\{sym}.strategies.core.condition(lambda x: x%2==0, lambda x: x-1 if x>0 else x)(\{x})")
}

///|
pub fn core_chain_posdec(x : Int) -> Int raise {
  py_eval_int("\{sym}.strategies.core.chain(lambda x: x-1 if x>0 else x, lambda x: x-1 if x>0 else x)(\{x})")
}

///|
pub fn core_tryit_assertion(x : Int) -> Int raise {
  py_eval_int(
    "\{sym}.strategies.core.tryit(lambda x: (_ for _ in ()).throw(AssertionError()), AssertionError)(\{x})",
  )
}

///|
pub fn core_do_one_posdec(x : Int) -> Int raise {
  py_eval_int("\{sym}.strategies.core.do_one(lambda x: x-1 if x>0 else x, lambda x: x-1 if x>0 else x)(\{x})")
}

///|
pub fn core_do_one_pair(x : Int) -> Int raise {
  py_eval_int(
    "\{sym}.strategies.core.do_one(lambda x: 2 if x==1 else x, lambda x: 3 if x==2 else x)(\{x})",
  )
}

///|
pub fn core_switch_mod3(x : Int) -> Int raise {
  py_eval_int(
    "\{sym}.strategies.core.switch(lambda x: x%3, {0: (lambda x: x+1), 1: (lambda x: x-1)})(\{x})",
  )
}

///|
pub fn core_minimize(x : Int, maximize? : Bool = false) -> Int raise {
  if maximize {
    py_eval_int(
      "\{sym}.strategies.core.minimize(lambda x: x+1, lambda x: x-1, objective=lambda x: -x)(\{x})",
    )
  } else {
    py_eval_int("\{sym}.strategies.core.minimize(lambda x: x+1, lambda x: x-1)(\{x})")
  }
}

///|
pub fn core_debug_log_posdec(x : Int) -> String raise {
  py_eval_str(
    "(lambda sym, io: (lambda rule, buf: (sym.strategies.core.debug(rule, buf)(\{x}), buf.getvalue())[1])((lambda g: (setattr(g, '__name__', 'posdec') or g))(lambda x: x-1 if x>0 else x), io.StringIO()))(\{sym}, __import__('io'))",
  )
}

///|
/// RL oracles
pub fn rl_rm_id(expr : @symcore.Expr) -> String raise {
  let isid = py_eval_callable("lambda x: x==0")
  let rule_enum = sympy_call_must("sympy.strategies.rl.rm_id", [OracleArg::PyObj(isid.obj())])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn rl_glom(expr : @symcore.Expr) -> String raise {
  let key = py_eval_callable("lambda t: t.as_coeff_Mul()[1]")
  let count = py_eval_callable("lambda t: t.as_coeff_Mul()[0]")
  let combine = py_eval_callable("lambda cnt, arg: cnt*arg")
  let rule_enum = sympy_call_must("sympy.strategies.rl.glom", [
    OracleArg::PyObj(key.obj()),
    OracleArg::PyObj(count.obj()),
    OracleArg::PyObj(combine.obj()),
  ])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn rl_flatten(expr : @symcore.Expr) -> String raise {
  let res = sympy_call_must("sympy.strategies.rl.flatten", [
    OracleArg::PyObj(expr_to_sympy(expr)),
  ])
  py_str_enum(res)
}

///|
pub fn rl_unpack(expr : @symcore.Expr) -> String raise {
  let res = sympy_call_must("sympy.strategies.rl.unpack", [
    OracleArg::PyObj(expr_to_sympy(expr)),
  ])
  py_str_enum(res)
}

///|
pub fn rl_sort(expr : @symcore.Expr) -> String raise {
  let key = py_eval_callable("lambda x: str(x)")
  let rule_enum = sympy_call_must("sympy.strategies.rl.sort", [OracleArg::PyObj(key.obj())])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn rl_distribute_custom() -> String raise {
  let expr =
    "(lambda sym: (lambda T1, T2: sym.strategies.rl.distribute(T1, T2)(T1(1, 2, T2(3, 4), 5)))(type('T1', (sym.core.basic.Basic,), {}), type('T2', (sym.core.basic.Basic,), {})))(\{sym})"
  py_eval_str(expr)
}

///|
pub fn rl_distribute_add_mul(expr : @symcore.Expr) -> String raise {
  let sym_mod = match @py.pyimport("sympy") {
    Some(mod) => mod
    None => fail("sympy-missing")
  }
  let mul_obj = match sym_mod.get_attr("Mul", print_err=true) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-mul-missing")
  }
  let add_obj = match sym_mod.get_attr("Add", print_err=true) {
    Some(obj) => objenum_to_obj(obj)
    None => fail("sympy-add-missing")
  }
  let rule_enum = sympy_call_must("sympy.strategies.rl.distribute", [
    OracleArg::PyObj(mul_obj),
    OracleArg::PyObj(add_obj),
  ])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn rl_subs(
  expr : @symcore.Expr,
  a : @symcore.Expr,
  b : @symcore.Expr,
) -> String raise {
  let rule_enum = sympy_call_must("sympy.strategies.rl.subs", [
    OracleArg::PyObj(expr_to_sympy(a)),
    OracleArg::PyObj(expr_to_sympy(b)),
  ])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn rl_rebuild(expr : @symcore.Expr) -> String raise {
  let res = sympy_call_must("sympy.strategies.rl.rebuild", [
    OracleArg::PyObj(expr_to_sympy(expr)),
  ])
  py_str_enum(res)
}

///|
/// Traverse oracles
pub fn traverse_sall_zero_symbols(expr : @symcore.Expr) -> String raise {
  let rule = py_eval_callable(
    "lambda e: __import__('sympy').S.Zero if isinstance(e, __import__('sympy').Symbol) else e",
  )
  let trav_enum = sympy_call_must("sympy.strategies.traverse.sall", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn traverse_top_down_zero_symbols(expr : @symcore.Expr) -> String raise {
  let rule = py_eval_callable(
    "lambda e: __import__('sympy').S.Zero if isinstance(e, __import__('sympy').Symbol) else e",
  )
  let trav_enum = sympy_call_must("sympy.strategies.traverse.top_down", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn traverse_bottom_up_zero_symbols(expr : @symcore.Expr) -> String raise {
  let rule = py_eval_callable(
    "lambda e: __import__('sympy').S.Zero if isinstance(e, __import__('sympy').Symbol) else e",
  )
  let trav_enum = sympy_call_must("sympy.strategies.traverse.bottom_up", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn traverse_top_down_once(expr : @symcore.Expr) -> String raise {
  let rule = py_eval_callable(
    "(lambda sym: (lambda Basic2: (lambda x: Basic2(*x.args) if x.args and not isinstance(x.args[0], sym.Integer) else x))(type('Basic2', (sym.core.basic.Basic,), {})))(\{sym})",
  )
  let trav_enum = sympy_call_must("sympy.strategies.traverse.top_down_once", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn traverse_bottom_up_once(expr : @symcore.Expr) -> String raise {
  let rule = py_eval_callable(
    "(lambda sym: (lambda Basic2: (lambda x: Basic2(*x.args) if x.args and not isinstance(x.args[0], sym.Integer) else x))(type('Basic2', (sym.core.basic.Basic,), {})))(\{sym})",
  )
  let trav_enum = sympy_call_must("sympy.strategies.traverse.bottom_up_once", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn traverse_expr_fns(expr : @symcore.Expr) -> String raise {
  let rule = py_eval_callable("lambda v: v + 1")
  let trav_enum = sympy_call_must("sympy.strategies.traverse.bottom_up", [
    OracleArg::PyObj(rule.obj()),
    OracleArg::PyObj(py_eval_obj("__import__('sympy').strategies.util.expr_fns")),
  ])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
/// Tools oracles
pub fn tools_subs(expr : @symcore.Expr, mapping : Map[@symcore.Expr, @symcore.Expr]) -> String raise {
  let dict = @py.PyDict::new()
  for k, v in mapping {
    let key_obj = expr_to_sympy(k)
    let val_obj = expr_to_sympy(v)
    dict.setByObj(key_obj, val_obj)
  }
  let rule_enum = sympy_call_must("sympy.strategies.tools.subs", [OracleArg::PyObj(dict.obj())])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn tools_subs_empty(expr : @symcore.Expr) -> String raise {
  let rule_enum = sympy_call_must("sympy.strategies.tools.subs", [OracleArg::Dict({})])
  let rule = py_callable_from_enum(rule_enum)
  let res = py_call_with_args(rule, [OracleArg::PyObj(expr_to_sympy(expr))])
  py_str_enum(res)
}

///|
pub fn tools_typed(expr : @symcore.Expr) -> String raise {
  let expr_str = py_str_obj(expr_to_sympy(expr))
  let code =
    "(lambda sym: (lambda A, B: (lambda rmzeros, rmones: sym.strategies.tools.typed({A: rmzeros, B: rmones})(\{expr_str}))(sym.strategies.rl.rm_id(lambda x: x==sym.S(0)), sym.strategies.rl.rm_id(lambda x: x==sym.S(1))))(type('A', (sym.core.basic.Basic,), {}), type('B', (sym.core.basic.Basic,), {})))(\{sym})"
  py_eval_str(code)
}

///|
/// Tree oracles
pub fn tree_treeapply_minmax() -> Int raise {
  py_eval_int("__import__('sympy').strategies.tree.treeapply(([3, 3], [4, 1], 2), {list: min, tuple: max})")
}

///|
pub fn tree_treeapply_addmul() -> Int raise {
  py_eval_int(
    "(lambda add, mul: __import__('sympy').strategies.tree.treeapply(([3, 3], [4, 1], 2), {list: add, tuple: mul}))(lambda *args: sum(args), lambda *args: __import__('functools').reduce(lambda a,b: a*b, args, 1))",
  )
}

///|
pub fn tree_treeapply_leaf_square() -> Int raise {
  py_eval_int("__import__('sympy').strategies.tree.treeapply(3, {}, leaf=lambda x: x**2)")
}

///|
pub fn tree_treeapply_strategies_1() -> Int raise {
  py_eval_int(
    "(lambda inc, dec: __import__('sympy').strategies.tree.treeapply((inc, dec), {list: __import__('sympy').strategies.chain, tuple: __import__('sympy').strategies.minimize})(5))(lambda x: x+1, lambda x: x-1)",
  )
}

///|
pub fn tree_treeapply_strategies_2() -> Int raise {
  py_eval_int(
    "(lambda inc, dec, double: __import__('sympy').strategies.tree.treeapply((inc, [dec, double]), {list: __import__('sympy').strategies.chain, tuple: __import__('sympy').strategies.minimize})(1))(lambda x: x+1, lambda x: x-1, lambda x: 2*x)",
  )
}

///|
pub fn tree_treeapply_maximize(x : Int) -> Int raise {
  py_eval_int(
    "(lambda inc, dec, double: __import__('sympy').strategies.tree.treeapply((inc, [dec, double]), {list: __import__('sympy').strategies.chain, tuple: (lambda *rules: __import__('sympy').strategies.minimize(*rules, objective=lambda x: -x))})(\{x}))(lambda x: x+1, lambda x: x-1, lambda x: 2*x)",
  )
}

///|
pub fn tree_greedy_max(x : Int) -> Int raise {
  py_eval_int(
    "(lambda inc, dec, double: __import__('sympy').strategies.tree.greedy([inc, (dec, double)], objective=lambda x: -x)(\{x}))(lambda x: x+1, lambda x: x-1, lambda x: 2*x)",
  )
}

///|
pub fn tree_greedy_chain(x : Int, maximize? : Bool = false) -> Int raise {
  if maximize {
    py_eval_int(
      "(lambda inc, dec: __import__('sympy').strategies.tree.greedy([inc, dec, [inc, dec, [(inc, inc), (dec, dec)]]], objective=lambda x: -x)(\{x}))(lambda x: x+1, lambda x: x-1)",
    )
  } else {
    py_eval_int(
      "(lambda inc, dec: __import__('sympy').strategies.tree.greedy([inc, dec, [inc, dec, [(inc, inc), (dec, dec)]]])(\{x}))(lambda x: x+1, lambda x: x-1)",
    )
  }
}

///|
pub fn tree_allresults_1(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda inc, dec, double: list(__import__('sympy').strategies.tree.allresults([inc, (dec, double)])(\{x})))(lambda x: x+1, lambda x: x-1, lambda x: 2*x)",
  )
}

///|
pub fn tree_allresults_2(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda inc, dec: list(__import__('sympy').strategies.tree.allresults([inc, dec])(\{x})))(lambda x: x+1, lambda x: x-1)",
  )
}

///|
pub fn tree_allresults_3(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda inc, dec: list(__import__('sympy').strategies.tree.allresults((inc, dec))(\{x})))(lambda x: x+1, lambda x: x-1)",
  )
}

///|
pub fn tree_allresults_single(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda inc: list(__import__('sympy').strategies.tree.allresults(inc)(\{x})))(lambda x: x+1)",
  )
}

///|
pub fn tree_brute(x : Int) -> Int raise {
  py_eval_int(
    "(lambda inc, dec, square: __import__('sympy').strategies.tree.brute(([inc, dec], square), lambda x: -x)(\{x}))(lambda x: x+1, lambda x: x-1, lambda x: x**2)",
  )
}

///|
pub fn tree_brute_inc(x : Int) -> Int raise {
  py_eval_int(
    "(lambda inc: __import__('sympy').strategies.tree.brute(inc)(\{x}))(lambda x: x+1)",
  )
}

///|
/// Branch core oracles
pub fn branch_exhaust_branch5(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda branch5: list(__import__('sympy').strategies.branch.core.exhaust(branch5)(\{x})))(lambda x: [x-1] if 0<x<5 else ([x+1] if 5<x<10 else ([x+1, x-1] if x==5 else [x])))",
  )
}

///|
pub fn branch_debug_posdec(x : Int) -> String raise {
  py_eval_str(
    "(lambda sym, io: (lambda rule, buf: (list(sym.strategies.branch.core.debug(rule, buf)(\{x})), buf.getvalue())[1])((lambda g: (setattr(g, '__name__', 'posdec') or g))(lambda x: [x-1] if x>0 else [x]), io.StringIO()))(\{sym}, __import__('io'))",
  )
}

///|
pub fn branch_multiplex_posdec_branch5(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda posdec, branch5: list(__import__('sympy').strategies.branch.core.multiplex(posdec, branch5)(\{x})))(lambda x: [x-1] if x>0 else [x], lambda x: [x-1] if 0<x<5 else ([x+1] if 5<x<10 else ([x+1, x-1] if x==5 else [x])))",
  )
}

///|
pub fn branch_condition_even_branch5(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda branch5: list(__import__('sympy').strategies.branch.core.condition(lambda x: x%2==0, branch5)(\{x})))(lambda x: [x-1] if 0<x<5 else ([x+1] if 5<x<10 else ([x+1, x-1] if x==5 else [x])))",
  )
}

///|
pub fn branch_sfilter_even_one_to_n(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda one_to_n: list(__import__('sympy').strategies.branch.core.sfilter(lambda x: x%2==0, one_to_n)(\{x})))(lambda n: list(range(n)))",
  )
}

///|
pub fn branch_notempty_even_only(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda ident_if_even: list(__import__('sympy').strategies.branch.core.notempty(ident_if_even)(\{x})))(lambda n: [n] if n%2==0 else [])",
  )
}

///|
pub fn branch_chain_examples(x : Int, kind : Int) -> Array[Int] raise {
  let base =
    "(lambda inc, branch5: list(__import__('sympy').strategies.branch.core.chain__CHAIN_ARGS__(\{x})))(lambda x: [x+1], lambda x: [x-1] if 0<x<5 else ([x+1] if 5<x<10 else ([x+1, x-1] if x==5 else [x])))"
  let chain_args = match kind {
    0 => "()"
    1 => "(inc, inc)"
    2 => "(branch5, inc)"
    3 => "(branch5, inc)"
    4 => "(inc, branch5)"
    _ => "()"
  }
  py_eval_list_int(base.replace_all(old="__CHAIN_ARGS__", new=chain_args))
}

///|
pub fn branch_onaction_inc() -> Array[String] raise {
  py_eval_list_str(
    "(lambda sym: (lambda L, inc: (list(sym.strategies.branch.core.onaction(inc, lambda fn, i, o: L.append((i, o)))(2)), L)[1])([], lambda x: [x+1]))(\{sym})",
  )
}

///|
pub fn branch_yieldify_inc(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda inc: list(__import__('sympy').strategies.branch.core.yieldify(inc)(\{x})))(lambda x: x+1)",
  )
}

///|
pub fn branch_do_one_inc_posdec(x : Int) -> Array[Int] raise {
  py_eval_list_int(
    "(lambda inc, posdec: list(__import__('sympy').strategies.branch.core.do_one(inc, posdec)(\{x})))(lambda x: [x+1], lambda x: [x-1] if x>0 else [x])",
  )
}

///|
/// Branch traverse oracles
pub fn branch_traverse_top_down_inc(expr : @symcore.Expr) -> Array[String] raise {
  let rule = py_eval_callable(
    "lambda x: [x+1] if isinstance(x, __import__('sympy').Integer) else []",
  )
  let trav_enum = sympy_call_must("sympy.strategies.branch.traverse.top_down", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_strings(list_res)
}

///|
pub fn branch_traverse_top_down_split5(expr : @symcore.Expr) -> Array[String] raise {
  let rule = py_eval_callable(
    "lambda x: [x-1, x+1] if x==5 else []",
  )
  let trav_enum = sympy_call_must("sympy.strategies.branch.traverse.top_down", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_strings(list_res)
}

///|
pub fn branch_traverse_sall_inc(expr : @symcore.Expr) -> Array[String] raise {
  let rule = py_eval_callable(
    "lambda x: [x+1] if isinstance(x, __import__('sympy').Integer) else []",
  )
  let trav_enum = sympy_call_must("sympy.strategies.branch.traverse.sall", [OracleArg::PyObj(rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_strings(list_res)
}

///|
pub fn branch_traverse_sall_do_one(expr : @symcore.Expr) -> Array[String] raise {
  let inc = py_eval_callable(
    "lambda x: [x+1] if isinstance(x, __import__('sympy').Integer) else []",
  )
  let ident = py_eval_obj("__import__('sympy').strategies.branch.core.identity")
  let do_one_enum = sympy_call_must("sympy.strategies.branch.core.do_one", [
    OracleArg::PyObj(inc.obj()),
    OracleArg::PyObj(ident),
  ])
  let do_one_rule = py_callable_from_enum(do_one_enum)
  let trav_enum = sympy_call_must("sympy.strategies.branch.traverse.sall", [OracleArg::PyObj(do_one_rule.obj())])
  let trav = py_callable_from_enum(trav_enum)
  let res = py_call_with_args(trav, [OracleArg::PyObj(expr_to_sympy(expr))])
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_strings(list_res)
}

///|
/// Branch tools oracles
pub fn branch_canon_branch5(expr : @symcore.Expr) -> Array[String] raise {
  let rule = py_eval_callable(
    "lambda x: [x-1] if isinstance(x, __import__('sympy').Integer) and 0<x<5 else ([x+1] if isinstance(x, __import__('sympy').Integer) and 5<x<10 else ([x+1, x-1] if isinstance(x, __import__('sympy').Integer) and x==5 else ([x] if isinstance(x, __import__('sympy').Integer) else [])))",
  )
  let canon_enum = sympy_call_must("sympy.strategies.branch.tools.canon", [OracleArg::PyObj(rule.obj())])
  let canon = py_callable_from_enum(canon_enum)
  let res = py_call_with_args(canon, [OracleArg::PyObj(expr_to_sympy(expr))])
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_strings(list_res)
}

///|
pub fn branch_canon_posdec(expr : @symcore.Expr) -> Array[String] raise {
  let rule = py_eval_callable(
    "lambda x: [x-1] if isinstance(x, __import__('sympy').Integer) and x>0 else ([x] if isinstance(x, __import__('sympy').Integer) else [])",
  )
  let canon_enum = sympy_call_must("sympy.strategies.branch.tools.canon", [OracleArg::PyObj(rule.obj())])
  let canon = py_callable_from_enum(canon_enum)
  let res = py_call_with_args(canon, [OracleArg::PyObj(expr_to_sympy(expr))])
  let to_list = py_eval_callable("lambda it: list(it)")
  let list_res = py_call_with_args(to_list, [OracleArg::PyObj(objenum_to_obj(res))])
  py_list_to_strings(list_res)
}
