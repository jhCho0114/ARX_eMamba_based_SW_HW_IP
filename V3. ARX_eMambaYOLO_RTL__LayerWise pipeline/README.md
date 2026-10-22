# eMamba-YOLO INT8 RTL (U_106)

Mamba-YOLO-T (COCO, 640×640) INT8 모델의 **layer 0–20 전체**를 SystemVerilog 로 구현한 RTL 입니다.
SS2D 의 selective scan 은 eMamba SSM 코어 방식 (ReLU delta, PWL exp, 4 방향 단방향 scan) 을 따릅니다.
top 모듈: `rtl/top/eMambaYOLO.sv`.

## HW / SW 경계

| 위치 | 하는 일 |
|---|---|
| 호스트 (SW) | 이미지 정규화 + int8 양자화 (3 × 640 × 640, shift 6 = 값 × 2⁻⁶) |
| **RTL (이 폴더)** | **layer 0–20 의 모든 연산** (아래 표). 입력: int8 픽셀 스트림 / 출력: P3, P4, P5 int8 (shift 5) |
| 호스트 (SW, float) | layer 21 Detect (P3 / P4 / P5 → boxes), NMS |

- BatchNorm 은 HW 에 없습니다: PTQ 단계에서 앞 Conv 의 weight / bias 로 접혀 들어갔습니다.
- GELU 는 HW 모델에서 모두 SiLU 로 바뀌었고 (LayerNorm 은 LightNorm 으로), 그 상태로 fine-tuning 했습니다.
- 모든 scale 은 2 의 거듭제곱 (값 = int × 2⁻ˢʰⁱᶠᵗ), 반올림은 half-up, 그 다음 포화입니다.

## RTL 이 하는 연산 (정수 step 321 개)

step 하나하나 (이름, 연산, 입력, shift, 출력 크기) 는 `docs/step_graph.csv` 에 있습니다. RTL 주석의 step 이름과
`rtl/Lxx/*.sv` 의 인스턴스 표는 이 파일의 `step` 열과 같은 이름입니다.

| 연산 (step 수) | RTL |
|---|---|
| Conv2d 1×1 / 3×3 (79) | `ops/Conv1x1.sv`, `ops/Conv3x3.sv` (← `core/emy_im2col.sv` line buffer + `core/emy_conv_core.sv`) |
| Depthwise Conv 3×3 (30) | `ops/DWConv3x3.sv` → `ss2d/DWConv2d_3x3.sv` |
| SiLU (59) | `ops/SiLU.sv`, `core/emy_silu_pwl.sv` (8 구간 PWL, 256-entry 표) |
| LightNorm (30) | `ops/LightNorm.sv` → `ss2d/LightNormInt.sv` |
| Add (40) / Mul (20) | `ops/Add.sv`, `ops/Mul.sv` |
| Requant (shift 맞춤) | `ops/Requant.sv`, `common/emy_requant.sv` |
| SS2D: CrossScan · XProj · DtProj (+ReLU) · exp(Δ·A) · Δ·B · SelectiveScan · +D·u · CrossMerge (각 10) | `ss2d/SS2D.sv` → `SS2D_Core4.sv`, `CrossScan.sv`, `CrossMerge.sv`, `SelectiveScan.sv`, `Exp_PWL_Pipe.sv`, `SSM_y_compute_Pipe.sv` |
| MaxPool 5×5 (3, SPPF) | `ops/MaxPool5x5.sv` |
| SpaceToDepth (3, VisionClueMerge) | `ops/SpaceToDepth.sv` |
| Upsample ×2 (2) / Concat (5) | `ops/Upsample.sv`, `ops/Concat.sv` |

layer 별로 보면:

| layer | 모듈 | 내용 |
|---|---|---|
| L00 | `L00_SimpleStem` | Conv3×3 s2 + SiLU, Conv3×3 s2 + SiLU |
| L01, L03, L05 ×3, L07 | `Lxx_VSSBlock*` | VSSBlock (step 01–29, 아래) |
| L02, L04, L06 | `Lxx_VisionClueMerge` | SpaceToDepth + Conv1×1 + SiLU |
| L08 | `L08_SPPF` | Conv1×1 + SiLU, MaxPool5×5 ×3, Concat, Conv1×1 + SiLU |
| L09, L12 | `Lxx_Upsample` | nearest ×2 |
| L10, L13, L16, L19 | `Lxx_Concat` | skip 은 한 프레임 FIFO 에서 기다림 |
| L11, L14, L17, L20 | `Lxx_XSSBlock` | XSSBlock (VSSBlock 과 같은 구조, step 01–02 이름만 `in_proj`) |
| L15, L18 | `Lxx_Conv` | Conv3×3 s2 + SiLU |

VSSBlock / XSSBlock 한 개 (예: L07, `layers/SSBlock.sv` 하나를 10 개 블록이 파라미터만 바꿔 씀):

```
01-02 proj_conv   Conv1x1 + SiLU
03-07 LSBlock     DWConv3x3, Conv1x1, SiLU, Conv1x1, Add(residual)
08    norm        LightNorm
09-20 SS2D        in_proj Conv1x1 -> [z: SiLU] / [x: DWConv3x3 -> SiLU -> CrossScan -> XProj -> DtProj(+ReLU)
                  -> SelectiveScan (exp(dA) PWL, dB, state, +D*u) -> CrossMerge -> out_norm LightNorm] -> Mul(x, z) -> out_proj Conv1x1
21    Add         residual
22    norm2       LightNorm
23-28 RGBlock     Conv1x1 (2 x hidden) -> [DWConv3x3 + Add -> SiLU] * gate (Mul) -> Conv1x1
29    Add         residual
```

