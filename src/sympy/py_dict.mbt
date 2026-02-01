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

///|
pub fn py_dict_from_oracle_args(values : Map[String, OracleArg]) -> @py.PyDict {
  let dict = @py.PyDict::new()
  for k, v in values {
    dict.set(k, py_pack(v))
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
