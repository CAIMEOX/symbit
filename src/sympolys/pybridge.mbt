///|
/// Convert a MoonBit `Expr` into a live SymPy object by calling
/// `sympy.sympify` on the stable human printer from `symprint`.
/// This keeps the conversion logic small while relying on SymPy's
/// parser for canonical construction (and avoids reproducing its
/// dispatch rules in MoonBit).
pub fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise PolyError {
  with_py_gil_poly(fn() {
    add_repo_to_syspath()
    let sympy = ensure_sympy_module()
    let sympify = resolve_sympify(sympy)
    let args = @py.PyTuple::new(1)
    // Prefer explicit Rational() for non-integral numbers to avoid
    // parser differences in sympify.
    let rendered = match expr {
      @symcore.Expr::Number(n) =>
        if n.is_integral() {
          n.to_string()
        } else {
          "Rational(\{n.numerator().to_string()}, \{n.denominator().to_string()})"
        }
      _ => @symprint.to_string(expr)
    }
    let pystr = @py.PyString::from(rendered)
    tuple_set_borrowed(args, 0, pystr)
    let res = py_call_object(sympify, args, print_err=true)
    match res {
      Some(obj) => objenum_to_obj(obj)
      None => raise PolyError::NotImplemented("sympy-sympify-none")
    }
  })
}

///|
const REPO_ROOT : String = "/Users/caimeo/code/learning/sym-workspace"

///|
fn add_repo_to_syspath() -> Unit {
  match @py.pyimport("sys") {
    Some(sys) =>
      match sys.get_attr("path", print_err=false) {
        Some(PyList(path_list)) => path_list.append(@py.PyString::from(REPO_ROOT))
        _ => ()
      }
    None => ()
  }
}

///|
fn ensure_sympy_module() -> @py.PyModule raise PolyError {
  match @py.pyimport("sympy") {
    Some(sympy) => sympy
    None => raise PolyError::NotImplemented("sympy-missing")
  }
}

///|
fn resolve_sympify(sympy : @py.PyModule) -> @py.PyCallable raise PolyError {
  let sympify0 = match sympy.get_attr("sympify", print_err=false) {
    Some(PyCallable(callable)) => Some(callable)
    Some(PyClass(obj)) =>
      try @py.PyCallable::create(obj) catch { _ => None } noraise { v => Some(v) }
    Some(other) =>
      try @py.PyCallable::create(objenum_to_obj(other)) catch { _ => None } noraise { v => Some(v) }
    _ => None
  }
  match sympify0 {
    Some(callable) => callable
    None => {
      // Try sympy.core.sympify.sympify via attribute access to avoid dotted import issues.
      match sympy.get_attr("core", print_err=false) {
        Some(core_obj) => {
          let core = objenum_to_obj(core_obj)
          match core.get_attr("sympify", print_err=false) {
            Some(mod_obj) => {
              let mod = objenum_to_obj(mod_obj)
              match mod.get_attr("sympify", print_err=false) {
                Some(PyCallable(callable)) => callable
                Some(PyClass(obj)) =>
                  @py.PyCallable::create(obj) catch {
                    _ => raise PolyError::NotImplemented("sympy-sympify-missing")
                  }
                Some(other) =>
                  @py.PyCallable::create(objenum_to_obj(other)) catch {
                    _ => raise PolyError::NotImplemented("sympy-sympify-missing")
                  }
                None => raise PolyError::NotImplemented("sympy-sympify-missing")
              }
            }
            None => raise PolyError::NotImplemented("sympy-sympify-missing")
          }
        }
        None => raise PolyError::NotImplemented("sympy-sympify-missing")
      }
    }
  }
}

///|
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  match obj {
    PyBool(v) => v.obj()
    PyCallable(v) => v.obj()
    PyClass(v) => v
    PyDict(v) => v.obj()
    PyFloat(v) => v.obj()
    PyInteger(v) => v.obj()
    PyList(v) => v.obj()
    PyModule(v) => v.obj()
    PyString(v) => v.obj()
    PyTuple(v) => v.obj()
  }
}
