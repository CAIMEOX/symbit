#!/usr/bin/env python3
"""Persistent, framed JSON worker for Symbit's test-only SymPy oracle."""

from __future__ import annotations

import builtins
import contextlib
import io
import json
import os
from pathlib import Path
import struct
import sys
import traceback
from typing import Any, Callable


PROTOCOL_VERSION = 1
MAX_FRAME_SIZE = 64 * 1024 * 1024


def _open_protocol_output() -> Any:
    if len(sys.argv) != 3 or sys.argv[1] != "--protocol-fd":
        raise RuntimeError("expected --protocol-fd <number>")
    try:
        protocol_fd = int(sys.argv[2])
    except ValueError as exc:
        raise RuntimeError("protocol fd must be an integer") from exc
    return os.fdopen(protocol_fd, "wb", buffering=0, closefd=False)


PROTOCOL_OUTPUT = _open_protocol_output()


class ProtocolFault(Exception):
    pass


def _is_sympy_source(path: Path) -> bool:
    return (path / "sympy" / "__init__.py").is_file()


def _find_sympy_source() -> Path:
    seen: set[Path] = set()
    source_file = Path(__file__).resolve()
    for base in (source_file, *source_file.parents):
        for candidate in (base / "sympy", base.parent / "sympy"):
            candidate = candidate.resolve()
            if candidate in seen:
                continue
            seen.add(candidate)
            if _is_sympy_source(candidate):
                return candidate
    raise RuntimeError("sibling repository SymPy source was not found")


SYMPY_SOURCE = _find_sympy_source()
sys.path.insert(0, str(SYMPY_SOURCE))
for module_name in tuple(sys.modules):
    if module_name == "sympy" or module_name.startswith("sympy."):
        sys.modules.pop(module_name, None)

import sympy  # noqa: E402

SYMPY_FILE = Path(sympy.__file__).resolve()
try:
    SYMPY_FILE.relative_to(SYMPY_SOURCE)
except ValueError as exc:
    raise RuntimeError(
        f"loaded SymPy outside repository source: {SYMPY_FILE}"
    ) from exc


def _integrals_globals() -> dict[str, Any]:
    names = (
        "sqrt", "exp", "exp_polar", "sin", "cos", "tan", "cot", "sec",
        "csc", "sinh", "cosh", "tanh", "coth", "acoth", "log", "atan",
        "atanh", "asin", "asinh", "arg", "re", "im", "polar_lift", "Ei",
        "expint", "E1", "Si", "Ci", "Shi", "Chi", "erf", "erfc",
        "fresnels", "fresnelc", "besselj", "bessely", "besselk", "besseli",
        "gamma", "lowergamma", "uppergamma", "Abs", "DiracDelta",
        "Heaviside", "SingularityFunction", "Piecewise", "Tuple", "And", "Or",
        "Not", "Eq", "Ne", "Min", "Max", "Lt", "Le", "Gt", "Ge",
        "Derivative", "Subs", "LaplaceTransform", "InverseLaplaceTransform",
        "Matrix",
    )
    symbol_cache: dict[str, Any] = {}

    def symbol(name: str) -> Any:
        try:
            return symbol_cache[name]
        except KeyError:
            value = sympy.Symbol(name)
            symbol_cache[name] = value
            return value

    return {
        "__builtins__": builtins.__dict__,
        "sympy": sympy,
        "json": json,
        "__symbit_locals": {name: getattr(sympy, name) for name in names},
        "__symbit_symbol_cache": symbol_cache,
        "__symbit_symbol": symbol,
    }


def _runtime_info(_: Any) -> dict[str, Any]:
    return {
        "protocol_version": PROTOCOL_VERSION,
        "pid": os.getpid(),
        "python_executable": sys.executable,
        "python_version": sys.version,
        "sympy_file": str(SYMPY_FILE),
        "sympy_version": sympy.__version__,
    }


def _echo(value: Any) -> Any:
    return value


def _eval_str(code: Any) -> str:
    if not isinstance(code, str):
        raise ProtocolFault("string-evaluation input must be a string")
    globals_dict = _integrals_globals()
    return str(eval(code, globals_dict, globals_dict))


def _crash(_: Any) -> None:
    os._exit(86)


