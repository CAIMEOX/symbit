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
fn objenum_to_obj(obj : @py.PyObjectEnum) -> @py.PyObject {
  @sympy.objenum_to_obj(obj)
}

///|
fn ensure_repo_sympy_path() -> Unit raise {
  let builtins = match @py.pyimport("builtins") {
    Some(v) => v
    None => fail("python-missing:builtins")
  }
  let globals = @py.PyDict::new()
  globals.set("__builtins__", builtins.obj())
  let exec_fn = match builtins.get_attr("exec", print_err=true) {
    Some(PyCallable(callable)) => callable
    Some(other) =>
      @py.PyCallable::create(objenum_to_obj(other)) catch {
        _ => fail("python-missing:exec")
      }
    None => fail("python-missing:exec")
  }
  let script = [
    "from pathlib import Path\n", "import sys\n", "_mods = [k for k in list(sys.modules) if k == 'sympy' or k.startswith('sympy.')]\n",
    "_cwd = Path.cwd().resolve()\n", "_seen = set()\n", "_path = None\n", "for _base in [_cwd, *_cwd.parents]:\n",
    "    for _candidate in (_base / 'sympy', _base.parent / 'sympy'):\n", "        if _candidate in _seen:\n",
    "            continue\n", "        _seen.add(_candidate)\n", "        if (_candidate / 'sympy').is_dir():\n",
    "            _path = str(_candidate)\n", "            break\n", "    if _path is not None:\n",
    "        break\n", "if _path is None:\n", "    raise RuntimeError('repo sympy path not found')\n",
    "if _path not in sys.path:\n", "    sys.path.insert(0, _path)\n", "for _name in _mods:\n",
    "    sys.modules.pop(_name, None)\n",
  ].join("")
  ignore(
    exec_fn.invoke(
      args=@sympy.py_pack_args([
        Str(script),
        PyObj(globals.obj()),
        PyObj(globals.obj()),
      ]),
      kwargs=@sympy.py_pack_kwargs({}),
      print_err=true,
    ),
  )
}

///|
pub fn vector_eval_str(expr : String) -> String raise {
  let state = py_gil_ensure()
  let res = try {
    ensure_repo_sympy_path()
    @sympy_utilities.utilities_eval_str(expr)
  } catch {
    err => {
      py_gil_release(state)
      raise err
    }
  }
  py_gil_release(state)
  res
}
