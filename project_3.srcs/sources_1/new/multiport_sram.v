`timescale 1ns / 1ps

module multiport_sram #(
    parameter DEPTH  = 256,
    parameter DATA_W = 8
)(
    input  wire clk,
    
    // 1 Write Port (For the external bus)
    input  wire                     wr_en,
    input  wire [$clog2(DEPTH)-1:0] wr_addr,
    input  wire [DATA_W-1:0]        wr_data,
    
    // 3 Parallel Read Ports (For the Engine)
    input  wire [$clog2(DEPTH)-1:0] rd_addr0,
    output reg  [DATA_W-1:0]        rd_data0,
    
    input  wire [$clog2(DEPTH)-1:0] rd_addr1,
    output reg  [DATA_W-1:0]        rd_data1,
    
    input  wire [$clog2(DEPTH)-1:0] rd_addr2,
    output reg  [DATA_W-1:0]        rd_data2
);

    reg [DATA_W-1:0] mem_array [0:DEPTH-1];

    always @(posedge clk) begin
        if (wr_en) begin
            mem_array[wr_addr] <= wr_data;
        end
        
        // Fetch 3 addresses simultaneously!
        rd_data0 <= mem_array[rd_addr0];
        rd_data1 <= mem_array[rd_addr1];
        rd_data2 <= mem_array[rd_addr2];
    end

endmodule