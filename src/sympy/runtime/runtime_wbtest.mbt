///|
test "oracle runtime contains worker death and restarts on demand" {
  let before = worker_info()
  let saw_worker_death = try {
    request("runtime.crash", Json::null()) |> ignore
    false
  } catch {
    WorkerDied(_) => true
    _ => false
  }
  assert_true(saw_worker_death)
  let after = worker_info()
  assert_true(after.pid > 0)
  assert_true(after.pid != before.pid)
  assert_eq(eval_str("runtime.eval_str", "40 + 2"), "42")
}

///|
test "oracle runtime rejects fractional protocol integers" {
  let rejected = try {
    required_int({ "id": Json::number(1.5) }, "id") |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  assert_true(rejected)
}

///|
test "oracle runtime validates response envelope shape and identity" {
  let mismatched_id = Json::object({
    "version": Json::number(1),
    "id": Json::number(2),
    "ok": Json::boolean(true),
    "value": Json::null(),
  })
  let rejected_id = try {
    validate_response(mismatched_id, 1) |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  let invalid_ok = Json::object({
    "version": Json::number(1),
    "id": Json::number(1),
    "ok": Json::string("yes"),
  })
  let rejected_ok = try {
    validate_response(invalid_ok, 1) |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  let rejected_shape = try {
    validate_response(Json::array([]), 1) |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  assert_true(rejected_id)
  assert_true(rejected_ok)
  assert_true(rejected_shape)
}

///|
test "oracle runtime distinguishes transport status classes" {
  let spawn_error = try {
    decode_transport_result(Bytes::make(1, b'\x02')) |> ignore
    false
  } catch {
    TransportError(_) => true
    _ => false
  }
  let frame_error = try {
    decode_transport_result(Bytes::make(1, b'\x06')) |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  let timeout_error = try {
    decode_transport_result(Bytes::make(1, b'\x07')) |> ignore
    false
  } catch {
    WorkerTimeout(_) => true
    _ => false
  }
  assert_true(spawn_error)
  assert_true(frame_error)
  assert_true(timeout_error)
}

///|
test "oracle runtime rejects malformed UTF-8 and JSON payloads" {
  let invalid_utf8 = Bytes::makei(2, index => {
    if index == 0 {
      b'\x00'
    } else {
      b'\xff'
    }
  })
  let rejected_utf8 = try {
    decode_transport_result(invalid_utf8) |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  let invalid_json = Bytes::makei(2, index => {
    if index == 0 {
      b'\x00'
    } else {
      b'{'
    }
  })
  let rejected_json = try {
    decode_transport_result(invalid_json) |> ignore
    false
  } catch {
    ProtocolError(_) => true
    _ => false
  }
  assert_true(rejected_utf8)
  assert_true(rejected_json)
}

///|
test "oracle runtime times out a stuck worker and restarts" {
  let before = worker_info()
  symbit_oracle_set_timeout_for_test(100)
  let timed_out = try {
    eval_str("runtime.eval_str", "(__import__('time').sleep(1), 42)[1]")
    |> ignore
    false
  } catch {
    WorkerTimeout(_) => true
    _ => false
  }
  symbit_oracle_set_timeout_for_test(30000)
  assert_true(timed_out)
  let after = worker_info()
  assert_true(after.pid != before.pid)
  assert_eq(eval_str("runtime.eval_str", "40 + 2"), "42")
}

///|
extern "C" fn symbit_oracle_set_timeout_for_test(timeout_ms : Int) -> Unit = "symbit_oracle_set_timeout_for_test"
