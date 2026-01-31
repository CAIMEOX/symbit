///|
pub fn tuple_set_borrowed[T : @py.IsPyObject](
  tup : @py.PyTuple,
  idx : Int,
  item : T,
) -> Unit {
  // Keep a live reference even if the local MoonBit wrapper gets dropped.
  @cpython.py_incref(item.obj_ref())
  let _ = py_tuple_set_item_borrowed(tup.obj_ref(), idx.to_uint64(), item.obj_ref())
}

///| Call PyTuple_SetItem without transferring ownership of the tuple wrapper.
#borrow(tuple, item)
extern "C" fn py_tuple_set_item_borrowed(
  tuple : @cpython.PyObjectRef,
  idx : UInt64,
  item : @cpython.PyObjectRef,
) -> Int = "PyTuple_SetItem"
