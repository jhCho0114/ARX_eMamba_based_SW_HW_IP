`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// [J_LOG] Module Name: U_log_pkg
// Description: 레이어별 출력 덤프용 공용 패키지.
//
//   legacy 는 각 모듈이 절대경로를 하드코딩해서 $fopen 했는데, 그러면 경로를
//   바꿀 때마다 30군데를 고쳐야 해. 여기서는 경로 하나만 두고 모든 모듈이 쓴다.
//
//   포맷은 legacy_RTL_log 와 동일:
//     - 한 줄 = 토큰 1개, 값은 콤마 구분 10진수, 줄 끝 개행
//     - delta_A / delta_B 는 토큰당 ED 줄 x N 값  (16토큰 -> 640줄)
//
//   파일은 append("a") 로 열고 바로 닫는다. 핸들을 들고 있지 않으므로
//   시뮬이 중간에 죽어도 거기까지는 디스크에 남아.
//   대신 매 토큰 open/close 라 느려. 필요 없을 때는 LOG_EN=0.
//
//   TB 에서 설정:
//     U_log_pkg::LOG_DIR = "/home/.../U_RTL_log";
//     U_log_pkg::LOG_EN  = 1;
//     U_log_pkg::reset_all();     // 프레임 시작 전에 전체 파일 truncate
//////////////////////////////////////////////////////////////////////////////////

package U_log_pkg;

    string LOG_DIR = "/home/jcho/eMamba_WB/v2xx_workspace/eMamba_CLA_all_FF.srcs/sources_1/new/U_RTL_log";

    bit LOG_EN = 1'b1;

    function automatic string pfx(input int sw);
        case (sw)
            1:       return "1st_";
            2:       return "2nd_";
            default: return "";
        endcase
    endfunction

    function automatic void trunc(input string nm);
        int fd;
        if (!LOG_EN) return;
        fd = $fopen({LOG_DIR, "/", nm}, "w");
        if (fd == 0)
            $display("[J_LOG][WARN] Cannot create: %s/%s  (No DIR?)", LOG_DIR, nm);
        else
            $fclose(fd);
    endfunction

    function automatic int opn(input string nm);
        if (!LOG_EN) return 0;
        return $fopen({LOG_DIR, "/", nm}, "a");
    endfunction

    function automatic void reset_all();
        string blk[2];
        int    b;
        if (!LOG_EN) return;
        blk[0] = "1st_"; blk[1] = "2nd_";
        trunc("Patch_linear.txt");
        for (b = 0; b < 2; b++) begin
            trunc({blk[b], "LightNorm.txt"});
            trunc({blk[b], "Linear_x1.txt"});
            trunc({blk[b], "Linear_z1.txt"});
            trunc({blk[b], "SiLU.txt"});
            trunc({blk[b], "Conv1D.txt"});
            trunc({blk[b], "SSM_dIn.txt"});
            trunc({blk[b], "SSM_D.txt"});
            trunc({blk[b], "SSM_C.txt"});
            trunc({blk[b], "SSM_delta_A.txt"});
            trunc({blk[b], "SSM_delta_B.txt"});
            trunc({blk[b], "SSM_y.txt"});
            trunc({blk[b], "Elementwise_Prod.txt"});
            trunc({blk[b], "Linear_contract.txt"});
        end
        trunc("OH_LightNorm.txt");
        trunc("OH_Linear.txt");

        

        $display("[J_LOG] 로그 디렉터리 초기화: %s", LOG_DIR);
    endfunction

endpackage
