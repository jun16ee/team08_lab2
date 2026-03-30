module Rsa256Core (
	input          i_clk,
	input          i_rst,
	input          i_start,
	input  [255:0] i_a, // 密文
	input  [255:0] i_d, // 私鑰
	input  [255:0] i_n, // 模數
	output [255:0] o_a_pow_d, // 明文
	output         o_finished
);

	// operations for RSA256 decryption
	// namely, the Montgomery algorithm
	// typedef enum logic [2:0] {
    //     S_IDLE,
    //     S_PREP,
    //     S_MUL,
    //     S_SQR,
	// 	S_EXIT,
	// 	S_DONE
    // } state_t;

    // state_t state_r, state_w;
	
	// logic [255:0] result_r, result_w, c_reg;
	// logic [8:0] bit_cnt_r, bit_cnt_w;

	// //control
	// logic monpro_start_r, monpro_start_w, monpro_done;


	// logic [255:0] monpro_in_A, monpro_in_B;
	// logic [255:0] monpro_out;

 	// logic m
	// MonPro u_monpro (
    //     .clk    (i_clk),
    //     .rst    (i_rst),
    //     .start  (monpro_start_r),
    //     .A      (monpro_in_A_r),
    //     .B      (monpro_in_B_r),
    //     .N      (i_n),
    //     .result (monpro_out),
    //     .done   (monpro_done)
    // );

	// always_comb begin
	// 	state_w        = state_r;
    // 	monpro_start_w = 1'b0;
    // 	bit_cnt_w      = bit_cnt_r;
	// 	monpro_in_A_r  = 256'd0;
	// 	monpro_in_B_r  = 256'd0;

	// 	case(state_r)
	// 		S_IDLE: begin
	// 			if (i_start) begin
	// 				state_w = S_PREP;
	// 				monpro_start_w = 1'b1;
	// 				bit_cnt_w = 9'd255;
	// 			end
	// 		end

	// 		S_PREP: begin
	// 			monpro_in_A_r  = i_a;
	// 			monpro_in_B_r  = //R^2 mod n;
	// 			if (monpro_done) begin
	// 				state_w = S_SQR;
	// 				monpro_start_w = 1'b1;
	// 				c_reg = monpro_out;
	// 			end
	// 		end

	// 		S_SQR: begin
	// 			monpro_in_A_r  = result_r;
	// 			monpro_in_B_r  = result_r;
	// 			if (monpro_done) begin					
	// 				result_w = monpro_out;
	// 				monpro_start_w = 1'b1;
	// 				if (i_d[bit_cnt_r] == 1'b0) begin
	// 					if (bit_cnt_r==9'd0) begin
	// 						state_w = S_EXIT;
	// 					end else begin
	// 						state_w = S_SQR;
	// 						bit_cnt_w = bit_cnt_r - 9'd1;
	// 					end
	// 				end else begin
	// 					state_w = S_MUL;
	// 				end
	// 			end
	// 		end

	// 		S_MUL: begin
	// 			monpro_in_A_r  = result_r;
	// 			monpro_in_B_r  = i_a;
	// 			if (monpro_done == 1'b1) begin
	// 				result_w = monpro_out;
	// 				monpro_start_w = 1'b1;
	// 				if (bit_cnt_r==9'd0) begin
	// 					state_w = S_EXIT;
	// 				end else begin
	// 					state_w = S_SQR;
	// 					bit_cnt_w = bit_cnt_r - 9'd1;
	// 				end
	// 			end
	// 		end

		
	// 		S_EXIT: begin
	// 			monpro_in_A_r  = result_r;
	// 			monpro_in_B_r  = 256'd1;
	// 			if (monpro_done) begin
	// 				result_w = monpro_out;
	// 				state_w = S_DONE;
	// 			end
	// 		end

	// 		S_DONE: begin
	// 			if (i_start) begin
	// 				state_w = S_PREP;
	// 				monpro_start_w = 1'b1;
	// 				bit_cnt_w = 9'd255;
	// 			end else begin
	// 				state_w = state_r;
	// 				monpro_start_w = 0;
	// 			end
	// 		end

	// 		default: state_w = S_IDLE;
	// 	endcase
	// end

	// always @(posedge i_clk or posedge i_rst) begin
    //     if (i_rst) begin
    //         state_r <= S_IDLE;
    //         bit_cnt_r <= 9'd0;
	// 		monpro_start_r <= 0;
	// 		result_r <= 256'd0;
    //     end else begin
	// 		state_r <= state_w;
	// 		monpro_start_r <= monpro_start_w;
	// 		bit_cnt_r <= bit_cnt_w;
	// 		result_r <= result_w;
	// 	end
	// end

	// assign o_finished = (state_r==S_DONE);
	// assign o_a_pow_d = (state == S_DONE) ? result_r : 256'd0;

	typedef enum logic [2:0] {
        S_IDLE,
        S_PREP,
        S_MUL,
        S_SQR,
        S_EXIT,
        S_DONE
    } state_t;

    state_t state_r, state_w;
    
    // ==========================================
    // 關鍵修正：宣告完整的 256-bit 暫存器
    // ==========================================
    logic [255:0] m_reg_r, m_reg_w; // 累積結果 (M)
    logic [255:0] c_reg_r, c_reg_w; // 轉換後的密文 (C_tilde)
    logic [8:0]   bit_cnt_r, bit_cnt_w;

    // control
    logic monpro_start_r, monpro_start_w, monpro_done;

    // 這些是餵給底層的組合邏輯訊號，拿掉 _r 尾綴比較不會混淆
    logic [255:0] monpro_in_A, monpro_in_B;
    logic [255:0] monpro_out;

    MonPro u_monpro (
        .clk    (i_clk),
        .rst    (i_rst),
        .start  (monpro_start_r),
        .A      (monpro_in_A),
        .B      (monpro_in_B),
        .N      (i_n),
        .result (monpro_out),
        .done   (monpro_done)
    );

    always_comb begin
        // 防 Latch 預設值
        state_w        = state_r;
        monpro_start_w = 1'b0;
        bit_cnt_w      = bit_cnt_r;
        m_reg_w        = m_reg_r;    // 預設保持不變
        c_reg_w        = c_reg_r;    // 預設保持不變
        monpro_in_A    = 256'd0;
        monpro_in_B    = 256'd0;

        case(state_r)
            S_IDLE: begin
                if (i_start) begin
                    state_w        = S_PREP;
                    monpro_start_w = 1'b1;
                    bit_cnt_w      = 9'd255;
                    // 初始化 m_reg，在空間中代表數字 1
                    m_reg_w        = i_r_mod_n; 
                end
            end

            S_PREP: begin
                // 目標：計算 c_reg = MonPro(i_a, R^2 mod n)
                monpro_in_A = i_a;
                monpro_in_B = i_r2_mod_n;
                
                if (monpro_done) begin
                    c_reg_w        = monpro_out; // 把轉進空間的密文存起來！
                    state_w        = S_SQR;
                    monpro_start_w = 1'b1;
                end
            end

            S_SQR: begin
                monpro_in_A = m_reg_r;
                monpro_in_B = m_reg_r;
                
                if (monpro_done) begin
                    m_reg_w = monpro_out;        // 把平方的結果存起來！
                    
                    if (i_d[bit_cnt_r] == 1'b0) begin
                        if (bit_cnt_r == 9'd0) begin
                            state_w        = S_EXIT;
                            monpro_start_w = 1'b1;
                        end else begin
                            state_w        = S_SQR;
                            monpro_start_w = 1'b1;
                            bit_cnt_w      = bit_cnt_r - 9'd1;
                        end
                    end else begin
                        state_w        = S_MUL;
                        monpro_start_w = 1'b1;
                    end
                end
            end

            S_MUL: begin
                monpro_in_A = m_reg_r;
                monpro_in_B = c_reg_r;           // 必須乘上轉換後的 c_reg_r，不能用 i_a！
                
                if (monpro_done == 1'b1) begin
                    m_reg_w = monpro_out;        // 把乘法的結果存起來！
                    
                    if (bit_cnt_r == 9'd0) begin
                        state_w        = S_EXIT;
                        monpro_start_w = 1'b1;
                    end else begin
                        state_w        = S_SQR;
                        monpro_start_w = 1'b1;
                        bit_cnt_w      = bit_cnt_r - 9'd1;
                    end
                end
            end
        
            S_EXIT: begin
                monpro_in_A = m_reg_r;
                monpro_in_B = 256'd1;            // 乘上 1 來轉出空間
                
                if (monpro_done) begin
                    m_reg_w = monpro_out;        // 最後真正的明文 M 出爐了！
                    state_w = S_DONE;
                end
            end

            S_DONE: begin
                if (i_start) begin
                    state_w        = S_PREP;
                    monpro_start_w = 1'b1;
                    bit_cnt_w      = 9'd255;
                    m_reg_w        = i_r_mod_n;  // 重新初始化
                end
            end

            default: state_w = S_IDLE;
        endcase
    end

    // Sequential Block (D-Flip Flops)
    always_ff @(posedge i_clk or posedge i_rst) begin
        if (i_rst) begin
            state_r        <= S_IDLE;
            bit_cnt_r      <= 9'd0;
            monpro_start_r <= 1'b0;
            m_reg_r        <= 256'd0;
            c_reg_r        <= 256'd0;
        end else begin
            state_r        <= state_w;
            monpro_start_r <= monpro_start_w;
            bit_cnt_r      <= bit_cnt_w;
            m_reg_r        <= m_reg_w;
            c_reg_r        <= c_reg_w;
        end
    end

    assign o_finished = (state_r == S_DONE);
    assign o_a_pow_d  = (state_r == S_DONE) ? m_reg_r : 256'd0; // 修改為 state_r 且輸出 m_reg_r


endmodule

module MonPro(
	input clk,
	input rst,
	input start,
	input [255:0] a,
	input [255:0] b,
	input [255:0] n,
	output [255:0] pro,
	output o_valid
);
	logic [8:0] counter;
	logic a_bit;
	logic run_r;
	logic run_w;
	logic [256:0] ans_r;
    logic [256:0] ans_w;
	logic [257:0] psum1, psum2;

	assign run_w = (start) ? 1'b1 : (o_valid) ? 1'b0 : run_r;
	assign o_valid = (counter == 9'd256 && run_r);
	assign pro = (ans_r >= {1'b0, n}) ? (ans_r - {1'b0, n}) : ans_r[255:0];
	assign a_bit = a[counter[7:0]];
	
	assign psum1 = a_bit ? ({1'b0, ans_r} + {2'b00, b}) : {1'b0, ans_r};
    assign psum2 = psum1[0] ? (psum1 + {2'b00, n}) : psum1;
    // 擷取 257 到 1 的 bit，等同於 >> 1 且把長度切回 257-bit
    assign ans_w = psum2[257:1];


	always_ff @(posedge clk) begin
		if (rst) begin
			counter <= 0;
			run_r <= 0;
			ans_r <= 0;
		end else begin
			run_r <= run_w;
            if (start) begin
                counter <= 8'd0;
                ans_r <= 256'd0;
            end else if (run_r) begin
				ans_r <= ans_w;
                counter <= counter + 8'd1;
            end
		end
		
	end
endmodule