## 폴더

| 경로 | 내용 |
|---|---|
| `rtl/top/` | `eMambaYOLO` : 23 개 layer 인스턴스 연결 (두 소비자로 가는 layer 는 `emy_stream_fork`) |
| `rtl/L00`–`rtl/L20/` | layer 별 얇은 wrapper (그 layer 의 채널 수 · 맵 크기 · shift · weight 창 위치만 지정) |
| `rtl/layers/` | generic layer 모듈: `SSBlock` (VSS / XSS 10 개), `VisionClueMerge`, `ConvSiLU`, `ConcatSkip`, `UpsampleLayer` |
| `rtl/ops/` | 연산 하나씩 (Conv, DWConv, SiLU, LightNorm, Add, Mul, MaxPool, SpaceToDepth, Upsample, Concat, Requant) |
| `rtl/ss2d/` | SS2D (step 09–20) 와 그 하위 모듈, `Linear_Transform_PerCh` (모든 1×1 Conv 의 datapath) |
| `rtl/core/` | `emy_conv_core`, `emy_im2col`, `emy_silu_pwl` |
| `rtl/common/` | 패키지 (`emy_pkg` 숫자 규칙, `emy_wb_map_pkg` weight 창 위치), requant, stream FIFO / fork, frame counter |
| `rtl/emamba/` | eMamba RTL 에서 그대로 가져온 산술 모듈 (delta·A, x(k+1), exp PWL, shifter, saturator) |
| `docs/step_graph.csv` | step 321 개 목록 |
| `A_Blocks_Stem_Merge_SPPF.html` | SS2D 밖 블록 (Stem, VisionClueMerge, SPPF, Upsample, Concat, Conv3×3 s2) 의 내부 구조 설명 |

컴파일 순서: `rtl/common/emy_pkg.sv`, `rtl/common/emy_wb_map_pkg.sv` 먼저, 나머지는 순서 무관.
Vivado xsim 은 한글 등 비 ASCII 경로의 파일을 읽지 못하니 ASCII 경로에 풀어 주세요.

## 인터페이스 (`eMambaYOLO`)

- `clk`, `nRst` (동기, active low), `ps_start` (시작 / 중단 펄스).
- weight / bias: `wb_valid`, `wb_addr[23:0]`, `wb_data[31:0]` 로 **전체 weight 이미지를 한 번** broadcast 합니다 (`ps_start` 전에).
  각 모듈은 `emy_wb_map_pkg` 에 적힌 자기 창의 주소만 받아 둡니다.
- 데이터: `dIn[0:2]` (픽셀 하나 = 3 채널, 래스터 순서) → `p3_dOut[0:63]` (80×80), `p4_dOut[0:127]` (40×40), `p5_dOut[0:255]` (20×20).
  모든 스트림은 valid / ready 핸드셰이크 (`s_valid`/`s_ready`, `m_valid`/`m_ready`) 입니다.
- 프레임: `ps_start` 한 번 뒤로 프레임이 연속으로 흐릅니다. `frame_done` 은 P3 · P4 · P5 가 한 프레임을 다 냈을 때 1 클럭 펄스, `layer_done[i]` 는 layer 별 펄스 (디버그).

## 검증과 범위

- 모든 step 의 출력이 INT8 reference 모델 (v002) 과 **bit-exact** 임을 Vivado xsim 시뮬레이션으로 확인했습니다
  (블록 10 개, 블록 밖 layer 전부, top 을 6 구간으로 나눈 연결, 연속 2 프레임). testbench 와 reference 데이터는 이 폴더에 넣지 않았습니다.
- 이 RTL 은 **기능 모델**입니다: layer 23 개가 각각 자기 인스턴스와 프레임 크기 FIFO 를 가지고, weight 는 칩 안에 모두 받아 둡니다
  (weight 이미지만 약 5.4 MB). 그대로는 FPGA 한 개에 들어가지 않습니다. 보드용 구성 (외부 메모리, 엔진 공유 / 시분할) 은 이 폴더에 없습니다.

## 용어

| 용어 | 뜻 |
|---|---|
| step | INT8 모델의 정수 연산 하나 (`docs/step_graph.csv` 한 줄) |
| golden, v002 | 이 RTL 이 비교 기준으로 쓴 INT8 reference 모델과 그 버전 (이 폴더에 없음) |
| LOG, int8_WB | reference 모델이 step 마다 내놓은 출력값 / weight·bias·shift 파일. 주석의 "step (LOG / int8_WB)" 는 step 이름을 뜻합니다 |
| SW.xxx | reference 모델의 해당 연산 함수 (예: `SW.Conv2d`, `SW.MaxPool2d`) |
| shift | 고정 소수점 지수: 값 = int × 2⁻ˢʰⁱᶠᵗ |
| WB | weight / bias |
| chord8 | SiLU · exp 의 8 구간 piecewise linear 근사 |
| Linear_Transform_Dynamic_WB 핸드셰이크 | eMamba RTL 의 valid / ready 방식 (입력 한 칸 버퍼, 출력 valid = 결과 준비) |
| Anh | SS2D (step 09–20) 와 그 하위 모듈의 원 작성자 |
