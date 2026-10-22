/* 기대 후보 — 출력 어댑터 필터 (FILTER_EN) 가 내보내야 할 픽셀: 골든 헤드 행에 같은 규칙 (cls 최대 logit ≥ qthr 1 / 1 / 1) 을 적용한 것.
 * 순서 = 헤드 P3 → P4 → P5, 헤드 안은 픽셀 행 우선. 보드 앱은 헤드별로 (표 시작 + 그 헤드에서 받은 순번) 으로 찾는다 — 슬롯은 헤드 순서로
 * 오지 않는다 (덜 찬 슬롯은 프레임 끝 END 때 넘어오므로 P3 의 마지막 후보들이 P4 · P5 뒤에 도착).
 * (tools/gen_cand_golden.py 가 만든 파일, --det)
 */
#ifndef EMY_EXPECTED_CAND_H_
#define EMY_EXPECTED_CAND_H_
#include <stdint.h>

#define EMY_EXPECTED_CAND_N 49
static const uint16_t emy_expected_cand_n[3] = { 4, 45, 0 };
static const int8_t   emy_expected_qthr[3] = { 1, 1, 1 };

/* DET 모드 (FILTER[1] = DET_EN): IP 가 보내는 DET 행의 워드 0-3 그대로 — w0 = pixel | head << 16 | cls << 24, w1 = qmax | 0x02 << 8 | conf16 << 16,
 * w2 = x1 | y1 << 16, w3 = x2 | y2 << 16 (int16, 1/16 px). 보드는 워드 4 개를 비교한다. */
typedef struct { uint32_t w[4]; } emy_expected_cand_t;

