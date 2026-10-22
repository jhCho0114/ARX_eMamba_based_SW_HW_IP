#!/usr/bin/env python3
"""
JSON의 int_value 배열을 줄바꿈으로 구분된 int8 텍스트 파일로 변환한다.

사용 예:
    python json_to_txt.py down_input_token.json
    python json_to_txt.py down_input_token.json -o down_input_token.txt
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


INT8_MIN = -128
INT8_MAX = 127


def flatten_int8(value: Any, location: str = "int_value") -> tuple[list[int], tuple[int, ...]]:
    """중첩 리스트를 평탄화하고, 직사각형 shape 및 int8 범위를 검증한다."""
    if isinstance(value, list):
        if not value:
            return [], (0,)

        flattened: list[int] = []
        child_shape: tuple[int, ...] | None = None

        for index, item in enumerate(value):
            child_values, item_shape = flatten_int8(item, f"{location}[{index}]")

            if child_shape is None:
                child_shape = item_shape
            elif item_shape != child_shape:
                raise ValueError(
                    f"{location}: 직사각형 배열이 아닙니다. "
                    f"{location}[{index}]의 shape {item_shape}가 이전 shape {child_shape}와 다릅니다."
                )

            flattened.extend(child_values)

        return flattened, (len(value),) + (child_shape or ())

    if isinstance(value, bool) or not isinstance(value, int):
        raise ValueError(f"{location}: 정수가 아닌 값 {value!r}가 있습니다.")

    if not INT8_MIN <= value <= INT8_MAX:
        raise ValueError(
            f"{location}: 값 {value}가 int8_t 범위 "
            f"({INT8_MIN} ~ {INT8_MAX})를 벗어났습니다."
        )

    return [value], ()


def main() -> int:
    parser = argparse.ArgumentParser(
        description="JSON의 int_value를 한 줄당 하나의 int8 값으로 TXT 파일에 저장합니다."
    )
    parser.add_argument("input_json", type=Path, help="입력 JSON 파일")
    parser.add_argument(
        "-o",
        "--output",
        type=Path,
        help="출력 TXT 파일 경로 (생략 시 입력 파일과 같은 이름의 .txt 파일)",
    )
    args = parser.parse_args()

    input_path: Path = args.input_json
    output_path: Path = args.output or input_path.with_suffix(".txt")

    if not input_path.is_file():
        print(f"오류: 입력 파일을 찾을 수 없습니다: {input_path}", file=sys.stderr)
        return 1

    try:
        with input_path.open("r", encoding="utf-8") as file:
            data = json.load(file)

        if not isinstance(data, dict):
            raise ValueError("JSON 최상위 구조는 객체(object)여야 합니다.")

        if "int_value" not in data:
            raise ValueError('JSON에 "int_value" 키가 없습니다.')

        values, shape = flatten_int8(data["int_value"])

        if not values:
            raise ValueError('"int_value" 배열이 비어 있습니다.')

        output_path.parent.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8", newline="\n") as file:
            file.write("\n".join(str(value) for value in values))
            file.write("\n")

        print(f"완료: {output_path}")
        print(f"shape: {shape}, 총 값 개수: {len(values)}")
        return 0

    except (OSError, json.JSONDecodeError, ValueError) as error:
        print(f"오류: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
