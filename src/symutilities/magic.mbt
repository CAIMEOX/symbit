///|\
/// Small helpers for explicit namespace mutation, adapted from
/// `sympy.utilities.magic`.

///|
pub fn[T] pollute(
  names : Array[String],
  objects : Array[T],
  scope : Ref[Map[String, T]],
) -> Unit raise UtilitiesError {
  if names.length() != objects.length() {
    raise InvalidArgument("pollute expects matching name/object lengths")
  }
  for i in 0..<names.length() {
    scope.val[names[i]] = objects[i]
  }
}
