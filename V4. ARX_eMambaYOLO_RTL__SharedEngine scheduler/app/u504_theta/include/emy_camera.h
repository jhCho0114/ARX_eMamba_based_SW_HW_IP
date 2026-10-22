/* u504_eta — 카메라 경로 (docs/CAMERA_ZETA_PLAN.html)
 *
 *   HDMI 카메라 → VIM → DDR 프레임 버퍼 (XBGR_8888: 워드 = R<<24 | G<<16 | B<<8) → CPU 변환 (1/3 최근접 + 양자화) → DDR 스테이징
 *   (640×640 HWC int8, 패딩 140 행 = 29) → BRAM_IN 청크 → IP (NMS 모드) → 검출 → 캡처 버퍼에 박스 → VOM.
 *
 *   버퍼 풀: VIM 은 언제나 두 장에 번갈아 쓰고 (완성 버퍼 = VIM_IDX), 캡처한 버퍼는 결과 박스가 그려져 화면에 보일 때까지 보존한다
 *   (직렬 4 장, 겹침 5 장). VIM 은 변환 (DDR 읽기) 동안만 끈다. ADDR0/1 은 VIM 을 끈 상태에서 다시 쓴다 (초기화 코드와 같은 방법).
 *
 *   플랫폼 호출은 모두 emy_camera.c 안에 있고, EMY_HOST_MOCK 빌드 (PC) 에서는 malloc 버퍼 + 빈 함수로 바뀐다.
 */
#ifndef EMY_CAMERA_H
#define EMY_CAMERA_H
#include <stdint.h>

/* ---- 빌드 스위치 (main.c 의 표 참고; RVX Makefile 에 CFLAGS 훅이 없어 #ifndef 기본값으로 둔다) ---- */
#ifndef EMY_CAM_720P
#define EMY_CAM_720P 1                /* 1: 소스가 1280×720 (1/2 축소), 0: 1920×1080 (1/3 축소). 둘 다 640×360 + 패딩 140 행.
                                         [2026-10-22] 기본 1: 보드의 HDMI 소스가 720p 를 보낸다 (10-21 진단 · 첫 eta 실행에서 1080p 설정으로는 VIM_IDX 불변) */
#endif
#ifndef EMY_CAM_PIPELINE
#define EMY_CAM_PIPELINE 1            /* 1: 다음 프레임의 캡처 · 변환을 IP 계산 (유휴 폴링) 사이에 끼움 — 버퍼 5 장. [2026-10-22] 기본 1: 변환기 v2 가 IP 유휴 1,017 ms 안에 들어감 */
#endif
#ifndef EMY_CAM_SRAM_CODE
#define EMY_CAM_SRAM_CODE 1           /* 1: 변환 핫 루프 (외부 참조 없는 함수) 를 온칩 SRAM 에 복사해 거기서 실행 — 게이트 앱 G4: 명령 비용 1.8 배 단축 (보드 확인) */
#endif
#ifndef EMY_CAM_SRAM_CODE_ADDR
#define EMY_CAM_SRAM_CODE_ADDR 0xE003C000u   /* 온칩 SRAM 256 KB (0xE000_0000) 의 위쪽 16 KB; link.ld heap_sram 과 겹치지 않는다고 가정 (게이트 앱에서 동작 확인) */
#endif
#ifndef EMY_CAM_VDMA
#define EMY_CAM_VDMA 0                /* 1: 스테이징 → BRAM_IN 청크를 VDMA (EDGE_VIDEO_SYSTEM, 0xE204_0000) 로 */
#endif

/* ---- 기하 ---- */
#define EMY_CAM_W          640
#define EMY_CAM_H          640
#define EMY_CAM_IMG_ROWS   360                                  /* 영상 행 (FHD 1080 / 3, 720p 720 / 2) */
#define EMY_CAM_PAD_ROWS   140                                  /* 위 · 아래 패딩 행 (letterbox 114 → q 29) */
#define EMY_CAM_PAD_Q      0x1Du
#define EMY_CAM_PAD_WORD   0x1D1D1D1Du
#define EMY_CAM_ROW_BYTES  (EMY_CAM_W * 3)                      /* 1,920 */
#define EMY_CAM_FRAME_BYTES (EMY_CAM_W * EMY_CAM_H * 3)         /* 1,228,800 */
#define EMY_CAM_CHUNK_BYTES (8 * EMY_CAM_ROW_BYTES)             /* 15,360 = 8 행: 청크가 행 경계에서 끝나 픽셀이 쪼개지지 않음 (IN_LEN 은 4 의 배수 ≤ 16 KB 면 됨) */
#define EMY_CAM_CHUNKS     (EMY_CAM_FRAME_BYTES / EMY_CAM_CHUNK_BYTES)   /* 80 */
#if EMY_CAM_720P
#define EMY_CAM_SRC_W      1280
#define EMY_CAM_SRC_H      720
#define EMY_CAM_SCALE      2
#define EMY_CAM_SRC_OFF    0                                    /* 1/2 에는 가운데 표본이 없다 */
#else
#define EMY_CAM_SRC_W      1920
#define EMY_CAM_SRC_H      1080
#define EMY_CAM_SCALE      3
#define EMY_CAM_SRC_OFF    1                                    /* 3×3 블록의 가운데 표본 */
#endif

/* 실행 시 기하 (setup 이 위 기본값으로 채움; 셀프테스트는 골든 프레임의 레터박스에 맞춰 바꿈 — 골든은 패딩 107 행 · 영상 426 행 (3:2 사진) 이라
 * 1280×852 (배율 2) 합성 프레임이 골든을 바이트 그대로 재현한다). 변환 · 그리기 · 스테이징 패딩이 모두 이 값을 쓴다. */
