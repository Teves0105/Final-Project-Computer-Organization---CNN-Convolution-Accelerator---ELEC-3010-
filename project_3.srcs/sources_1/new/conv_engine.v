`timescale 1ns / 1ps

module conv_engine #(
    parameter H      = 16,  
    parameter W      = 16,
    parameter K      = 3,
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    output reg  [$clog2(H*W)-1:0]       input_rd_addr,
    input  wire signed [DATA_W-1:0]     input_rd_data,

    output reg  [$clog2(K*K)-1:0]       kernel_rd_addr,
    input  wire signed [DATA_W-1:0]     kernel_rd_data,

    output reg                          output_wr_en,
    output reg  [$clog2((H-K+1)*(W-K+1))-1:0] output_wr_addr,
    output reg  signed [DATA_W-1:0]     output_wr_data,

    output reg  done
);

    localparam ST_WAIT_START  = 3'd0,
               ST_FETCH_DATA  = 3'd1,
               ST_ACCUMULATE  = 3'd2,
               ST_STORE_PIXEL = 3'd3,
               ST_DONE_CONV   = 3'd4;

    reg [2:0] state;
    reg [$clog2(H)-1:0] out_row;
    reg [$clog2(W)-1:0] out_col;
    reg [$clog2(K):0]   ki, kj;
    reg signed [ACC_W-1:0] acc;

    // Combinational Logic
    always @(*) begin
        input_rd_addr  = ((out_row + ki) << $clog2(W)) + (out_col + kj);
        kernel_rd_addr = (ki * K) + kj;
        output_wr_addr = (out_row * (W - K + 1)) + out_col;
        
        // Write instantly while we are in the STORE state
        output_wr_en   = (state == ST_STORE_PIXEL);
        output_wr_data = acc[7:0]; 
    end

    // --- FSM Datapath ---
    always @(posedge clk) begin
        if (rst) begin
            state        <= ST_WAIT_START;
            done         <= 0;
            out_row      <= 0;
            out_col      <= 0;
            ki           <= 0;
            kj           <= 0;
            acc          <= 0;
        end else begin
            case (state)
                ST_WAIT_START: begin
                    done <= 0;
                    if (start) begin
                        state   <= ST_FETCH_DATA;
                        out_row <= 0;
                        out_col <= 0;
                        ki      <= 0;
                        kj      <= 0;
                        acc     <= 0;
                    end
                end

                ST_FETCH_DATA: begin
                    state <= ST_ACCUMULATE;
                end

                ST_ACCUMULATE: begin
                    acc <= acc + (input_rd_data * kernel_rd_data);
                    if (kj == K - 1) begin
                        kj <= 0;
                        if (ki == K - 1) begin
                            state <= ST_STORE_PIXEL;
                        end else begin
                            ki <= ki + 1;
                            state <= ST_FETCH_DATA; 
                        end
                    end else begin
                        kj <= kj + 1;
                        state <= ST_FETCH_DATA; 
                    end
                end

                ST_STORE_PIXEL: begin
                    acc <= 0;
                    ki  <= 0;
                    kj  <= 0;

                    if (out_col == (W - K)) begin
                        out_col <= 0;
                        if (out_row == (H - K)) begin
                            state <= ST_DONE_CONV;
                        end else begin
                            out_row <= out_row + 1;
                            state <= ST_FETCH_DATA;
                        end
                    end else begin
                        out_col <= out_col + 1;
                        state <= ST_FETCH_DATA;
                    end
                end

                ST_DONE_CONV: begin
                    done <= 1;
                    if (!start) begin
                        state <= ST_WAIT_START;
                    end
                end
            endcase
        end
    end
endmodule