///|
pub fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  if !@cpython.py_is_initialized() {
    @py.init_py()
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
  let state = py_gil_ensure()
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
    py_gil_release(state)
    return None
  }
  if @cpython.py_none_check(obj_ref) {
    py_gil_release(state)
    return None
  }
  let obj = @py.PyObject::create(obj_ref)
  py_gil_release(state)
  Some(@py.PyObjectEnum::create(obj))
}

///|
/// Like py_call_object, but allows Python None as a valid return.
pub fn py_call_object_allow_none(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  if !@cpython.py_is_initialized() {
    @py.init_py()
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
  let state = py_gil_ensure()
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
    py_gil_release(state)
    return None
  }
  let obj = @py.PyObject::create(obj_ref)
  py_gil_release(state)
  Some(@py.PyObjectEnum::create(obj))
}

///|
pub fn py_call_object_kwargs(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  kwargs? : @py.PyDict = @py.PyDict::new(),
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  if !@cpython.py_is_initialized() {
    @py.init_py()
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
  let state = py_gil_ensure()
  let obj_ref = py_object_call_borrowed(
    callable.obj_ref(),
    args.obj_ref(),
    kwargs.obj_ref(),
  )
  if obj_ref.is_null() {
    let e = @cpython.py_err_occurred()
    if !e.is_null() {
      if print_err {
        @cpython.py_err_print()
      }
      @cpython.py_err_clear()
    }
    py_gil_release(state)
    return None
  }
  if @cpython.py_none_check(obj_ref) {
    py_gil_release(state)
    return None
  }
  let obj = @py.PyObject::create(obj_ref)
  py_gil_release(state)
  Some(@py.PyObjectEnum::create(obj))
}

///|
/// Call PyObject_CallObject without transferring ownership of args/callable.
#borrow(callable, args)
extern "C" fn py_object_call_object_borrowed(
  callable : @cpython.PyObjectRef,
  args : @cpython.PyObjectRef,
) -> @cpython.PyObjectRef = "PyObject_CallObject"

///|
/// Call PyObject_Call with kwargs without transferring ownership of args/callable.
#borrow(callable, args, kwargs)
extern "C" fn py_object_call_borrowed(
  callable : @cpython.PyObjectRef,
  args : @cpython.PyObjectRef,
  kwargs : @cpython.PyObjectRef,
) -> @cpython.PyObjectRef = "PyObject_Call"

///|
extern "C" fn py_gil_ensure_raw() -> Int = "PyGILState_Ensure"

///|
extern "C" fn py_gil_release_raw(state : Int) -> Unit = "PyGILState_Release"

///|
let gil_hold_count : Ref[Int] = { val: 0 }

///|
let gil_hold_state : Ref[Int] = { val: 0 }

///|
fn py_gil_hold_begin() -> Unit {
  if gil_hold_count.val == 0 {
    gil_hold_state.val = py_gil_ensure_raw()
  }
  gil_hold_count.val = gil_hold_count.val + 1
}

///|
fn py_gil_hold_end() -> Unit {
  if gil_hold_count.val == 0 {
    return
  }
  gil_hold_count.val = gil_hold_count.val - 1
  if gil_hold_count.val == 0 {
    py_gil_release_raw(gil_hold_state.val)
  }
}

///|
fn py_gil_ensure() -> Int {
  if gil_hold_count.val > 0 {
    0
  } else {
    py_gil_ensure_raw()
  }
}

///|
fn py_gil_release(state : Int) -> Unit {
  if gil_hold_count.val > 0 {
    ()
  } else {
    py_gil_release_raw(state)
  }
}
