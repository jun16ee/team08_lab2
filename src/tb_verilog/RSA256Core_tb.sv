`timescale 1ns/1ps

module Rsa256Core_tb;

    // =========================
    // DUT signals
    // =========================
    logic         i_clk;
    logic         i_rst;
    logic         i_start;
    logic [255:0] i_a;
    logic [255:0] i_d;
    logic [255:0] i_n;
    logic [255:0] o_a_pow_d;
    logic         o_finished;

    // =========================
    // DUT
    // =========================
    Rsa256Core dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_start(i_start),
        .i_a(i_a),
        .i_d(i_d),
        .i_n(i_n),
        .o_a_pow_d(o_a_pow_d),
        .o_finished(o_finished)
    );

    // =========================
    // Clock
    // =========================
    initial i_clk = 1'b0;
    always #5 i_clk = ~i_clk;

    // =========================
    // Golden model helpers
    // =========================
    function automatic [255:0] mod_mul;
        input [255:0] x;
        input [255:0] y;
        input [255:0] n;
        reg   [511:0] prod;
        reg   [511:0] rem;
        begin
            if (n == 256'd0) begin
                mod_mul = 256'd0;
            end else begin
                prod = x * y;
                rem  = prod % n;
                mod_mul = rem[255:0];
            end
        end
    endfunction

    function automatic [255:0] mod_exp;
        input [255:0] base;
        input [255:0] exp;
        input [255:0] n;
        reg   [255:0] result;
        reg   [255:0] cur;
        integer i;
        begin
            if (n == 256'd0) begin
                mod_exp = 256'd0;
            end else begin
                result = 256'd1 % n;
                cur    = base % n;

                for (i = 0; i < 256; i = i + 1) begin
                    if (exp[i])
                        result = mod_mul(result, cur, n);
                    cur = mod_mul(cur, cur, n);
                end

                mod_exp = result;
            end
        end
    endfunction

    // =========================
    // Run one case
    // =========================
    task automatic run_case;
        input [255:0] in_a;
        input [255:0] in_d;
        input [255:0] in_n;

        reg [255:0] expected;
        integer cycle_count;
        begin
            expected = mod_exp(in_a, in_d, in_n);

            @(negedge i_clk);
            i_a     = in_a;
            i_d     = in_d;
            i_n     = in_n;
            i_start = 1'b1;

            @(negedge i_clk);
            i_start = 1'b0;

            cycle_count = 0;
            while (o_finished !== 1'b1) begin
                @(posedge i_clk);
                cycle_count = cycle_count + 1;
                if (cycle_count > 100000) begin
                    $display("[FAIL] Timeout");
                    $display("       a = %h", in_a);
                    $display("       d = %h", in_d);
                    $display("       n = %h", in_n);
                    $finish;
                end
            end

            @(negedge i_clk);
            if (o_a_pow_d !== expected) begin
                $display("[FAIL] Mismatch");
                $display("       a        = %h", in_a);
                $display("       d        = %h", in_d);
                $display("       n        = %h", in_n);
                $display("       expected = %h", expected);
                $display("       got      = %h", o_a_pow_d);
                $finish;
            end else begin
                $display("[PASS] a=%h", in_a);
                $display("       d=%h", in_d);
                $display("       n=%h", in_n);
                $display("       result=%h", o_a_pow_d);
                $display("       cycles=%0d", cycle_count);
            end

            // leave a few idle cycles so DONE can return to IDLE cleanly
            repeat (10) @(posedge i_clk);
        end
    endtask

    // =========================
    // Main test sequence
    // =========================
    initial begin
        i_rst   = 1'b1;
        i_start = 1'b0;
        i_a     = 256'd0;
        i_d     = 256'd0;
        i_n     = 256'd0;

        repeat (5) @(posedge i_clk);
        i_rst = 1'b0;
        repeat (2) @(posedge i_clk);

        // -------------------------
        // Very small sanity checks
        // -------------------------
        run_case(256'd0,  256'd7,  256'd33);  // 0^7 mod 33 = 0
        run_case(256'd1,  256'd7,  256'd33);  // 1^7 mod 33 = 1
        run_case(256'd2,  256'd5,  256'd33);  // 2^5 mod 33 = 32
        run_case(256'd7,  256'd3,  256'd19);  // 7^3 mod 19 = 1

        // -------------------------
        // RSA-like small examples
        // -------------------------
        // n = 33, d = 7
        // 31^7 mod 33 = 4
        run_case(256'd31, 256'd7,  256'd33);

        // n = 55, d = 27
        // 23^27 mod 55 = 12
        run_case(256'd23, 256'd27, 256'd55);

        // -------------------------
        // Larger arbitrary modexp cases
        // -------------------------
        run_case(
            256'h0000000000000000000000000000000000000000000000000000000000001234,
            256'h0000000000000000000000000000000000000000000000000000000000000011,
            256'h0000000000000000000000000000000000000000000000000000000000010001
        );

        run_case(
            256'h0123456789abcdef000000000000000000000000000000000000000000000000,
            256'h0000000000000000000000000000000000000000000000000000000000001235,
            256'h1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff
        );

        $display("All tests passed.");
        $finish;
    end

endmodule
