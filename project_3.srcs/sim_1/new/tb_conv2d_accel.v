`timescale 1ns / 1ps

module tb_conv2d_accel();
 
    // Setup for a 16x16 input image and a 3x3 kernel
    parameter H      = 16;
    parameter W      = 16;
    parameter K      = 3;
    parameter DATA_W = 8;
    parameter ADDR_W = 14;

    parameter OUT_H    = H - K + 1;
    parameter OUT_W    = W - K + 1;
    parameter OUT_SIZE = OUT_H * OUT_W;

    reg                 clk;
    reg                 rst;
    reg                 wr_en;
    reg  [ADDR_W-1:0]   wr_addr;
    reg  [DATA_W-1:0]   wr_data;
    wire                wr_ready;
    reg                 rd_en;
    reg  [ADDR_W-1:0]   rd_addr;
    wire [DATA_W-1:0]   rd_data;
    wire                rd_valid;

    // Hook up the convolution accelerator module
    conv2d_accel #(
        .H(H), .W(W), .K(K), .DATA_W(DATA_W), .ADDR_W(ADDR_W)
    ) dut (
        .clk(clk), .rst(rst),
        .wr_en(wr_en), .wr_addr(wr_addr), .wr_data(wr_data), .wr_ready(wr_ready),
        .rd_en(rd_en), .rd_addr(rd_addr), .rd_data(rd_data), .rd_valid(rd_valid)
    );

    // Generate a standard 10ns clock
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Local memory arrays for simulation data
    reg [DATA_W-1:0] input_img [0:(H*W)-1];
    reg [DATA_W-1:0] kernel    [0:(K*K)-1];
    reg [DATA_W-1:0] expected  [0:OUT_SIZE-1];

    // Helper task to write data to the hardware bus
    task bus_write(input [ADDR_W-1:0] addr, input [DATA_W-1:0] data);
        begin
            @(posedge clk);
            wr_en   <= 1;
            wr_addr <= addr;
            wr_data <= data;
            @(posedge clk);
            wr_en   <= 0;
        end
    endtask

    // Helper task to read data (accounts for read latency)
    task bus_read(input [ADDR_W-1:0] addr, output [DATA_W-1:0] data);
        begin
            @(posedge clk);
            rd_en   <= 1;
            rd_addr <= addr;
            @(posedge clk);
            @(posedge clk);
            data = rd_data;
            rd_en   <= 0;
        end
    endtask

    // Variables used for verification and performance tracking
    integer i, r, c, kr, kc;
    integer sum;
    reg [DATA_W-1:0] read_val;
    integer current_errors;
    integer total_errors;
    reg [7:0] cycle_low, cycle_high;

    // Run a complete hardware test and check the results
    task execute_test_case(input reg [8*30:1] test_name);
        begin
            $display("\nStarting test: %s", test_name);
            current_errors = 0;

            // Calculate the golden reference internally
            for (r = 0; r < OUT_H; r = r + 1) begin
                for (c = 0; c < OUT_W; c = c + 1) begin
                    sum = 0;
                    for (kr = 0; kr < K; kr = kr + 1) begin
                        for (kc = 0; kc < K; kc = kc + 1) begin
                            sum = sum + ($signed(input_img[(r + kr) * W + (c + kc)]) *
                                         $signed(kernel[kr * K + kc]));
                        end
                    end
                    expected[r * OUT_W + c] = sum[7:0]; // Emulate hardware truncation
                end
            end

            // Load data into the hardware SRAMs
            for (i = 0; i < H*W; i = i + 1) bus_write(14'h0000 + i, input_img[i]);
            for (i = 0; i < K*K; i = i + 1) bus_write(14'h1000 + i, kernel[i]);

            // Trigger the start signal
            bus_write(14'h3000, 8'h01);

            // Wait until the hardware asserts the done flag
            read_val = 0;
            while (read_val == 0) begin
                bus_read(14'h3004, read_val);
            end

            // Fetch and print the cycle count
            bus_read(14'h3008, cycle_low);
            bus_read(14'h3009, cycle_high);
            $display("Hardware finished in %0d clock cycles", {cycle_high, cycle_low});
            $display("Verifying output pixels against expected logic");

            // Verify every single pixel
            for (i = 0; i < OUT_SIZE; i = i + 1) begin
                bus_read(14'h2000 + i, read_val);
                if (read_val !== expected[i]) begin
                    $display("  [FAIL] Pixel %0d: expected %h, but got %h", i, expected[i], read_val);
                    current_errors = current_errors + 1;
                end else begin
                    $display("  [PASS] Pixel %0d: matched %h", i, expected[i]);
                end
            end

            if (current_errors == 0) 
                $display("Test passed with no errors");
            else 
                $display("Test failed with %0d pixel errors", current_errors);

            total_errors = total_errors + current_errors;
        end
    endtask

    // Load Python data files and ensure they match our internal math
    task load_files_and_verify();
        reg [DATA_W-1:0] expected_from_file [0:OUT_SIZE-1];
        integer r, c, kr, kc, sum, local_i;
        reg mismatch_in_file;

        begin
            $readmemh("input_feature_map.txt", input_img);
            $readmemh("kernel.txt", kernel);
            $readmemh("expected_output.txt", expected_from_file);

            // Re-calculate to cross-check the Python script
            for (r = 0; r < OUT_H; r = r + 1) begin
                for (c = 0; c < OUT_W; c = c + 1) begin
                    sum = 0;
                    for (kr = 0; kr < K; kr = kr + 1) begin
                        for (kc = 0; kc < K; kc = kc + 1) begin
                            sum = sum + ($signed(input_img[(r + kr) * W + (c + kc)]) *
                                         $signed(kernel[kr * K + kc]));
                        end
                    end
                    expected[r * OUT_W + c] = sum[7:0];
                end
            end

            mismatch_in_file = 0;
            for (local_i = 0; local_i < OUT_SIZE; local_i = local_i + 1) begin
                if (expected[local_i] !== expected_from_file[local_i]) begin
                    $display("Warning: File mismatch at pixel %0d. Python file has %h, but Verilog computed %h",
                             local_i, expected_from_file[local_i], expected[local_i]);
                    mismatch_in_file = 1;
                end
            end
            
            if (mismatch_in_file == 0)
                $display("Sanity check passed: Python expected file perfectly matches our Verilog computation");
            else
                $display("Sanity check failed: Python output file has discrepancies");
        end
    endtask

    // Main simulation sequence
    initial begin
        rst   = 1;
        wr_en = 0;
        rd_en = 0;
        total_errors = 0;
        
        #40 rst = 0;
        #20;

        $display("\nBooting up testbench environment");

        // Load the external files and run the main verification
        load_files_and_verify(); 
        execute_test_case("Python CNN Data (16x16)");

        // Print final verdict
        if (total_errors == 0) begin
            $display("\nSign-off approved: Hardware verification complete with 0 errors\n");
        end else begin
            $display("\nSign-off rejected: Found a total of %0d errors\n", total_errors);
        end

        $finish;
    end

endmodule