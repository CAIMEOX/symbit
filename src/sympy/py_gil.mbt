///|
/// Acquire Python's GIL for the duration of a closure, releasing on error.
pub fn[T] with_py_gil(f : () -> T raise) -> T raise {
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
/// Backward-compatible alias.
pub fn[T] with_py_gil_any(f : () -> T raise) -> T raise {
  with_py_gil(f)
}

///|
extern "C" fn py_gil_ensure() -> Int = "PyGILState_Ensure"

///|
extern "C" fn py_gil_release(state : Int) -> Unit = "PyGILState_Release"