PROGRAMS: dict[str, Callable[[Any], Any]] = {
    "runtime.info": _runtime_info,
    "runtime.echo": _echo,
    "runtime.eval_str": _eval_str,
    "runtime.crash": _crash,
    "integrals.eval_str": _eval_str,
}


def _response(request_id: int, *, value: Any) -> dict[str, Any]:
    return {
        "version": PROTOCOL_VERSION,
        "id": request_id,
        "ok": True,
        "value": value,
    }


def _error_response(
    request_id: int,
    *,
    kind: str,
    type_name: str,
    message: str,
    traceback_text: str,
    stdout: str = "",
    stderr: str = "",
) -> dict[str, Any]:
    return {
        "version": PROTOCOL_VERSION,
        "id": request_id,
        "ok": False,
        "error": {
            "kind": kind,
            "type": type_name,
            "message": message,
            "traceback": traceback_text,
            "stdout": stdout,
            "stderr": stderr,
        },
    }


def _dispatch(request: Any) -> dict[str, Any]:
    if not isinstance(request, dict):
        raise ProtocolFault("request must be a JSON object")
    request_id = request.get("id")
    if isinstance(request_id, bool) or not isinstance(request_id, int):
        raise ProtocolFault("request id must be an integer")
    if request.get("version") != PROTOCOL_VERSION:
        raise ProtocolFault("protocol version mismatch")
    program = request.get("program")
    if not isinstance(program, str):
        raise ProtocolFault("program must be a string")
    handler = PROGRAMS.get(program)
    if handler is None:
        raise ProtocolFault(f"unknown program: {program}")
    return _response(request_id, value=handler(request.get("input")))


def _handle(request: Any) -> dict[str, Any]:
    request_id = request.get("id", 0) if isinstance(request, dict) else 0
    if isinstance(request_id, bool) or not isinstance(request_id, int):
        request_id = 0
    stdout = io.StringIO()
    stderr = io.StringIO()
    try:
        with contextlib.redirect_stdout(stdout), contextlib.redirect_stderr(stderr):
            return _dispatch(request)
    except ProtocolFault as exc:
        return _error_response(
            request_id,
            kind="protocol",
            type_name=type(exc).__name__,
            message=str(exc),
            traceback_text="",
            stdout=stdout.getvalue(),
            stderr=stderr.getvalue(),
        )
    except BaseException as exc:
        return _error_response(
            request_id,
            kind="python",
            type_name=type(exc).__name__,
            message=str(exc),
            traceback_text=traceback.format_exc(),
            stdout=stdout.getvalue(),
            stderr=stderr.getvalue(),
        )


def _read_exact(size: int) -> bytes | None:
    chunks: list[bytes] = []
    remaining = size
    while remaining:
        chunk = sys.stdin.buffer.read(remaining)
        if not chunk:
            return None
        chunks.append(chunk)
        remaining -= len(chunk)
    return b"".join(chunks)


def _read_frame() -> bytes | None:
    header = _read_exact(4)
    if header is None:
        return None
    size = struct.unpack(">I", header)[0]
    if size > MAX_FRAME_SIZE:
        raise ProtocolFault(f"request frame exceeds {MAX_FRAME_SIZE} bytes")
    payload = _read_exact(size)
    if payload is None:
        raise ProtocolFault("request frame ended early")
    return payload


def _write_frame(payload: bytes) -> None:
    if len(payload) > MAX_FRAME_SIZE:
        raise ProtocolFault(f"response frame exceeds {MAX_FRAME_SIZE} bytes")
    PROTOCOL_OUTPUT.write(struct.pack(">I", len(payload)))
    PROTOCOL_OUTPUT.write(payload)
    PROTOCOL_OUTPUT.flush()


def main() -> int:
    while True:
        try:
            frame = _read_frame()
            if frame is None:
                return 0
            request = json.loads(frame.decode("utf-8"))
            response = _handle(request)
        except BaseException as exc:
            response = _error_response(
                0,
                kind="protocol",
                type_name=type(exc).__name__,
                message=str(exc),
                traceback_text=traceback.format_exc(),
            )
        encoded = json.dumps(
            response,
            ensure_ascii=False,
            separators=(",", ":"),
        ).encode("utf-8")
        _write_frame(encoded)


if __name__ == "__main__":
    raise SystemExit(main())
