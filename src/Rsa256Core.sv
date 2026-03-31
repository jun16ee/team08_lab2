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
    typedef enum logic [1:0] {
        IDLE,
        PREP,
        MONT,
        CALC
    } state_t;

    // ================== FSM ====================
    state_t state, next_state;

    // CS
    always_ff @(posedge i_clk or posedge i_rst) begin
        
        if(i_rst) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // NL
    always_comb begin
        case (state)
            IDLE:
            PREP:
            MONT:
            CALC: 
        endcase
    end

    // OL
    always_comb begin

    end

endmodule