`timescale 1ns/1ps

module ModuloProduct_tb;

    // =========================
    // DUT signals
    // =========================
    logic         i_clk;
    logic         i_rst;
    logic [255:0] N;
    logic [255:0] y;
    logic         i_start;
    logic         o_finished;
    logic [255:0] o_mod_pro;

    // =========================
    // DUT
    // =========================
    ModuloProduct dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .N(N),
        .y(y),
        .i_start(i_start),
        .o_finished(o_finished),
        .o_mod_pro(o_mod_pro)
    );

    // =========================
    // Clock
    // =========================
    initial i_clk = 1'b0;
    always #5 i_clk = ~i_clk;

    // =========================
    // Golden model:
    // y * 2^256 mod N
    // =========================
    function automatic [255:0] golden_mod_product;
        input [255:0] in_y;
        input [255:0] in_N;
        reg   [255:0] t;
        reg   [256:0] tmp;
        reg   [256:0] diff;
        integer k;
        begin
            t = in_y;
            for (k = 0; k < 256; k = k + 1) begin
                tmp = {1'b0, t} << 1;
                if (tmp >= {1'b0, in_N}) begin
                    diff = tmp - {1'b0, in_N};
                    t = diff[255:0];
                end
                else begin
                    t = tmp[255:0];
                end
            end
            golden_mod_product = t;
        end
    endfunction

    // =========================
    // Run one case
    // =========================
    task automatic run_case;
        input [255:0] in_y;
        input [255:0] in_N;
        reg   [255:0] expected;
        integer cycle_count;
        begin
            expected = golden_mod_product(in_y, in_N);

            @(negedge i_clk);
            y       = in_y;
            N       = in_N;
            i_start = 1'b1;

            @(negedge i_clk);
            i_start = 1'b0;

            cycle_count = 0;
            while (o_finished !== 1'b1) begin
                @(posedge i_clk);
                cycle_count = cycle_count + 1;
                if (cycle_count > 300) begin
                    $display("[FAIL] Timeout");
                    $display("       y = %h", in_y);
                    $display("       N = %h", in_N);
                    $finish;
                end
            end

            @(negedge i_clk);
            if (o_mod_pro !== expected) begin
                $display("[FAIL] Mismatch");
                $display("       y        = %h", in_y);
                $display("       N        = %h", in_N);
                $display("       expected = %h", expected);
                $display("       got      = %h", o_mod_pro);
                $finish;
            end
            else begin
                $display("[PASS] y=%h N=%h result=%h", in_y, in_N, o_mod_pro);
            end

            @(posedge i_clk);
        end
    endtask

    // =========================
    // Main test
    // =========================
    initial begin
        i_rst   = 1'b1;
        i_start = 1'b0;
        N       = 256'b0;
        y       = 256'b0;

        repeat (3) @(posedge i_clk);
        i_rst = 1'b0;
        repeat (2) @(posedge i_clk);

        // Basic cases
        run_case(256'd0,     256'd17);
        run_case(256'd1,     256'd17);
        run_case(256'd5,     256'd17);
        run_case(256'd16,    256'd17);
        run_case(256'd7,     256'd19);
        run_case(256'd12345, 256'd65537);
        run_case(256'd42,    256'd1000003);

        // Bigger directed cases
        run_case(
            256'h0000000000000000000000000000000000000000000000000000000000001234,
            256'h0000000000000000000000000000000000000000000000000000000000010001
        );

        run_case(
            256'h0123456789abcdef000000000000000000000000000000000000000000000000,
            256'h1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );

        run_case(
            256'h00abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678,
            256'h0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed
        );

        // Random cases
        repeat (20) begin
            reg [255:0] randN;
            reg [255:0] randy;

            randN = {
                $urandom(), $urandom(), $urandom(), $urandom(),
                $urandom(), $urandom(), $urandom(), $urandom()
            };

            randy = {
                $urandom(), $urandom(), $urandom(), $urandom(),
                $urandom(), $urandom(), $urandom(), $urandom()
            };

            randN[255] = 1'b0;
            randN[0]   = 1'b1;
            if (randN < 256'd3)
                randN = randN + 256'd3;

            randy = randy % randN;

            run_case(randy, randN);
        end

        $display("All tests passed.");
        $finish;
    end

endmodule
