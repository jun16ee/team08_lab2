`timescale 1ns/1ps

module tb_Rsa256Core();
    // ----------------------------------------------------
    // Signals
    // ----------------------------------------------------
    logic clk = 0;
    logic rst;
    logic start;
    logic finished;
    
    logic [255:0] i_n, i_a, i_d;
    logic [255:0] o_a_pow_d, expected_out;

    int passed_cnt = 0;
    int failed_cnt = 0;

    // ----------------------------------------------------
    // Clock Generation (10ns period)
    // ----------------------------------------------------
    always #5 clk = ~clk;

    // ----------------------------------------------------
    // Device Under Test (DUT)
    // ----------------------------------------------------
    Rsa256Core dut (
        .i_clk(clk),
        .i_rst(rst),
        .i_start(start),
        .i_a(i_a),
        .i_d(i_d),
        .i_n(i_n),
        .o_a_pow_d(o_a_pow_d),
        .o_finished(finished)
    );

    // ----------------------------------------------------
    // Complex Test Data Array (Embedded Directly)
    // Note: Montgomery algorithm strictly requires N to be ODD.
    // ----------------------------------------------------
    typedef struct {
        logic [255:0] N;
        logic [255:0] a;
        logic [255:0] d;
        string        name;
    } test_vector_t;

    test_vector_t test_vectors [] = '{
        // 1. Standard Public Key Test (d = 65537) with large padded data
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43, // Large prime-like odd number
            a: 256'h123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0,
            d: 256'h0000000000000000000000000000000000000000000000000000000000010001,
            name: "Standard Exponent (65537)"
        },
        // 2. Full 256-bit stress test (Massive N, a, and d)
        '{
            N: 256'h8A9B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8A9B0C1D2E3F4A5B6C7D8E9F0A11,
            a: 256'hFEDCBA0987654321FEDCBA0987654321FEDCBA0987654321FEDCBA0987654321,
            d: 256'h112233445566778899AABBCCDDEEFF00112233445566778899AABBCCDDEEFF01,
            name: "Full 256-bit Stress Test"
        },
        // 3. Corner Case: Exponent is 0 (Result should always be 1)
        '{
            N: 256'h1234567890ABCDEF1234567890ABCDEF1234567890ABCDEF1234567890ABCDEB,
            a: 256'hDEADBEEFCAFEBABEDEADBEEFCAFEBABEDEADBEEFCAFEBABEDEADBEEFCAFEBABE,
            d: 256'h0000000000000000000000000000000000000000000000000000000000000000,
            name: "Corner Case: d = 0"
        },
        // 4. Corner Case: Plaintext is 0 (Result should always be 0)
        '{
            N: 256'hBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEFBEEF,
            a: 256'h0000000000000000000000000000000000000000000000000000000000000000,
            d: 256'h9999999999999999999999999999999999999999999999999999999999999999,
            name: "Corner Case: a = 0"
        },
        // 5. Corner Case: Plaintext is 1 (Result should always be 1)
        '{
            N: 256'h7777777777777777777777777777777777777777777777777777777777777777,
            a: 256'h0000000000000000000000000000000000000000000000000000000000000001,
            d: 256'hFEDCBA0987654321FEDCBA0987654321FEDCBA0987654321FEDCBA0987654321,
            name: "Corner Case: a = 1"
        }
    };

    // ----------------------------------------------------
    // Golden Reference Model (Instant Behavioral Math)
    // ----------------------------------------------------

    function automatic [255:0] golden_exp(input [255:0] n_val, a_val, d_val);
        logic [511:0] res;
        logic [511:0] base;
        logic [511:0] big_N;
    
        // Procedural assignment ensures evaluation on every call
        res = 1;
        base = {256'b0, a_val};
        big_N = {256'b0, n_val};
    
        for (int i = 0; i < 256; i++) begin
            if (d_val[i]) res = (res * base) % big_N;
            base = (base * base) % big_N;
        end
        return res[255:0];
    endfunction

    // ----------------------------------------------------
    // Main Stimulus
    // ----------------------------------------------------
    initial begin
        // Initialize
        start = 0;
        i_n = 0; i_a = 0; i_d = 0;
        
        // Reset Sequence
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING RSA-256 CORE VERIFICATION   ");
        $display("==================================================");


        foreach(test_vectors[i]) begin
            $display("Running Test [%0d]: %s...", i, test_vectors[i].name);
            
            // Assign inputs from struct
            i_n = test_vectors[i].N;
            i_a = test_vectors[i].a;
            i_d = test_vectors[i].d;
            
            // Calculate exact expected output using the golden model
            expected_out = golden_exp(i_n, i_a, i_d);

            // Trigger Start Pulse
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            // Wait for DUT to finish, with a timeout failsafe
            fork
                begin
                    wait(finished);
                    @(posedge clk); // Align with clock edge to read data safely
                    
                    if (o_a_pow_d === expected_out) begin
                        $display("  -> [PASS]");
                        passed_cnt++;
                    end else begin
                        $display("  -> [FAIL]");
                        $display("       Expected: %h", expected_out);
                        $display("       Got     : %h", o_a_pow_d);
                        failed_cnt++;
                    end
                end
                begin
                    // Timeout logic: ~65,536 cycles expected, timeout at 100,000
                    repeat(100000) @(posedge clk);
                    $display("  -> [FAIL] TIMEOUT");
                    failed_cnt++;
                end
            join_any
            disable fork; // Kill the timeout thread if wait(finished) succeeds
            
            // Wait a few cycles before the next test
            repeat(10) @(posedge clk);
        end

        $display("==================================================");
        $display(" TEST SUITE COMPLETE: %0d Passed | %0d Failed", passed_cnt, failed_cnt);
        $display("==================================================");
            
        $finish;
    end
endmodule
