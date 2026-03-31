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

    state_t state_r, state_w;
    logic [255:0] m_r, m_w, t_r, t_w;
    logic prep_start, prep_finished;
    logic mont1_start, mont1_finished;
    logic mont2_start, mont2_finished;
    logic [7:0] calc_i_r, calc_i_w;
    ModuloProduct u_prep (.N(i_n), .y(i_a), .i_start(prep_start), .o_finished(prep_finished), .o_mod_pro(t_w));
    // m * t
    MontAlg       u1_mont(.N(i_n), .a(t_r), .b(m_r), .i_start(mont1_start), .o_finished(mont1_finished), .o_mont_alg(m_w));
    // t * t
    MontAlg       u2_mont(.N(i_n), .a(t_r), .b(t_r), .i_start(mont2_start), .o_finished(mont2_finished), .o_mont_alg(t_w));

    // ===================== CS =====================
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            state_r <= IDLE;
        end else begin
            state_r <= state_w;
        end
    end

    // ===================== SEQ =====================
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            m_r <= 256'b0;
            t_r <= 256'b0;
            calc_i_r <= 8'b0;
            
        end else begin
            if (i_d[calc_i_r]) begin
                m_r <= m_w;
            end
            t_r <= t_w;
            calc_i_r <= calc_i_w;
        end
    end

    // ===================== NL =====================
    always_comb begin
        state_w = state_r;
        prep_start = 1'b0;
        case (state_r)
            IDLE: begin
                if(i_start) begin
                    state_w = PREP;
                    prep_start = 1'b1;
                end
            end

            PREP: begin
                if(prep_finished) begin
                    state_w = MONT;
                    mont1_start = 1'b1;
                    mont2_start = 1'b1;
                end
            end

            MONT: begin
                if(mont1_finished && mont2_finished) begin
                    state_w = CALC;
                end
            end

            CALC: begin
                if(calc_i_r == 255) begin
                    state_w = IDLE;
                end else begin
                    calc_i_w = calc_i_r + 1;
                    state_w = MONT;
                end

            end

            default: begin
                state_w = IDLE;
            end

        endcase
    end

    // ===================== OL =====================
    always_comb begin
        o_a_pow_d  =  256'b0;
        o_finished = 1'b0;

    end

endmodule


module ModuloProduct (
    input  logic [255:0] N,
    input  logic [255:0] y,
    input  logic i_start,
    output logic o_finished,
    output logic [255:0] o_mod_pro
);

endmodule


module MontAlg (
    input logic [255:0] N,
    input logic [255:0] a,
    input logic [255:0] b
    input logic i_start,
    output logic o_finished,
    output logic [255:0] o_mont_alg
);
endmodule