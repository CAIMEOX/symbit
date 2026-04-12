///|
test "combinatorial integer semantics align with SymPy" {
  let one_third = @symcore.Expr::Number(
    @symnum.BigRational::from_ints(1, 3) catch {
      _ => fail("1/3")
    },
  )
  let one_half = @symcore.Expr::Number(
    @symnum.BigRational::from_ints(1, 2) catch {
      _ => fail("1/2")
    },
  )
  assert_true(factorial2(@symcore.int(-5)) == one_third)
  assert_true(factorial2(@symcore.int(-1)) == @symcore.int(1))
  assert_true(bernoulli(@symcore.int(1)) == one_half)
  assert_true(bernoulli(@symcore.int(11)) == @symcore.int(0))
}
