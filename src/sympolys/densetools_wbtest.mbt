///|
fn dt_wb_fe(n : Int) -> FieldElem raise PolyError {
  fe_from_int(n, Domain::ZZ)
}

///|
fn dt_wb_qq(num : Int, den : Int) -> FieldElem raise PolyError {
  fe_from_rational(
    @symnum.BigRational::from_ints(num, den) catch {
      _ => raise PolyError::DivisionByZero
    },
    Domain::QQ,
  )
}

///|
fn dt_wb_dup(vals : Array[Int]) -> Array[FieldElem] raise PolyError {
  let out : Array[FieldElem] = Array::new()
  for value in vals {
    out.push(dt_wb_fe(value))
  }
  out
}

///|
fn dt_wb_poly(vals : Array[Int]) -> DensePoly raise PolyError {
  let items : Array[DensePoly] = Array::new()
  for value in vals {
    items.push(DensePoly::Coef(dt_wb_fe(value)))
  }
  DensePoly::Poly(items)
}

///|
fn dt_wb_dup_repr(coeffs : Array[FieldElem]) -> String {
  "[" + coeffs.map(c => c.to_string()).join(",") + "]"
}

///|
fn dt_wb_dmp_repr(poly : DensePoly) -> String {
  match poly {
    DensePoly::Coef(c) => c.to_string()
    DensePoly::Poly(items) =>
      "[" + items.map(item => dt_wb_dmp_repr(item)).join(",") + "]"
  }
}

///|
fn dt_wb_extract_repr(
  value : (FieldElem, Array[FieldElem], Array[FieldElem]),
) -> String {
  "(\{value.0},\{dt_wb_dup_repr(value.1)},\{dt_wb_dup_repr(value.2)})"
}

///|
fn dt_wb_clear_repr(value : (FieldElem, Array[FieldElem])) -> String {
  "(\{value.0},\{dt_wb_dup_repr(value.1)})"
}

///|
fn dt_wb_dmp_extract_repr(value : (FieldElem, DensePoly, DensePoly)) -> String {
  "(\{value.0},\{dt_wb_dmp_repr(value.1)},\{dt_wb_dmp_repr(value.2)})"
}

///|
fn dt_wb_dmp_clear_repr(value : (FieldElem, DensePoly)) -> String {
  "(\{value.0},\{dt_wb_dmp_repr(value.1)})"
}

///|
test "densetools wb: extract and trunc frontdoors" {
  let f = dt_wb_dup([6, 12, 18])
  let g = dt_wb_dup([4, 8, 12])
  inspect(
    dt_wb_extract_repr(dup_extract(f, g, Domain::ZZ)),
    content="(2,[3,6,9],[2,4,6])",
  )

  let xy1 = DensePoly::Poly([dt_wb_poly([6, 12]), dt_wb_poly([18])])
  let xy2 = DensePoly::Poly([dt_wb_poly([4, 8]), dt_wb_poly([12])])
  inspect(
    dt_wb_dmp_extract_repr(dmp_ground_extract(xy1, xy2, 1, Domain::ZZ)),
    content="(2,[[3,6],[9]],[[2,4],[6]])",
  )

  inspect(
    dt_wb_dup_repr(dup_trunc(dt_wb_dup([2, 3, 5, 7]), dt_wb_fe(3), Domain::ZZ)),
    content="[-1,0,-1,1]",
  )
  let h = DensePoly::Poly([
    dt_wb_poly([3, 8]),
    dt_wb_poly([5, 6]),
    dt_wb_poly([2, 3]),
  ])
  inspect(
    dt_wb_dmp_repr(dmp_ground_trunc(h, dt_wb_fe(3), 1, Domain::ZZ)),
    content="[[-1],[-1,0],[-1,0]]",
  )
  inspect(
    dt_wb_dmp_repr(dmp_trunc(h, dt_wb_poly([1, -1]), 1, Domain::ZZ)),
    content="[[11],[11],[5]]",
  )
}

