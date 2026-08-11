///|
test "matrices block diag and block matrix" {
  let a = matrix([[@symcore.int(1), @symcore.int(2)]])
  let b = matrix([[@symcore.int(3)], [@symcore.int(4)]])
  inspect(
    Show::to_string(block_diag([a, b])),
    content="Matrix([[1, 2, 0], [0, 0, 3], [0, 0, 4]])",
  )
  let c = matrix([[@symcore.int(5), @symcore.int(6)]])
  let d = matrix([[@symcore.int(3)]])
  let e = matrix([[@symcore.int(7)]])
  inspect(
    Show::to_string(block_matrix([[a, d], [c, e]])),
    content="Matrix([[1, 2, 3], [5, 6, 7]])",
  )
}
