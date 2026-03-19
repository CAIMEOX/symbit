///|
/// Lightweight autowrap helpers aligned with the practical surface of
/// `sympy.utilities.autowrap`.
///
/// Symbit does not shell out to external compilers.  Instead, autowrapped
/// functions combine generated source text from `codegen` with a numeric
/// evaluator from `lambdify`, which keeps the workflow useful inside MoonBit
/// while preserving the high-level SymPy API shape.

///|
pub enum WrapBackend {
  Dummy
  F2Py
  Cython
  Ufunc
} derive(Eq, Show)

///|
pub struct WrappedBinary {
  name : String
  args : Array[String]
  lambda_fn : LambdaFn
  source_files : Array[(String, String)]
  backend : WrapBackend
}

///|
pub struct BinaryFunction {
  name : String
  wrapped : WrappedBinary
}

///|
fn wrap_backend_from_string(name : String) -> WrapBackend raise UtilitiesError {
  match string_lower(name) {
    "dummy" => WrapBackend::Dummy
    "f2py" => WrapBackend::F2Py
    "cython" => WrapBackend::Cython
    "ufunc" | "ufuncify" => WrapBackend::Ufunc
    other =>
      raise UtilitiesError::Unsupported("unsupported autowrap backend " + other)
  }
}

///|
fn infer_wrap_args(
  expr : Expr,
  args : Array[String]?,
) -> Array[String] {
  match args {
    Some(values) => values
    None => free_symbols(expr)
  }
}

///|
pub fn WrappedBinary::call(
  self : WrappedBinary,
  values : Array[Double],
) -> Double raise UtilitiesError {
  self.lambda_fn.call(values)
}

///|
pub fn WrappedBinary::call_map(
  self : WrappedBinary,
  values : Map[String, Double],
) -> Double raise UtilitiesError {
  self.lambda_fn.call_map(values)
}

///|
pub fn WrappedBinary::files(self : WrappedBinary) -> Array[(String, String)] {
  self.source_files
}

///|
pub fn BinaryFunction::apply(
  self : BinaryFunction,
  args : Array[Expr],
) -> Expr {
  @symcore.function(self.name, args)
}

///|
pub fn BinaryFunction::call(
  self : BinaryFunction,
  values : Array[Double],
) -> Double raise UtilitiesError {
  self.wrapped.call(values)
}

///|
pub fn BinaryFunction::files(self : BinaryFunction) -> Array[(String, String)] {
  self.wrapped.files()
}

///|
pub fn autowrap(
  expr : Expr,
  language? : String? = None,
  backend? : String = "dummy",
  tempdir? : String? = None,
  args? : Array[String]? = None,
  name? : String = "autofunc",
) -> WrappedBinary raise UtilitiesError {
  ignore(tempdir)
  let backend0 = wrap_backend_from_string(backend)
  let arg_names = infer_wrap_args(expr, args)
  let language0 = match language {
    Some(value) => value
    None =>
      match backend0 {
        WrapBackend::Dummy | WrapBackend::F2Py | WrapBackend::Cython => "C99"
        WrapBackend::Ufunc => "C99"
      }
  }
  let source_files = codegen([(name, expr)], language0, name)
  {
    name,
    args: arg_names,
    lambda_fn: lambdify(arg_names, expr),
    source_files,
    backend: backend0,
  }
}

///|
pub fn binary_function(
  name : String,
  expr : Expr,
  language? : String? = None,
  backend? : String = "dummy",
  tempdir? : String? = None,
  args? : Array[String]? = None,
) -> BinaryFunction raise UtilitiesError {
  let wrapped = autowrap(expr, language~, backend~, tempdir~, args~, name~)
  ignore(implemented_function(name, values => try! wrapped.call(values)))
  { name, wrapped }
}

///|
pub fn ufuncify(
  args : Array[String],
  expr : Expr,
  language? : String? = None,
  backend? : String = "ufunc",
  tempdir? : String? = None,
  name? : String = "ufunc",
) -> WrappedBinary raise UtilitiesError {
  autowrap(expr, language~, backend~, tempdir~, args=Some(args), name~)
}
