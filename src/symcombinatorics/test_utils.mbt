///|
pub fn assert_oracle(result : Result[Bool, Error]) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch")
    Err(err) => fail(err.to_string())
  }
}

///|
pub fn assert_oracle_named(
  name : String,
  result : Result[Bool, Error],
) -> Unit raise {
  match result {
    Ok(true) => ()
    Ok(false) => fail("oracle mismatch: \{name}")
    Err(err) => fail("\{name}: \{err.to_string()}")
  }
}

///|
pub fn array_forms(perms : Array[Permutation]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = Array::new()
  for p in perms {
    out.push(p.array_form())
  }
  out
}
