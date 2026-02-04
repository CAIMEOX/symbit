///|
/// Oracle helpers for SymPy series.

///|
pub type OracleArg = @sympy.OracleArg

///|
fn py_gil_ensure() -> Int {
  @sympy.py_gil_ensure()
}

///|
fn py_gil_release(state : Int) -> Unit {
  @sympy.py_gil_release(state)
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
fn sympy_symbol(name : String) -> @py.PyObject raise {
  let obj = sympy_call_must("sympy.symbols", [OracleArg::Str(name)])
  objenum_to_obj(obj)
}

///|
pub fn series_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  n : Int,
  dir? : String = "+",
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let res = sympy_call_must("sympy.series", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
    OracleArg::Int(n),
    OracleArg::Str(dir),
  ])
  py_str_enum(res)
}

///|
pub fn sympy_normalize_str(expr_str : String) -> String raise {
  let res = sympy_call_must("sympy.sympify", [OracleArg::Str(expr_str)])
  py_str_enum(res)
}

///|
pub fn sympy_equiv_str(a : String, b : String) -> Bool raise {
  let diff = "(\{a})- (\{b})"
  let res = sympy_call_must("sympy.simplify", [OracleArg::Str(diff)])
  py_str_enum(res) == "0"
}

///|
pub fn limit_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let res = sympy_call_must("sympy.limit", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
    OracleArg::Str(dir),
  ])
  py_str_enum(res)
}

///|
pub fn fps_truncate_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  n : Int,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let fps_enum = sympy_call_must("sympy.fps", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
  ])
  let fps_obj = objenum_to_obj(fps_enum)
  let trunc_enum = match fps_obj.get_attr("truncate", print_err=true) {
    Some(v) => v
    None => fail("fps-truncate-missing")
  }
  let trunc_callable = match trunc_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("fps-truncate-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("fps-truncate-callable")
      }
  }
  let res = py_call_with_args(trunc_callable, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn pade_approximant_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  m : Int,
  n? : Int = -1,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let n_arg = if n < 0 { OracleArg::Null } else { OracleArg::Int(n) }
  let res = sympy_call_must("sympy.series.approximants.pade_approximant", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
    OracleArg::Int(m),
    n_arg,
  ])
  py_str_enum(res)
}

///|
pub fn approximants_str(coeffs : Array[Int], var_name : String) -> String raise {
  let var_obj = sympy_symbol(var_name)
  let res = sympy_call_must("sympy.series.approximants.approximants", [
    OracleArg::IntList(coeffs),
    OracleArg::PyObj(var_obj),
  ])
  // Convert generator to list in Python
  let gen_obj = objenum_to_obj(res)
  let builtins = match @py.pyimport("builtins") {
    Some(mod) => mod
    None => fail("py-builtins-missing")
  }
  let list_obj = match builtins.get_attr("list", print_err=true) {
    Some(obj) => obj
    None => fail("py-list-missing")
  }
  let list_callable = match list_obj {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-list-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("py-list-callable")
      }
  }
  let list_res = py_call_with_args(list_callable, [OracleArg::PyObj(gen_obj)])
  py_str_enum(list_res)
}

///|
pub fn gruntz_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  dir? : String = "+",
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let res = sympy_call_must("sympy.gruntz", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
    OracleArg::Str(dir),
  ])
  py_str_enum(res)
}

///|
pub fn residue_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let res = sympy_call_must("sympy.residue", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
  ])
  py_str_enum(res)
}

///|
pub fn richardson_str(
  expr : @symcore.Expr,
  k_name : String,
  n : Int,
  m : Int,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let k_obj = sympy_symbol(k_name)
  let res = sympy_call_must("sympy.series.acceleration.richardson", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(k_obj),
    OracleArg::Int(n),
    OracleArg::Int(m),
  ])
  py_str_enum(res)
}

///|
pub fn shanks_str(
  expr : @symcore.Expr,
  k_name : String,
  n : Int,
  m? : Int = 1,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let k_obj = sympy_symbol(k_name)
  let res = sympy_call_must("sympy.series.acceleration.shanks", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(k_obj),
    OracleArg::Int(n),
    OracleArg::Int(m),
  ])
  py_str_enum(res)
}

///|
pub fn difference_delta_str(
  expr : @symcore.Expr,
  n_name : String,
  step? : Int = 1,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let n_obj = sympy_symbol(n_name)
  let res = sympy_call_must("sympy.difference_delta", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(n_obj),
    OracleArg::Int(step),
  ])
  py_str_enum(res)
}

///|
pub fn limit_seq_str(expr : @symcore.Expr, n_name : String) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let n_obj = sympy_symbol(n_name)
  let res = sympy_call_must("sympy.limit_seq", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(n_obj),
  ])
  py_str_enum(res)
}

