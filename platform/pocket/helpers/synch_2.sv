//------------------------------------------------------------------------------
// SPDX-License-Identifier: MIT
// SPDX-FileType: SOURCE
// SPDX-FileCopyrightText: (c) 2023, OpenGateware authors and contributors
//------------------------------------------------------------------------------
//
// 2-stage synchronizer
//
// Copyright (c) 2023, Marcus Andrade <marcus@opengateware.org>
// Copyright (c) 2022, Analogue Enterprises Limited
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
// This creates a pipeline where each signal holds the value of the signal that
// was one clock cycle earlier.
//
// It effectively delays the 'i' input by two clock cycles and propagates it
// to the 'o' output.
//
// Useful for tasks such as synchronizing data or creating a 2-stage pipeline
// register.
//------------------------------------------------------------------------------
// altera message_off 10036

`default_nettype none
`timescale 1ns/1ps

module synch_2
    #(
         parameter WIDTH = 1
     ) (
         input  logic [WIDTH-1:0] i,    //! Input Signal
         output logic [WIDTH-1:0] o,    //! Synchronized Output
         input  logic             clk,  //! Clock To Synchronize On
         output logic             rise, //! One-Cycle Rising Edge Pulse
         output logic             fall  //! One-Cycle Falling Edge Pulse
     );

    logic [WIDTH-1:0] s1, s2;

    always_ff @(posedge clk) begin
        {s2, o, s1} <= {o, s1, i};
    end

    generate
        if(WIDTH == 1) begin : genEdges
            assign rise =  o & ~s2;
            assign fall = ~o &  s2;
        end
        else begin : genNoEdges
            assign rise = 1'b0;
            assign fall = 1'b0;
        end
    endgenerate

endmodule
