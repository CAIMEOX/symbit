///|
pub fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  let obj_ref = py_object_call_object_borrowed(
    callable.obj_ref(),
    args.obj_ref(),
  )
  if obj_ref.is_null() {
    let e = @cpython.py_err_occurred()
    if !e.is_null() {
      if print_err {
        @cpython.py_err_print()
      }
      @cpython.py_err_clear()
    }
    return None
  }
  if @cpython.py_none_check(obj_ref) {
    return None
  }
  let obj = @py.PyObject::create(obj_ref)
  Some(@py.PyObjectEnum::create(obj))
}

///|
/// Call PyObject_CallObject without transferring ownership of args/callable.
#borrow(callable, args)
extern "C" fn py_object_call_object_borrowed(
  callable : @cpython.PyObjectRef,
  args : @cpython.PyObjectRef,
) -> @cpython.PyObjectRef = "PyObject_CallObject"
