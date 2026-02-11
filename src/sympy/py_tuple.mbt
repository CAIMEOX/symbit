///|
pub fn[T : @py.IsPyObject] tuple_set_borrowed(
  tup : @py.PyTuple,
  idx : Int,
  item : T,
) -> Unit {
  // Keep a live reference even if the local MoonBit wrapper gets dropped.
  @cpython.py_incref(item.obj_ref())
  let _ = py_tuple_set_item_borrowed(
    tup.obj_ref(),
    idx.to_uint64(),
    item.obj_ref(),
  )
}

///|
/// Call PyTuple_SetItem without transferring ownership of the tuple wrapper.
#borrow(tuple, item)
extern "C" fn py_tuple_set_item_borrowed(
  tuple : @cpython.PyObjectRef,
  idx : UInt64,
  item : @cpython.PyObjectRef,
) -> Int = "PyTuple_SetItem"

///|
pub fn py_tuple_from_objects(values : Array[@py.PyObject]) -> @py.PyTuple {
  let state = py_gil_ensure()
  let tup = @py.PyTuple::new(values.length().to_uint64())
  for i in 0..<values.length() {
    tup.set(i, values[i])
  }
  py_gil_release(state)
  tup
}
