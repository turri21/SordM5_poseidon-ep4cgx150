//============================================================================
//  Computer: Sord M5
//
//  Copyright (C) 2018 Sorgelig
//  Copyright (C) 2021 molekula
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//
//============================================================================

// Sord M5

`default_nettype none

module guest_top
(
        input         CLOCK_27,
`ifdef USE_CLOCK_50
        input         CLOCK_50,
`endif

	output        LED,

	output [VGA_BITS-1:0] VGA_R,
	output [VGA_BITS-1:0] VGA_G,
	output [VGA_BITS-1:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,

`ifdef USE_HDMI
	output        HDMI_RST,
	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_PCLK,
	output        HDMI_DE,
	inout         HDMI_SDA,
	inout         HDMI_SCL,
	input         HDMI_INT,
`endif

	input         SPI_SCK,
	inout         SPI_DO,
	input         SPI_DI,
	input         SPI_SS2,    // data_io
	input         SPI_SS3,    // OSD
	input         CONF_DATA0, // SPI_SS for user_io

`ifdef USE_QSPI
	input         QSCK,
	input         QCSn,
	inout   [3:0] QDAT,
`endif
`ifndef NO_DIRECT_UPLOAD
	input         SPI_SS4,
`endif

	output [12:0] SDRAM_A,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nWE,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nCS,
	output  [1:0] SDRAM_BA,
	output        SDRAM_CLK,
	output        SDRAM_CKE,

`ifdef DUAL_SDRAM
	output [12:0] SDRAM2_A,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_DQML,
	output        SDRAM2_DQMH,
	output        SDRAM2_nWE,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nCS,
	output  [1:0] SDRAM2_BA,
	output        SDRAM2_CLK,
	output        SDRAM2_CKE,
`endif

	output        AUDIO_L,
	output        AUDIO_R,
`ifdef I2S_AUDIO
	output        I2S_BCK,
	output        I2S_LRCK,
	output        I2S_DATA,
`endif
`ifdef I2S_AUDIO_HDMI
	output        HDMI_MCLK,
	output        HDMI_BCK,
	output        HDMI_LRCK,
	output        HDMI_SDATA,
`endif
`ifdef SPDIF_AUDIO
	output        SPDIF,
`endif
`ifdef USE_AUDIO_IN
	input         AUDIO_IN,
`endif
`ifdef USE_MIDI_PINS
	output        MIDI_OUT,
	input         MIDI_IN,
`endif
`ifdef SIDI128_EXPANSION
	input         UART_CTS,
	output        UART_RTS,
	inout         EXP7,
	inout         MOTOR_CTRL,
`endif
	input         UART_RX,
	output        UART_TX
);

`ifdef NO_DIRECT_UPLOAD
localparam bit DIRECT_UPLOAD = 0;
wire SPI_SS4 = 1;
`else
localparam bit DIRECT_UPLOAD = 1;
`endif

`ifdef USE_QSPI
localparam bit QSPI = 1;
assign QDAT = 4'hZ;
`else
localparam bit QSPI = 0;
`endif

`ifdef VGA_8BIT
localparam VGA_BITS = 8;
`else
localparam VGA_BITS = 6;
`endif

`ifdef USE_HDMI
localparam bit HDMI = 1;
assign HDMI_RST = 1'b1;
`else
localparam bit HDMI = 0;
`endif

`ifdef BIG_OSD
localparam bit BIG_OSD = 1;
`define SEP "-;",
`else
localparam bit BIG_OSD = 0;
`define SEP
`endif

//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
 
assign LED = ~ioctl_download;


`include "build_id.v" 
parameter CONF_STR = {
  "Sord M5;;",
  "-;",
  "O02,Memory extension,None,EM-5,EM-64,64KBF,64KRX,BrnoMod;",
  "h0O34,Cartridge,None,BASIC-I,BASIC-G,BASIC-F;",
  "h1O5,EM64 mode,64KB,32KB;",
  "h1O6,EM64 mon. deactivate,Dis.,En.;",
  "h1O7,EM64 wp low 32KB,Dis.,En.;",
  "h1O8,EM64 boot on,ROM,RAM;",  
  "h2F1,binROM,Load to ROM;",
//  "F,CAS,Load Tape;",
//  "O9,Fast Tape Load,On,Off;",
  "OA,Tape Sound,On,Off;",
  "-;",
  //"OCD,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
  "OEF,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%;",
  "OG,Border,No,Yes;",
  "-;",
  "OI,Swap Joysticks,No,Yes;",
  "-;",
  "TH,Reset;",
  "V,Poseidon-",`BUILD_DATE 
};

wire [31:0] status;
wire [10:0] ps2_key = {key_strobe, key_pressed, key_extended, key_code};
wire  [1:0] buttons;
wire  [1:0] switches;

