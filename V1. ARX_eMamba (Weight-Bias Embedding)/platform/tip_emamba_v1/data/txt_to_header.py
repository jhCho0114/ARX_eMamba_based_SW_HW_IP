#!/usr/bin/env python3
"""현재 txt 디렉터리의 int8 텍스트 파일을 C 헤더로 변환한다.

입력 형식:
    한 줄에 int8_t 범위(-128~127)의 정수 하나

사용 예:
    python txt_to_header.py --output-dir ../app/ev01/include

출력 예:
    input.txt -> ../app/ev01/include/input.h
    const int8_t input[320] = { ... };
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


INT8_MIN = -128
INT8_MAX = 127
SCRIPT_DIR = Path(__file__).resolve().parent

C_KEYWORDS = {
    "auto", "break", "case", "char", "const", "continue", "default", "do",
    "double", "else", "enum", "extern", "float", "for", "goto", "if",
    "inline", "int", "long", "register", "restrict", "return", "short",
    "signed", "sizeof", "static", "struct", "switch", "typedef", "union",
    "unsigned", "void", "volatile", "while",
    "_Alignas", "_Alignof", "_Atomic", "_Bool", "_Complex", "_Generic",
    "_Imaginary", "_Noreturn", "_Static_assert", "_Thread_local",
}


def validate_filename(path: Path) -> None:
    """파일명에 공백 문자가 있으면 변환을 거부한다."""
    if any(char.isspace() for char in path.name):
        raise ValueError(
            f"{path.name}: 파일명에 공백 문자가 포함되어 있습니다. "
            "띄어쓰기·탭 등 공백을 제거하세요."
        )


def make_c_identifier(stem: str) -> str:
    """파일명 stem을 안전한 C 배열 변수명으로 변환한다."""
    identifier = re.sub(r"[^A-Za-z0-9_]", "_", stem)

    if not identifier:
        identifier = "data"

    # 전역 식별자에서 예약될 수 있는 '_' 시작 이름은 피한다.
    if identifier[0].isdigit() or identifier.startswith("_"):
        identifier = f"data_{identifier.lstrip('_')}"

    if identifier in C_KEYWORDS:
        identifier = f"data_{identifier}"

    return identifier


def parse_int8_file(path: Path) -> list[int]:
    """한 줄당 하나의 정수인 TXT를 읽고 int8 범위를 검증한다."""
    values: list[int] = []

    for line_no, raw_line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        value_text = raw_line.strip()

        # 빈 줄은 허용한다.
        if not value_text:
            continue

        try:
            value = int(value_text, 10)
        except ValueError as exc:
            raise ValueError(
                f"{path.name}:{line_no}: 정수가 아닙니다: {value_text!r}"
            ) from exc

        if not INT8_MIN <= value <= INT8_MAX:
            raise ValueError(
                f"{path.name}:{line_no}: int8_t 범위 "
                f"({INT8_MIN}~{INT8_MAX})를 벗어났습니다: {value}"
            )

        values.append(value)

    if not values:
        raise ValueError(f"{path.name}: 변환할 숫자가 없습니다.")

    return values


def format_array(values: list[int], values_per_line: int = 16) -> str:
    lines: list[str] = []

    for start in range(0, len(values), values_per_line):
        chunk = values[start : start + values_per_line]
        suffix = "," if start + values_per_line < len(values) else ""
        lines.append("    " + ", ".join(map(str, chunk)) + suffix)

    return "\n".join(lines)


def make_header(source_path: Path, values: list[int]) -> tuple[str, str]:
    array_name = make_c_identifier(source_path.stem)
    guard = f"TXT_TO_HEADER_{array_name.upper()}_H"

    header = f"""\\
#ifndef {guard}
#define {guard}

#include <stdint.h>

const int8_t {array_name}[{len(values)}] = {{
{format_array(values)}
}};

#endif  // {guard}
"""
    return array_name, header


def main() -> int:
    parser = argparse.ArgumentParser(
        description="현재 TXT 디렉터리의 int8 값을 C 헤더 파일로 변환합니다."
    )
    parser.add_argument(
        "--input-dir",
        type=Path,
        default=SCRIPT_DIR,
        help="변환할 .txt 파일이 있는 디렉터리 (기본값: 스크립트 위치)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        required=True,
        help="생성된 .h 파일을 저장할 디렉터리",
    )
    args = parser.parse_args()

    input_dir: Path = args.input_dir.resolve()
    output_dir: Path = args.output_dir.resolve()

    if not input_dir.is_dir():
        raise FileNotFoundError(f"입력 디렉터리를 찾지 못했습니다: {input_dir}")

    input_paths = sorted(path for path in input_dir.glob("*.txt") if path.is_file())
    if not input_paths:
        raise FileNotFoundError(f".txt 파일을 찾지 못했습니다: {input_dir}")

    # 하나라도 오류가 있으면 헤더 파일을 하나도 쓰지 않는다.
    converted: list[tuple[Path, list[int]]] = []
    for input_path in input_paths:
        validate_filename(input_path)
        converted.append((input_path, parse_int8_file(input_path)))

    output_dir.mkdir(parents=True, exist_ok=True)

    for input_path, values in converted:
        array_name, header = make_header(input_path, values)
        output_path = output_dir / f"{input_path.stem}.h"
        output_path.write_text(header, encoding="utf-8", newline="\n")
        print(f"생성: {output_path} ({len(values)}개, 배열명: {array_name})")

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (FileNotFoundError, ValueError, OSError) as exc:
        print(f"오류: {exc}", file=sys.stderr)
        raise SystemExit(1)
