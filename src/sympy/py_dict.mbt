///|
pub fn py_dict_from_str_map(values : Map[String, @py.PyObject]) -> @py.PyDict {
  let dict = @py.PyDict::new()
  for k, v in values {
    dict.set(k, v)
  }
  dict
}

///|
pub fn py_dict_from_enum_map(
  values : Map[String, @py.PyObjectEnum],
) -> @py.PyDict {
  let dict = @py.PyDict::new()
  for k, v in values {
    dict.set(k, objenum_to_obj(v))
  }
  dict
}

///|
fn py_obj_from_oracle_arg(arg : OracleArg) -> @py.PyObject {
  match arg {
    OracleArg::Null => @py.PyString::from("None").obj()
    OracleArg::Str(s) => @py.PyString::from(s).obj()
    OracleArg::Int(n) => @py.PyInteger::from(n.to_int64()).obj()
    OracleArg::Bool(b) => @py.PyBool::from(b).obj()
    OracleArg::StrList(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyString::from(v))
      }
      py_list.obj()
    }
    OracleArg::IntList(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyInteger::from(v.to_int64()))
      }
      py_list.obj()
    }
    OracleArg::List(list) => {
      let py_list = @py.PyList::new()
      for v in list {
        py_list.append(@py.PyObject::create(py_obj_from_oracle_arg(v).obj_ref()))
      }
      py_list.obj()
    }
    OracleArg::Dict(map) => {
      let py_dict = @py.PyDict::new()
      for k, v in map {
        py_dict.set(k, py_obj_from_oracle_arg(v))
      }
      py_dict.obj()
    }
  }
}

///|
pub fn py_dict_from_oracle_args(
  values : Map[String, OracleArg],
) -> @py.PyDict {
  let dict = @py.PyDict::new()
  for k, v in values {
    dict.set(k, py_obj_from_oracle_arg(v))
  }
  dict
}

///|
pub fn py_dict_set_enum(
  dict : @py.PyDict,
  key : String,
  value : @py.PyObjectEnum,
) -> Unit {
  dict.set(key, objenum_to_obj(value))
}
