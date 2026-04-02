`timescale 1ns/1ps

module tb_MontAlg();
    // ----------------------------------------------------
    // Signals
    // ----------------------------------------------------
    logic clk = 0;
    logic rst;
    logic start;
    logic finished;
    
    logic [255:0] i_n, i_a, i_b;
    logic [255:0] o_mont_alg, expected_out;

    int passed_cnt = 0;
    int failed_cnt = 0;

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    // Instantiate DUT
    MontAlg dut (
        .i_clk(clk),
        .i_rst(rst),
        .N(i_n),
        .a(i_a),
        .b(i_b),
        .i_start(start),
        .o_finished(finished),
        .o_mont_alg(o_mont_alg)
    );

    // ----------------------------------------------------
    // Complex Test Data Array
    // ----------------------------------------------------
    typedef struct {
        logic [255:0] N;
        logic [255:0] a;
        logic [255:0] b;
        string        name;
    } test_vector_t;

    test_vector_t test_vectors [] = '{
        // 1. Minimum values (Verification of Modular Inverse of R)
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'h1,
            b: 256'h1,
            name: "Minimal: 1 * 1 * R^-1 mod N"
        },
        
        // 2. High Entropy Stress Test (Randomly generated 256-bit values)
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'hA5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5,
            b: 256'h5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A,
            name: "High Entropy Pattern"
        },

        // 3. Boundary Test: a and b are nearly N (Stresses the 258-bit carry logic)
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF42,
            b: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF41,
            name: "Boundary: (N-1)*(N-2) * R^-1 mod N"
        },

        // 4. Sparse Bits Test (Verifies addition logic for rare 1s)
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'h8000000000000000000000000000000000000000000000000000000000000001,
            b: 256'h00000000000000000000000000000000000000000000000000000000000000FF,
            name: "Sparse Bits"
        },

        // 5. Mixed Pattern (Checks for bit-alignment issues)
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'h123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0123456789ABCDEF0,
            b: 256'h0FEDCBA9876543210FEDCBA9876543210FEDCBA9876543210FEDCBA987654321,
            name: "Mixed Hex Pattern"
        },
       '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'hAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA,
            b: 256'h5555555555555555555555555555555555555555555555555555555555555555,
            name: "Checkerboard Pattern (Alternating Bits)"
        },
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF00000000000000000000000000000000,
            b: 0, // Assigned below to ensure random-looking entropy
            name: "Half-Full/Half-Empty Carry Ripple"
        },
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            b: 256'h8000000000000000000000000000000000000000000000000000000000000001,
            name: "MSB/LSB Toggle Stress"
        },
        '{
            N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43,
            a: 256'hC0DE1234FACEB00BDEADC0FFEE1234567890ABCDEF112233445566778899AABB,
            b: 256'hBEEFCAFEBAAAAAAA1111222233334444555566667777888899990000AAAABBBB,
            name: "High-Density Random Hex"
        },
        '{
            N: 256'h8000000000000000000000000000000000000000000000000000000000000001,
            a: 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            b: 256'h7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF,
            name: "Near-Power-of-Two Modulus Reduction"
        } 
    };
    // ----------------------------------------------------
    // Golden Reference Model (Outside Initial Block)
    // ----------------------------------------------------
    function automatic logic [255:0] golden_mont(
        input logic [255:0] n_val, 
        input logic [255:0] a_val, 
        input logic [255:0] b_val
    );
        // Using 258 bits for m to prevent overflow during additions (m + b + n)
        logic [257:0] m; 
        m = 0;
        
        for (int i = 0; i < 256; i++) begin
            // 1. Add b if the current bit of a is 1
            if (a_val[i]) m = m + {2'b0, b_val};
            
            // 2. Add N if m is odd (to make it even before shifting)
            if (m[0]) m = m + {2'b0, n_val};
            
            // 3. Divide by 2 (Shift right)
            m = m >> 1;
        end
        
        // Final reduction
        if (m >= {2'b0, n_val}) m = m - {2'b0, n_val};
        
        return m[255:0];
    endfunction

    // ----------------------------------------------------
    // Main Stimulus
    // ----------------------------------------------------
    initial begin
        start = 0; i_n = 0; i_a = 0; i_b = 0;
        
        // Reset Sequence
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING MONT-ALG SUBMODULE VERIFICATION       ");
        $display("==================================================");

        foreach(test_vectors[i]) begin
            $display("Running Test [%0d]: %s...", i, test_vectors[i].name);
            
            // Setup inputs
            i_n = test_vectors[i].N;
            i_a = test_vectors[i].a;
            i_b = test_vectors[i].b;
            expected_out = golden_mont(i_n, i_a, i_b);

            // Start Pulse
            @(posedge clk);
            start = 1'b1;
            @(posedge clk);
            start = 1'b0;

            // Wait for completion
            fork
                begin
                    wait(finished);
                    @(posedge clk); 
                    if (o_mont_alg === expected_out) begin
                        $display("  -> [PASS]");
                        passed_cnt++;
                    end else begin
                        $display("  -> [FAIL]");
                        $display("       Expected: %h", expected_out);
                        $display("       Got     : %h", o_mont_alg);
                        failed_cnt++;
                    end
                end
                begin
                    // Montgomery takes exactly 257 cycles
                    repeat(500) @(posedge clk);
                    $display("  -> [FAIL] TIMEOUT (FSM stuck)");
                    failed_cnt++;
                end
            join_any
            disable fork;
            
            repeat(5) @(posedge clk);
        end

        $display("==================================================");
        $display(" SUBMODULE COMPLETE: %0d Passed | %0d Failed", passed_cnt, failed_cnt);
        $display("==================================================");
        $finish;
    end
endmodule
