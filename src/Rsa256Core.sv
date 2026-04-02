module Rsa256Core (
	input                i_clk,
	input                i_rst,
	input                i_start,
	input        [255:0] i_a, // 密文
	input        [255:0] i_d, // 私鑰
	input        [255:0] i_n, // 模數
	output logic [255:0] o_a_pow_d, // 明文
	output logic         o_finished
);
    typedef enum logic [2:0] {
        IDLE,
        PREP,
        MONT_START,
        MONT_WAIT,
        CALC,
        DONE
    } state_t;

    state_t state_r, state_w;
    logic [255:0] m_r, m_w, t_r, t_w;
    logic [255:0] prep_result, mont1_result, mont2_result;
    logic prep_start, prep_finished;
    logic mont1_start, mont1_finished;
    logic mont2_start, mont2_finished;
    logic [255:0] o_a_pow_d_w;
    logic o_finished_w;

    logic [8:0] bit_idx_r, bit_idx_w;
    ModuloProduct u_prep (.i_clk(i_clk), .i_rst(i_rst), .N(i_n), .y(i_a), .i_start(prep_start), .o_finished(prep_finished), .o_mod_pro(prep_result));
    // m * t
    MontAlg       u1_mont(.i_clk(i_clk), .i_rst(i_rst), .N(i_n), .a(t_r), .b(m_r), .i_start(mont1_start), .o_finished(mont1_finished), .o_mont_alg(mont1_result));
    // t * t
    MontAlg       u2_mont(.i_clk(i_clk), .i_rst(i_rst), .N(i_n), .a(t_r), .b(t_r), .i_start(mont2_start), .o_finished(mont2_finished), .o_mont_alg(mont2_result));
    // ===================== FSM =====================

    // --------------------- CS ---------------------
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            state_r <= IDLE;
        end else begin
            state_r <= state_w;
        end
    end

    // --------------------- NL ---------------------
    always_comb begin
        state_w = state_r;

        prep_start = 1'b0;
        mont1_start = 1'b0;
        mont2_start = 1'b0;

        case (state_r)
            IDLE: begin
                if(i_start) begin
                    state_w = PREP;
                    prep_start = 1'b1;
                end
            end

            PREP: begin
                if(prep_finished) begin
                    state_w = MONT_START;
                end
            end

            MONT_START: begin
                mont1_start = 1'b1;
                mont2_start = 1'b1;
                state_w = MONT_WAIT;
            end

            MONT_WAIT: begin
                if(mont1_finished && mont2_finished) begin
                    state_w = CALC;
                end
            end

            CALC: begin
                if(bit_idx_r == 9'd255) begin
                    state_w = DONE;
                end else begin
                    state_w = MONT_START;
                end
            end

            DONE: begin
                state_w = IDLE;
            end

            default: begin
                state_w = IDLE;
            end

        endcase
    end


    // ===================== Datapath =====================

    // --------------------- SEQ ---------------------
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            m_r <= 256'b1;
            t_r <= 256'b0;
            bit_idx_r <= 9'b0;
            o_a_pow_d <= 256'b0;
            o_finished <= 1'b0;
            
        end else begin
            t_r <= t_w;
            m_r <= m_w;
            bit_idx_r <= bit_idx_w;
            o_a_pow_d <= o_a_pow_d_w;
            o_finished <= o_finished_w;
        end
    end

    // --------------------- COMB ---------------------
    always_comb begin
        m_w = m_r;
        t_w = t_r;
        bit_idx_w = bit_idx_r;
        o_a_pow_d_w = o_a_pow_d;
        o_finished_w = o_finished;

        case(state_r)
            IDLE: begin
                m_w = 256'b1;
                t_w = 256'b0;
                bit_idx_w = 9'b0;
                o_a_pow_d_w = 256'b0;
                o_finished_w = 1'b0;
            end

            PREP: begin
                if(prep_finished) begin
                    t_w = prep_result;
                end
            end

            MONT_START: begin
                // do nothing, wait for mont results
            end

            MONT_WAIT: begin
                // do nothing, wait for mont results
            end

            CALC: begin
                

                m_w = (i_d[bit_idx_r] == 1'b1 ? mont1_result : m_r);
                t_w = mont2_result;
                bit_idx_w = bit_idx_r + 1;

                if(bit_idx_r == 9'd255) begin
                    o_a_pow_d_w = m_w;
                    o_finished_w = 1'b1;
                end 
            
            end

            DONE: begin
               // do nothing
            end

            default: begin
                m_w = m_r;
                t_w = t_r;
            end
        endcase
    end

endmodule













// calculate: y * 2^256 mod N
module ModuloProduct (
    input  logic i_clk,
    input  logic i_rst,
    input  logic [255:0] N,
    input  logic [255:0] y,
    input  logic i_start,
    output logic o_finished,
    output logic [255:0] o_mod_pro
);
    logic [255:0] t_r, t_w;
    logic o_finished_w;
    logic [255:0] o_mod_pro_w;
    logic [8:0] bit_idx_r, bit_idx_w;
    logic [256:0] sum_tt, diff_tt; // for addition, one more bit for carry
    // ============== COMB ==============
    always_comb begin
        t_w = t_r;
        bit_idx_w = bit_idx_r;
        o_finished_w = 1'b0;
        o_mod_pro_w = o_mod_pro;
        sum_tt = 257'b0;
        diff_tt = 257'b0;

        if(i_start) begin
            t_w = y;
            bit_idx_w = 9'b0;
            o_finished_w = 1'b0;
            o_mod_pro_w = 256'b0;
        end else begin
            // t = t * 2 mod N
            sum_tt = ({1'b0, t_r} << 1);
            if(sum_tt >= {1'b0, N}) begin
                diff_tt = (sum_tt - {1'b0, N});
                t_w = diff_tt[255:0];
            end else begin
                t_w = sum_tt[255:0];
            end

            if(bit_idx_r < 9'd256) begin
                bit_idx_w = bit_idx_r + 1;
            end

            if(bit_idx_r == 9'd255) begin
                // the 256-th doubling
                o_finished_w = 1'b1;
                o_mod_pro_w = t_w;
            end
        end
    end


    // ============== SEQ ===============
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            o_finished <= 1'b0;
            o_mod_pro <= 256'b0;
            t_r <= 256'b0;
            bit_idx_r <= 9'b0;
        end else begin
            o_finished <= o_finished_w;
            o_mod_pro <= o_mod_pro_w;
            t_r <= t_w;
            bit_idx_r <= bit_idx_w;
        end
    end

endmodule

// calculate: a * b * 2^-256 mod N
module MontAlg (
    input logic i_clk,
    input logic i_rst,
    input logic [255:0] N,
    input logic [255:0] a,
    input logic [255:0] b,
    input logic i_start,
    output logic o_finished,
    output logic [255:0] o_mont_alg
);
    logic [256:0] m_r, m_w;
    logic [255:0] o_mont_alg_w;
    logic [8:0] bit_idx_r, bit_idx_w;
    logic o_finished_w;
    logic [257:0] sum_mb, sum_mN; // for addition, one more bit for carry
    // ============== COMB ==============
    always_comb begin
        m_w = m_r;
        bit_idx_w = bit_idx_r;
        o_finished_w = 1'b0;
        o_mont_alg_w = o_mont_alg;
        sum_mb = 258'b0;
        sum_mN = 258'b0;

        if (i_start) begin
            m_w = 257'b0;
            bit_idx_w = 9'b0;
            o_finished_w = 1'b0;
            o_mont_alg_w = 256'b0;
        end else begin
            if(bit_idx_r < 9'd256) begin
                if(a[bit_idx_r] == 1'b1) begin
                    sum_mb = {1'b0, m_r} + {2'b0, b};
                end else begin
                    sum_mb = {1'b0, m_r};
                end

                if(sum_mb[0]) begin
                    sum_mN = sum_mb + {2'b0, N};
                end else begin
                    sum_mN = sum_mb;
                end
                sum_mN = sum_mN >> 1;
                m_w = sum_mN[256:0];              
                bit_idx_w = bit_idx_r + 1;


            end else if(bit_idx_r == 9'd256) begin
                if(m_r >= N) begin
                    m_w = m_r - N;
                end else begin
                    m_w = m_r;
                end
                o_finished_w = 1'b1;
                o_mont_alg_w = m_w[255:0];
                bit_idx_w = bit_idx_r + 1;
            end
        end
    end

    // ============== SEQ ===============
    always_ff @(posedge i_clk or posedge i_rst) begin
        if(i_rst) begin
            m_r <= 257'b0;
            o_mont_alg <= 256'b0;
            o_finished <= 1'b0;
            bit_idx_r <= 9'b0;
        end else begin
            m_r <= m_w;
            o_mont_alg <= o_mont_alg_w;
            o_finished <= o_finished_w;
            bit_idx_r <= bit_idx_w;
        end
    end
endmodule