wire ps2_kbd_clk,ps2_kbd_data;
wire ps2_mouse_clk,ps2_mouse_data;

wire        key_pressed;
wire [7:0]  key_code;
wire        key_strobe;
wire        key_extended;
wire [15:0] joystick_0;
wire [15:0] joystick_1;
wire [15:0] joystick_analog_0;
wire [15:0] joystick_analog_1;

wire [31:0] joystick_a = status[18] ? joystick_1 : joystick_0;
wire [31:0] joystick_b = status[18] ? joystick_0 : joystick_1;

//wire [31:0] sd_lba;
//wire  [1:0] sd_rd;
//wire  [1:0] sd_wr;
//wire        sd_ack;
//wire  [8:0] sd_buff_addr;
//wire  [7:0] sd_buff_dout;
//wire  [7:0] sd_buff_din;
//wire        sd_buff_wr;
//wire        sd_ack_conf;
//wire        sd_busy;
//wire        sd_sdhc;
//wire        sd_conf;

//wire  [1:0] img_mounted;
//wire  [1:0] img_readonly;
//wire [63:0] img_size;

wire        ioctl_download;
wire  [7:0] ioctl_index;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire        forced_scandoubler;
wire [21:0] gamma_bus;
wire        cart_enable = status[2:1] ==  2'b00 | status[2:0] == 3'b010;
wire        binary_load_enable = cart_enable & status[4:3] == 2'b00;
wire        kb64_enable = status[2:0] == 3'b010;

