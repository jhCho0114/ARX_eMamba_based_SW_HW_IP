# eMamba 구현 버전 안내

이 저장소에는 **eMamba의 두 가지 구현 버전**이 포함되어 있습니다.

## 디렉터리 설명

### `tip_v04`
eMamba를 **C 언어로 포팅한 버전**입니다. eMamba의 연산을 C 언어로 구현했습니다.

### `tip_emamba_v1`
**Weight와 Bias가 RTL에 직접 내장된 eMamba 구현 버전**입니다.

- **RTL:** 내장된 Weight와 Bias를 사용해 eMamba 연산을 수행합니다.
- **C:** RTL 구현부에 입력 데이터를 전달하고 연산 결과를 받아오는 역할을 담당합니다.

## 주요 차이점

| 디렉터리 | eMamba 연산 수행 | Weight / Bias | C 언어의 역할 |
|---|---|---|---|
| `tip_v04` | C | C 구현에서 관리 | eMamba 연산 수행 |
| `tip_emamba_v1` | RTL | RTL에 내장 | 입력 데이터 전달 및 출력 결과 수신 |

---

# eMamba Implementations

This repository contains two implementations of **eMamba**.

## Directory Overview

### `tip_v04`
A C-language port of eMamba. The eMamba computation is implemented in C.

### `tip_emamba_v1`
An RTL-based implementation of eMamba with **weights and biases embedded directly in the RTL**.

- **RTL:** Executes the eMamba computation using the embedded weights and biases.
- **C:** Provides input data to the RTL implementation and receives the output results.

## Key Difference

| Directory | eMamba Execution | Weights & Biases | Role of C |
|---|---|---|---|
| `tip_v04` | C | Managed in the C implementation | Runs eMamba |
| `tip_emamba_v1` | RTL | Embedded in RTL | Handles input and output |
