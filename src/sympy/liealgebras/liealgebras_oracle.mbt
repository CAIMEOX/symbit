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
      _ =>
        @py.PyCallable::create(objenum_to_obj(eval_obj)) catch {
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
fn py_list_to_pyobjects(value : @py.PyObjectEnum) -> Array[@py.PyObject] raise {
  let state = py_gil_ensure()
  let out : Array[@py.PyObject] = Array::new()
  try {
    match value {
      PyList(list) => {
        let len = list.len()
        for i in 0..<len {
          match list.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
      }
      PyTuple(tup) => {
        let len = tup.len().to_int()
        for i in 0..<len {
          match tup.get(i) {
            Some(item) => out.push(objenum_to_obj(item))
            None => ()
          }
        }
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
  out
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
fn py_list_to_string_lists(
  value : @py.PyObjectEnum,
) -> Array[Array[String]] raise {
  let rows = py_list_to_pyobjects(value)
  let out : Array[Array[String]] = Array::new()
  for row in rows {
    let row_enum = @py.PyObjectEnum::create(row)
    out.push(py_list_to_strings(row_enum))
  }
  out
}

///|
fn list_string(items : Array[String]) -> String {
  if items.is_empty() {
    return "[]"
  }
  let joined = items.join(", ")
  "[\{joined}]"
}

///|
fn list_list_string(items : Array[Array[String]]) -> String {
  if items.is_empty() {
    return "[]"
  }
  let rows : Array[String] = Array::new()
  for row in items {
    rows.push(list_string(row))
  }
  let joined = rows.join(", ")
  "[\{joined}]"
}

///|
fn map_entries_string(entries : Array[String]) -> String {
  if entries.is_empty() {
    return "{}"
  }
  let joined = entries.join(", ")
  "{\{joined}}"
}

///|
pub fn cartan_type_rank_str(ct : String) -> String raise {
  let fn_rank = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).rank()",
  )
  let res = py_call_with_args(fn_rank, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_type_series_str(ct : String) -> String raise {
  let fn_series = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).series",
  )
  let res = py_call_with_args(fn_series, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_matrix_list_str(ct : String) -> String raise {
  let fn_mat = py_eval_callable(
    "lambda ct: [[str(x) for x in row] for row in __import__('sympy.liealgebras.cartan_matrix', fromlist=['CartanMatrix']).CartanMatrix(ct).tolist()]",
  )
  let res = py_call_with_args(fn_mat, [OracleArg::Str(ct)])
  let rows = py_list_to_string_lists(res)
  list_list_string(rows)
}

///|
pub fn dynkin_diagram_str(ct : String) -> String raise {
  let fn_diag = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.dynkin_diagram', fromlist=['DynkinDiagram']).DynkinDiagram(ct)",
  )
  let res = py_call_with_args(fn_diag, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_type_dimension_str(ct : String) -> String raise {
  let fn_dim = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).dimension()",
  )
  let res = py_call_with_args(fn_dim, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_type_roots_str(ct : String) -> String raise {
  let fn_roots = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).roots()",
  )
  let res = py_call_with_args(fn_roots, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_type_basis_str(ct : String) -> String raise {
  let fn_basis = py_eval_callable(
    "lambda ct: int(__import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).basis())",
  )
  let res = py_call_with_args(fn_basis, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_type_lie_algebra_str(ct : String) -> String raise {
  let fn_la = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).lie_algebra()",
  )
  let res = py_call_with_args(fn_la, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn cartan_type_simple_root_list_str(
  ct : String,
  index : Int,
) -> String raise {
  let fn_root = py_eval_callable(
    "lambda ct, i: [str(x) for x in __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).simple_root(i)]",
  )
  let res = py_call_with_args(fn_root, [
    OracleArg::Str(ct),
    OracleArg::Int(index),
  ])
  let items = py_list_to_strings(res)
  list_string(items)
}

///|
pub fn cartan_type_highest_root_list_str(ct : String) -> String raise {
  let fn_root = py_eval_callable(
    "lambda ct: [str(x) for x in __import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).highest_root()]",
  )
  let res = py_call_with_args(fn_root, [OracleArg::Str(ct)])
  let items = py_list_to_strings(res)
  list_string(items)
}

///|
pub fn cartan_type_positive_roots_map_str(ct : String) -> String raise {
  let fn_roots = py_eval_callable(
    "lambda ct: (lambda d: [str(k) + ': [' + ', '.join([str(x) for x in d[k]]) + ']' for k in sorted(d)])(__import__('sympy.liealgebras.cartan_type', fromlist=['CartanType']).CartanType(ct).positive_roots())",
  )
  let res = py_call_with_args(fn_roots, [OracleArg::Str(ct)])
  let entries = py_list_to_strings(res)
  map_entries_string(entries)
}

///|
pub fn root_system_simple_roots_map_str(ct : String) -> String raise {
  let fn_roots = py_eval_callable(
    "lambda ct: (lambda d: [str(k) + ': [' + ', '.join([str(x) for x in d[k]]) + ']' for k in sorted(d)])(__import__('sympy.liealgebras.root_system', fromlist=['RootSystem']).RootSystem(ct).simple_roots())",
  )
  let res = py_call_with_args(fn_roots, [OracleArg::Str(ct)])
  let entries = py_list_to_strings(res)
  map_entries_string(entries)
}

///|
pub fn root_system_all_roots_map_str(ct : String) -> String raise {
  let fn_roots = py_eval_callable(
    "lambda ct: (lambda d: [str(k) + ': [' + ', '.join([str(x) for x in d[k]]) + ']' for k in sorted(d)])(__import__('sympy.liealgebras.root_system', fromlist=['RootSystem']).RootSystem(ct).all_roots())",
  )
  let res = py_call_with_args(fn_roots, [OracleArg::Str(ct)])
  let entries = py_list_to_strings(res)
  map_entries_string(entries)
}

///|
pub fn root_system_root_space_str(ct : String) -> String raise {
  let fn_rs = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.root_system', fromlist=['RootSystem']).RootSystem(ct).root_space()",
  )
  let res = py_call_with_args(fn_rs, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn root_system_add_simple_roots_list_str(
  ct : String,
  root1 : Int,
  root2 : Int,
) -> String raise {
  let fn_add = py_eval_callable(
    "lambda ct, a, b: [str(x) for x in __import__('sympy.liealgebras.root_system', fromlist=['RootSystem']).RootSystem(ct).add_simple_roots(a, b)]",
  )
  let res = py_call_with_args(fn_add, [
    OracleArg::Str(ct),
    OracleArg::Int(root1),
    OracleArg::Int(root2),
  ])
  let items = py_list_to_strings(res)
  list_string(items)
}

///|
pub fn root_system_add_as_roots_str(
  ct : String,
  root1 : Array[Int],
  root2 : Array[Int],
) -> String raise {
  let fn_add = py_eval_callable(
    "lambda ct, r1, r2: __import__('sympy.liealgebras.root_system', fromlist=['RootSystem']).RootSystem(ct).add_as_roots(r1, r2)",
  )
  let args1 : Array[OracleArg] = Array::new()
  for v in root1 {
    args1.push(OracleArg::Int(v))
  }
  let args2 : Array[OracleArg] = Array::new()
  for v in root2 {
    args2.push(OracleArg::Int(v))
  }
  let res = py_call_with_args(fn_add, [
    OracleArg::Str(ct),
    OracleArg::List(args1),
    OracleArg::List(args2),
  ])
  py_str_enum(res)
}

///|
pub fn weyl_group_generators_list_str(ct : String) -> String raise {
  let fn_gen = py_eval_callable(
    "lambda ct: [str(x) for x in __import__('sympy.liealgebras.weyl_group', fromlist=['WeylGroup']).WeylGroup(ct).generators()]",
  )
  let res = py_call_with_args(fn_gen, [OracleArg::Str(ct)])
  let items = py_list_to_strings(res)
  list_string(items)
}

///|
pub fn weyl_group_group_order_str(ct : String) -> String raise {
  let fn_order = py_eval_callable(
    "lambda ct: int(__import__('sympy.liealgebras.weyl_group', fromlist=['WeylGroup']).WeylGroup(ct).group_order())",
  )
  let res = py_call_with_args(fn_order, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn weyl_group_group_name_str(ct : String) -> String raise {
  let fn_name = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.weyl_group', fromlist=['WeylGroup']).WeylGroup(ct).group_name()",
  )
  let res = py_call_with_args(fn_name, [OracleArg::Str(ct)])
  py_str_enum(res)
}

///|
pub fn weyl_group_element_order_str(ct : String, elt : String) -> String raise {
  let fn_order = py_eval_callable(
    "lambda ct, elt: int(__import__('sympy.liealgebras.weyl_group', fromlist=['WeylGroup']).WeylGroup(ct).element_order(elt))",
  )
  let res = py_call_with_args(fn_order, [
    OracleArg::Str(ct),
    OracleArg::Str(elt),
  ])
  py_str_enum(res)
}

///|
pub fn weyl_group_matrix_form_list_str(
  ct : String,
  elt : String,
) -> String raise {
  let fn_mat = py_eval_callable(
    "lambda ct, elt: [[str(x) for x in row] for row in __import__('sympy.liealgebras.weyl_group', fromlist=['WeylGroup']).WeylGroup(ct).matrix_form(elt).tolist()]",
  )
  let res = py_call_with_args(fn_mat, [OracleArg::Str(ct), OracleArg::Str(elt)])
  let rows = py_list_to_string_lists(res)
  list_list_string(rows)
}

///|
pub fn weyl_group_coxeter_diagram_str(ct : String) -> String raise {
  let fn_diag = py_eval_callable(
    "lambda ct: __import__('sympy.liealgebras.weyl_group', fromlist=['WeylGroup']).WeylGroup(ct).coxeter_diagram()",
  )
  let res = py_call_with_args(fn_diag, [OracleArg::Str(ct)])
  py_str_enum(res)
}
