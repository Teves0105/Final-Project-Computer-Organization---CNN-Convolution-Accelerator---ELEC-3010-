`timescale 1ns / 1ps

module conv2d_accel #(
    parameter H      = 16,
    parameter W      = 16,
    parameter K      = 3,
    parameter DATA_W = 8,
    parameter ACC_W  = 32,
    parameter ADDR_W = 14  
)(
    input  wire                 clk,
    input  wire                 rst,

    input  wire                 wr_en,
    input  wire [ADDR_W-1:0]    wr_addr,
    input  wire [DATA_W-1:0]    wr_data,
    output reg                  wr_ready,

    input  wire                 rd_en,
    input  wire [ADDR_W-1:0]    rd_addr,
    output reg  [DATA_W-1:0]    rd_data,
    output reg                  rd_valid
);

    // Internal signals & Engine wiring
    wire start, done;
    wire [$clog2(H*W)-1:0]        eng_in_rd_addr;
    wire [DATA_W-1:0]             eng_in_rd_data;
    wire [$clog2(K*K)-1:0]        eng_ker_rd_addr;
    wire [DATA_W-1:0]             eng_ker_rd_data;
    wire                          eng_out_wr_en;
    wire [$clog2((H-K+1)*(W-K+1))-1:0] eng_out_wr_addr;
    wire [DATA_W-1:0]             eng_out_wr_data;
    
    reg [31:0] cycle_count;
    reg        counting;

    // Address decoding for SRAM banks
    wire [1:0] bank_sel_wr = wr_addr[13:12];
    wire [1:0] bank_sel_rd = rd_addr[13:12];

    wire ext_in_wr_en   = wr_en & (bank_sel_wr == 2'b00);
    wire ext_ker_wr_en  = wr_en & (bank_sel_wr == 2'b01);
    wire csr_write_start = wr_en & (bank_sel_wr == 2'b11) & (wr_addr[11:0] == 12'h000);
    assign start = csr_write_start & (wr_data == 8'h01);

    // SRAM storage instances
    simple_sram #(.DEPTH(H*W), .DATA_W(DATA_W)) input_sram (
        .clk(clk), .wr_en(ext_in_wr_en), .wr_addr(wr_addr[$clog2(H*W)-1:0]), .wr_data(wr_data),
        .rd_addr(eng_in_rd_addr), .rd_data(eng_in_rd_data)
    );

    simple_sram #(.DEPTH(K*K), .DATA_W(DATA_W)) kernel_sram (
        .clk(clk), .wr_en(ext_ker_wr_en), .wr_addr(wr_addr[$clog2(K*K)-1:0]), .wr_data(wr_data),
        .rd_addr(eng_ker_rd_addr), .rd_data(eng_ker_rd_data)
    );

    wire [DATA_W-1:0] ext_out_rd_data;
    simple_sram #(.DEPTH((H-K+1)*(W-K+1)), .DATA_W(DATA_W)) output_sram (
        .clk(clk), .wr_en(eng_out_wr_en), .wr_addr(eng_out_wr_addr), .wr_data(eng_out_wr_data),
        .rd_addr(rd_addr[$clog2((H-K+1)*(W-K+1))-1:0]), .rd_data(ext_out_rd_data)
    );

    conv_engine #(.H(H), .W(W), .K(K), .DATA_W(DATA_W), .ACC_W(ACC_W)) engine (
        .clk(clk), .rst(rst), .start(start),
        .input_rd_addr(eng_in_rd_addr), .input_rd_data(eng_in_rd_data),
        .kernel_rd_addr(eng_ker_rd_addr), .kernel_rd_data(eng_ker_rd_data),
        .output_wr_en(eng_out_wr_en), .output_wr_addr(eng_out_wr_addr), .output_wr_data(eng_out_wr_data),
        .done(done)
    );

    // Combinational Read: Map banks/CSR registers to output
    always @(*) begin
        rd_data = 8'h00; 
        if (rd_en) begin
            case (bank_sel_rd)
                2'b10: rd_data = ext_out_rd_data; 
                2'b11: begin 
                    if (rd_addr[11:0] == 12'h004)      rd_data = {7'b0, done};         
                    else if (rd_addr[11:0] == 12'h008) rd_data = cycle_count[7:0];     
                    else if (rd_addr[11:0] == 12'h009) rd_data = cycle_count[15:8];    
                end
            endcase
        end
    end

    // Sequential logic: Status, Cycle counter, Control
    always @(posedge clk) begin
        if (rst) begin
            wr_ready    <= 0;
            rd_valid    <= 0;
            cycle_count <= 0;
            counting    <= 0;
        end else begin
            wr_ready <= wr_en; 
            rd_valid <= rd_en; 

            if (start) begin
                counting    <= 1;
                cycle_count <= 0;
            end else if (done) begin
                counting    <= 0;
            end else if (counting) begin
                cycle_count <= cycle_count + 1;
            end
        end
    end
endmodule