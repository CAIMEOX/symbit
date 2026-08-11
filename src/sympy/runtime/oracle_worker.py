#!/usr/bin/env python3
"""Persistent, framed JSON worker for Symbit's test-only SymPy oracle."""

from __future__ import annotations

import builtins
import contextlib
import importlib
import io
import json
import os
import operator
from pathlib import Path
import struct
import sys
import traceback
from typing import Any, Callable


PROTOCOL_VERSION = 1
MAX_FRAME_SIZE = 64 * 1024 * 1024
MAX_JSON_SAFE_INTEGER = (1 << 53) - 1


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


def _utilities_globals() -> dict[str, Any]:
    sympy_names = (
        "Eq", "Function", "I", "Integral", "Pow", "S", "Symbol", "acos",
        "cos", "cosh", "exp", "log", "sin", "sinh", "sqrt",
    )
    globals_dict = {
        "__builtins__": builtins,
        "sympy": sympy,
        "json": json,
    }
    globals_dict.update({name: getattr(sympy, name) for name in sympy_names})
    globals_dict.update(
        {
            name: sympy.Symbol(name)
            for name in ("x", "y", "z", "C1", "C2", "C3", "u2", "_a")
        }
    )
    globals_dict.update(
        {
            name: sympy.Function(name)
            for name in ("f", "g", "h", "u", "X", "Y")
        }
    )
    return globals_dict


def _sympy_base_globals() -> dict[str, Any]:
    globals_dict = {
        "__builtins__": dict(builtins.__dict__),
        "sympy": sympy,
        "json": json,
    }
    globals_dict.update(
        {
            name: value
            for name, value in vars(sympy).items()
            if not name.startswith("_")
        }
    )
    return globals_dict


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


def _utilities_eval_str(code: Any) -> str:
    if not isinstance(code, str):
        raise ProtocolFault("utilities evaluation input must be a string")
    globals_dict = _utilities_globals()
    return str(eval(code, globals_dict, globals_dict))


def _exec_result_str(script: Any) -> str:
    if not isinstance(script, str):
        raise ProtocolFault("script-execution input must be a string")
    globals_dict = {
        "__builtins__": builtins.__dict__,
        "sympy": sympy,
    }
    exec(script, globals_dict, globals_dict)
    return str(globals_dict["__result__"])


def _crash(_: Any) -> None:
    os._exit(86)


def _recipe_ref(value: Any, *, before: int, context: str) -> int:
    if not isinstance(value, dict) or set(value) != {"ref"}:
        raise ProtocolFault(f"{context} must be a reference object")
    ref = value["ref"]
    if type(ref) is not int or not 0 <= ref < before:
        raise ProtocolFault(f"{context} must reference an earlier node")
    return ref


def _recipe_exact_fields(
    value: dict[str, Any], expected: set[str], *, context: str
) -> None:
    if set(value) != expected:
        raise ProtocolFault(f"{context} has invalid fields")


def _validate_recipe_codec(codec: Any, *, context: str) -> None:
    if isinstance(codec, str):
        if codec not in (
            "discard", "none", "str", "repr", "srepr", "bool", "int",
            "float", "json",
        ):
            raise ProtocolFault(f"{context} has unknown codec")
        return
    if not isinstance(codec, dict):
        raise ProtocolFault(f"{context} has unknown codec")
    kind = codec.get("kind")
    if kind in ("optional", "list"):
        if set(codec) != {"kind", "item"}:
            raise ProtocolFault(f"{context} {kind} codec has invalid fields")
        _validate_recipe_codec(codec["item"], context=f"{context} {kind} item")
    elif kind == "tuple":
        if set(codec) != {"kind", "items"} or not isinstance(
            codec.get("items"), list
        ):
            raise ProtocolFault(f"{context} tuple codec has invalid fields")
        for index, item_codec in enumerate(codec["items"]):
            _validate_recipe_codec(
                item_codec, context=f"{context} tuple item {index}"
            )
    elif kind == "dict_pairs":
        if set(codec) != {"kind", "key", "value"}:
            raise ProtocolFault(
                f"{context} dict_pairs codec has invalid fields"
            )
        _validate_recipe_codec(codec["key"], context=f"{context} dict key")
        _validate_recipe_codec(
            codec["value"], context=f"{context} dict value"
        )
    else:
        raise ProtocolFault(f"{context} has unknown codec")


