//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// Analogue Pocket Audio FIFO Controller
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2022, Adam Gastineau
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

`default_nettype none
`timescale 1ns/1ps

module audio_fifo
    (
        // Clocks
        input  wire         clk_sys,
        input  wire         audio_mclk,
        // Core Audio
        input  wire  [15:0] core_al,
        input  wire  [15:0] core_ar,
        // Synced Audio
        output logic [15:0] audio_l,
        output logic [15:0] audio_r
    );

    localparam  READ_DELAY = 1,
                READ_WRITE = 2;

    logic  [1:0] read_state = 0;
    logic        wrreq = 0;
    logic        rdreq = 0;
    logic        empty;

    logic [15:0] prev_al, prev_ar;
    logic [15:0] fifo_al, fifo_ar;

    always_ff @(posedge clk_sys) begin : fifoWriteControl
        prev_al <= core_al;
        prev_ar <= core_ar;
        wrreq   <= 0;
        if (core_al != prev_al || core_ar != prev_ar) begin
            wrreq <= 1;
        end
    end

    dcfifo #(
        .intended_device_family ( "Cyclone V"        ),
        .lpm_numwords           ( 4                  ),
        .lpm_showahead          ( "OFF"              ),
        .lpm_type               ( "dcfifo"           ),
        .lpm_width              ( 32                 ),
        .lpm_widthu             ( 2                  ),
        .overflow_checking      ( "ON"               ),
        .rdsync_delaypipe       ( 5                  ),
        .underflow_checking     ( "ON"               ),
        .use_eab                ( "ON"               ),
        .wrsync_delaypipe       ( 5                  )
    ) dcfifo_component (
        // Write
        .wrclk                  ( clk_sys            ),
        .wrreq                  ( wrreq              ),
        .data                   ( {core_al, core_ar} ),
        // Read
        .rdclk                  ( audio_mclk         ),
        .rdreq                  ( rdreq              ),
        .rdempty                ( empty              ),
        .q                      ( {fifo_al, fifo_ar} )
    );

    always_ff @(posedge audio_mclk) begin : fifoReadControl
        rdreq <= 0;
        if (~empty) begin
            read_state <= READ_DELAY;
            rdreq      <= 1;
        end
        case (read_state)
            READ_DELAY: begin
                read_state <= READ_WRITE;
            end
            READ_WRITE: begin
                read_state <= 0;
                audio_l    <= fifo_al;
                audio_r    <= fifo_ar;
            end
        endcase
    end

endmodule
