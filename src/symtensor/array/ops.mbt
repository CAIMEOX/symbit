///|
/// Array operations.

///|
fn expr_is_zero(expr : @symcore.Expr) -> Bool {
  match expr {
    @symcore.Expr::Number(n) => n.is_zero()
    _ => false
  }
}

///|
pub fn shape(arr : NDimArray) -> Array[Int] {
  match arr {
    NDimArray::Dense(d) => @symtensor.clone_int_array(d.shape)
    NDimArray::Sparse(s) => @symtensor.clone_int_array(s.shape)
  }
}

///|
pub fn rank(arr : NDimArray) -> Int {
  match arr {
    NDimArray::Dense(d) => d.shape.length()
    NDimArray::Sparse(s) => s.shape.length()
  }
}

///|
fn dense_data(arr : NDimArray) -> DenseArray {
  match arr {
    NDimArray::Dense(d) => d
    NDimArray::Sparse(s) => {
      let size = @symtensor.product_ints(s.shape)
      let data : Array[@symcore.Expr] = Array::new()
      for _ in 0..<size {
        data.push(@symcore.int(0))
      }
      for key, value in s.data {
        if key.is_empty() {
          data[0] = value
        } else {
          let parts = key.split(",")
          let idx : Array[Int] = Array::new()
          for part in parts {
            idx.push(parse_int_simple(part))
          }
          if index_in_bounds(s.shape, idx) {
            let pos = linear_index(s.shape, idx)
            data[pos] = value
          }
        }
      }
      DenseArray::{ shape: @symtensor.clone_int_array(s.shape), data }
    }
  }
}

///|
pub fn getitem(arr : NDimArray, index : Array[Int]) -> @symcore.Expr raise {
  match arr {
    NDimArray::Dense(d) => {
      if !index_in_bounds(d.shape, index) {
        fail("index out of bounds")
      }
      d.data[linear_index(d.shape, index)]
    }
    NDimArray::Sparse(s) => {
      if !index_in_bounds(s.shape, index) {
        fail("index out of bounds")
      }
      let key = index_key(index)
      s.data.get_or_default(key, @symcore.int(0))
    }
  }
}

///|
pub fn setitem(
  arr : NDimArray,
  index : Array[Int],
  value : @symcore.Expr,
) -> NDimArray raise {
  match arr {
    NDimArray::Dense(d) => {
      if !index_in_bounds(d.shape, index) {
        fail("index out of bounds")
      }
      let data : Array[@symcore.Expr] = Array::new()
      for item in d.data {
        data.push(item)
      }
      data[linear_index(d.shape, index)] = value
      NDimArray::Dense(DenseArray::{
        shape: @symtensor.clone_int_array(d.shape),
        data,
      })
    }
    NDimArray::Sparse(s) => {
      if !index_in_bounds(s.shape, index) {
        fail("index out of bounds")
      }
      let data = s.data.copy()
      let key = index_key(index)
      if expr_is_zero(value) {
        data.remove(key)
      } else {
        data[key] = value
      }
      NDimArray::Sparse(SparseArray::{
        shape: @symtensor.clone_int_array(s.shape),
        data,
      })
    }
  }
}

///|
pub fn reshape(arr : NDimArray, new_shape : Array[Int]) -> NDimArray raise {
  let old_shape = shape(arr)
  if @symtensor.product_ints(old_shape) != @symtensor.product_ints(new_shape) {
    fail("reshape size mismatch")
  }
  let dense = dense_data(arr)
  NDimArray::Dense(DenseArray::{
    shape: @symtensor.clone_int_array(new_shape),
    data: dense.data,
  })
}

///|
pub fn permutedims(arr : NDimArray, axes : Array[Int]) -> NDimArray raise {
  let dense = dense_data(arr)
  if axes.length() != dense.shape.length() {
    fail("permutedims rank mismatch")
  }
  let new_shape : Array[Int] = Array::new()
  for axis in axes {
    new_shape.push(dense.shape[axis])
  }
  let new_data : Array[@symcore.Expr] = Array::new()
  let indices = all_indices(new_shape)
  for idx in indices {
    let old_idx : Array[Int] = Array::new()
    for _ in 0..<dense.shape.length() {
      old_idx.push(0)
    }
    for i in 0..<axes.length() {
      old_idx[axes[i]] = idx[i]
    }
    new_data.push(dense.data[linear_index(dense.shape, old_idx)])
  }
  NDimArray::Dense(DenseArray::{ shape: new_shape, data: new_data })
}

///|
pub fn tensorproduct(arrays : Array[NDimArray]) -> NDimArray raise {
  if arrays.is_empty() {
    fail("tensorproduct requires at least one array")
  }
  let mut current = dense_data(arrays[0])
  let mut i = 1
  while i < arrays.length() {
    let next = dense_data(arrays[i])
    let new_shape : Array[Int] = Array::new()
    for v in current.shape {
      new_shape.push(v)
    }
    for v in next.shape {
      new_shape.push(v)
    }
    let new_data : Array[@symcore.Expr] = Array::new()
    for a in current.data {
      for b in next.data {
        new_data.push(@symcore.mul([a, b]))
      }
    }
    current = DenseArray::{ shape: new_shape, data: new_data }
    i = i + 1
  }
  NDimArray::Dense(current)
}

///|
fn contract_once(
  dense : DenseArray,
  axis1 : Int,
  axis2 : Int,
) -> DenseArray raise {
  if axis1 == axis2 {
    fail("contract axes must be distinct")
  }
  let a = if axis1 < axis2 { axis1 } else { axis2 }
  let b = if axis1 < axis2 { axis2 } else { axis1 }
  if dense.shape[a] != dense.shape[b] {
    fail("contract axes must have same dimension")
  }
  let new_shape : Array[Int] = Array::new()
  for i in 0..<dense.shape.length() {
    if i != a && i != b {
      new_shape.push(dense.shape[i])
    }
  }
  let new_indices = all_indices(new_shape)
  let new_data : Array[@symcore.Expr] = Array::new()
  for idx in new_indices {
    let sum_terms : Array[@symcore.Expr] = Array::new()
    let dim = dense.shape[a]
    for k in 0..<dim {
      let full_idx : Array[Int] = Array::new()
      let mut j = 0
      for pos in 0..<dense.shape.length() {
        if pos == a || pos == b {
          full_idx.push(k)
        } else {
          full_idx.push(idx[j])
          j = j + 1
        }
      }
      sum_terms.push(dense.data[linear_index(dense.shape, full_idx)])
    }
    let sum = @symcore.add(sum_terms)
    new_data.push(sum)
  }
  DenseArray::{ shape: new_shape, data: new_data }
}

///|
pub fn tensorcontraction(
  arr : NDimArray,
  axes : Array[(Int, Int)],
) -> NDimArray raise {
  let mut dense = dense_data(arr)
  for pair in axes {
    let (a, b) = pair
    dense = contract_once(dense, a, b)
  }
  NDimArray::Dense(dense)
}
