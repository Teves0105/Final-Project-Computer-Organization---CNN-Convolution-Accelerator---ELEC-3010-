`timescale 1ns / 1ps

module conv_engine_parallel #(
    parameter H      = 16,
    parameter W      = 16,
    parameter K      = 3,
    parameter DATA_W = 8,
    parameter ACC_W  = 32
)(
    input  wire clk,
    input  wire rst,
    input  wire start,

    // 3 Parallel Input Read Ports
    output reg  [$clog2(H*W)-1:0]   in_rd_addr0, in_rd_addr1, in_rd_addr2,
    input  wire signed [DATA_W-1:0] in_rd_data0, in_rd_data1, in_rd_data2,

    // 3 Parallel Kernel Read Ports
    output reg  [$clog2(K*K)-1:0]   ker_rd_addr0, ker_rd_addr1, ker_rd_addr2,
    input  wire signed [DATA_W-1:0] ker_rd_data0, ker_rd_data1, ker_rd_data2,

    // Output Port
    output reg                          output_wr_en,
    output reg  [$clog2((H-K+1)*(W-K+1))-1:0] output_wr_addr,
    output reg  signed [DATA_W-1:0]     output_wr_data,

    output reg  done
);

    localparam ST_WAIT_START  = 3'd0,
               ST_FETCH_ROW   = 3'd1,
               ST_MAC_ROW     = 3'd2,
               ST_STORE_PIXEL = 3'd3,
               ST_DONE_CONV   = 3'd4;

    reg [2:0] state;
    reg [$clog2(H)-1:0] out_row;
    reg [$clog2(W)-1:0] out_col;
    reg [$clog2(K):0]   ki; // Notice: kj is GONE!
    reg signed [ACC_W-1:0] acc;

    always @(*) begin
        // Ask for 3 consecutive pixels in a row
        in_rd_addr0 = ((out_row + ki) * W) + out_col + 0;
        in_rd_addr1 = ((out_row + ki) * W) + out_col + 1;
        in_rd_addr2 = ((out_row + ki) * W) + out_col + 2;

        // Ask for 3 consecutive kernel weights in a row
        ker_rd_addr0 = (ki * K) + 0;
        ker_rd_addr1 = (ki * K) + 1;
        ker_rd_addr2 = (ki * K) + 2;

        output_wr_addr = (out_row * (W - K + 1)) + out_col;
        output_wr_en   = (state == ST_STORE_PIXEL);
        output_wr_data = acc[7:0];
    end

    always @(posedge clk) begin
        if (rst) begin
            state <= ST_WAIT_START; done <= 0; out_row <= 0; out_col <= 0; ki <= 0; acc <= 0;
        end else begin
            case (state)
                ST_WAIT_START: begin
                    done <= 0;
                    if (start) begin state <= ST_FETCH_ROW; out_row<=0; out_col<=0; ki<=0; acc<=0; end
                end

                ST_FETCH_ROW: state <= ST_MAC_ROW;

                ST_MAC_ROW: begin
                    // THE EXTENSION: 3 Multipliers and an Adder Tree in 1 cycle!
                    acc <= acc + (in_rd_data0 * ker_rd_data0) 
                               + (in_rd_data1 * ker_rd_data1) 
                               + (in_rd_data2 * ker_rd_data2);

                    if (ki == K - 1) begin
                        state <= ST_STORE_PIXEL;
                    end else begin
                        ki <= ki + 1;
                        state <= ST_FETCH_ROW;
                    end
                end

                ST_STORE_PIXEL: begin
                    acc <= 0; ki <= 0;
                    if (out_col == (W - K)) begin
                        out_col <= 0;
                        if (out_row == (H - K)) state <= ST_DONE_CONV;
                        else begin out_row <= out_row + 1; state <= ST_FETCH_ROW; end
                    end else begin out_col <= out_col + 1; state <= ST_FETCH_ROW; end
                end

                ST_DONE_CONV: begin done <= 1; if (!start) state <= ST_WAIT_START; end
            endcase
        end
    end
endmodule