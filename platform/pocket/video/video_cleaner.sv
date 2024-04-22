//------------------------------------------------------------------------------
// SPDX-License-Identifier: GPL-3.0-or-later
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, Open Gateware authors and contributors
//------------------------------------------------------------------------------
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2017, Alexey Melnikov <pour.garbage@gmail.com>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//
//------------------------------------------------------------------------------
// Align vb_in/vs_in to hb_in/hs_in edges.
// Warning! Breaks interlaced vs_in.
//------------------------------------------------------------------------------

`default_nettype none
`timescale 1ns/1ps

module video_cleaner
    #(
         parameter             DW = 8   //! Color Depth
     )(
         input  logic          clk,     //! System clock
         input  logic          enable,  //! Enable Video Cleaner

         input  logic [DW-1:0] r_in,    //! Red
         input  logic [DW-1:0] g_in,    //! Green
         input  logic [DW-1:0] b_in,    //! Blue
         input  logic          hs_in,   //! Horizontal Sync
         input  logic          vs_in,   //! Vertical Sync
         input  logic          hb_in,   //! Horizontal Blank
         input  logic          vb_in,   //! Vertical Blank
         // Video output signals
         output logic [DW-1:0] r_out,   //! Red
         output logic [DW-1:0] g_out,   //! Green
         output logic [DW-1:0] b_out,   //! Blue
         output logic          vs_out,  //! Horizontal Sync
         output logic          hs_out,  //! Vertical Sync
         // Optional aligned blank
         output logic          hb_out,  //! Horizontal Blank
         output logic          vb_out   //! Vertical Blank
     );

    wire hs, vs;

    sync_fix sync_hs(clk, hs_in, hs);
    sync_fix sync_vs(clk, vs_in, vs);

    logic hbl = hs | hb_in;
    logic vbl = vs | vb_in;

    always_ff @(posedge clk) begin
        if(enable) begin
            r_out  <= r_in;
            g_out  <= g_in;
            b_out  <= b_in;
            hs_out <= hs;
            if(~hs_out & hs) begin
                vs_out <= vs;
            end
            hb_out <= hbl;
            if(hb_out & ~hbl) begin
                vb_out <= vbl;
            end
        end
        else begin
            // Passthrough
            r_out  <= r_in;
            g_out  <= g_in;
            b_out  <= b_in;
            hs_out <= hs_in;
            vs_out <= vs_in;
            hb_out <= hb_in;
            vb_out <= vb_in;
        end
    end

endmodule
