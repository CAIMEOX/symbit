///|\
/// Error values for `symutilities` helpers.

///|
pub(all) suberror UtilitiesError {
  InvalidArgument(String)
  Unsupported(String)
  MissingValue(String)
} derive(Debug, Eq)

///|
fn double_quoted_string(value : String) -> String {
  "\"" +
  value
  .replace_all(old="\\", new="\\\\")
  .replace_all(old="\"", new="\\\"")
  .replace_all(old="\n", new="\\n")
  .replace_all(old="\r", new="\\r")
  .replace_all(old="\t", new="\\t") +
  "\""
}

///|
pub impl Show for UtilitiesError with fn to_string(self) {
  match self {
    InvalidArgument(message) =>
      "InvalidArgument(" + double_quoted_string(message) + ")"
    Unsupported(message) => "Unsupported(" + double_quoted_string(message) + ")"
    MissingValue(message) =>
      "MissingValue(" + double_quoted_string(message) + ")"
  }
}

///|
pub impl Show for UtilitiesError with fn output(self, logger : &Logger) -> Unit {
  logger.write_string(Show::to_string(self))
}