static const emy_expected_cand_t emy_expected_cand[EMY_EXPECTED_CAND_N] = {
    { { 0x38000E94u, 0xD14D0206u, 0x146A1972u, 0x19D81B7Eu } },  /* 0: P3 pixel 3732 cls 56 qmax 6 conf 53581 box 6514 5226 7038 6616 */
    { { 0x38000E95u, 0x9F590202u, 0x14771972u, 0x19CF1B89u } },  /* 1: P3 pixel 3733 cls 56 qmax 2 conf 40793 box 6514 5239 7049 6607 */
    { { 0x38000EE4u, 0xBB270204u, 0x144C1967u, 0x19F91B82u } },  /* 2: P3 pixel 3812 cls 56 qmax 4 conf 47911 box 6503 5196 7042 6649 */
    { { 0x38000EE5u, 0x9F590202u, 0x1464196Au, 0x19DB1B89u } },  /* 3: P3 pixel 3813 cls 56 qmax 2 conf 40793 box 6506 5220 7049 6619 */
    { { 0x000102C3u, 0x9F590201u, 0x107D19DEu, 0x19551D06u } },  /* 4: P4 pixel 707 cls 0 qmax 1 conf 40793 box 6622 4221 7430 6485 */
    { { 0x3E0102D4u, 0xE17C0204u, 0x11180062u, 0x174609ABu } },  /* 5: P4 pixel 724 cls 62 qmax 4 conf 57724 box 98 4376 2475 5958 */
    { { 0x3E0102D5u, 0xE17C0204u, 0x11180074u, 0x174A09B1u } },  /* 6: P4 pixel 725 cls 62 qmax 4 conf 57724 box 116 4376 2481 5962 */
    { { 0x000102EAu, 0x9F590201u, 0x108019D3u, 0x19681D04u } },  /* 7: P4 pixel 746 cls 0 qmax 1 conf 40793 box 6611 4224 7428 6504 */
    { { 0x000102EBu, 0xBB270202u, 0x108319D9u, 0x19581D0Bu } },  /* 8: P4 pixel 747 cls 0 qmax 2 conf 47911 box 6617 4227 7435 6488 */
    { { 0x000102ECu, 0xBB270202u, 0x108219E2u, 0x19591D12u } },  /* 9: P4 pixel 748 cls 0 qmax 2 conf 47911 box 6626 4226 7442 6489 */
    { { 0x480102EFu, 0x9F590201u, 0x11571E2Au, 0x18C32020u } },  /* 10: P4 pixel 751 cls 72 qmax 1 conf 40793 box 7722 4439 8224 6339 */
    { { 0x3E0102FCu, 0xE17C0204u, 0x11100061u, 0x175109B0u } },  /* 11: P4 pixel 764 cls 62 qmax 4 conf 57724 box 97 4368 2480 5969 */
    { { 0x3E0102FDu, 0xE17C0204u, 0x11080073u, 0x175509AEu } },  /* 12: P4 pixel 765 cls 62 qmax 4 conf 57724 box 115 4360 2478 5973 */
    { { 0x3E0102FEu, 0xE17C0204u, 0x1110007Cu, 0x175709AEu } },  /* 13: P4 pixel 766 cls 62 qmax 4 conf 57724 box 124 4368 2478 5975 */
    { { 0x00010312u, 0x9F590201u, 0x107E19DFu, 0x19701D03u } },  /* 14: P4 pixel 786 cls 0 qmax 1 conf 40793 box 6623 4222 7427 6512 */
    { { 0x00010313u, 0x9F590201u, 0x108019DBu, 0x195F1D0Bu } },  /* 15: P4 pixel 787 cls 0 qmax 1 conf 40793 box 6619 4224 7435 6495 */
    { { 0x00010314u, 0x9F590201u, 0x107F19E5u, 0x19681D09u } },  /* 16: P4 pixel 788 cls 0 qmax 1 conf 40793 box 6629 4223 7433 6504 */
    { { 0x3E010324u, 0xEC950205u, 0x11110060u, 0x174B09ACu } },  /* 17: P4 pixel 804 cls 62 qmax 5 conf 60565 box 96 4369 2476 5963 */
    { { 0x3E010325u, 0xEC950205u, 0x11180071u, 0x174D09B2u } },  /* 18: P4 pixel 805 cls 62 qmax 5 conf 60565 box 113 4376 2482 5965 */
    { { 0x3E010326u, 0xE17C0204u, 0x11180077u, 0x174F09AEu } },  /* 19: P4 pixel 806 cls 62 qmax 4 conf 57724 box 119 4376 2478 5967 */
    { { 0x0001033Bu, 0xBB270202u, 0x107C19E0u, 0x195E1D12u } },  /* 20: P4 pixel 827 cls 0 qmax 2 conf 47911 box 6624 4220 7442 6494 */
    { { 0x0001033Cu, 0xBB270202u, 0x108119E6u, 0x19681CF8u } },  /* 21: P4 pixel 828 cls 0 qmax 2 conf 47911 box 6630 4225 7416 6504 */
    { { 0x3E01034Cu, 0xD14D0203u, 0x11090064u, 0x175009ABu } },  /* 22: P4 pixel 844 cls 62 qmax 3 conf 53581 box 100 4361 2475 5968 */
    { { 0x3E01034Du, 0xE17C0204u, 0x1109006Cu, 0x175509A8u } },  /* 23: P4 pixel 845 cls 62 qmax 4 conf 57724 box 108 4361 2472 5973 */
    { { 0x38010362u, 0x9F590201u, 0x14661962u, 0x19CF1B9Cu } },  /* 24: P4 pixel 866 cls 56 qmax 1 conf 40793 box 6498 5222 7068 6607 */
    { { 0x00010364u, 0x9F590201u, 0x108519EFu, 0x195E1CF2u } },  /* 25: P4 pixel 868 cls 0 qmax 1 conf 40793 box 6639 4229 7410 6494 */
    { { 0x38010383u, 0xD14D0203u, 0x144A126Fu, 0x1AA11607u } },  /* 26: P4 pixel 899 cls 56 qmax 3 conf 53581 box 4719 5194 5639 6817 */
    { { 0x38010384u, 0xE17C0204u, 0x1454126Fu, 0x1AA01601u } },  /* 27: P4 pixel 900 cls 56 qmax 4 conf 57724 box 4719 5204 5633 6816 */
    { { 0x38010387u, 0xD14D0203u, 0x145C1690u, 0x1A6719FCu } },  /* 28: P4 pixel 903 cls 56 qmax 3 conf 53581 box 5776 5212 6652 6759 */
    { { 0x38010388u, 0xD14D0203u, 0x14531690u, 0x1A6F1A02u } },  /* 29: P4 pixel 904 cls 56 qmax 3 conf 53581 box 5776 5203 6658 6767 */
    { { 0x3801038Au, 0xBB270202u, 0x146F1967u, 0x19F61BACu } },  /* 30: P4 pixel 906 cls 56 qmax 2 conf 47911 box 6503 5231 7084 6646 */
    { { 0x380103ABu, 0xE17C0204u, 0x1454126Au, 0x1AA41610u } },  /* 31: P4 pixel 939 cls 56 qmax 4 conf 57724 box 4714 5204 5648 6820 */
    { { 0x380103ACu, 0xD14D0203u, 0x14591268u, 0x1A9C1610u } },  /* 32: P4 pixel 940 cls 56 qmax 3 conf 53581 box 4712 5209 5648 6812 */
    { { 0x380103ADu, 0xD14D0203u, 0x145A1271u, 0x1A991619u } },  /* 33: P4 pixel 941 cls 56 qmax 3 conf 53581 box 4721 5210 5657 6809 */
    { { 0x380103AFu, 0xD14D0203u, 0x1459168Eu, 0x1A6C19FAu } },  /* 34: P4 pixel 943 cls 56 qmax 3 conf 53581 box 5774 5209 6650 6764 */
    { { 0x380103B0u, 0xD14D0203u, 0x14581693u, 0x1A731A01u } },  /* 35: P4 pixel 944 cls 56 qmax 3 conf 53581 box 5779 5208 6657 6771 */
    { { 0x380103B2u, 0xD14D0203u, 0x1473196Bu, 0x19F61BACu } },  /* 36: P4 pixel 946 cls 56 qmax 3 conf 53581 box 6507 5235 7084 6646 */
    { { 0x380103D3u, 0xE17C0204u, 0x14541270u, 0x1A9E1608u } },  /* 37: P4 pixel 979 cls 56 qmax 4 conf 57724 box 4720 5204 5640 6814 */
    { { 0x380103D4u, 0xD14D0203u, 0x1454126Fu, 0x1A9B1610u } },  /* 38: P4 pixel 980 cls 56 qmax 3 conf 53581 box 4719 5204 5648 6811 */
    { { 0x380103D5u, 0xBB270202u, 0x14511273u, 0x1A991611u } },  /* 39: P4 pixel 981 cls 56 qmax 2 conf 47911 box 4723 5201 5649 6809 */
    { { 0x380103D7u, 0xBB270202u, 0x14621691u, 0x1A6B1A03u } },  /* 40: P4 pixel 983 cls 56 qmax 2 conf 47911 box 5777 5218 6659 6763 */
    { { 0x380103D8u, 0xD14D0203u, 0x14591692u, 0x1A701A00u } },  /* 41: P4 pixel 984 cls 56 qmax 3 conf 53581 box 5778 5209 6656 6768 */
    { { 0x380103DAu, 0xBB270202u, 0x1475196Au, 0x1A071BADu } },  /* 42: P4 pixel 986 cls 56 qmax 2 conf 47911 box 6506 5237 7085 6663 */
    { { 0x380103DBu, 0x9F590201u, 0x14701970u, 0x19F71BD9u } },  /* 43: P4 pixel 987 cls 56 qmax 1 conf 40793 box 6512 5232 7129 6647 */
    { { 0x380103FBu, 0xBB270202u, 0x1454126Au, 0x1A991618u } },  /* 44: P4 pixel 1019 cls 56 qmax 2 conf 47911 box 4714 5204 5656 6809 */
    { { 0x380103FCu, 0xD14D0203u, 0x14591271u, 0x1A9A1618u } },  /* 45: P4 pixel 1020 cls 56 qmax 3 conf 53581 box 4721 5209 5656 6810 */
    { { 0x380103FFu, 0x9F590201u, 0x1465168Bu, 0x1A7E1A03u } },  /* 46: P4 pixel 1023 cls 56 qmax 1 conf 40793 box 5771 5221 6659 6782 */
    { { 0x38010400u, 0xBB270202u, 0x14621696u, 0x1A7119F9u } },  /* 47: P4 pixel 1024 cls 56 qmax 2 conf 47911 box 5782 5218 6649 6769 */
    { { 0x38010402u, 0x9F590201u, 0x14721964u, 0x1A111BB5u } },  /* 48: P4 pixel 1026 cls 56 qmax 1 conf 40793 box 6500 5234 7093 6673 */
};

#endif /* EMY_EXPECTED_CAND_H_ */
