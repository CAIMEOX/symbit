///|
test "matrices block diag and block matrix" {
  let a = try! matrix([[@symcore.int(1), @symcore.int(2)]])
  let b = try! matrix([[@symcore.int(3)], [@symcore.int(4)]])
  inspect(
    (try! block_diag([a, b])).to_string(),
    content="Matrix([[1, 2, 0], [0, 0, 3], [0, 0, 4]])",
  )
  let c = try! matrix([[@symcore.int(5), @symcore.int(6)]])
  let d = try! matrix([[@symcore.int(3)]])
  let e = try! matrix([[@symcore.int(7)]])
  inspect(
    (try! block_matrix([[a, d], [c, e]])).to_string(),
    content="Matrix([[1, 2, 3], [5, 6, 7]])",
  )
}
