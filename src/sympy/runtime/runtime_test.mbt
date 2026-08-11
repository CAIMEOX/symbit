///|
test "oracle runtime keeps one configured worker alive" {
  let first = @runtime.worker_info()
  assert_true(first.pid > 0)
  assert_eq(first.protocol_version, 1)
  assert_true(first.python_executable.length() > 0)
  assert_true(first.sympy_file.contains("/sympy/sympy/__init__.py"))
  assert_eq(@runtime.eval_str("runtime.eval_str", "40 + 2"), "42")
  let second = @runtime.worker_info()
  assert_eq(second.pid, first.pid)
}

///|
test "oracle runtime preserves Unicode NUL and noisy output" {
  let expected = "α中文😀\"\\\n\u{0000}尾"
  assert_eq(
    @runtime.eval_str(
      "runtime.eval_str",
      "(__import__('sys').stderr.write('noise'), print('noise'), " +
      "'α中文😀\\\"\\\\\\n\\x00尾')[2]",
    ),
    expected,
  )
  assert_eq(
    @runtime.eval_str(
      "runtime.eval_str", "(__import__('os').write(1, b'raw-noise'), 43)[1]",
    ),
    "43",
  )
  assert_eq(@runtime.eval_str("runtime.eval_str", "6 * 7"), "42")
}

///|
test "oracle runtime frames payloads larger than 64 KiB" {
  let expected = "界😀".repeat(40000)
  match @runtime.request("runtime.echo", Json::string(expected)) {
    String(actual) => assert_eq(actual, expected)
    other => fail("expected JSON string, got " + other.stringify())
  }
  assert_eq(@runtime.eval_str("runtime.eval_str", "21 * 2"), "42")
}

///|
test "oracle runtime reports Python exceptions without losing the worker" {
  let before = @runtime.worker_info()
  let seen = try {
    @runtime.eval_str("runtime.eval_str", "1 / 0") |> ignore
    "missing-error"
  } catch {
    PythonException(type_name, message, traceback) =>
      type_name + "|" + message + "|" + traceback
    _ => "wrong-error"
  }
  assert_true(seen.contains("ZeroDivisionError"))
  assert_true(seen.contains("division by zero"))
  assert_true(seen.contains("Traceback"))
  assert_eq(@runtime.eval_str("runtime.eval_str", "40 + 2"), "42")
  assert_eq(@runtime.worker_info().pid, before.pid)
}

///|
test "oracle runtime keeps captured output in Python diagnostics" {
  let diagnostics = try {
    @runtime.eval_str("runtime.eval_str", "(print('before-failure'), 1 / 0)[1]")
    |> ignore
    "missing-error"
  } catch {
    PythonException(_, _, details) => details
    _ => "wrong-error"
  }
  assert_true(diagnostics.contains("before-failure"))
  assert_true(diagnostics.contains("ZeroDivisionError"))
}

///|
test "oracle runtime rejects unknown programs without killing the worker" {
  let before = @runtime.worker_info()
  let seen = try {
    @runtime.request("does.not.exist", Json::null()) |> ignore
    "missing-error"
  } catch {
    ProtocolError(message) => message
    _ => "wrong-error"
  }
  assert_true(seen.contains("unknown program"))
  assert_eq(@runtime.eval_str("runtime.eval_str", "40 + 2"), "42")
  assert_eq(@runtime.worker_info().pid, before.pid)
}

///|
test "oracle runtime keeps framing aligned across repeated requests" {
  let before = @runtime.worker_info()
  for i = 0; i < 256; i = i + 1 {
    let input = Show::to_string(i) + " + 1"
    assert_eq(
      @runtime.eval_str("runtime.eval_str", input),
      Show::to_string(i + 1),
    )
  } where {
    proof_invariant: i >= 0,
    proof_invariant: i <= 256,
    proof_reasoning: (
      #| `i` starts at zero and increases by one toward 256.
    ),
  }
  assert_eq(@runtime.worker_info().pid, before.pid)
}

///|
test "oracle runtime scopes eval globals to one request" {
  assert_eq(
    @runtime.eval_str(
      "runtime.eval_str", "globals().__setitem__('sympy', None)",
    ),
    "None",
  )
  assert_eq(@runtime.eval_str("runtime.eval_str", "sympy.Integer(7)"), "7")
}