typedef struct { int scale, pad_rows, img_rows, src_off, src_w, src_h; } emy_cam_geom_t;
extern emy_cam_geom_t emy_cam_geom;

/* 양자화: q = round(p · 64 / 255), p 0 … 255 → 0 … 64.
 *   v1: (p·16448 + 32768) >> 16 — 256 값 전부 round 와 일치 (나눗셈 없음). 보드: 픽셀당 8.1 µs (연산이 7.7 — 명령 비용이 지배).
 *   v2: (p + 2) >> 2 도 256 값 전부 일치 (p·64/255 와 p/4 의 차 ≤ 0.25 가 반올림 경계를 넘지 않음) → XBGR 워드 통째로 (SWAR):
 *       qw = ((w >> 2) & 0x3F3F3F3F) + ((w >> 1) & 0x01010101)  — 바이트마다 q (R · G · B 동시에, 자리올림 없음: ≤ 63 + 1)
 *       그 뒤 바이트 순서만 뒤집어 (XBGR → R,G,B) 픽셀 4 개를 워드 3 개에 담는다. 픽셀당 ≈ 14 명령 (v1 ≈ 60). */
#define EMY_CAM_Q(p)       ((uint32_t)(((uint32_t)(p) + 2u) >> 2))
#define EMY_CAM_QWORD(w)   (((((uint32_t)(w)) >> 2) & 0x3F3F3F3Fu) + ((((uint32_t)(w)) >> 1) & 0x01010101u))
#define EMY_CAM_RGB(qw)    (((qw) >> 24) | (((qw) >> 8) & 0xFF00u) | (((qw) << 8) & 0xFF0000u))   /* [0,qB,qG,qR] → R | G<<8 | B<<16 */

/* 검출 (IP 가 준 1/16 px 좌표를 float 픽셀로; main.c 가 채움) */
typedef struct { float x1, y1, x2, y2; float conf; int cls; } emy_det_t;   /* 입력 영상 (640×640) 픽셀 xyxy */

/* 프레임 버퍼 보기: 행 r 의 첫 워드 = base + r · stride */
typedef struct { uintptr_t base; uint32_t stride; int w, h; } emy_cam_img_t;   /* base: 보드 32 bit 주소, PC 모의 빌드에서는 호스트 포인터 */

/* ---- 셋업 · 캡처 ---- */
void emy_cam_setup(int with_camera);          /* 0: 화면만 (셀프테스트), 1: 카메라 + 화면. 버퍼 풀 할당, VIM {0,1}, VOM = 검정 버퍼 */
int  emy_cam_capture(int wait_fresh);         /* 완성 버퍼를 풀에서 꺼내 (VIM 정지 → ADDR 재기록) 번호를 돌려준다. wait_fresh: 재가동 뒤 IDX 가 한 번 바뀌기를 기다림. -1 = 시간 초과 */
void emy_cam_resume(void);                    /* VIM 재가동 */
void emy_cam_show(int buf);                   /* VOM 을 buf 로; 전에 보이던 버퍼는 풀로 돌아간다 */
void emy_cam_release(int buf);                /* 보존 중인 버퍼를 풀로 */
const emy_cam_img_t *emy_cam_img(int buf);
int  emy_cam_key(void);                       /* non-blocking 키 (-1 = 없음) */
uint32_t emy_cam_idx_switches(void);          /* 진단: 지금까지 본 VIM_IDX 변화 수 */

/* ---- 변환 ---- */
void emy_cam_staging_init(uint8_t *stg);      /* 패딩 행 (emy_cam_geom 기준, 기본 위 · 아래 140) 을 0x1D 로 (한 번; 기하가 정해진 뒤) */
int  emy_cam_convert_rows(const emy_cam_img_t *src, uint8_t *stg, int row0, int nrows);   /* 스테이징 행 [row0, row0+nrows) 중 영상 행만 변환; 반환 = 다음 행 번호 */
void emy_cam_conv_core(const uint32_t *src, uint32_t stride_words, uint32_t *dst, int rows, int sc);   /* 핫 루프 (외부 참조 없음 — SRAM 복사 가능). src = 첫 표본 워드, dst = 스테이징 행 */
void emy_cam_convert_all(const emy_cam_img_t *src, uint8_t *stg);

/* ---- 결과 ---- */
void emy_cam_draw_dets(int buf, const emy_det_t *d, int n);   /* 640 좌표 → 소스 좌표 (×SCALE, y − 140), 둘레 3 px, 색 = cls % 8 */
uint32_t emy_cam_cls_color(int cls);                          /* 상자 색 (XBGR 워드) — 라벨 띠도 같은 색 */
#ifdef EMY_HOST_MOCK
void emy_cam_mock_dump_ppm(int buf, const char *path);        /* PC: 표시 버퍼 (소스 크기) 를 P6 PPM 으로 — 박스 · 라벨을 눈으로 확인 */
#endif
void emy_cam_fill_from_golden(int buf, const int8_t frame[EMY_CAM_H][EMY_CAM_W][3]);   /* 셀프테스트: 골든 int8 프레임의 레터박스를 재서 emy_cam_geom 을 맞추고 (패딩 107 → 배율 2, 1280×852),
                                                                                           영상 행을 XBGR 로 펼친다 (p = (q·255 + 32) / 64, 2×2 복제). 변환 결과 == 골든 프레임 */

/* ---- VDMA (EMY_CAM_VDMA) ---- */
#if EMY_CAM_VDMA
void emy_vdma_copy(uint32_t dst, uint32_t src, uint32_t nbytes);   /* once 복사, 끝날 때까지 대기 */
#endif

#endif
