//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.
//
//------------------------------------------------------------------------------
// Generic Video Interface for the Analogue Pocket Display
//
// Note: APF scaler requires HSync and VSync to last for a single clock, and
// video_rgb to be 0 when video_de is low
//
// RGB palettes
//
// | RGB Format | Bit Depth | Number of Colors |
// | ---------- | --------- | ---------------- |
// | RGB111     | 3 bits    | 8                |
// | RGB222     | 6 bits    | 64               |
// | RGB233     | 8 bits    | 256              |
// | RGB332     | 8 bits    | 256              |
// | RGB333     | 9 bits    | 512              |
// | RGB444     | 12 bits   | 4,096            |
// | RGB555     | 15 bits   | 32,768           |
// | RGB565     | 16 bits   | 65,536           |
// | RGB666     | 18 bits   | 262,144          |
// | RGB888     | 24 bits   | 16,777,216       |
//
//------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module video_mixer
    #(
         parameter             RW = 8,                   //! Bits Per Pixel Red
         parameter             GW = 8,                   //! Bits Per Pixel Green
         parameter             BW = 8,                   //! Bits Per Pixel Blue
         parameter             ENABLE_INTERLACED = 0,    //! Enable Interlaced Video Support
         parameter             USE_VBL           = 0     //! Capture and Use VBlank value at HSync
     ) (
         // Clocks
         input   wire          clk_74a,                  //! APF: Main Clock
         input   wire          clk_sys,                  //! Core: System Clock
         input   wire          clk_vid,                  //! Core: Pixel Clock
         input   wire          clk_vid_90deg,            //! Core: Pixel Clock 90º Phase Shift
         input   wire          reset,                    //! System Reset
         // Input Controls
         input   wire          grayscale_en,             //! Enable Grayscale video output
         input   wire    [2:0] video_preset,             //! Video preset configurations (up to 8)
         input   wire    [3:0] scnl_sw,                  //! Scanlines Switches
         input   wire    [3:0] smask_sw,                 //! Shadow Mask Switches
         // Interlaced Video Controls
         input   wire          field,                    //! [0] Even        | [1] Odd
         input   wire          interlaced,               //! [0] Progressive | [1] Interlaced
         // Input Video from Core
         input   wire [RW-1:0] core_r,                   //! Core: Video Red
         input   wire [GW-1:0] core_g,                   //! Core: Video Green
         input   wire [BW-1:0] core_b,                   //! Core: Video Blue
         input   wire          core_hs,                  //! Core: Horizontal Sync
         input   wire          core_vs,                  //! Core: Vertical   Sync
         input   wire          core_hb,                  //! Core: Horizontal Blank
         input   wire          core_vb,                  //! Core: Vertical   Blank
         // Output to Display Connection
         output logic   [23:0] video_rgb,                //! Display: RGB Color: Red[23:16] Green[15:8] Blue[7:0]
         output logic          video_hs,                 //! Display: Horizontal Sync
         output logic          video_vs,                 //! Display: Vertical   Sync
         output logic          video_de,                 //! Display: Data Enable
         output  wire          video_skip,               //! Display: Pixel Skip
         output  wire          video_rgb_clock,          //! Display: Pixel Clock
         output  wire          video_rgb_clock_90,       //! Display: Pixel Clock with 90º Phase Shift
         // Output Video from Core
         output  wire    [5:0] vga_r,                    //! VGA: Video Red
         output  wire    [5:0] vga_g,                    //! VGA: Video Green
         output  wire    [5:0] vga_b,                    //! VGA: Video Blue
         output  wire          vga_hs,                   //! VGA: Hsync
         output  wire          vga_vs,                   //! VGA: Vsync
         output  wire          vga_de,                   //! VGA: Data Enable
         output  wire          vga_clk,                  //! VGA: Pixel Clock
         // Pocket Bridge Slots
         input   wire          dataslot_requestwrite,    //!
         input   wire   [15:0] dataslot_requestwrite_id, //!
         input   wire          dataslot_allcomplete,     //!
         // Pocket Bridge
         input   wire          bridge_endian_little,     //!
         input   wire   [31:0] bridge_addr,              //!
         input   wire          bridge_wr,                //!
         input   wire   [31:0] bridge_wr_data            //!
     );

    //! ------------------------------------------------------------------------
    //! Combine Colors to Create a Full RGB888 Color Space
    //! ------------------------------------------------------------------------
    wire [7:0] R = RW == 8 ? core_r : {core_r, {8-RW{1'b0}}};
    wire [7:0] G = GW == 8 ? core_g : {core_g, {8-GW{1'b0}}};
    wire [7:0] B = BW == 8 ? core_b : {core_b, {8-BW{1'b0}}};

    //! ------------------------------------------------------------------------
    //! VGA Output
    //! ------------------------------------------------------------------------
    assign vga_r   = R[7:2];
    assign vga_g   = G[7:2];
    assign vga_b   = B[7:2];
    assign vga_vs  = core_vs;
    assign vga_hs  = core_hs;
    assign vga_de  = ~(core_vb | core_hb);
    assign vga_clk = video_rgb_clock;


    //!-------------------------------------------------------------------------
    //! Convert RGB to Grayscale
    //!-------------------------------------------------------------------------
    wire [7:0] bw_r, bw_g, bw_b;
    wire       bw_hs, bw_vs;
    wire       bw_hb, bw_vb;

    rgb2grayscale u_rgb2grayscale
    (
        .clk    ( clk_vid      ),
        .enable ( grayscale_en ),

        .r_in   ( R            ),
        .g_in   ( G            ),
        .b_in   ( B            ),
        .hs_in  ( core_hs      ),
        .vs_in  ( core_vs      ),
        .hb_in  ( core_hb      ),
        .vb_in  ( core_vb      ),

        .r_out  ( bw_r         ),
        .g_out  ( bw_g         ),
        .b_out  ( bw_b         ),
        .hs_out ( bw_hs        ),
        .vs_out ( bw_vs        ),
        .hb_out ( bw_hb        ),
        .vb_out ( bw_vb        )
    );

    //! ------------------------------------------------------------------------
    //! Sync Video Output
    //! ------------------------------------------------------------------------
    reg [7:0] r_out, g_out, b_out;
    reg       hs_out, vs_out;
    reg       hb_out, vb_out, vbl_out;
    reg       field_out, interlaced_out, preset_out;

    // Latch signals so they're delayed the same amount as the incoming video
    always_ff @(posedge clk_vid) begin : syncVideo
        r_out          <= bw_r;
        g_out          <= bw_g;
        b_out          <= bw_b;
        hs_out         <= bw_hs;
        vs_out         <= bw_vs;
        hb_out         <= bw_hb;
        vb_out         <= bw_vb;
        if (~hs_out && bw_hs) begin
            vbl_out <= bw_vb;
        end
        field_out      <= field;
        interlaced_out <= interlaced;
        preset_out     <= video_preset;
    end

    //! ------------------------------------------------------------------------
    //! APF Video Output
    //! ------------------------------------------------------------------------
    always_ff @(posedge clk_vid) begin : apfVideoOutput
        video_de  <= 1'b0;
        video_rgb <= { 8'h0, preset_out, 13'h0 };
        if (ENABLE_INTERLACED && vs_out) begin
            video_rgb <= { 20'h0, ~field_out, field_out, interlaced_out, 1'b0 };
        end
        else if ((USE_VBL && ~(hb_out | vbl_out)) || (!USE_VBL && ~(hb_out | vb_out))) begin
            video_de  <= 1'b1;
            video_rgb <= { r_out, g_out, b_out };
        end
        // Set HSync and VSync to be high for a single cycle on the rising edge
        // of the HSync and VSync coming out of the core
        video_hs  <= ~hs_out && bw_hs;
        video_vs  <= ~vs_out && bw_vs;
    end

    //! ------------------------------------------------------------------------
    //! Clock Output
    //! ------------------------------------------------------------------------
    assign video_rgb_clock    = clk_vid;
    assign video_rgb_clock_90 = clk_vid_90deg;
    assign video_skip         = 1'b0;

endmodule