///|
test "densetools wb: shift transform compose frontdoors" {
  inspect(
    dt_wb_dup_repr(dup_mirror(dt_wb_dup([1, 2, -4, 2]), Domain::ZZ)),
    content="[-1,2,4,2]",
  )
  inspect(
    dt_wb_dup_repr(dup_scale(dt_wb_dup([1, -2, 1]), dt_wb_fe(2), Domain::ZZ)),
    content="[4,-4,1]",
  )
  inspect(
    dt_wb_dup_repr(dup_shift(dt_wb_dup([1, -2, 1]), dt_wb_fe(2), Domain::ZZ)),
    content="[1,2,1]",
  )
  inspect(
    dt_wb_dup_repr(
      dup_transform(
        dt_wb_dup([1, -2, 1]),
        dt_wb_dup([1, 0, 1]),
        dt_wb_dup([1, -1]),
        Domain::ZZ,
      ),
    ),
    content="[1,-2,5,-4,4]",
  )
  inspect(
    dt_wb_dup_repr(
      dup_compose(dt_wb_dup([1, 1, 0]), dt_wb_dup([1, -1]), Domain::ZZ),
    ),
    content="[1,-1,0]",
  )

  let shifted = DensePoly::Poly([
    dt_wb_poly([1, 0]),
    dt_wb_poly([2, 3]),
    dt_wb_poly([4, 5]),
  ])
  inspect(
    dt_wb_dmp_repr(dmp_shift(shifted, dt_wb_dup([1, 2]), 1, Domain::ZZ)),
    content="[[1,2],[4,11],[7,22]]",
  )

  let composed = DensePoly::Poly([dt_wb_poly([1, 2]), dt_wb_poly([1, 0])])
  let y = DensePoly::Poly([dt_wb_poly([1, 0])])
  inspect(
    dt_wb_dmp_repr(dmp_compose(composed, y, 1, Domain::ZZ)),
    content="[[1,3,0]]",
  )
}

///|
test "densetools wb: eval tail diff eval clear denoms and revert" {
  inspect(
    dup_sign_variations(dt_wb_dup([1, 0, -1, -1, 1]), Domain::ZZ),
    content="2",
  )
  inspect(
    dt_wb_clear_repr(
      dup_clear_denoms([dt_wb_qq(1, 2), dt_wb_qq(1, 3)], Domain::QQ),
    ),
    content="(6,[3,2])",
  )
  let rational_xy = DensePoly::Poly([
    DensePoly::Poly([DensePoly::Coef(dt_wb_qq(1, 2))]),
    DensePoly::Poly([
      DensePoly::Coef(dt_wb_qq(1, 3)),
      DensePoly::Coef(dt_wb_qq(1, 1)),
    ]),
  ])
  inspect(
    dt_wb_dmp_clear_repr(dmp_clear_denoms(rational_xy, 1, Domain::QQ)),
    content="(6,[[3],[2,6]])",
  )

  let eval_poly = DensePoly::Poly([dt_wb_poly([2, 3]), dt_wb_poly([1, 2])])
  inspect(
    dt_wb_dmp_repr(dmp_eval_tail(eval_poly, [dt_wb_fe(2)], 1, Domain::ZZ)),
    content="[7,4]",
  )
  inspect(
    dt_wb_dmp_repr(
      dmp_eval_tail(eval_poly, [dt_wb_fe(2), dt_wb_fe(2)], 1, Domain::ZZ),
    ),
    content="18",
  )

  let diff_poly = DensePoly::Poly([dt_wb_poly([1, 2, 3]), dt_wb_poly([2, 3, 1])])
  inspect(
    dt_wb_dmp_repr(
      dmp_diff_eval_in(diff_poly, 1, dt_wb_fe(2), 0, 1, Domain::ZZ),
    ),
    content="[1,2,3]",
  )
  inspect(
    dt_wb_dmp_repr(
      dmp_diff_eval_in(diff_poly, 1, dt_wb_fe(2), 1, 1, Domain::ZZ),
    ),
    content="[6,11]",
  )

  let inv_poly = [dt_wb_qq(-1, 1), dt_wb_qq(1, 1)]
  inspect(
    dt_wb_dup_repr(dup_revert(inv_poly, 4, Domain::QQ)),
    content="[1,1,1,1]",
  )
  inspect(
    dt_wb_dmp_repr(
      dmp_revert(
        DensePoly::Poly([
          DensePoly::Coef(dt_wb_qq(-1, 1)),
          DensePoly::Coef(dt_wb_qq(1, 1)),
        ]),
        4,
        0,
        Domain::QQ,
      ),
    ),
    content="[1,1,1,1]",
  )
}
