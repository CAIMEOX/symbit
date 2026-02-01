///|
pub fn py_call_object(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  ensure_python()
  callable.invoke(args~, print_err~) catch {
    _ => None
  }
}

///|
/// Like py_call_object, but allows Python None as a valid return.
pub fn py_call_object_allow_none(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  py_call_object(callable, args, print_err~)
}

///|
pub fn py_call_object_kwargs(
  callable : @py.PyCallable,
  args : @py.PyTuple,
  kwargs? : @py.PyDict = @py.PyDict::new(),
  print_err? : Bool = false,
) -> @py.PyObjectEnum? {
  ensure_python()
  callable.invoke(args~, kwargs~, print_err~) catch {
    _ => None
  }
}

///|
/// Ensure the embedded Python runtime is initialized.
fn ensure_python() -> Unit {
  if !@cpython.py_is_initialized() {
    @py.init_py()
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
}

///|
let gil_state_cache : Ref[Int?] = { val: None }

///|
/// Keep the GIL held for the process to avoid missed guards in call sites.
fn py_gil_ensure() -> Int {
  ensure_python()
  match gil_state_cache.val {
    Some(state) => state
    None => {
      let state = py_gil_state_ensure()
      gil_state_cache.val = Some(state)
      state
    }
  }
}

///|
/// No-op release: we keep the GIL for the duration of the process.
fn py_gil_release(_state : Int) -> Unit {
  ()
}

///|
extern "C" fn py_gil_state_ensure() -> Int = "PyGILState_Ensure"

///|
fn init {
  ignore(py_gil_ensure())
}

///|
/// Placeholder: low-level call helpers kept for reference.
// low-level call helpers removed
