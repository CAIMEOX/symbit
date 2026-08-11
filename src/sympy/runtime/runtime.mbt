///|
/// Failures reported by the out-of-process SymPy oracle runtime.
pub(all) suberror OracleError {
  WorkerDied(String)
  WorkerTimeout(String)
  TransportError(String)
  ProtocolError(String)
  PythonException(String, String, String)
}

///|
pub impl Show for OracleError with fn output(self, logger : &Logger) -> Unit {
  match self {
    WorkerDied(message) => logger.write_string("WorkerDied(" + message + ")")
    WorkerTimeout(message) =>
      logger.write_string("WorkerTimeout(" + message + ")")
    TransportError(message) =>
      logger.write_string("TransportError(" + message + ")")
    ProtocolError(message) =>
      logger.write_string("ProtocolError(" + message + ")")
    PythonException(type_name, message, traceback) => {
      logger.write_string("PythonException(" + type_name + ": " + message)
      if traceback != "" {
        logger.write_string("\n" + traceback)
      }
      logger.write_string(")")
    }
  }
}

///|
/// Configuration returned by the live worker handshake.
pub(all) struct WorkerInfo {
  protocol_version : Int
  pid : Int
  python_executable : String
  python_version : String
  sympy_file : String
  sympy_version : String
}

///|
fn protocol_error(message : String) -> OracleError {
  symbit_oracle_reset_worker()
  ProtocolError(message)
}

///|
fn required_field(
  fields : Map[String, Json],
  name : String,
) -> Json raise OracleError {
  match fields.get(name) {
    Some(value) => value
    None => raise protocol_error("response is missing field " + name)
  }
}

///|
fn required_string(
  fields : Map[String, Json],
  name : String,
) -> String raise OracleError {
  match required_field(fields, name) {
    String(value) => value
    _ => raise protocol_error("response field " + name + " is not a string")
  }
}

///|
fn optional_string(fields : Map[String, Json], name : String) -> String {
  match fields.get(name) {
    Some(String(value)) => value
    _ => ""
  }
}

///|
fn required_int(
  fields : Map[String, Json],
  name : String,
) -> Int raise OracleError {
  match required_field(fields, name) {
    Number(value, ..) => {
      let integer = value.to_int()
      if value != integer.to_double() {
        raise protocol_error("response field " + name + " is not an integer")
      }
      integer
    }
    _ => raise protocol_error("response field " + name + " is not an integer")
  }
}

///|
fn decode_transport_result(payload : Bytes) -> Json raise OracleError {
  if payload.length() == 0 {
    raise TransportError("native transport returned an empty result")
  }
  match payload[0].to_int() {
    1 => raise TransportError("oracle worker script was not found")
    2 =>
      raise TransportError(
        "could not start SYMBIT_PYTHON (or python3 from PATH)",
      )
    3 => raise ProtocolError("oracle request exceeds the 64 MiB frame limit")
    4 => raise WorkerDied("oracle worker closed while receiving a request")
    5 => raise WorkerDied("oracle worker closed its response pipe")
    6 => raise ProtocolError("oracle worker returned an invalid frame")
    7 => raise WorkerTimeout("oracle worker request deadline expired")
    0 => ()
    status =>
      raise TransportError(
        "native transport returned unknown status " + Show::to_string(status),
      )
  }
  let text = @utf8.decode(payload[1:]) catch {
    _ => raise protocol_error("worker response is not valid UTF-8")
  }
  @json.parse(text) catch {
    err =>
      raise protocol_error(
        "worker response is not valid JSON: " + Show::to_string(err),
      )
  }
}

///|
fn exchange(request : Json) -> Json raise OracleError {
  let encoded = @utf8.encode(request.stringify())
  decode_transport_result(symbit_oracle_exchange(encoded))
}

///|
fn raise_remote_error(error : Json) -> Unit raise OracleError {
  let fields = match error {
    Object(fields) => fields
    _ => raise protocol_error("error response is not an object")
  }
  let kind = required_string(fields, "kind")
  let message = required_string(fields, "message")
  match kind {
    "python" => {
      let type_name = required_string(fields, "type")
      let mut details = required_string(fields, "traceback")
      let stdout = optional_string(fields, "stdout")
      let stderr = optional_string(fields, "stderr")
      if stdout != "" {
        details = details + "\nCaptured stdout:\n" + stdout
      }
      if stderr != "" {
        details = details + "\nCaptured stderr:\n" + stderr
      }
      raise PythonException(type_name, message, details)
    }
    "protocol" => raise ProtocolError(message)
    "worker_died" => raise WorkerDied(message)
    _ => raise protocol_error("unknown remote error kind " + kind)
  }
}

///|
fn validate_response(
  response : Json,
  expected_id : Int,
) -> Json raise OracleError {
  let fields = match response {
    Object(fields) => fields
    _ => raise protocol_error("worker response is not an object")
  }
  if required_int(fields, "version") != 1 {
    raise protocol_error("worker protocol version mismatch")
  }
  if required_int(fields, "id") != expected_id {
    raise protocol_error("worker response id mismatch")
  }
  match required_field(fields, "ok") {
    True => required_field(fields, "value")
    False => {
      raise_remote_error(required_field(fields, "error"))
      abort("unreachable")
    }
    _ => raise protocol_error("response field ok is not a boolean")
  }
}

///|
/// Execute one registered oracle program in the persistent worker.
pub fn request(program : String, input : Json) -> Json raise OracleError {
  let id = symbit_oracle_next_request_id()
  validate_response(
    exchange(
      Json::object({
        "version": Json::number(1),
        "id": Json::number(id.to_double()),
        "program": Json::string(program),
        "input": input,
      }),
    ),
    id,
  )
}

///|
/// Execute a registered string-evaluation program.
pub fn eval_str(program : String, code : String) -> String raise OracleError {
  match request(program, Json::string(code)) {
    String(value) => value
    _ => raise protocol_error("string-evaluation program returned non-string")
  }
}

///|
/// Return the interpreter and SymPy source selected by the live worker.
pub fn worker_info() -> WorkerInfo raise OracleError {
  let fields = match request("runtime.info", Json::null()) {
    Object(fields) => fields
    _ => raise protocol_error("runtime.info returned non-object")
  }
  {
    protocol_version: required_int(fields, "protocol_version"),
    pid: required_int(fields, "pid"),
    python_executable: required_string(fields, "python_executable"),
    python_version: required_string(fields, "python_version"),
    sympy_file: required_string(fields, "sympy_file"),
    sympy_version: required_string(fields, "sympy_version"),
  }
}

///|
#borrow(payload)
extern "C" fn symbit_oracle_exchange(payload : Bytes) -> Bytes = "symbit_oracle_exchange"

///|
extern "C" fn symbit_oracle_next_request_id() -> Int = "symbit_oracle_next_request_id"

///|
extern "C" fn symbit_oracle_reset_worker() -> Unit = "symbit_oracle_reset_worker"
