///| Acquire Python's GIL for the duration of a closure, releasing on error.
fn with_py_gil_poly[T](f : () -> T raise PolyError) -> T raise PolyError {
  if !@cpython.py_is_initialized() {
    @py.init_py()
    if !@cpython.py_is_initialized() {
      raise PolyError::NotImplemented("python-init-failed")
    }
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
  let state = py_gil_ensure()
  try f() catch {
    e => {
      py_gil_release(state)
      raise e
    }
  } noraise {
    v => {
      py_gil_release(state)
      v
    }
  }
}

///| Acquire Python's GIL for the duration of a closure, releasing on error.
pub fn with_py_gil_any[T](f : () -> T raise) -> T raise {
  if !@cpython.py_is_initialized() {
    @py.init_py()
    if !@cpython.py_is_initialized() {
      fail("python-init-failed")
    }
  }
  if @cpython.py_eval_threads_initialized() == 0 {
    @cpython.py_eval_init_threads()
  }
  let state = py_gil_ensure()
  try f() catch {
    e => {
      py_gil_release(state)
      raise e
    }
  } noraise {
    v => {
      py_gil_release(state)
      v
    }
  }
}

///|
extern "C" fn py_gil_ensure() -> Int = "PyGILState_Ensure"

///|
extern "C" fn py_gil_release(state : Int) -> Unit = "PyGILState_Release"
