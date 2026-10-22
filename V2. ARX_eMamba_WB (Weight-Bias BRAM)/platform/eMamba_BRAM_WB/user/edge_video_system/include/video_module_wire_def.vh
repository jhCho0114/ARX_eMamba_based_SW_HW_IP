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
wire       HDMI_I2C_SCL;
wire       HDMI_I2C_SDA;
`endif

`ifdef INCLUDE_VIM
// HDMI Rx
wire       HDMI_RX_DCK;
wire       HDMI_RX_HS;
wire       HDMI_RX_DE;
wire       HDMI_RX_VS;
wire      HDMI_RX_RST_N;
wire   [35:0]          HDMI_RX_VD;

wire       HDMI_RX_AMCLK;
wire       HDMI_RX_ASCLK;
wire   [5:0]           HDMI_RX_AP;
// [5] : LRCK, [4:1] : ASD[3:0], [0] : SPDIF

// CIS
wire   CIS_I2C_SCL;
wire   CIS_I2C_SDA;

wire       CIS_MCLK; // Master Clock (10 ~ 48MHz)
wire        CIS_PCLK; // Pixel Clock
wire       CIS_RESET_N;
wire        CIS_VS; // Frame Valid
wire        CIS_HS; // Line Valid
wire       CIS_PD_N;
wire [7:0]  CIS_D;
`endif

`ifdef INCLUDE_VOM
// HDMI Tx
wire      HDMI_TX_DCK;
wire      HDMI_TX_DE;
wire      HDMI_TX_HS;
wire      HDMI_TX_VS;
wire      HDMI_TX_RST_N;
wire  [35:0]          HDMI_TX_VD;

// HDMI Audio (Don't Use Now)
wire      HDMI_TX_AO_MCLK;
wire      HDMI_TX_AO_SCK;
wire      HDMI_TX_AO_WS;
wire  [3:0]           HDMI_TX_AO_SD;
wire      HDMI_TX_AO_SPDIF;
`endif

`ifdef INCLUDE_TFT_LCD
// LCD
wire        LCD_DCLK; // 40 ~ 70MHz
wire        LCD_HS;
wire        LCD_VS;
wire        LCD_DE;
wire        LCD_RST_N;
wire        LCD_PWM;
wire [7:0]  LCD_BD;
wire [7:0]  LCD_GD;
wire [7:0]  LCD_RD;
`endif

`ifdef INCLUDE_SPI_LCD
wire        SPI_LCD_PD_N;
`endif
