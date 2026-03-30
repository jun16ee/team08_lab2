`timescale 1ns/1ps
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