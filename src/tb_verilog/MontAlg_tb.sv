`timescale 1ns/1ps

module MontAlg_tb;

    // =========================
    // DUT signals
    // =========================
    logic         i_clk;
    logic         i_rst;
    logic [255:0] N;
    logic [255:0] a;
    logic [255:0] b;
    logic         i_start;
    logic         o_finished;
    logic [255:0] o_mont_alg;

    // =========================
    // DUT
    // =========================
    MontAlg dut (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .N(N),
        .a(a),
        .b(b),
        .i_start(i_start),
        .o_finished(o_finished),
        .o_mont_alg(o_mont_alg)
    );

    // =========================
    // Clock
    // =========================
    initial i_clk = 1'b0;
    always #5 i_clk = ~i_clk;

    // =========================
    // Golden model for Montgomery
    // Same algorithm as RTL, but written in TB
    // =========================
    function automatic [255:0] golden_mont;
        input [255:0] in_N;
        input [255:0] in_a;
        input [255:0] in_b;

        reg [255:0] m;
        reg [256:0] sum_mb;
        reg [256:0] sum_mN;
        integer i;
        begin
            m = 256'b0;

            for (i = 0; i < 256; i = i + 1) begin
                if (in_a[i])
                    sum_mb = {1'b0, m} + {1'b0, in_b};
                else
                    sum_mb = {1'b0, m};

                if (sum_mb[0])
                    sum_mN = sum_mb + {1'b0, in_N};
                else
                    sum_mN = sum_mb;

                m = sum_mN[256:1];
            end

            if (m >= in_N)
                golden_mont = m - in_N;
            else
                golden_mont = m;
        end
    endfunction

    // =========================
    // Task: run one test case
    // =========================
    task automatic run_case;
        input [255:0] in_N;
        input [255:0] in_a;
        input [255:0] in_b;

        reg [255:0] expected;
        integer cycle_count;
        begin
            expected = golden_mont(in_N, in_a, in_b);

            @(negedge i_clk);
            N       = in_N;
            a       = in_a;
            b       = in_b;
            i_start = 1'b1;

            @(negedge i_clk);
            i_start = 1'b0;

            cycle_count = 0;
            while (o_finished !== 1'b1) begin
                @(posedge i_clk);
                cycle_count = cycle_count + 1;
                if (cycle_count > 300) begin
                    $display("[FAIL] Timeout");
                    $display("       N = %h", in_N);
                    $display("       a = %h", in_a);
                    $display("       b = %h", in_b);
                    $finish;
                end
            end

            @(negedge i_clk);
            if (o_mont_alg !== expected) begin
                $display("[FAIL] Mismatch");
                $display("       N        = %h", in_N);
                $display("       a        = %h", in_a);
                $display("       b        = %h", in_b);
                $display("       expected = %h", expected);
                $display("       got      = %h", o_mont_alg);
                $finish;
            end else begin
                $display("[PASS] N=%h", in_N);
                $display("       a=%h", in_a);
                $display("       b=%h", in_b);
                $display("       result=%h", o_mont_alg);
            end

            @(posedge i_clk);
        end
    endtask

    // =========================
    // Main test sequence
    // =========================
    initial begin
        i_rst   = 1'b1;
        i_start = 1'b0;
        N       = 256'b0;
        a       = 256'b0;
        b       = 256'b0;

        repeat (3) @(posedge i_clk);
        i_rst = 1'b0;
        repeat (2) @(posedge i_clk);

        // -------------------------
        // Small easy sanity checks
        // -------------------------
        run_case(256'd3,  256'd0,  256'd0);
        run_case(256'd3,  256'd1,  256'd1);
        run_case(256'd5,  256'd1,  256'd2);
        run_case(256'd17, 256'd3,  256'd7);
        run_case(256'd19, 256'd5,  256'd9);

        // -------------------------
        // Some larger directed cases
        // -------------------------
        run_case(
            256'h0000000000000000000000000000000000000000000000000000000000010001,
            256'h0000000000000000000000000000000000000000000000000000000000001234,
            256'h0000000000000000000000000000000000000000000000000000000000005678
        );

        run_case(
            256'h1fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff,
            256'h0123456789abcdef000000000000000000000000000000000000000000000000,
            256'h00112233445566778899aabbccddeeff00112233445566778899aabbccddeeff
        );

        run_case(
            256'h0fffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffed,
            256'h00abcdef1234567890abcdef1234567890abcdef1234567890abcdef12345678,
            256'h0011111111111111222222222222222233333333333333334444444444444444
        );

        // -------------------------
        // Random tests
        // N odd, nonzero, a < N, b < N
        // -------------------------
        repeat (20) begin
            reg [255:0] randN;
            reg [255:0] randa;
            reg [255:0] randb;

            randN = {
                $urandom(), $urandom(), $urandom(), $urandom(),
                $urandom(), $urandom(), $urandom(), $urandom()
            };

            randa = {
                $urandom(), $urandom(), $urandom(), $urandom(),
                $urandom(), $urandom(), $urandom(), $urandom()
            };

            randb = {
                $urandom(), $urandom(), $urandom(), $urandom(),
                $urandom(), $urandom(), $urandom(), $urandom()
            };

            randN[255] = 1'b0;
            randN[0]   = 1'b1;
            if (randN < 256'd3)
                randN = randN + 256'd3;

            randa = randa % randN;
            randb = randb % randN;

            run_case(randN, randa, randb);
        end

        $display("All tests passed.");
        $finish;
    end

endmodule
