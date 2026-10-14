# ARX_eMamba_based_SW_HW_IP

eMamba (Mamba SSM 기반 경량 모델) 의 SW / HW IP 를 담은 저장소입니다. 두 프로젝트 (eMamba IP 플랫폼, eMamba-YOLO) 가 들어 있습니다.

| 폴더 | 내용 | 상태 |
|---|---|---|
| [`ARX_eMamba_WB/`](ARX_eMamba_WB) | RISC-V eXpress (RVX) 작업공간. eMamba IP 를 AXI 슬레이브로 붙인 SoC 플랫폼 `eMamba_BRAM_WB` (Edge-19p 보드) 와 참조용 플랫폼들 | 보드용 플랫폼 |
| [`ARX_eMambaYOLO_RTL__under-developing/`](ARX_eMambaYOLO_RTL__under-developing) | eMamba SSM 코어를 쓰는 Mamba-YOLO-T INT8 검출 모델의 RTL (layer 0–20) | 개발 중: functional simulation 까지 |
| [`ARX_eMambaYOLO_RTL__training/`](ARX_eMambaYOLO_RTL__training) | 위 RTL 의 기준 모델을 만든 학습 코드와 모델 (Mamba-YOLO 레포에 추가·수정한 파일) | 학습 완료 |

## 1. `ARX_eMamba_WB/` — eMamba IP 의 RVX 플랫폼

RVX 작업공간 그대로의 구조입니다 (`ARX_eMamba_WB/README.md` 는 RVX 원본 안내문입니다).

| 경로 | 내용 |
|---|---|
| `platform/eMamba_BRAM_WB/` | **eMamba IP 플랫폼.** RISC-V 코어 + eMamba IP (AXI4 슬레이브, 제어 레지스터) + AXI BRAM 3 개 (입력 프레임, weight / bias, 출력). 설명: [`platform/eMamba_BRAM_WB/README.md`](ARX_eMamba_WB/platform/eMamba_BRAM_WB/README.md) |
| `platform/test_video/` | 비디오 출력 시스템 (`EDGE_VIDEO_SYSTEM`, 합성된 netlist) 테스트 플랫폼. 컬러바 / 이미지 출력 앱 |
| `platform/tip_hello/` | RISC-V 코어만 있는 최소 플랫폼 (hello world) |
| `platform_sbki/test_dca_matrix_downsampler/` | DCA matrix downsampler 가속기 테스트 플랫폼 (참조용, 받은 구성 그대로). 가속기 RTL (`user/rtl`), 드라이버 API (`user/api`), 검증 앱 |
| `imp_class_info` | 보드 목록 (`rvx_install/mini_git/imp_class_info` 를 가리킴). eMamba 플랫폼은 `edge-19p` |
| `rvx_init/`, `rvx_install/` | RVX 설치 / 초기화 스크립트 (submodule: `rvx-etri/rvx_init`, `rvx-etri/rvx_install`) |
| `sync/` | RVX devkit, HW 라이브러리, SW 라이브러리, 합성 도구 (RVX 서버에서 동기화된 것) |
| `Makefile`, `rvx_config.mh`, `rvx_init.mh` | 작업공간 설정 |

사용법 (RVX 설치 후, 플랫폼 폴더에서): `make syn` → `make sim_rtl` / `make edge-19p` (FPGA 구현) →
`make test TEST_APP_NAME=<app>`. 설치 방법은 `rvx_install/README.md` 와 https://riscvexpress.github.io 를 참고하세요.

## 2. `ARX_eMambaYOLO_RTL__under-developing/` — eMamba-YOLO RTL

Mamba-YOLO-T (COCO, 640×640) INT8 모델의 layer 0–20 을 SystemVerilog 로 구현한 RTL 입니다.
SS2D 의 selective scan 은 eMamba SSM 코어 방식 (ReLU delta, PWL exp, 4 방향 단방향 scan) 을 따릅니다.
layer 21 (Detect) 와 후처리, 입력 정규화 / int8 양자화는 SW 에서 수행합니다.

| 경로 | 내용 |
|---|---|
| `README.md` | HW / SW 경계, 연산별 RTL 파일 대응, 블록 구조, 인터페이스, 용어 |
| `rtl/` | RTL 72 개 파일 (top: `rtl/top/eMambaYOLO.sv`) |
| `docs/step_graph.csv` | RTL 이 수행하는 정수 연산 321 개 (step) 목록 |
| `A_Blocks_Stem_Merge_SPPF.html` | SS2D 밖 블록 (Stem, VisionClueMerge, SPPF, Upsample, Concat, Conv3×3 s2) 구조 설명 |

모든 step 출력이 INT8 reference 모델과 bit-exact 임을 Vivado xsim 으로 확인했습니다. 아직 위 RVX 플랫폼에는
붙이지 않았습니다 (합성, 보드용 메모리 구성, 플랫폼 연결은 진행 전).

## 3. `ARX_eMambaYOLO_RTL__training/` — eMamba-YOLO 학습

Mamba-YOLO-T 를 eMamba RTL 에 맞게 다시 학습한 코드와 모델입니다. 설명: [`README.md`](ARX_eMambaYOLO_RTL__training/README.md)

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

## 두 프로젝트의 관계

| | eMamba (`ARX_eMamba_WB`) | eMamba-YOLO (`ARX_eMambaYOLO_RTL__under-developing`) |
|---|---|---|
| 모델 | 이미지 분류 (입력 5 × 8 × 8, 토큰 16 개, 57 class) | 물체 검출 (입력 3 × 640 × 640, 출력 P3 / P4 / P5) |
| RTL 범위 | patch embedding, Mamba 블록 2 개, output head (토큰 평균 / argmax 는 SW) | layer 0–20 (Detect 제외) |
| weight 적재 | weight / bias broadcast (BRAM → `wb_broadcast_loader`, 약 19 KB) | 같은 broadcast 방식 (약 5.4 MB) |
| 공통 산술 | `Dim_expand_delta_A_compute`, `SSM_xkP1_compute`, `saturator`, `shifter_left / right` 등 | eMamba 의 산술 모듈을 그대로 사용 (`rtl/emamba/`) |
| 상태 | 보드 플랫폼 | 시뮬레이션 단계 |