def _validate_json_safe_integers(
    value: Any, seen: set[int] | None = None
) -> None:
    if isinstance(value, int) and not isinstance(value, bool):
        if abs(value) > MAX_JSON_SAFE_INTEGER:
            raise ProtocolFault(
                "recipe JSON result exceeds the JSON-safe integer range"
            )
        return
    if not isinstance(value, (list, tuple, dict)):
        return
    if seen is None:
        seen = set()
    object_id = id(value)
    if object_id in seen:
        return
    seen.add(object_id)
    if isinstance(value, dict):
        for key, item in value.items():
            _validate_json_safe_integers(key, seen)
            _validate_json_safe_integers(item, seen)
    else:
        for item in value:
            _validate_json_safe_integers(item, seen)


def _encode_recipe_result(value: Any, codec: Any) -> Any:
    if isinstance(codec, dict):
        kind = codec["kind"]
        if kind == "optional":
            if value is None:
                return None
            return _encode_recipe_result(value, codec["item"])
        if kind == "list":
            if not isinstance(value, list):
                raise ProtocolFault("recipe result expected a list")
            return [
                _encode_recipe_result(item, codec["item"]) for item in value
            ]
        if kind == "tuple":
            if not isinstance(value, tuple) or len(value) != len(codec["items"]):
                raise ProtocolFault("recipe result expected a matching tuple")
            return [
                _encode_recipe_result(item, item_codec)
                for item, item_codec in zip(value, codec["items"])
            ]
        if not isinstance(value, dict):
            raise ProtocolFault("recipe result expected a dict")
        return [
            [
                _encode_recipe_result(key, codec["key"]),
                _encode_recipe_result(item, codec["value"]),
            ]
            for key, item in value.items()
        ]
    if codec == "discard":
        return None
    if codec == "none":
        if value is not None:
            raise ProtocolFault("recipe result expected None")
        return None
    if codec == "str":
        return str(value)
    if codec == "repr":
        return repr(value)
    if codec == "srepr":
        return sympy.srepr(value)
    if codec == "bool":
        if value is True or value is sympy.true:
            return True
        if value is False or value is sympy.false:
            return False
        raise ProtocolFault("recipe result expected a boolean")
    if codec == "int":
        try:
            return str(operator.index(value))
        except TypeError as exc:
            raise ProtocolFault(
                "recipe result expected an index-compatible integer"
            ) from exc
    if codec == "float":
        return repr(float(value))
    _validate_json_safe_integers(value)
    try:
        return json.loads(
            json.dumps(value, ensure_ascii=False, allow_nan=False)
        )
    except (TypeError, ValueError) as exc:
        raise ProtocolFault("recipe result is not valid JSON") from exc