///|
fn py_tuple_from_exprs(items : Array[@symcore.Expr]) -> @py.PyObject raise {
  let objs : Array[@py.PyObject] = Array::new()
  for item in items {
    objs.push(expr_to_sympy(item))
  }
  let tup = @sympy.py_tuple_from_objects(objs)
  tup.obj()
}

///|
fn py_slice_obj(start : Int, stop : Int, step? : Int = 1) -> @py.PyObject raise {
  let builtins = match @py.pyimport("builtins") {
    Some(mod) => mod
    None => fail("py-builtins-missing")
  }
  let slice_enum = match builtins.get_attr("slice", print_err=true) {
    Some(obj) => obj
    None => fail("py-slice-missing")
  }
  let slice_callable = match slice_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("py-slice-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("py-slice-callable")
      }
  }
  let res = py_call_with_args(slice_callable, [
    OracleArg::Int(start),
    OracleArg::Int(stop),
    OracleArg::Int(step),
  ])
  objenum_to_obj(res)
}

///|
pub fn fps_coeff_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  n : Int,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let fps_enum = sympy_call_must("sympy.fps", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
  ])
  let fps_obj = objenum_to_obj(fps_enum)
  let get_enum = match fps_obj.get_attr("__getitem__", print_err=true) {
    Some(v) => v
    None => fail("fps-getitem-missing")
  }
  let get_callable = match get_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("fps-getitem-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("fps-getitem-callable")
      }
  }
  let res = py_call_with_args(get_callable, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn fps_slice_str(
  expr : @symcore.Expr,
  var_name : String,
  x0 : @symcore.Expr,
  start : Int,
  stop : Int,
  step? : Int = 1,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let var_obj = sympy_symbol(var_name)
  let x0_obj = expr_to_sympy(x0)
  let fps_enum = sympy_call_must("sympy.fps", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(var_obj),
    OracleArg::PyObj(x0_obj),
  ])
  let fps_obj = objenum_to_obj(fps_enum)
  let get_enum = match fps_obj.get_attr("__getitem__", print_err=true) {
    Some(v) => v
    None => fail("fps-getitem-missing")
  }
  let get_callable = match get_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("fps-getitem-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("fps-getitem-callable")
      }
  }
  let slice_obj = py_slice_obj(start, stop, step~)
  let res = py_call_with_args(get_callable, [OracleArg::PyObj(slice_obj)])
  py_str_enum(res)
}

///|
pub fn fourier_truncate_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let limits_obj = py_tuple_from_exprs([@symcore.symbol(var_name), a, b])
  let series_enum = sympy_call_must("sympy.fourier_series", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(limits_obj),
  ])
  let series_obj = objenum_to_obj(series_enum)
  let trunc_enum = match series_obj.get_attr("truncate", print_err=true) {
    Some(v) => v
    None => fail("fourier-truncate-missing")
  }
  let trunc_callable = match trunc_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("fourier-truncate-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("fourier-truncate-callable")
      }
  }
  let res = py_call_with_args(trunc_callable, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn fourier_term_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let limits_obj = py_tuple_from_exprs([@symcore.symbol(var_name), a, b])
  let series_enum = sympy_call_must("sympy.fourier_series", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(limits_obj),
  ])
  let series_obj = objenum_to_obj(series_enum)
  let term_enum = match series_obj.get_attr("term", print_err=true) {
    Some(v) => v
    None => fail("fourier-term-missing")
  }
  let term_callable = match term_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("fourier-term-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("fourier-term-callable")
      }
  }
  let res = py_call_with_args(term_callable, [OracleArg::Int(n)])
  py_str_enum(res)
}

///|
pub fn fourier_sigma_str(
  expr : @symcore.Expr,
  var_name : String,
  a : @symcore.Expr,
  b : @symcore.Expr,
  n : Int,
) -> String raise {
  let expr_obj = expr_to_sympy(expr)
  let limits_obj = py_tuple_from_exprs([@symcore.symbol(var_name), a, b])
  let series_enum = sympy_call_must("sympy.fourier_series", [
    OracleArg::PyObj(expr_obj),
    OracleArg::PyObj(limits_obj),
  ])
  let series_obj = objenum_to_obj(series_enum)
  let sigma_enum = match
    series_obj.get_attr("sigma_approximation", print_err=true) {
    Some(v) => v
    None => fail("fourier-sigma-missing")
  }
  let sigma_callable = match sigma_enum {
    PyCallable(callable) => callable
    PyClass(obj0) =>
      @py.PyCallable::create(obj0) catch {
        _ => fail("fourier-sigma-callable")
      }
    other =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("fourier-sigma-callable")
      }
  }
  let res = py_call_with_args(sigma_callable, [OracleArg::Int(n)])
  py_str_enum(res)
}
