# eMamba_BRAM_WB — eMamba IP 플랫폼 (Edge-19p)

RISC-V 코어에 eMamba IP 를 AXI 슬레이브로 붙인 RVX 플랫폼입니다. 입력 프레임, weight / bias, 출력은 각각
AXI BRAM 에 두고, eMamba IP 가 BRAM 의 다른 포트로 직접 읽고 씁니다.

- 보드: Edge-19p (`xcku19p-ffvj1760-3-e`), `clk_core` 100 MHz
- 코어: `rvc_orca`, SRAM 256 kB, fast DRAM 포함
- 플랫폼 정의: `eMamba_BRAM_WB.xml`

## 구성과 메모리 맵

| 인스턴스 | 역할 | 주소 | 크기 |
|---|---|---|---|
| `input_bram` | 입력 프레임 (5 × 8 × 8 int8 = 320 B) | `0xC000_0000` | 32 KB |
| `wb_bram` | weight / bias 이미지 (19,440 B) | `0xC000_8000` | 32 KB |
| `output_bram` | 출력: 토큰 하나 = 64 B 행 (57 class + 토큰 번호) | `0xC001_0000` | 8 KB |
| `eMamba_IP` | 제어 / 상태 레지스터 (word 0) | `0xC001_3000` | 2 KB |

제어 레지스터 (word 0): bit 31 = start, bit 30 = WB load, bit 15 = frame done, bit 14 = WB done.

```
CPU ──AXI──▶ input_bram ──port B──▶ ┐
CPU ──AXI──▶ wb_bram ────port B──▶ wb_broadcast_loader ──▶ eMamba (U_eMamba) ──port B──▶ output_bram ──AXI──▶ CPU
CPU ──AXI──▶ eMamba_IP (ctrl / status) ─────────────────────┘
```

## 폴더

| 경로 | 내용 |
|---|---|
| `user/rtl/src/` | eMamba RTL. `eMamba_IP.v` (AXI 래퍼, BRAM 포트), `S_AXI.sv` (제어 레지스터), `wb_broadcast_loader.sv` (wb_bram → 각 모듈로 weight broadcast), `U_eMamba.sv` (top: `U_PatchEmbedding` → `U_MAMBA` × 2 → `U_Outputhead`), `my_axi_bram*.sv` (AXI BRAM), 연산 모듈들 |
| `user/rtl/include/eMamba_BRAM_WB_user_region.vh` | 플랫폼에 IP 와 BRAM 3 개를 연결하는 부분 |
| `user/edge_video_system/` | 비디오 출력 시스템 netlist (현재 xml 에서 꺼져 있음) |
| `user/env/` | RVX 가 user RTL 을 합성 / 시뮬레이션에 넣는 스크립트 |
| `app/bwb001/` | eMamba 한 프레임 테스트 앱 (아래) |
| `app/hello/` | hello world |
| `arch/` | RVX 가 xml 에서 생성한 플랫폼 (메모리 맵 `arch/ssw/src/memorymap_info.h` 등) |

## 테스트 앱 `app/bwb001`

`src/main.c` 의 순서:

1. `wb_raw.h` 의 weight / bias 배열로 19,440 B 이미지를 만들어 `wb_bram` 에 씀
2. ctrl 에 WB load → WB done 대기
3. 입력 프레임 하나 (320 B) 를 `input_bram` 에 씀
4. ctrl 에 start → frame done 대기
5. `output_bram` 에서 16 토큰 × 57 class 를 읽어 golden 과 비교 (허용 오차 1) → `PASS` / `MISMATCH`

`src/initial_input_new.h` (여러 프레임 입력 데이터, 약 14 MB) 는 현재 `main.c` 에서 쓰지 않습니다.

## 실행 (RVX)

이 폴더에서:

```
make syn                              # 플랫폼 생성
make sim_rtl                          # RTL 시뮬레이션
make edge-19p                         # FPGA 구현 (Edge-19p)
make test TEST_APP_NAME=bwb001        # 앱 실행
```

Vivado AXI BRAM IP 를 쓰는 block diagram 버전은 이 저장소에 없습니다 (필요하면 따로 공유).
