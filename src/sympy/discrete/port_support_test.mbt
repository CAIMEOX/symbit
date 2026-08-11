///|
using @symdiscrete {
  type Expr,
  complex,
  convolution,
  convolution_fft,
  convolution_fwht,
  convolution_int,
  convolution_ntt,
  convolution_subset,
  covering_product,
  fft,
  fwht,
  ifft,
  ifwht,
  intersecting_product,
  intt,
  inverse_mobius_transform,
  linrec,
  mobius_transform,
  ntt,
  rat,
  sqrt_int,
}

///|
fn[T] expect_error(action : () -> T raise) -> Unit raise {
  try action() catch {
    _ => ()
  } noraise {
    _ => fail("expected operation to raise")
  }
}
