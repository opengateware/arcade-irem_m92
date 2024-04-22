//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2024, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Irem M92 Compatible Gateware IP Core
//
// Copyright (c) 2024, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2023, Martin Donlon
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 3.
//
// This program is distributed in the hope that it will be useful, but
// WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
// General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
//
//------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

import m92_pkg::*;

module irem_m92
    (
        input  wire        clk_sys,            //! System Clock ( 40 MHz)
        input  wire        clk_ram,            //! SDRAM  Clock (120 MHz)
        input  wire        pll_locked,         //! PLL Locked
        input  wire        reset,              //! Reset
        // Core Config
        input  wire        pause,              //! Pause CPU
        input  wire  [7:0] mod_sw,             //! DIP Switch 1 (Default: 8'h00)
        input  wire  [7:0] dsw_1,              //! DIP Switch 1 (Default: 8'h00)
        input  wire  [7:0] dsw_2,              //! DIP Switch 2 (Default: 8'h00)
        input  wire  [7:0] dsw_3,              //! DIP Switch 3 (Default: 8'h00)
        // Input - Player 1
        input  wire        p1_coin,  p1_start, //! Mode  / Start
        input  wire        p1_up,    p1_left,  //! Up    / Left
        input  wire        p1_down,  p1_right, //! Down  / Right
        input  wire        p1_btn_y, p1_btn_x, //! Btn Y / X
        input  wire        p1_btn_b, p1_btn_a, //! Btn B / A
        input  wire        p1_btn_l, p1_btn_r, //! Btn L / R
        // Input - Player 2
        input  wire        p2_coin,  p2_start, //! Mode  / Start
        input  wire        p2_up,    p2_left,  //! Up    / Left
        input  wire        p2_down,  p2_right, //! Down  / Right
        input  wire        p2_btn_y, p2_btn_x, //! Btn Y / X
        input  wire        p2_btn_b, p2_btn_a, //! Btn B / A
        input  wire        p2_btn_l, p2_btn_r, //! Btn L / R
        // Input - Player 3
        input  wire        p3_coin,  p3_start, //! Mode  / Start
        input  wire        p3_up,    p3_left,  //! Up    / Left
        input  wire        p3_down,  p3_right, //! Down  / Right
        input  wire        p3_btn_y, p3_btn_x, //! Btn Y / X
        input  wire        p3_btn_b, p3_btn_a, //! Btn B / A
        input  wire        p3_btn_l, p3_btn_r, //! Btn L / R
        // Input - Player 4
        input  wire        p4_coin,  p4_start, //! Mode  / Start
        input  wire        p4_up,    p4_left,  //! Up    / Left
        input  wire        p4_down,  p4_right, //! Down  / Right
        input  wire        p4_btn_y, p4_btn_x, //! Btn Y / X
        input  wire        p4_btn_b, p4_btn_a, //! Btn B / A
        input  wire        p4_btn_l, p4_btn_r, //! Btn L / R
        // Audio
        output wire [15:0] audio_l,            //! Left Channel Output
        output wire [15:0] audio_r,            //! Right Channel Output
        // Video Signals
        output wire  [7:0] video_r,            //! Red
        output wire  [7:0] video_g,            //! Green
        output wire  [7:0] video_b,            //! Blue
        output wire        video_hs,           //! Horizontal Sync
        output wire        video_vs,           //! Vertical Sync
        output wire        video_hb,           //! Horizontal Blank
        output wire        video_vb,           //! Vertical Blank
        output wire        video_ce,           //! Pixel Clock Enable (6.666 MHz)
        output reg   [2:0] video_preset,       //! Video Preset [0] 320x240  | [1] 320x240 @ 270Deg
        // I/O Controller
        input  wire [16:0] ioctl_index,        //! Data Index
        input  wire        ioctl_download,     //! Download
        input  wire        ioctl_wr,           //! Write Enable
        input  wire [26:0] ioctl_addr,         //! Data Address
        input  wire [15:0] ioctl_data,         //! Data Input
        // SDRAM Interface
        output wire        sdram_clk,          //! Clock
        output wire        sdram_cke,          //! Clock Enable
        inout  wire [15:0] sdram_dq,           //! 16-bit Bidirectional Data Bus
        output wire [12:0] sdram_a,            //! 13-bit Multiplexed Address Bus
        output wire        sdram_dqml,         //! Two Byte Masks
        output wire        sdram_dqmh,         //! Two Byte Masks
        output wire  [1:0] sdram_ba,           //! Two Banks
        output wire        sdram_we_n,         //! Write Enable
        output wire        sdram_ras_n,        //! Row Address Select
        output wire        sdram_cas_n         //! Columns Address Select
    );

    //--------------------------------------------------------------------------
    // Settings
    //--------------------------------------------------------------------------
    parameter [15:0] ROM_IDX   = 16'd1,
                     HSDAT_IDX = 16'd2,
                     NVRAM_IDX = 16'd3;

    wire       flipped;
    wire [2:0] dbg_en_layers     = 3'b111;
    wire       dbg_fm_en         = 1'b1;
    wire       dbg_sprite_freeze = 1'b0;
    wire       filters           = ~mod_sw[1];

    assign video_preset          = {2'b00, mod_sw[0]};
    //--------------------------------------------------------------------------
    // Inputs
    //--------------------------------------------------------------------------
    wire  [9:0] p1_input      = { p1_btn_r, p1_btn_l, p1_btn_y, p1_btn_x, p1_btn_b, p1_btn_a, p1_up, p1_down, p1_left, p1_right };
    wire  [9:0] p2_input      = { p2_btn_r, p2_btn_l, p2_btn_y, p2_btn_x, p2_btn_b, p2_btn_a, p2_up, p2_down, p2_left, p2_right };
    wire  [9:0] p3_input      = { p3_btn_r, p3_btn_l, p3_btn_y, p3_btn_x, p3_btn_b, p3_btn_a, p3_up, p3_down, p3_left, p3_right };
    wire  [9:0] p4_input      = { p4_btn_r, p4_btn_l, p4_btn_y, p4_btn_x, p4_btn_b, p4_btn_a, p4_up, p4_down, p4_left, p4_right };

    wire  [3:0] coin_buttons  = { p4_coin,  p3_coin,  p2_coin,  p1_coin  };
    wire  [3:0] start_buttons = { p4_start, p3_start, p2_start, p1_start };
    wire [23:0] dip_sw        = { dsw_3, dsw_2, dsw_1 };

    //--------------------------------------------------------------------------
    // Core RTL
    //--------------------------------------------------------------------------
    m92 #(.NVRAM_IDX(NVRAM_IDX)) m92
    (
        .clk_sys              ( clk_sys              ), // [i]
        .reset_n              ( ~reset               ), // [i]

        .ce_pix               ( video_ce             ), // [o]
        .flipped              ( flipped              ), // [o]

        .board_cfg            ( board_cfg            ), // [i]

        .R                    ( video_r              ), // [o]
        .G                    ( video_g              ), // [o]
        .B                    ( video_b              ), // [o]
        .HSync                ( video_hs             ), // [o]
        .VSync                ( video_vs             ), // [o]
        .HBlank               ( video_hb             ), // [o]
        .VBlank               ( video_vb             ), // [o]

        .AUDIO_L              ( audio_l              ), // [o]
        .AUDIO_R              ( audio_r              ), // [o]

        .coin                 ( coin_buttons         ), // [i]
        .start_buttons        ( start_buttons        ), // [i]

        .p1_input             ( p1_input             ), // [i]
        .p2_input             ( p2_input             ), // [i]
        .p3_input             ( p3_input             ), // [i]
        .p4_input             ( p4_input             ), // [i]

        .dip_sw               ( dip_sw               ), // [i]

        .pause_rq             ( pause                ), // [i]

        .sdr_vram_addr        ( sdr_vram_addr        ), // [o]
        .sdr_vram_data        ( sdr_vram_data        ), // [i]
        .sdr_vram_req         ( sdr_vram_req         ), // [o]

        .sdr_sprite_addr      ( sdr_sprite_addr      ), // [o]
        .sdr_sprite_dout      ( sdr_sprite_dout      ), // [i]
        .sdr_sprite_req       ( sdr_sprite_req       ), // [o]
        .sdr_sprite_ack       ( sdr_sprite_ack       ), // [i]

        .sdr_bg_addr_a        ( sdr_bg_addr_a        ), // [o]
        .sdr_bg_data_a        ( sdr_bg_data_a        ), // [i]
        .sdr_bg_req_a         ( sdr_bg_req_a         ), // [o]
        .sdr_bg_ack_a         ( sdr_bg_ack_a         ), // [i]

        .sdr_bg_addr_b        ( sdr_bg_addr_b        ), // [o]
        .sdr_bg_data_b        ( sdr_bg_data_b        ), // [i]
        .sdr_bg_req_b         ( sdr_bg_req_b         ), // [o]
        .sdr_bg_ack_b         ( sdr_bg_ack_b         ), // [i]

        .sdr_bg_addr_c        ( sdr_bg_addr_c        ), // [o]
        .sdr_bg_data_c        ( sdr_bg_data_c        ), // [i]
        .sdr_bg_req_c         ( sdr_bg_req_c         ), // [o]
        .sdr_bg_ack_c         ( sdr_bg_ack_c         ), // [i]

        .sdr_cpu_addr         ( sdr_cpu_addr         ), // [o]
        .sdr_cpu_dout         ( sdr_cpu_dout         ), // [i]
        .sdr_cpu_din          ( sdr_cpu_din          ), // [o]
        .sdr_cpu_req          ( sdr_cpu_req          ), // [o]
        .sdr_cpu_ack          ( sdr_cpu_ack          ), // [i]
        .sdr_cpu_wr_sel       ( sdr_cpu_wr_sel       ), // [o]

        .sdr_audio_cpu_addr   ( sdr_audio_cpu_addr   ), // [o]
        .sdr_audio_cpu_dout   ( sdr_audio_cpu_dout   ), // [i]
        .sdr_audio_cpu_din    ( sdr_audio_cpu_din    ), // [o]
        .sdr_audio_cpu_req    ( sdr_audio_cpu_req    ), // [o]
        .sdr_audio_cpu_ack    ( sdr_audio_cpu_ack    ), // [i]
        .sdr_audio_cpu_wr_sel ( sdr_audio_cpu_wr_sel ), // [o]

        .sdr_audio_addr       ( sample_rom_addr      ), // [o]
        .sdr_audio_dout       ( sample_rom_dout      ), // [i]
        .sdr_audio_req        ( sample_rom_req       ), // [o]
        .sdr_audio_ack        ( sample_rom_ack       ), // [i]

        .clk_bram             ( clk_sys              ), // [i]
        .bram_wr              ( bram_wr              ), // [i]
        .bram_data            ( bram_data            ), // [i]
        .bram_addr            ( bram_addr            ), // [i]
        .bram_cs              ( bram_cs              ), // [i]

        .ioctl_download       ( ioctl_download       ), // [i]
        .ioctl_index          ( ioctl_index          ), // [i]
        .ioctl_wr             ( ioctl_wr             ), // [i]
        .ioctl_addr           ( ioctl_addr           ), // [i]
        .ioctl_dout           ( ioctl_data           ), // [i]

        .ioctl_upload         (                      ), // [i]
        .ioctl_upload_index   (                      ), // [o]
        .ioctl_din            (                      ), // [o]
        .ioctl_rd             (                      ), // [i]
        .ioctl_upload_req     (                      ), // [o]

        .dbg_en_layers        ( dbg_en_layers        ), // [i]
        .dbg_solid_sprites    (                      ), // [i]
        .en_audio_filters     ( filters              ), // [i]
        .dbg_fm_en            ( dbg_fm_en            ), // [i]

        .sprite_freeze        ( dbg_sprite_freeze    )  // [i]
    );

    //--------------------------------------------------------------------------
    // ROM download controller
    //--------------------------------------------------------------------------
    board_cfg_t board_cfg;
    wire        rom_downl = ioctl_download && (ioctl_index == ROM_IDX);

    rom_loader rom_loader
    (
        .sys_clk     ( clk_sys         ), // [i]

        .ioctl_downl ( rom_downl       ), // [i]
        .ioctl_wr    ( ioctl_wr        ), // [i]
        .ioctl_data  ( ioctl_data      ), // [i]

        .ioctl_wait  (                 ), // [o]

        .sdr_addr    ( sdr_rom_addr    ), // [o]
        .sdr_data    ( sdr_rom_data    ), // [o]
        .sdr_be      ( sdr_rom_be      ), // [o]
        .sdr_req     ( sdr_rom_req     ), // [o]
        .sdr_ack     ( sdr_rom_ack     ), // [i]

        .bram_addr   ( bram_addr       ), // [o]
        .bram_data   ( bram_data       ), // [o]
        .bram_cs     ( bram_cs         ), // [o]
        .bram_wr     ( bram_wr         ), // [o]

        .board_cfg   ( board_cfg       )  // [o]
    );

    //--------------------------------------------------------------------------
    // SDRAM
    //--------------------------------------------------------------------------
    wire        sdr_rom_write = ioctl_download && (ioctl_index == ROM_IDX);

    wire        sdr_vram_req;
    wire [24:0] sdr_vram_addr;
    wire [31:0] sdr_vram_data;

    wire [63:0] sdr_sprite_dout;
    wire [24:0] sdr_sprite_addr;
    wire        sdr_sprite_req, sdr_sprite_ack;

    wire [31:0] sdr_bg_data_a;
    wire [24:0] sdr_bg_addr_a;
    wire        sdr_bg_req_a, sdr_bg_ack_a;

    wire [31:0] sdr_bg_data_b;
    wire [24:0] sdr_bg_addr_b;
    wire        sdr_bg_req_b, sdr_bg_ack_b;

    wire [31:0] sdr_bg_data_c;
    wire [24:0] sdr_bg_addr_c;
    wire        sdr_bg_req_c, sdr_bg_ack_c;

    wire [15:0] sdr_cpu_dout, sdr_cpu_din;
    wire [24:0] sdr_cpu_addr;
    wire        sdr_cpu_req, sdr_cpu_ack;
    wire  [1:0] sdr_cpu_wr_sel;

    wire [15:0] sdr_audio_cpu_dout, sdr_audio_cpu_din;
    wire [24:0] sdr_audio_cpu_addr;
    wire        sdr_audio_cpu_req, sdr_audio_cpu_ack;
    wire  [1:0] sdr_audio_cpu_wr_sel;

    wire [24:0] sdr_rom_addr;
    wire [15:0] sdr_rom_data;
    wire  [1:0] sdr_rom_be;
    wire        sdr_rom_req;
    wire        sdr_rom_ack;

    wire [24:0] sample_rom_addr;
    wire [63:0] sample_rom_dout;
    wire        sample_rom_req;
    wire        sample_rom_ack;

    wire [19:0] bram_addr;
    wire  [7:0] bram_data;
    wire  [3:0] bram_cs;
    wire        bram_wr;

    assign sdram_clk = clk_ram;
    assign sdram_cke = 1'b1;

    sdram_4w_cl3 #(120) sdram
    (
        .SDRAM_DQ      ( sdram_dq           ),
        .SDRAM_A       ( sdram_a            ),
        .SDRAM_DQML    ( sdram_dqml         ),
        .SDRAM_DQMH    ( sdram_dqmh         ),
        .SDRAM_BA      ( sdram_ba           ),
        .SDRAM_nCS     (                    ),
        .SDRAM_nWE     ( sdram_we_n         ),
        .SDRAM_nRAS    ( sdram_ras_n        ),
        .SDRAM_nCAS    ( sdram_cas_n        ),
        .init_n        ( pll_locked         ),
        .clk           ( clk_ram            ),

        // Bank 0-1 ops
        .port1_a       ( sdr_rom_addr[24:1] ),
        .port1_req     ( sdr_rom_req        ),
        .port1_ack     ( sdr_rom_ack        ),
        .port1_we      ( sdr_rom_write      ),
        .port1_ds      ( sdr_rom_be         ),
        .port1_d       ( sdr_rom_data       ),
        .port1_q       ( sdr_rom_ack        ),

        // Main CPU
        .cpu1_rom_addr ( ),
        .cpu1_rom_cs   ( ),
        .cpu1_rom_q    ( ),
        .cpu1_rom_valid( ),

        .cpu1_ram_req  ( sdr_cpu_req        ),
        .cpu1_ram_ack  ( sdr_cpu_ack        ),
        .cpu1_ram_addr ( sdr_cpu_addr[24:1] ),
        .cpu1_ram_we   ( |sdr_cpu_wr_sel    ),
        .cpu1_ram_d    ( sdr_cpu_din        ),
        .cpu1_ram_q    ( sdr_cpu_dout       ),
        .cpu1_ram_ds   ( |sdr_cpu_wr_sel ? sdr_cpu_wr_sel : 2'b11 ),

        // Audio CPU
        .cpu2_ram_req  ( sdr_audio_cpu_req        ),
        .cpu2_ram_ack  ( sdr_audio_cpu_ack        ),
        .cpu2_ram_addr ( sdr_audio_cpu_addr[24:1] ),
        .cpu2_ram_we   ( |sdr_audio_cpu_wr_sel    ),
        .cpu2_ram_d    ( sdr_audio_cpu_din        ),
        .cpu2_ram_q    ( sdr_audio_cpu_dout       ),
        .cpu2_ram_ds   ( |sdr_audio_cpu_wr_sel ? sdr_audio_cpu_wr_sel : 2'b11 ),

        // VRAM
        .vram_addr     ( sdr_vram_addr[24:1] ),
        .vram_req      ( sdr_vram_req        ),
        .vram_q        ( sdr_vram_data       ),
        .vram_ack      (  ),

        // Bank 2-3 ops
        .port2_a       ( sdr_rom_addr[24:1] ),
        .port2_req     ( sdr_rom_req        ),
        .port2_ack     ( sdr_rom_ack        ),
        .port2_we      ( sdr_rom_write      ),
        .port2_ds      ( sdr_rom_be         ),
        .port2_d       ( sdr_rom_data       ),
        .port2_q       ( sdr_rom_ack        ),

        .gfx1_req      ( sdr_bg_req_a        ),
        .gfx1_ack      ( sdr_bg_ack_a        ),
        .gfx1_addr     ( sdr_bg_addr_a[24:1] ),
        .gfx1_q        ( sdr_bg_data_a       ),

        .gfx2_req      ( sdr_bg_req_b        ),
        .gfx2_ack      ( sdr_bg_ack_b        ),
        .gfx2_addr     ( sdr_bg_addr_b[24:1] ),
        .gfx2_q        ( sdr_bg_data_b       ),

        .gfx3_req      ( sdr_bg_req_c        ),
        .gfx3_ack      ( sdr_bg_ack_c        ),
        .gfx3_addr     ( sdr_bg_addr_c[24:1] ),
        .gfx3_q        ( sdr_bg_data_c       ),

        .sample_addr   ( {sample_rom_addr[24:3], 2'b00} ),
        .sample_q      ( sample_rom_dout     ),
        .sample_req    ( sample_rom_req      ),
        .sample_ack    ( sample_rom_ack      ),

        .sp_addr       ( sdr_sprite_addr[24:1] ),
        .sp_req        ( sdr_sprite_req        ),
        .sp_ack        ( sdr_sprite_ack        ),
        .sp_q          ( sdr_sprite_dout       )
    );

endmodule
