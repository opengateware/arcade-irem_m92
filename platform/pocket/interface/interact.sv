//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Analogue Pocket Interact Controller for APF bridge
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
// altera message_off 10762

`default_nettype none
`timescale 1ns/1ps

module interact
    (
        // Clocks and Reset
        input   wire        clk_74a,        //! APF Main Clock
        input   wire        clk_sync,       //! Clock to Sync to
        input   wire        reset_n,        //! APF Reset (Active Low)
        // Reset Core
        output logic        reset_sw,       //! Reset Switch
        // Service Mode Switch
        output logic        svc_sw,         //! Service Switch
        // DIP Switches
        output logic  [7:0] dip_sw0,        //! DIP Switch 1
        output logic  [7:0] dip_sw1,        //! DIP Switch 2
        output logic  [7:0] dip_sw2,        //! DIP Switch 3
        output logic  [7:0] dip_sw3,        //! DIP Switch 4
        // Extra DIP Switches
        output logic  [7:0] ext_sw0,        //! Extra DIP Switch 1
        output logic  [7:0] ext_sw1,        //! Extra DIP Switch 2
        output logic  [7:0] ext_sw2,        //! Extra DIP Switch 3
        output logic  [7:0] ext_sw3,        //! Extra DIP Switch 4
        // Modifiers Switches
        output logic  [7:0] mod_sw0,        //! Modifiers Switch 1
        output logic  [7:0] mod_sw1,        //! Modifiers Switch 2
        output logic  [7:0] mod_sw2,        //! Modifiers Switch 3
        output logic  [7:0] mod_sw3,        //! Modifiers Switch 4
        // Inputs Switches
        output logic  [7:0] inp_sw0,        //! Inputs Switch 1
        output logic  [7:0] inp_sw1,        //! Inputs Switch 2
        output logic  [7:0] inp_sw2,        //! Inputs Switch 3
        output logic  [7:0] inp_sw3,        //! Inputs Switch 4
        // Status (Legacy Support)
        output logic [63:0] status,         //! MiST/MiSTer Legacy Status Flag
        // Filters
        output logic  [3:0] scnl_sw,        //! Scanlines
        output logic  [3:0] smask_sw,       //! ShadowMask
        output logic  [3:0] afilter_sw,     //! Audio Filters
        output logic  [3:0] vol_att,        //! Volume Attenuation
        // High Score NVRAM
        output logic [15:0] nvram_size,     //! High Score Save Size
        // Analogizer
        output logic [31:0] analogizer_sw,  //! Analogizer/SNAC Switches
        // Pocket Bridge
        input   wire [31:0] bridge_addr,
        input   wire        bridge_wr,
        input   wire [31:0] bridge_wr_data,
        input   wire        bridge_rd,
        output logic [31:0] bridge_rd_data = 32'h0
    );

    //!-------------------------------------------------------------------------
    //! Reset Handler
    //!-------------------------------------------------------------------------
    reg [31:0] reset_counter;
    reg        reset_timer;
    reg        core_reset_n = 1'b1;
    reg        core_reset_r = 1'b1;

    always_ff @(posedge clk_74a) begin
        if(reset_timer) begin
            reset_counter <= 32'd8000;
            core_reset_n  <= 1'b0;
        end
        else begin
            if (reset_counter == 32'h0) begin
                core_reset_n <= 1'b1;
            end
            else begin
                reset_counter <= reset_counter - 32'h1;
                core_reset_n  <= 1'b0;
            end
        end
    end

    //!-------------------------------------------------------------------------
    //! Read/Write APF Bridge
    //!-------------------------------------------------------------------------
    reg        svc_mode   =  1'h0;
    reg [31:0] dip_switch = 32'h0;
    reg [31:0] ext_switch = 32'h0;
    reg [31:0] modifiers  = 32'h0;
    reg [31:0] filters    = 32'h0;
    reg [31:0] status_h   = 32'h0;
    reg [31:0] status_l   = 32'h0;
    reg [31:0] inputs     = 32'h0;
    reg [15:0] nvram_sz   = 16'h0;
    reg [31:0] analogizer = 32'h0;

    always_ff @(posedge clk_74a) begin
        reset_timer <= 1'b0; //! Always default this to zero
        if(bridge_wr) begin
            case(bridge_addr)
                32'hF0000000: begin /*        RESET ONLY          */    reset_timer <= 1'b1; end //! Reset Core Command
                32'hF0000010: begin svc_mode   <= bridge_wr_data[0];    reset_timer <= 1'b1; end //! Service Mode Switch
                32'hF1000000: begin dip_switch <= bridge_wr_data;       reset_timer <= 1'b1; end //! DIP Switches
                32'hF2000000: begin modifiers  <= bridge_wr_data;                            end //! Modifiers
                32'hF3000000: begin filters    <= bridge_wr_data;                            end //! A/V Filters
                32'hF4000000: begin ext_switch <= bridge_wr_data;       reset_timer <= 1'b1; end //! Extra DIP Switches
                32'hF5000000: begin nvram_sz   <= bridge_wr_data[15:0];                      end //! NVRAM Size in Bytes
                32'hFA000000: begin status_l   <= bridge_wr_data;                            end //! Status Low  [31:0]
                32'hFB000000: begin status_h   <= bridge_wr_data;                            end //! Status High [63:32]
                32'hFC000000: begin inputs     <= bridge_wr_data;                            end //! Inputs
                32'hA0000000: begin analogizer <= bridge_wr_data;                            end //! Analogizer
            endcase
        end
        if(bridge_rd) begin
            case(bridge_addr)
                32'hF0000000: begin bridge_rd_data <= core_reset_r;        end
                32'hF0000010: begin bridge_rd_data <= {31'h0, svc_mode};   end
                32'hF1000000: begin bridge_rd_data <= dip_switch;          end
                32'hF2000000: begin bridge_rd_data <= modifiers;           end
                32'hF3000000: begin bridge_rd_data <= filters;             end
                32'hF4000000: begin bridge_rd_data <= ext_switch;          end
                32'hF5000000: begin bridge_rd_data <= {16'h0, nvram_sz};   end
                32'hFA000000: begin bridge_rd_data <= status_l;            end
                32'hFB000000: begin bridge_rd_data <= status_h;            end
                32'hFC000000: begin bridge_rd_data <= inputs;              end
                32'hA0000000: begin bridge_rd_data <= analogizer;          end
            endcase
        end
    end

    //!-------------------------------------------------------------------------
    //! Sync and Assign Outputs
    //!-------------------------------------------------------------------------
    wire [31:0] dip_switch_s, ext_switch_s, modifiers_s, filters_s, status_l_s, status_h_s, inputs_s, analogizer_s;
    wire [15:0] nvram_sz_s;
    wire        svc_mode_s, core_reset_s;

    synch_3 #(32) u_sync_dsw(dip_switch,   dip_switch_s, clk_sync);
    synch_3 #(32) u_sync_ext(ext_switch,   ext_switch_s, clk_sync);
    synch_3 #(32) u_sync_mod(modifiers,    modifiers_s,  clk_sync);
    synch_3 #(32) u_sync_flr(filters,      filters_s,    clk_sync);
    synch_3 #(32) u_sync_stl(status_l,     status_l_s,   clk_sync);
    synch_3 #(32) u_sync_sth(status_h,     status_h_s,   clk_sync);
    synch_3 #(32) u_sync_inp(inputs,       inputs_s,     clk_sync);
    synch_3 #(16) u_sync_nvm(nvram_sz,     nvram_sz_s,   clk_sync);
    synch_3       u_sync_svc(svc_mode,     svc_mode_s,   clk_sync);
    synch_3       u_sync_rst(core_reset_n, core_reset_s, clk_sync);
    synch_3 #(32) u_sync_agr(analogizer,   analogizer_s, clk_sync);

    always_comb begin
        reset_sw                             = ~(reset_n && core_reset_s);
        {dip_sw3, dip_sw2, dip_sw1, dip_sw0} = dip_switch_s;
        {ext_sw3, ext_sw2, ext_sw1, ext_sw0} = ext_switch_s;
        {mod_sw3, mod_sw2, mod_sw1, mod_sw0} = modifiers_s;
        {inp_sw0, inp_sw1, inp_sw2, inp_sw3} = inputs_s;
        scnl_sw                              = filters_s[3:0];
        smask_sw                             = filters_s[7:4];
        afilter_sw                           = filters_s[11:8];
        vol_att                              = filters_s[15:12];
        nvram_size                           = nvram_sz_s;
        svc_sw                               = svc_mode_s;
        status                               = {status_h_s, status_l_s};
        analogizer_sw                        = analogizer_s;
    end

endmodule
