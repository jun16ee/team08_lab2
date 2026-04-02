`timescale 1ns/1ps

module tb_ModuloProduct();
    // ----------------------------------------------------
    // Signals
    // ----------------------------------------------------
    logic clk = 0;
    logic rst;
    logic start;
    logic finished;
    
    logic [255:0] i_n, i_y;
    logic [255:0] o_mod_pro, expected_out;

    int passed_cnt = 0;
    int failed_cnt = 0;

    // Clock Generation (100MHz)
    always #5 clk = ~clk;

    // Instantiate DUT
    ModuloProduct dut (
        .i_clk(clk),
        .i_rst(rst),
        .N(i_n),
        .y(i_y),
        .i_start(start),
        .o_finished(finished),
        .o_mod_pro(o_mod_pro)
    );

    // ----------------------------------------------------
    // Complex Test Data Array
    // ----------------------------------------------------
    typedef struct {
        logic [255:0] N;
        logic [255:0] y;
        string        name;
    } test_vector_t;

    test_vector_t test_vectors [] = '{
        // Small Case: 3 * 2^256 mod 11
        // Math: 2^256 mod 11 = 9. So 3 * 9 = 27. 27 mod 11 = 5.
        '{ N: 256'd11, y: 256'd3, name: "Small Prime N=11" },
        
        // Corner Case: y = 0
        '{ N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43, 
           y: 256'h0, name: "Corner: y = 0" },
           
        // Corner Case: y = 1
        '{ N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43, 
           y: 256'h1, name: "Corner: y = 1" },

        // Large Vector: Full 256-bit stress
        '{ N: 256'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF43, 
           y: 256'hA5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5A5, 
           name: "Large 256-bit Random-style" }
    };

    // ----------------------------------------------------
    // Golden Reference Model (Module Level)
    // ----------------------------------------------------
    function automatic logic [255:0] golden_mod_pro(
        input logic [255:0] n_val, 
        input logic [255:0] y_val
    );
        logic [511:0] temp;
        logic [511:0] big_n;
        
        // Mathematically: (y * 2^256) mod N
        temp = {256'b0, y_val};
        big_n = {256'b0, n_val};
        
        temp = (temp << 256) % big_n;
        
        return temp[255:0];
    endfunction

    // ----------------------------------------------------
    // Main Stimulus
    // ----------------------------------------------------
    initial begin
        start = 0; i_n = 0; i_y = 0;
        
        // Reset Sequence
        rst = 1;
        repeat(5) @(posedge clk);
        rst = 0;
        repeat(2) @(posedge clk);

        $display("==================================================");
        $display("   STARTING MODULO-PRODUCT VERIFICATION           ");
        $display("==================================================");

        foreach(test_vectors[i]) begin
            $display("Running Test [%0d]: %s...", i, test_vectors[i].name);
            
            // Setup inputs
            i_n = test_vectors[i].N;
            i_y = test_vectors[i].y;
            expected_out = golden_mod_pro(i_n, i_y);

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
                    if (o_mod_pro === expected_out) begin
                        $display("  -> [PASS]");
                        passed_cnt++;
                    end else begin
                        $display("  -> [FAIL]");
                        $display("       Expected: %h", expected_out);
                        $display("       Got     : %h", o_mod_pro);
                        failed_cnt++;
                    end
                end
                begin
                    // ModuloProduct takes exactly 256 cycles
                    repeat(500) @(posedge clk);
                    $display("  -> [FAIL] TIMEOUT (FSM stuck)");
                    failed_cnt++;
                end
            join_any
            disable fork;
            
            repeat(10) @(posedge clk);
        end

        $display("==================================================");
        $display(" SUBMODULE COMPLETE: %0d Passed | %0d Failed", passed_cnt, failed_cnt);
        $display("==================================================");
        $finish;
    end
endmodule
