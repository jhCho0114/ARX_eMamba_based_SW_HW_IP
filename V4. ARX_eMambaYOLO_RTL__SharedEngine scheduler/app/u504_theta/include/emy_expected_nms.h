/* 기대 검출 행 — NMS 모드 (FILTER = EN | DET_EN | NMS_EN): 어댑터의 emy_nms 가 헤드 0 슬롯으로 내보내는 행 (형식 0x03) 의 워드 0-3 을
 * 내보내는 순서 (conf 내림차순, 동률은 앵커 번호) 그대로. 골든 후보 49 개 (qthr 1 / 1 / 1) 에 C 와 같은 정수 NMS (10·inter > 7·uni, uint32).
 * (tools/gen_cand_golden.py --nms 가 만든 파일)
 */
#ifndef EMY_EXPECTED_NMS_H_
#define EMY_EXPECTED_NMS_H_
#include <stdint.h>

#define EMY_EXPECTED_NMS_N 6
static const uint16_t emy_expected_nms_cand_n[3] = { 4, 45, 0 };   /* END 행 바이트 8-9 (헤드별 후보 수) */

typedef struct { uint32_t w[4]; } emy_expected_nms_t;

static const emy_expected_nms_t emy_expected_nms[EMY_EXPECTED_NMS_N] = {
    { { 0x3E010324u, 0xEC950305u, 0x11110060u, 0x174B09ACu } },  /* 0: P4 pixel 804 cls 62 conf 60565 box 96 4369 2476 5963 */
    { { 0x38010384u, 0xE17C0304u, 0x1454126Fu, 0x1AA01601u } },  /* 1: P4 pixel 900 cls 56 conf 57724 box 4719 5204 5633 6816 */
    { { 0x38000E94u, 0xD14D0306u, 0x146A1972u, 0x19D81B7Eu } },  /* 2: P3 pixel 3732 cls 56 conf 53581 box 6514 5226 7038 6616 */
    { { 0x38010387u, 0xD14D0303u, 0x145C1690u, 0x1A6719FCu } },  /* 3: P4 pixel 903 cls 56 conf 53581 box 5776 5212 6652 6759 */
    { { 0x000102EBu, 0xBB270302u, 0x108319D9u, 0x19581D0Bu } },  /* 4: P4 pixel 747 cls 0 conf 47911 box 6617 4227 7435 6488 */
    { { 0x480102EFu, 0x9F590301u, 0x11571E2Au, 0x18C32020u } },  /* 5: P4 pixel 751 cls 72 conf 40793 box 7722 4439 8224 6339 */
};

#endif /* EMY_EXPECTED_NMS_H_ */
