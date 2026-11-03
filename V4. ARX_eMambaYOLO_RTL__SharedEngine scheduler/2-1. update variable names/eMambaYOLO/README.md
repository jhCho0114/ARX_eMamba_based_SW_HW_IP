# eMambaYOLO — 납품용 RVX 플랫폼 트리 (ARX_eMambaYOLO_platform 의 이름 재정리, 2026-11-01)

`ARX_eMambaYOLO_platform` (= u601 + 이름 변경) 은 보드에서 UART 무응답이었다. 두 서버 사본 (u601 10-26 · ARX 11-01) 을 이름만 정규화해 전부 비교하면 **유일한 기능 차이가 RVX 생성 `arch/rtl/include/munoc_node_id.vh` 의 NoC 슬레이브 노드 번호**였다: RVX 는 노드 번호를 인스턴스 이름의 ASCII 순으로 매기는데 `ARX_eMambaYOLO_IP` 는 대문자 A 로 시작해 0 번으로 앞당겨지고 common_peri_group · core_peri_group 이 한 칸씩 밀렸다 (NI 순서 · 메모리맵은 그대로라 노드 번호 ≠ NI 인덱스).

이 트리는 플랫폼 `eMambaYOLO`, IP 인스턴스 `eMambaYOLO_IP` (소문자 e: core 와 external 사이에 정렬) 로 만든 것이다. 재생성된 `munoc_node_id.vh` 를 확인하면 **common 0 · core 1 · eMambaYOLO_IP 2 — u601 과 완전히 동일**하다.

## 2026-11-01 점검 · 보완

| 항목 | 상태 | 비고 |
|---|---|---|
| `eMambaYOLO.xml` | OK | u601.xml 과 이름 · IP 인스턴스 이름만 다름 (`include_spi_flash` 포함) |
| `arch/` (재생성) | OK | 노드 번호 u601 과 동일; IP 매크로 `EMAMBAYOLO_IP_SLAVE_BASEADDR` 0xC001_3000; 생성 모듈 이름 `EMAMBAYOLO` / `EMAMBAYOLO_RTL` 이라 user 모듈 `eMambaYOLO_IP` 와 충돌 없음 |
| `user/rtl/src` (24) | OK | ARX 서버 사본과 md5 전부 동일 (Bao omega 150 MHz RTL) |
| `user/rtl/include/eMambaYOLO_user_region.vh` | **보완** | 재생성된 **템플릿** (IP 미배선) 이었음 → ARX 의 배선판을 `ARX_eMambaYOLO_IP → eMambaYOLO_IP` 치환해 설치 (16,110 B, `gclk_150M`). 신호 집합 165 개가 새 템플릿과 일치 확인. 템플릿은 `*.template_bak` |
| `user/template/ARX_eMambaYOLO_platform_user_region.vh` | 삭제 | 옛 이름의 잔재 |
| `fpga_component/edge-19p/` | **보완** | 없었음 → ARX 트리에서 복사 (DDR4 xci 등 215 파일, 83 MB) |
| `app/dma_u7/src/main.c` | **보완** | `EMY_IP` 가 `EMAMBAYOLO_IP_SLAVE_BASEADDR` 를 먼저 받도록 (`#if defined` 3 단: eMambaYOLO → ARX → u504/u601). 코드는 ARX 앱과 동일 (emy_camera · emy_label · 헤더 · compile_list) |
| `user/env/set_rtl_syn_env.tcl` | OK | SV 패키지 3 개 선행 순서 유지 |
| `user/edge_video_system/`, `user/env`, `user/sim` | OK | ARX 트리와 동일 |

## 서버에서 할 일

1. 트리를 `platform/eMambaYOLO` 로 올린다 (`fpga_component` 83 MB · `app/dma_u7/include/emy_weights.h` 42 MB 포함).
2. `make edge-19p` → `imp_edge-19p_<날짜>/`. 끝나면 **`user/rtl/include/eMambaYOLO_user_region.vh` 가 그대로인지** (16,110 B, `assign eMambaYOLO_IP_clk = gclk_150M`) 와 `arch/rtl/include/munoc_node_id.vh` 의 `EMAMBAYOLO_IP_SLAVE (2)` 를 한 번 더 확인. 타이밍은 ARX 빌드 기준 WNS +0.077 (150 MHz).
3. `make program` → `make dma_u7.all` → UART 에 `[RVX/START]`, `DMA_DIAG`, `TIME frame …`.
4. 플래시 부팅: `make program_flash` (MCS) → `make dma_u7.flash` → 부트 스위치 STAND_ALONE → 전원만으로 카메라 입력 · 모니터 출력.

## 관련

- ARX 트리 점검 기록: `C:\c_work\U_final\ARX_eMambaYOLO_platform\README.md`
- 원인 분석 기록: `U_504/u504_host/docs/TODO.md` 56 차 (11-01)