def _recipe_v1(recipe: Any) -> Any:
    if not isinstance(recipe, dict):
        raise ProtocolFault("recipe must be a JSON object")
    _recipe_exact_fields(
        recipe, {"schema", "nodes", "result"}, context="recipe"
    )
    if type(recipe.get("schema")) is not int or recipe["schema"] != 1:
        raise ProtocolFault("recipe schema must be 1")
    nodes = recipe.get("nodes")
    if not isinstance(nodes, list):
        raise ProtocolFault("recipe nodes must be an array")
    for expected_id, node in enumerate(nodes):
        if not isinstance(node, dict):
            raise ProtocolFault(f"recipe node {expected_id} must be an object")
        if type(node.get("id")) is not int or node["id"] != expected_id:
            raise ProtocolFault(
                f"recipe node {expected_id} id must equal its array index"
            )
        op = node.get("op")
        if op == "const":
            codec = node.get("codec")
            if codec == "none":
                _recipe_exact_fields(
                    node, {"id", "op", "codec"},
                    context=f"recipe node {expected_id}",
                )
                if "value" in node:
                    raise ProtocolFault(
                        f"recipe node {expected_id} none constant cannot have a value"
                    )
            else:
                _recipe_exact_fields(
                    node, {"id", "op", "codec", "value"},
                    context=f"recipe node {expected_id}",
                )
                if codec == "bool" and type(node.get("value")) is bool:
                    pass
                elif codec == "str" and isinstance(node.get("value"), str):
                    pass
                elif codec == "int" and isinstance(node.get("value"), str):
                    try:
                        int(node["value"], 10)
                    except ValueError as exc:
                        raise ProtocolFault(
                            f"recipe node {expected_id} int constant must be a decimal string"
                        ) from exc
                elif codec == "float" and isinstance(node.get("value"), str):
                    try:
                        float(node["value"])
                    except ValueError as exc:
                        raise ProtocolFault(
                            f"recipe node {expected_id} float constant must be a string"
                        ) from exc
                else:
                    raise ProtocolFault(
                        f"recipe node {expected_id} has unknown constant codec"
                    )
        elif op == "import":
            _recipe_exact_fields(
                node, {"id", "op", "module"},
                context=f"recipe node {expected_id}",
            )
            if not isinstance(node.get("module"), str):
                raise ProtocolFault(
                    f"recipe node {expected_id} import module must be a string"
                )
        elif op == "getattr":
            _recipe_exact_fields(
                node, {"id", "op", "object", "name"},
                context=f"recipe node {expected_id}",
            )
            _recipe_ref(
                node.get("object"),
                before=expected_id,
                context=f"recipe node {expected_id} object",
            )
            if not isinstance(node.get("name"), str):
                raise ProtocolFault(
                    f"recipe node {expected_id} attribute name must be a string"
                )
        elif op == "getattr_or":
            _recipe_exact_fields(
                node, {"id", "op", "object", "name", "fallback"},
                context=f"recipe node {expected_id}",
            )
            _recipe_ref(
                node.get("object"),
                before=expected_id,
                context=f"recipe node {expected_id} object",
            )
            if not isinstance(node.get("name"), str):
                raise ProtocolFault(
                    f"recipe node {expected_id} name must be a string"
                )
            _recipe_ref(
                node.get("fallback"),
                before=expected_id,
                context=f"recipe node {expected_id} fallback",
            )
        elif op == "getitem":
            _recipe_exact_fields(
                node, {"id", "op", "object", "key"},
                context=f"recipe node {expected_id}",
            )
            _recipe_ref(
                node.get("object"),
                before=expected_id,
                context=f"recipe node {expected_id} object",
            )
            _recipe_ref(
                node.get("key"),
                before=expected_id,
                context=f"recipe node {expected_id} key",
            )
        elif op == "call":
            _recipe_exact_fields(
                node, {"id", "op", "callable", "args", "kwargs"},
                context=f"recipe node {expected_id}",
            )
            _recipe_ref(
                node.get("callable"),
                before=expected_id,
                context=f"recipe node {expected_id} callable",
            )
            args = node.get("args")
            if not isinstance(args, list):
                raise ProtocolFault(
                    f"recipe node {expected_id} call args must be an array"
                )
            for arg_index, arg in enumerate(args):
                _recipe_ref(
                    arg,
                    before=expected_id,
                    context=f"recipe node {expected_id} arg {arg_index}",
                )
            kwargs = node.get("kwargs")
            if not isinstance(kwargs, dict):
                raise ProtocolFault(
                    f"recipe node {expected_id} call kwargs must be an object"
                )
            for name, value in kwargs.items():
                if not isinstance(name, str):
                    raise ProtocolFault(
                        f"recipe node {expected_id} kwarg name must be a string"
                    )
                _recipe_ref(
                    value,
                    before=expected_id,
                    context=f"recipe node {expected_id} kwarg {name}",
                )
        elif op == "collection":
            _recipe_exact_fields(
                node, {"id", "op", "kind", "items"},
                context=f"recipe node {expected_id}",
            )
            kind = node.get("kind")
            if kind not in ("list", "tuple", "set", "frozenset", "dict"):
                raise ProtocolFault(
                    f"recipe node {expected_id} has unknown collection kind"
                )
            items = node.get("items")
            if not isinstance(items, list):
                raise ProtocolFault(
                    f"recipe node {expected_id} collection items must be an array"
                )
            if kind == "dict":
                for item_index, pair in enumerate(items):
                    if not isinstance(pair, list) or len(pair) != 2:
                        raise ProtocolFault(
                            f"recipe node {expected_id} dict item {item_index} must be a pair"
                        )
                    for pair_index, value in enumerate(pair):
                        _recipe_ref(
                            value,
                            before=expected_id,
                            context=(
                                f"recipe node {expected_id} dict item "
                                f"{item_index}:{pair_index}"
                            ),
                        )
            else:
                for item_index, value in enumerate(items):
                    _recipe_ref(
                        value,
                        before=expected_id,
                        context=(
                            f"recipe node {expected_id} collection item {item_index}"
                        ),
                    )
        elif op == "scope":
            _recipe_exact_fields(
                node, {"id", "op", "profile"},
                context=f"recipe node {expected_id}",
            )
            if node.get("profile") != "sympy.base":
                raise ProtocolFault(
                    f"recipe node {expected_id} has unknown scope profile"
                )
        elif op == "bind":
            _recipe_exact_fields(
                node, {"id", "op", "scope", "name", "value"},
                context=f"recipe node {expected_id}",
            )
            _recipe_ref(
                node.get("scope"),
                before=expected_id,
                context=f"recipe node {expected_id} scope",
            )
            if not isinstance(node.get("name"), str):
                raise ProtocolFault(
                    f"recipe node {expected_id} binding name must be a string"
                )
            _recipe_ref(
                node.get("value"),
                before=expected_id,
                context=f"recipe node {expected_id} value",
            )
        elif op in ("exec", "eval"):
            _recipe_exact_fields(
                node, {"id", "op", "scope", "code"},
                context=f"recipe node {expected_id}",
            )
            _recipe_ref(
                node.get("scope"),
                before=expected_id,
                context=f"recipe node {expected_id} scope",
            )
            if not isinstance(node.get("code"), str):
                raise ProtocolFault(
                    f"recipe node {expected_id} code must be a string"
                )
        elif op == "require_non_none":
            expected_fields = {"id", "op", "value"}
            if "message" in node:
                expected_fields.add("message")
            _recipe_exact_fields(
                node, expected_fields, context=f"recipe node {expected_id}"
            )
            _recipe_ref(
                node.get("value"),
                before=expected_id,
                context=f"recipe node {expected_id} value",
            )
            if "message" in node and not isinstance(node["message"], str):
                raise ProtocolFault(
                    f"recipe node {expected_id} message must be a string"
                )
        else:
            raise ProtocolFault(
                f"recipe node {expected_id} has unknown op: {op}"
            )
    result = recipe.get("result")
    if not isinstance(result, dict):
        raise ProtocolFault("recipe result must be an object")
    _recipe_exact_fields(
        result, {"ref", "codec"}, context="recipe result"
    )
    result_ref = result.get("ref")
    if type(result_ref) is not int or not 0 <= result_ref < len(nodes):
        raise ProtocolFault("recipe result ref is out of range")
    result_codec = result.get("codec")
    _validate_recipe_codec(result_codec, context="recipe result")

    new, evaluating, done = 0, 1, 2
    states = [new] * len(nodes)
    values: list[Any] = [None] * len(nodes)

    def evaluate(node_id: int) -> Any:
        if states[node_id] == done:
            return values[node_id]
        if states[node_id] == evaluating:
            raise ProtocolFault(f"recipe node {node_id} is cyclic")
        states[node_id] = evaluating
        node = nodes[node_id]
        op = node["op"]
        if op == "const":
            if node["codec"] == "none":
                value = None
            elif node["codec"] == "int":
                value = int(node["value"], 10)
            elif node["codec"] == "float":
                value = float(node["value"])
            else:
                value = node["value"]
        elif op == "import":
            value = importlib.import_module(node["module"])
        elif op == "getattr":
            value = getattr(evaluate(node["object"]["ref"]), node["name"])
        elif op == "getattr_or":
            object_value = evaluate(node["object"]["ref"])
            try:
                value = getattr(object_value, node["name"])
            except AttributeError:
                value = evaluate(node["fallback"]["ref"])
        elif op == "getitem":
            value = evaluate(node["object"]["ref"])[
                evaluate(node["key"]["ref"])
            ]
        elif op == "call":
            function = evaluate(node["callable"]["ref"])
            args = [evaluate(arg["ref"]) for arg in node["args"]]
            kwargs = {
                name: evaluate(argument["ref"])
                for name, argument in node["kwargs"].items()
            }
            value = function(*args, **kwargs)
        elif op == "collection":
            kind = node["kind"]
            if kind == "dict":
                value = {
                    evaluate(pair[0]["ref"]): evaluate(pair[1]["ref"])
                    for pair in node["items"]
                }
            else:
                items = [evaluate(item["ref"]) for item in node["items"]]
                if kind == "list":
                    value = items
                elif kind == "tuple":
                    value = tuple(items)
                elif kind == "set":
                    value = set(items)
                else:
                    value = frozenset(items)
        elif op == "scope":
            value = _sympy_base_globals()
        elif op == "bind":
            scope = evaluate(node["scope"]["ref"])
            scope[node["name"]] = evaluate(node["value"]["ref"])
            value = scope
        elif op == "exec":
            scope = evaluate(node["scope"]["ref"])
            exec(node["code"], scope, scope)
            value = scope
        elif op == "eval":
            scope = evaluate(node["scope"]["ref"])
            value = eval(node["code"], scope, scope)
        else:
            value = evaluate(node["value"]["ref"])
            if value is None:
                raise ValueError(
                    node.get("message", "recipe value must not be None")
                )
        values[node_id] = value
        states[node_id] = done
        return value

    return _encode_recipe_result(evaluate(result_ref), result_codec)


PROGRAMS: dict[str, Callable[[Any], Any]] = {
    "runtime.info": _runtime_info,
    "runtime.echo": _echo,
    "runtime.eval_str": _eval_str,
    "runtime.crash": _crash,
    "integrals.eval_str": _eval_str,
    "unify.exec_result_str": _exec_result_str,
    "utilities.eval_str": _utilities_eval_str,
    "oracle.recipe.v1": _recipe_v1,
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
