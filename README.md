# ARX_eMamba_based_SW_HW_IP

eMamba (Mamba SSM 기반 경량 모델) 의 SW / HW IP 를 버전별로 모은 저장소입니다. V1–V2 는 eMamba 이미지 분류 IP,
V3–V4 는 eMamba SSM 코어를 쓰는 물체 검출 모델 eMamba-YOLO 의 RTL 입니다.

| 폴더 | 내용 | 상태 |
|---|---|---|
| [`V1. ARX_eMamba (Weight-Bias Embedding)/`](<V1. ARX_eMamba (Weight-Bias Embedding)>) | eMamba IP 첫 버전. weight / bias 를 RTL 안에 상수로 내장 (Genesys2-eb 보드) | frozen |
| [`V2. ARX_eMamba_WB (Weight-Bias BRAM)/`](<V2. ARX_eMamba_WB (Weight-Bias BRAM)>) | eMamba IP. weight / bias 를 BRAM 에 두고 broadcast 로 적재 (Edge-19p 보드) | frozen, 보드용 플랫폼 |
| [`V3. ARX_eMambaYOLO_RTL__LayerWise pipeline/`](<V3. ARX_eMambaYOLO_RTL__LayerWise pipeline>) | eMamba-YOLO RTL (layer 0–20). layer 마다 전용 하드웨어를 두는 파이프라인 구조 | functional simulation 까지 (LUT 초과) |
| [`V3-1.ARX_eMambaYOLO_RTL__training/`](<V3-1.ARX_eMambaYOLO_RTL__training>) | V3 / V4 RTL 의 기준 모델을 만든 학습 · 양자화 코드와 모델 | 학습 완료 |
| [`V4. ARX_eMambaYOLO_RTL__SharedEngine scheduler/`](<V4. ARX_eMambaYOLO_RTL__SharedEngine scheduler>) | eMamba-YOLO RTL. 연산 엔진 몇 개를 scheduler 가 layer 순서대로 돌려쓰는 구조 | 준비 중 |

## V1. `ARX_eMamba (Weight-Bias Embedding)` — weight / bias 내장 eMamba

RVX 작업공간 그대로의 구조입니다. 설명 자료는 폴더 안의 pptx 파일 (`6월2주차.pptx`, `ETRI_발표용_pres.pptx`,
`7월1.5주차 UOU tip_emamba_v0 과정.pptx`, `ETRI_발표용 2회차.pptx`) 에 있습니다.

| 경로 | 내용 |
|---|---|
| `platform/tip_v04/` | eMamba 연산을 C 로 포팅한 버전 (RISC-V 코어에서 실행) |
| `platform/tip_emamba_v1/` | eMamba 연산을 RTL 로 수행하는 버전. weight / bias 는 RTL 에 내장, C 는 입력 전달과 결과 수신만 함. RTL: `user/rtl/src/` (top `eMamba_IP.v`, `eMamba.sv`), 앱: `app/ev01/` |
| `platform/tip_hello/` | RISC-V 코어만 있는 최소 플랫폼 (hello world) |
| `platform/README.md` | `tip_v04` 와 `tip_emamba_v1` 의 차이 |
| `rvx_init/`, `rvx_install/`, `sync/`, `imp_class_info/` | RVX 설치 / 초기화 스크립트, devkit · 라이브러리, 보드 목록 |

## V2. `ARX_eMamba_WB (Weight-Bias BRAM)` — eMamba IP 의 RVX 플랫폼

V1 의 내장 weight / bias 를 AXI BRAM 으로 옮겨, CPU 가 weight / bias 를 써 넣은 뒤 IP 가 읽어 가는 구조입니다.
RVX 작업공간 그대로의 구조입니다 (폴더의 `README.md` 는 RVX 원본 안내문입니다).

| 경로 | 내용 |
|---|---|
| `platform/eMamba_BRAM_WB/` | **eMamba IP 플랫폼.** RISC-V 코어 + eMamba IP (AXI4 슬레이브, 제어 레지스터) + AXI BRAM 3 개 (입력 프레임, weight / bias, 출력). 설명: [`platform/eMamba_BRAM_WB/README.md`](<V2. ARX_eMamba_WB (Weight-Bias BRAM)/platform/eMamba_BRAM_WB/README.md>) |
| `eMamba_system_diagram.drawio` | 플랫폼 구성도 (draw.io) |
| `platform/test_video/` | 비디오 출력 시스템 (`EDGE_VIDEO_SYSTEM`, 합성된 netlist) 테스트 플랫폼. 컬러바 / 이미지 출력 앱 |
| `platform/tip_hello/` | RISC-V 코어만 있는 최소 플랫폼 (hello world) |
| `platform_sbki/test_dca_matrix_downsampler/` | DCA matrix downsampler 가속기 테스트 플랫폼 (참조용, 받은 구성 그대로). 가속기 RTL 은 `rvx_special_ip/dca/` |
| `imp_class_info` | 보드 목록 (`rvx_install/mini_git/imp_class_info` 를 가리킴). eMamba 플랫폼은 `edge-19p` |
| `rvx_init/`, `rvx_install/` | RVX 설치 / 초기화 스크립트 (submodule: `rvx-etri/rvx_init`, `rvx-etri/rvx_install`) |
| `sync/` | RVX devkit, HW 라이브러리, SW 라이브러리, 합성 도구 (RVX 서버에서 동기화된 것) |
| `Makefile`, `rvx_config.mh`, `rvx_init.mh` | 작업공간 설정 |

