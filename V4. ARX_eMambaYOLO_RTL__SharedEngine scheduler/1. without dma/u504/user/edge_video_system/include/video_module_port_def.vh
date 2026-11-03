// THESE DOCUMENTS CONTAIN CONFIDENTIAL INFORMATION AND KNOWLEDGE 
// WHICH IS THE PROPERTY OF ETRI. NO PART OF THIS PUBLICATION IS 
// TO BE USED FOR ANY OTHER PURPOSE, AND THESE ARE NOT TO BE 
// REPRODUCED, COPIED, DISCLOSED, TRANSMITTED, STORED IN A RETRIEVAL 
// SYSTEM OR TRANSLATED INTO ANY OTHER HUMAN OR COMPUTER LANGUAGE, 
// IN ANY FORM, BY ANY MEANS, IN WHOLE OR IN PART, WITHOUT THE 
// COMPLETE PRIOR WRITTEN PERMISSION OF ETRI.
// ****************************************************************************
// 2018-06
// Kyuseung Han (han@etri.re.kr)
// ****************************************************************************
// ****************************************************************************

`ifdef INCLUDE_HDMI
inout wire       HDMI_I2C_SCL;
inout wire       HDMI_I2C_SDA;
`endif

`ifdef INCLUDE_VIM
// HDMI Rx
input wire       HDMI_RX_DCK;
input wire       HDMI_RX_HS;
input wire       HDMI_RX_DE;
input wire       HDMI_RX_VS;
output wire      HDMI_RX_RST_N;
input wire   [35:0]          HDMI_RX_VD;

input wire       HDMI_RX_AMCLK;
input wire       HDMI_RX_ASCLK;
input wire   [5:0]           HDMI_RX_AP;
// [5] : LRCK, [4:1] : ASD[3:0], [0] : SPDIF

// CIS
inout wire   CIS_I2C_SCL;
inout wire   CIS_I2C_SDA;

output wire       CIS_MCLK; // Master Clock (10 ~ 48MHz)
input wire        CIS_PCLK; // Pixel Clock
output wire       CIS_RESET_N;
input wire        CIS_VS; // Frame Valid
input wire        CIS_HS; // Line Valid
output wire       CIS_PD_N;
input wire [7:0]  CIS_D;
`endif

`ifdef INCLUDE_VOM
// HDMI Tx
output wire      HDMI_TX_DCK;
output wire      HDMI_TX_DE;
output wire      HDMI_TX_HS;
output wire      HDMI_TX_VS;
output wire      HDMI_TX_RST_N;
output wire  [35:0]          HDMI_TX_VD;

// HDMI Audio (Don't Use Now)
output wire      HDMI_TX_AO_MCLK;
output wire      HDMI_TX_AO_SCK;
output wire      HDMI_TX_AO_WS;
output wire  [3:0]           HDMI_TX_AO_SD;
output wire      HDMI_TX_AO_SPDIF;
`endif

`ifdef INCLUDE_TFT_LCD
// LCD
output wire        LCD_DCLK; // 40 ~ 70MHz
output wire        LCD_HS;
output wire        LCD_VS;
output wire        LCD_DE;
output wire        LCD_RST_N;
output wire        LCD_PWM;
output wire [7:0]  LCD_BD;
output wire [7:0]  LCD_GD;
output wire [7:0]  LCD_RD;
`endif

`ifdef INCLUDE_SPI_LCD 
output wire        SPI_LCD_PD_N;
`endif