user_io #(.STRLEN($size(CONF_STR)>>3), .SD_IMAGES(1), .PS2DIV(500), .FEATURES(32'h0 | (BIG_OSD << 13) | (HDMI << 14))) user_io
(	
	.clk_sys        	(clk_sys          ),
	.clk_sd           (clk_sys          ),
	.conf_str       	(CONF_STR       	),
	.SPI_CLK        	(SPI_SCK        	),
	.SPI_SS_IO      	(CONF_DATA0     	),
	.SPI_MISO       	(SPI_DO        	),
	.SPI_MOSI       	(SPI_DI         	),
	.buttons        	(buttons        	),
	.switches       	(switches      	),
	.no_csync         (no_csync         ),
	.ypbpr          	(ypbpr          	),

	.ps2_kbd_clk      (ps2_kbd_clk      ),
	.ps2_kbd_data     (ps2_kbd_data     ),
	.key_strobe     	(key_strobe     	),
	.key_pressed    	(key_pressed    	),
	.key_extended   	(key_extended   	),
	.key_code       	(key_code       	),
	.joystick_0       (joystick_0       ),
	.joystick_1       (joystick_1       ),
	.status         	(status         	),
	.scandoubler_disable(scandoubler_disable),

`ifdef USE_HDMI
	.i2c_start        (i2c_start        ),
	.i2c_read         (i2c_read         ),
	.i2c_addr         (i2c_addr         ),
	.i2c_subaddr      (i2c_subaddr      ),
	.i2c_dout         (i2c_dout         ),
	.i2c_din          (i2c_din          ),
	.i2c_ack          (i2c_ack          ),
	.i2c_end          (i2c_end          ),
`endif
	

data_io data_io(
	.clk_sys          (clk_sys          ),
	.SPI_SCK          (SPI_SCK          ),
	.SPI_SS2          (SPI_SS2          ),
`ifdef NO_DIRECT_UPLOAD
   .SPI_SS4          (SPI_SS4          ),
`endif
	.SPI_DI           (SPI_DI           ),
	.SPI_DO           (SPI_DO           ),
	.clkref_n         (1'b0             ),
	.ioctl_download   (ioctl_download   ),
	.ioctl_index      (ioctl_index      ),
	.ioctl_wr         (ioctl_wr         ),
	.ioctl_addr       (ioctl_addr       ),
	.ioctl_dout       (ioctl_dout       )
);

///////////////////////   CLOCKS   ///////////////////////////////

wire clk_sys, locked;
pll pll
(
   .areset(0),
	.inclk0(CLOCK_50),
	.c0(clk_sys),     // 42.666667 MHz
	.locked(locked)
);

reg ce_10m7 = 0;
reg ce_5m3 = 0;
always @(posedge clk_sys) begin
	reg [2:0] div;
	
	div <= div+1'd1;
	ce_10m7 <= !div[1:0];
	ce_5m3  <= !div[2:0];
end

/////////////////  RESET  /////////////////////////
reg [4:0] old_ram_mode = 5'd0;
always @(posedge clk_sys) begin
	old_ram_mode <= status[4:0];
end

wire ram_mode_changed = old_ram_mode == status[4:0] ? 1'b0 : 1'b1 ;
wire reset = ram_mode_changed | status[17] | (ioctl_index == 8'd1 & ioctl_download);

////////////////  Console  ////////////////////////


wire [7:0] R,G,B;
wire hblank, vblank;
wire hsync, vsync;
wire ypbpr, no_csync;
wire scandoubler_disable;

sordM5 SordM5
(
	.clk_i(clk_sys),
	.clk_en_10m7_i(ce_10m7),
	.reset_n_i(~reset),
	.por_n_o(),
	.border_i(status[16]),
	.rgb_r_o(R),
	.rgb_g_o(G),
	.rgb_b_o(B),
	.hsync_n_o(hsync),
	.vsync_n_o(vsync),
	.hblank_o(hblank),
	.vblank_o(vblank),
	.audio_o(audio), 
	.ps2_key_i(ps2_key),
	.joy0_i(joystick_a),
        .joy1_i(joystick_b),
	.ioctl_addr (ioctl_addr),
	.ioctl_dout (ioctl_dout),
	.ioctl_index (8'd1),
	.ioctl_wr (ioctl_wr),  
	.ioctl_download (ioctl_download),
	// .DDRAM_BUSY ( DDRAM_BUSY),
	// .DDRAM_BURSTCNT ( DDRAM_BURSTCNT),
	// .DDRAM_ADDR ( DDRAM_ADDR),
	// .DDRAM_DOUT ( DDRAM_DOUT),
	// .DDRAM_DOUT_READY ( DDRAM_DOUT_READY),
	// .DDRAM_RD ( DDRAM_RD),
	// .DDRAM_DIN ( DDRAM_DIN),
	// .DDRAM_BE ( DDRAM_BE),
	// .DDRAM_WE ( DDRAM_WE),
	// .DDRAM_CLK ( DDRAM_CLK),

//	.SRAM_A(SRAM_A),
//	.SRAM_Q(SRAM_Q),
//	.SRAM_WE(SRAM_WE),

	.AUDIO_INPUT( AUDIO_IN ),

	.casSpeed (status[9]),
	.tape_sound_i (status[10]),
	.ramMode_i (status[8:0])
);

reg hs_o, vs_o;
always @(posedge clk_sys) begin
	hs_o <= ~hsync;
	if(~hs_o & ~hsync) vs_o <= ~vsync;
end

wire [2:0] scanlines = status[15:14];

mist_video #(.COLOR_DEPTH(8), .SD_HCNT_WIDTH(10), .OUT_COLOR_DEPTH(VGA_BITS), .BIG_OSD(BIG_OSD)) mist_video(
	.clk_sys      (clk_sys    ),
	.SPI_SCK      (SPI_SCK    ),
	.SPI_SS3      (SPI_SS3    ),
	.SPI_DI       (SPI_DI     ),
	.R            (R          ),
	.G            (G          ),
	.B            (B          ),
	.HSync        (hs_o       ),
	.VSync        (vs_o       ),
	.HBlank       (hblank     ),
	.VBlank       (vblank     ),
	.VGA_R        (VGA_R      ),
	.VGA_G        (VGA_G      ),
	.VGA_B        (VGA_B      ),
	.VGA_VS       (VGA_VS     ),
	.VGA_HS       (VGA_HS     ),
	.ce_divider   (3'b0       ),
	.no_csync     (no_csync   ),
	.ypbpr        (ypbpr      ),
	.scandoubler_disable ( scandoubler_disable ),
    .scanlines   (scanlines     ),
	.rotate       ( 2'b00     ),
	.blend        ( 1'b0      )
);

////////////////////   AUDIO   ///////////////////

wire [10:0] audio;

//sigma_delta_dac sigma_delta_dac (
//	.clk      ( CLOCK_50    ),      // bus clock
//	.ldatasum ( DAC_L >> 1  ),      // left channel data		(ok1) sndmix >> 1 bad, (ok2) sndmix >> 2 ok
//	.rdatasum ( DAC_R >> 1  ),      // right channel data		sndmix_pcm >> 1 bad, sndmix_pcm >> 2 bad
//	.left     ( AUDIO_L     ),      // left bitstream output
//	.right    ( AUDIO_R     )       // right bitsteam output
//);


`ifdef I2S_AUDIO
wire [31:0] clk_rate =  32'd42_666_667;

i2s i2s (
	.reset(reset),
	.clk(clk_sys),
	.clk_rate(clk_rate),

	.sclk(I2S_BCK),
	.lrclk(I2S_LRCK),
	.sdata(I2S_DATA),

	.left_chan({audio,5'd0}),
	.right_chan({audio,5'd0})
);

`ifdef I2S_AUDIO_HDMI
assign HDMI_MCLK = 0;
always @(posedge clk_sys) begin
	HDMI_BCK <= I2S_BCK;
	HDMI_LRCK <= I2S_LRCK;
	HDMI_SDATA <= I2S_DATA;
end
`endif
`endif

endmodule