사용법 (RVX 설치 후, 플랫폼 폴더에서): `make syn` → `make sim_rtl` / `make edge-19p` (FPGA 구현) →
`make test TEST_APP_NAME=<app>`. 설치 방법은 `rvx_install/README.md` 와 https://riscvexpress.github.io 를 참고하세요.

## V3. `ARX_eMambaYOLO_RTL__LayerWise pipeline` — eMamba-YOLO RTL (layer 별 하드웨어)

Mamba-YOLO-T (COCO, 640×640) INT8 모델의 layer 0–20 을 SystemVerilog 로 구현한 RTL 입니다.
SS2D 의 selective scan 은 eMamba SSM 코어 방식 (ReLU delta, PWL exp, 4 방향 단방향 scan) 을 따릅니다.
layer 21 (Detect) 와 후처리, 입력 정규화 / int8 양자화는 SW 에서 수행합니다.

| 경로 | 내용 |
|---|---|
| `README.md` | HW / SW 경계, 연산별 RTL 파일 대응, 블록 구조, 인터페이스, 용어 |
| `rtl/` | RTL 72 개 파일 (top: `rtl/top/eMambaYOLO.sv`, layer 별 `rtl/L00`–`rtl/L20`) |
| `docs/step_graph.csv` | RTL 이 수행하는 정수 연산 321 개 (step) 목록 |
| `A_Blocks_Stem_Merge_SPPF.html` | SS2D 밖 블록 (Stem, VisionClueMerge, SPPF, Upsample, Concat, Conv3×3 s2) 구조 설명 |

모든 step 출력이 INT8 reference 모델과 bit-exact 임을 Vivado xsim 으로 확인했습니다. 다만 layer 마다 하드웨어를
따로 두는 구조라 FPGA 의 LUT 를 넘어서, 보드에는 올리지 않고 V4 구조로 넘어갔습니다.

## V3-1. `ARX_eMambaYOLO_RTL__training` — eMamba-YOLO 학습

Mamba-YOLO-T 를 eMamba RTL 에 맞게 다시 학습한 코드와 모델입니다. 설명: [`README.md`](<V3-1.ARX_eMambaYOLO_RTL__training/README.md>)

| 단계 | 내용 | COCO mAP50-95 |
|---|---|---|
| 1 | SSM delta 활성화 softplus → ReLU, 처음부터 300 epoch | 0.4503 |
| 2 | LayerNorm → LightNorm, GELU → SiLU 변환 (`prepare_hw_finetune.py`) | — |
| 3 | 30 epoch fine-tune → `mambayolo_t_relu_lightnorm.pt` | 0.4438 |

| 경로 | 내용 |
|---|---|
| `MambaYOLO_eMamba_reference/model/` | 수정한 모델 코드 (SS2D backend, LightNorm / SiLU, eMamba 방식 SS2D), 3 단계 yaml 과 모델 |
| `MambaYOLO_eMamba_reference/train/` | 학습 스크립트, 2 단계 변환 |
| `MambaYOLO_eMamba_reference/quantization/` | layer 0–20 INT8 PTQ 와 eMamba SSM 코어 golden 모델 |

## V4. `ARX_eMambaYOLO_RTL__SharedEngine scheduler` — eMamba-YOLO RTL (공유 엔진)

V3 와 같은 INT8 모델을, layer 별 전용 하드웨어 대신 연산 엔진 몇 개를 두고 scheduler 가 layer 순서대로
엔진을 돌려쓰는 구조로 다시 구현한 버전입니다 (V3 의 LUT 초과 해결). 아직 이 폴더에 올리지 않았습니다.

## 버전 비교

| | V1 | V2 | V3 | V4 |
|---|---|---|---|---|
| 모델 | eMamba 이미지 분류 | eMamba 이미지 분류 (입력 5 × 8 × 8, 토큰 16 개, 57 class) | eMamba-YOLO 물체 검출 (입력 3 × 640 × 640, 출력 P3 / P4 / P5) | V3 와 같음 |
| 하드웨어 구조 | 블록별 전용 모듈 (`Patchembedding` → `MAMBA` × 2 → `Outputhead`) | 같은 구조 (`U_PatchEmbedding` → `U_MAMBA` × 2 → `U_Outputhead`) | layer 별 전용 하드웨어 파이프라인 | 공유 연산 엔진 + scheduler |
| weight / bias | RTL 에 상수로 내장 | BRAM → `wb_broadcast_loader` 로 broadcast (약 19 KB) | 같은 broadcast 방식 (약 5.4 MB) | — |
| 보드 | Genesys2-eb | Edge-19p | (LUT 초과로 미구현) | Edge-19p 목표 |
| 공통 산술 | `Dim_expand_delta_A_compute`, `SSM_xkP1_compute`, `saturator`, `shifter_left / right` 등 | V1 과 같음 | eMamba 의 산술 모듈을 그대로 사용 (`rtl/emamba/`) | — |
