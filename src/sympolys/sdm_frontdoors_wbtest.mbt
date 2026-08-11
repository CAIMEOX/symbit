///|
fn sdm_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, ZZ)
}

///|
fn sdm_wb_vec_repr(vec : Map[Int, FieldElem]) -> String {
  let keys : Array[Int] = Array::new()
  for key, _ in vec {
    keys.push(key)
  }
  keys.sort()
  let parts : Array[String] = Array::new()
  for key in keys {
    parts.push("\{key}:\{vec[key]}")
  }
  let body = parts.join(",")
  "{\{body}}"
}

///|
fn sdm_wb_berk_repr(poly : Map[Int, FieldElem]) -> String {
  sdm_wb_vec_repr(poly)
}

///|
test "sdm functional frontdoors" {
  let one = sdm_wb_fe(1)
  let two = sdm_wb_fe(2)
  let three = sdm_wb_fe(3)
  let four = sdm_wb_fe(4)
  let five = sdm_wb_fe(5)
  let seven = sdm_wb_fe(7)
  let a = sdm_from_entries(2, 2, [(0, 1, two), (1, 0, one)], ZZ)
  let b = sdm_from_entries(2, 2, [(0, 0, three), (1, 1, four)], ZZ)
  inspect(sdm_transpose(a).to_dense().to_string(), content="[[0, 1], [2, 0]]")
  inspect(sdm_matmul(a, b).to_dense().to_string(), content="[[0, 8], [3, 0]]")
  inspect(
    sdm_matmul_exraw(a, b).to_dense().to_string(),
    content="[[0, 8], [3, 0]]",
  )
  inspect(
    sdm_scalar_mul(a, two).to_dense().to_string(),
    content="[[0, 4], [2, 0]]",
  )
  let row : Map[Int, FieldElem] = { 0: one, 2: three }
  let vec : Map[Int, FieldElem] = { 0: two, 1: one, 2: four }
  inspect(sdm_dotvec(row, vec, ZZ), content="14")
  inspect(
    sdm_wb_vec_repr(sdm_matvecmul(a, { 0: five, 1: seven })),
    content="{0:14,1:5}",
  )
  let dense = sdm_from_entries(
    2,
    2,
    [(0, 0, one), (0, 1, two), (1, 0, three), (1, 1, four)],
    ZZ,
  )
  let rref = sdm_rref_den(dense)
  inspect(rref.0.to_dense().to_string(), content="[[-2, 0], [0, -2]]")
  inspect(rref.1, content="-2")
  inspect(rref.2.map(p => p.to_string()).join(","), content="0,1")
  inspect(sdm_wb_berk_repr(sdm_berk(dense)), content="{0:1,1:-5,2:-2}")
}

///|
test "sdm dictionary operation frontdoors" {
  let one = sdm_wb_fe(1)
  let two = sdm_wb_fe(2)
  let left : DomainMatrixDOD = { 0: { 0: one }, 1: { 1: two } }
  let right : DomainMatrixDOD = { 0: { 1: two }, 1: { 1: one } }
  let added = binop_dict(
    left,
    right,
    fn(a : FieldElem, b : FieldElem) raise PolyError { fe_add(a, b) },
    fn(a : FieldElem) { a },
    fn(b : FieldElem) { b },
  )
  inspect(sdm_wb_vec_repr(added[0]), content="{0:1,1:2}")
  inspect(sdm_wb_vec_repr(added[1]), content="{1:3}")
  let negated = unop_dict(left, fn(a : FieldElem) { fe_neg(a) })
  inspect(sdm_wb_vec_repr(negated[0]), content="{0:-1}")
  inspect(sdm_wb_vec_repr(negated[1]), content="{1:-2}")
}
