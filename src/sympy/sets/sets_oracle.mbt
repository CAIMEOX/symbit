///|
/// Oracle helpers for SymPy sets.

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
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn expr_to_sympy(expr : @symcore.Expr) -> @py.PyObject raise {
  @sympy.expr_to_sympy(expr)
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
fn sympy_const(name : String) -> @py.PyObject raise {
  let res = sympy_call_must("sympy.sympify", [Str(name)])
  objenum_to_obj(res)
}

///|
fn sympy_call_obj(
  path : String,
  args : Array[OracleArg],
  kwargs? : Map[String, OracleArg] = {},
) -> @py.PyObject raise {
  let res = sympy_call_must(path, args, kwargs~)
  objenum_to_obj(res)
}

///|
fn bool_expr_to_sympy(expr : @symlogic.BoolExpr) -> @py.PyObject raise {
  let s = @symlogic.to_string(expr)
  let res = sympy_call_must("sympy.sympify", [Str(s)])
  objenum_to_obj(res)
}

///|
fn set_to_sympy(set : @symsets.Set) -> @py.PyObject raise {
  match set {
    EmptySet => sympy_const("EmptySet")
    UniversalSet => sympy_const("UniversalSet")
    Naturals => sympy_const("Naturals")
    Naturals0 => sympy_const("Naturals0")
    Integers => sympy_const("Integers")
    Rationals => sympy_const("Rationals")
    Reals => sympy_const("Reals")
    Complexes => sympy_const("Complexes")
    FiniteSet(items) => {
      let args : Array[OracleArg] = Array::new()
      for item in items {
        args.push(PyObj(expr_to_sympy(item)))
      }
      sympy_call_obj("sympy.FiniteSet", args)
    }
    Interval(left~, right~, left_open~, right_open~) => {
      let args : Array[OracleArg] = Array::new()
      args.push(PyObj(expr_to_sympy(left)))
      args.push(PyObj(expr_to_sympy(right)))
      args.push(Bool(left_open))
      args.push(Bool(right_open))
      sympy_call_obj("sympy.Interval", args)
    }
    ConditionSet(symbol~, condition~, base~) => {
      let args : Array[OracleArg] = [
        PyObj(expr_to_sympy(symbol)),
        PyObj(bool_expr_to_sympy(condition)),
        PyObj(set_to_sympy(base)),
      ]
      sympy_call_obj("sympy.ConditionSet", args)
    }
    ImageSet(symbol~, expr~, base~) => {
      let lambda_obj = sympy_call_obj("sympy.Lambda", [
        PyObj(expr_to_sympy(symbol)),
        PyObj(expr_to_sympy(expr)),
      ])
      let args : Array[OracleArg] = [
        PyObj(lambda_obj),
        PyObj(set_to_sympy(base)),
      ]
      sympy_call_obj("sympy.ImageSet", args)
    }
    ProductSet(items) => {
      let args : Array[OracleArg] = Array::new()
      for item in items {
        args.push(PyObj(set_to_sympy(item)))
      }
      sympy_call_obj("sympy.ProductSet", args)
    }
    Union(items) =>
      if items.is_empty() {
        sympy_const("EmptySet")
      } else {
        let args : Array[OracleArg] = Array::new()
        for item in items {
          args.push(PyObj(set_to_sympy(item)))
        }
        sympy_call_obj("sympy.Union", args)
      }
    Intersection(items) =>
      if items.is_empty() {
        sympy_const("UniversalSet")
      } else {
        let args : Array[OracleArg] = Array::new()
        for item in items {
          args.push(PyObj(set_to_sympy(item)))
        }
        sympy_call_obj("sympy.Intersection", args)
      }
    Complement(a, b) => {
      let args : Array[OracleArg] = [
        PyObj(set_to_sympy(a)),
        PyObj(set_to_sympy(b)),
      ]
      sympy_call_obj("sympy.Complement", args)
    }
  }
}

///|
pub fn set_str(set : @symsets.Set) -> String raise {
  py_str_obj(set_to_sympy(set))
}

///|
pub fn union_str(sets : Array[@symsets.Set]) -> String raise {
  if sets.is_empty() {
    return py_str_obj(sympy_const("EmptySet"))
  }
  let args : Array[OracleArg] = Array::new()
  for item in sets {
    args.push(PyObj(set_to_sympy(item)))
  }
  let res = sympy_call_must("sympy.Union", args)
  py_str_enum(res)
}

///|
pub fn intersection_str(sets : Array[@symsets.Set]) -> String raise {
  if sets.is_empty() {
    return py_str_obj(sympy_const("UniversalSet"))
  }
  let args : Array[OracleArg] = Array::new()
  for item in sets {
    args.push(PyObj(set_to_sympy(item)))
  }
  let res = sympy_call_must("sympy.Intersection", args)
  py_str_enum(res)
}

///|
pub fn complement_str(a : @symsets.Set, b : @symsets.Set) -> String raise {
  let args : Array[OracleArg] = [PyObj(set_to_sympy(a)), PyObj(set_to_sympy(b))]
  let res = sympy_call_must("sympy.Complement", args)
  py_str_enum(res)
}

///|
pub fn contains_str(set : @symsets.Set, elem : @symcore.Expr) -> String raise {
  let args : Array[OracleArg] = [
    PyObj(expr_to_sympy(elem)),
    PyObj(set_to_sympy(set)),
  ]
  let res = sympy_call_must("sympy.Contains", args)
  py_str_enum(res)
}
