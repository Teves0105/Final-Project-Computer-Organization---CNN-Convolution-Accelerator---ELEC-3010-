`timescale 1ns / 1ps

module simple_sram #(
    parameter DEPTH  = 64,
    parameter DATA_W = 8
)(
    input  wire                   clk,
    
    // Write Port
    input  wire                   wr_en,
    input  wire [$clog2(DEPTH)-1:0] wr_addr,
    input  wire [DATA_W-1:0]        wr_data,
    
    // Read Port
    input  wire [$clog2(DEPTH)-1:0] rd_addr,
    output reg  [DATA_W-1:0]        rd_data
);      

    // Memory array storage
    reg [DATA_W-1:0] mem_array [0:DEPTH-1];

    // Synchronous memory access
    always @(posedge clk) begin
        if (wr_en) 
            mem_array[wr_addr] <= wr_data;
        
        // Registered output: 1-cycle latency
        rd_data <= mem_array[rd_addr];
    end

endmodule