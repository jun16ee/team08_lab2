`timescale 1ns/1ps

module tb_MonPro();

    // 1. 宣告訊號線
    logic clk;
    logic rst;
    logic start;
    logic [255:0] a;
    logic [255:0] b;
    logic [255:0] n;
    logic [255:0] pro;
    logic o_valid;

    // 2. 例化待測模組 (DUT)
    MonPro dut (
        .clk(clk),
        .rst(rst),
        .start(start),
        .a(a),
        .b(b),
        .n(n),
        .pro(pro),
        .o_valid(o_valid)
    );

    // 3. 產生 Clock (週期 10ns)
    always #5 clk = ~clk;

    // 4. 測試流程
    initial begin
        // 初始化訊號
        clk = 0;
        rst = 1;
        start = 0;
        a = 256'd0;
        b = 256'd0;
        n = 256'd0;

        // 釋放 Reset
        #20;
        rst = 0;
        #10;

        // ===== 測試案例 1：小型數學驗證 =====
        $display("--- 啟動測試案例 1 ---");
        a = 256'd7;
        b = 256'd11;
        n = 256'd13;
        
        // 觸發 Start (維持 1 個 Clock Cycle)
        @(posedge clk);
        start = 1;
        @(posedge clk);
        start = 0;

        // 等待運算完成 (o_valid 拉高)
        wait(o_valid == 1);
        
        // 檢查結果
        @(posedge clk); // 等待 o_valid 的下一個 cycle 確認資料穩定
        if (pro == 256'd4) begin
            $display(" [PASS] Test Case 1 成功！預期: 4, 實際: %0d", pro);
        end else begin
            $display(" [FAIL] Test Case 1 失敗！預期: 4, 實際: %0d", pro);
        end

        #50;
        
        // ===== 測試案例 2：你可以把大數測資加在這裡 =====
        // a = 256'h...;
        // b = 256'h...;
        // n = 256'h...;
        // ...
        
        $display("測試結束。");
        $finish;
    end

    // 5. 產生波形檔
    initial begin
        $fsdbDumpfile("monpro.fsdb");
        $fsdbDumpvars;
    end

endmodule