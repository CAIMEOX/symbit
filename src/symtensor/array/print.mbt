///|
/// Printers for arrays.

///|
fn render_nested(
  data : Array[@symcore.Expr],
  shape : Array[Int],
  strides : Array[Int],
  dim : Int,
  offset : Int,
) -> String {
  if shape.is_empty() {
    return @symprint.to_string(data[0])
  }
  if dim == shape.length() - 1 {
    let parts : Array[String] = Array::new()
    for i in 0..<shape[dim] {
      parts.push(@symprint.to_string(data[offset + i]))
    }
    return "[" + parts.join(", ") + "]"
  }
  let parts : Array[String] = Array::new()
  let stride = strides[dim]
  for i in 0..<shape[dim] {
    parts.push(
      render_nested(data, shape, strides, dim + 1, offset + i * stride),
    )
  }
  "[" + parts.join(", ") + "]"
}

///|
pub fn to_string(arr : NDimArray) -> String {
  let dense = match arr {
    NDimArray::Dense(d) => d
    NDimArray::Sparse(_) => {
      let dense = dense_data(arr)
      dense
    }
  }
  if dense.shape.is_empty() {
    return if dense.data.is_empty() {
      "[]"
    } else {
      @symprint.to_string(dense.data[0])
    }
  }
  let strides = compute_strides(dense.shape)
  render_nested(dense.data, dense.shape, strides, 0, 0)
}
