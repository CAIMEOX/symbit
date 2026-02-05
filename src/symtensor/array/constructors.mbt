///|
/// Constructors for arrays.

///|
fn zeros_data(size : Int) -> Array[@symcore.Expr] {
  let out : Array[@symcore.Expr] = Array::new()
  for _ in 0..<size {
    out.push(@symcore.int(0))
  }
  out
}

///|
///|
pub fn dense(shape : Array[Int], data : Array[@symcore.Expr]) -> NDimArray raise {
  let expected = @symtensor.product_ints(shape)
  if data.length() != expected {
    fail("dense data length mismatch")
  }
  NDimArray::Dense(DenseArray::{ shape: @symtensor.clone_int_array(shape), data })
}

///|
pub fn sparse(
  shape : Array[Int],
  entries : Array[(Array[Int], @symcore.Expr)],
) -> NDimArray {
  let map : Map[String, @symcore.Expr] = {}
  for entry in entries {
    let (idx, value) = entry
    if !expr_is_zero(value) {
      map[index_key(idx)] = value
    }
  }
  NDimArray::Sparse(SparseArray::{ shape: @symtensor.clone_int_array(shape), data: map })
}

///|
pub fn zeros(shape : Array[Int]) -> NDimArray {
  let size = @symtensor.product_ints(shape)
  NDimArray::Dense(DenseArray::{ shape: @symtensor.clone_int_array(shape), data: zeros_data(size) })
}

///|
pub fn eye(n : Int) -> NDimArray {
  let shape = [n, n]
  let size = n * n
  let data : Array[@symcore.Expr] = Array::new()
  for i in 0..<size {
    data.push(@symcore.int(0))
  }
  for i in 0..<n {
    data[i * n + i] = @symcore.int(1)
  }
  NDimArray::Dense(DenseArray::{ shape, data })
}
