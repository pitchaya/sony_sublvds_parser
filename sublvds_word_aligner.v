`timescale 1ns/1ns

/*

: Pitchaya Sitthi-amorn
: pitchaya@gmail.com
: You may do whatever you want with the code.

This is a word aligner for LVDS, it supports 8-bit, 10-bit, and 12-bit.

This module delayed data at most 7 clocks cycles in order to match the input starting and ending symbol

All most everything is hard code.....

  Given the signals always start at FF then 00, there are a lot of optimizations to be able to do 
    the parser, but who cares

// Todo, parsing invalid line? 

*/


module word_aligner(
						input wire clk_i,
						input wire reset_i,
						input wire [7:0] word_i,
						output reg [11:0]word_o,
						output reg word_valid_o,
						output reg last,
                        output reg [1:0] line_type,   // 1 8 bits, 2 10bits, 3- 12 bits
                        output wire [47+8:0]debug
						);

localparam [31:0] SYNC_SAV_8BIT = 32'hFF000080;
localparam [31:0] SYNC_EAV_8BIT = 32'hFF00009D;
//                                     SAV4      SAV3     SAV2     SAV1
localparam [39:0] SYNC_SAV_10BIT = { 10'h3ff , 10'h000, 10'h000, 10'h200};
localparam [39:0] SYNC_EAV_10BIT = { 10'h3ff , 10'h000, 10'h000, 10'h274};
localparam [47:0] SYNC_SAV_12BIT = { 12'hfff , 12'h000, 12'h000, 12'h800};
localparam [47:0] SYNC_EAV_12BIT = { 12'hfff , 12'h000, 12'h000, 12'h9D0};

//wire clk_i;
//wire reset_i;
//wire [7:0]word_i;

// Output is actually 12 bits
//wire [11:0]word_o = 0;
//reg word_valid_o = 0;
//reg [1:0] line_type = 0;

reg [5:0]offset = 0;
reg [47:0] last_stream = 0;
reg [47:0] word_r = 0; 
wire [7:0] word_ir;
wire [47+8:0]word;
wire [11:0] word_oi;
reg state = 0;
reg [2:0] SAV_word = 0;

// assign word_ir =  { word_i[0], word_i[1], word_i[2], word_i[3], word_i[4], word_i[5], word_i[6], word_i[7]};

// Simulation needs no reverse bit
assign word_ir =word_i;
assign  word_oi = (line_type == 1)? {4'h0, word_r[24+:8]}: ((line_type == 2) ?{2'h0, word_r[30+:10]}: word_r[36+:12] );

reg [11:0]word_o1;
reg word_valid_o1;
reg last_o1;

reg [11:0]word_o2;
reg word_valid_o2;
reg last_o2;

reg word_valid_i;
reg last_i;
//  word_r[11:0];

assign debug =word;// {word_i, last};
//assign debug =  {word_i, last};


// TODO: Optimize first byte output;
integer i;
assign word = {last_stream, word_ir};

//assign debug = word; 

always @(posedge clk_i)
begin
	if (reset_i)
	begin
		last_stream <= 48'h0;
		word_valid_i <= 1'b0;
        line_type <= 0;
		offset <= 6'h0;
		word_r <= 48'h0;
		state <= 0;
		SAV_word<=0;
		last_i <= 0;

		last_o2 <=0;
		word_valid_o2<=0;
		word_valid_o1<=0;
		last_o1 <=0;
		word_valid_o <=0;
		last <= 0;
	end
	else
	begin

		// last_byte <= word_i;
        last_stream <= { last_stream[39:0], word_ir};
		last_i <= 0;
		if (!state)
		begin
		 for (i= 0; i < 8; i = i + 1)
			begin
				if ( (word[(i + 1'h1 ) +: 32] == SYNC_SAV_8BIT))
					begin
						word_valid_i <= 1'h0;
						offset  <= i[5:0] + 1'b1;
						//word_i <=  12'h3ff; //first byte output if sync found is always going to be the syncbyte itself
						word_r <= word[i[5:0] + 1'b1 +:48];
                        line_type <= 1;
						state <= 1;
						SAV_word <= 3'b111;
					end
				if ( (word[(i + 1'h1 ) +: 40] == SYNC_SAV_10BIT))
					begin
						word_valid_i <= 1'h0;
						offset  <= i[5:0] + 1'b1 + 8 - 2;
						//word_i <=  12'h3ff; //first byte output if sync found is always going to be the syncbyte itself
						word_r <= word[i[5:0] + 1'b1 +:48];
                        line_type <= 2;
						state <= 1;
						SAV_word <= 3'b111;
					end
				if ( (word[(i + 1'h1 ) +: 48] == SYNC_SAV_12BIT))
					begin
						word_valid_i <= 1'h0;
						offset  <= i[5:0] + 1'b1 + 8 - 4;
						//word_i <=  12'h3ff; //first byte output if sync found is always going to be the syncbyte itself
						word_r <= word[i[5:0] + 1'b1 +:48];
                        line_type <= 3;
						state <= 1;
						SAV_word <= 3'b111;
					end
			end
		end
		else
		begin
				//word_i <= word[offset +:12]; // from offset 8bits upwards
			case (line_type)			
			    2'b00: begin
		 				end
				2'b01: begin
				      word_r <= word[offset +:48]; // from offset 8bits upwards
					//   word_valid_i<= 1;
					word_valid_i<=1 & ~SAV_word[0];
					  SAV_word <= {1'b0, SAV_word[2:1]};
					if (word[ offset +: 32] == SYNC_EAV_8BIT) begin
					// if (word_r[31:0] == SYNC_EAV_8BIT) begin
						  line_type <= 0;
						  state <= 0;
						  word_valid_i<=0;
						  last_i <= 1;
					  end

				end
				2'b10: begin
					if (offset<=8) begin
						offset <= offset + 8;
						word_valid_i<=0;
					end else begin
				      word_r <= word[offset - 8 +:48]; // from offset 8bits upwards
					  
					  word_valid_i<=1 & ~SAV_word[0];
					  SAV_word <= {1'b0, SAV_word[2:1]};
					  offset <= offset - 2;
					  if (word[ (offset-8) +: 40] == SYNC_EAV_10BIT) begin
					//   if (word_r[39:0] == SYNC_EAV_10BIT) begin					  
						  line_type <= 0;
						  state <= 0;
						  word_valid_i<=0;
						  last_i <= 1;
					  end

					end
				end
				2'b11: begin
				    //   word_r <= word[offset +:48]; // from offset 8bits upwards
					if (offset<=8) begin
						offset <= offset + 8;
						word_valid_i<=0;
					end else begin
				      word_r <= word[offset - 8 +:48]; // from offset 8bits upwards
					//   word_valid_i<=1;
					  word_valid_i<=1 & ~SAV_word[0];
					  SAV_word <= {1'b0, SAV_word[2:1]};
					  offset <= offset - 4;
					//   if (word_r[47:0] == SYNC_EAV_12BIT) begin
					  if (word[ (offset-8) +: 48] == SYNC_EAV_12BIT) begin
						  line_type <= 0;
						  state <= 0;
						  word_valid_i<=0;
						  last_i <= 1;
					  end
					end					
				end
			endcase
			
		end
// Delay word
		if (word_valid_i | last_i) begin
			word_o1 <= word_oi;
			word_valid_o1 <= word_valid_i | last_i;
			last_o1<= last_i;

			word_o2<= word_o1;
			word_valid_o2 <= word_valid_o1;
			last_o2 <= last_o1;
		end  else begin
			word_valid_o2 <= 0;
		end
		if (last_o1) begin
			word_valid_o1<=0;
			last_o1 <=0;
		end

		if (word_valid_o2) begin 
			word_o <= word_o2;
			if (last_o1 == 0)
			begin
				word_valid_o <= 1;
				last <= 0;
			end
			else begin
				word_valid_o <= 1;
				last <= 1;
			end
		end else begin
			word_valid_o <= 0;
			last <= 0;
		end



	end
	
end

`ifdef COCOTB_SIM
initial begin
  $dumpfile ("word_aligner.vcd");
 $dumpvars (0, word_aligner);
//   $dumpvars (0, clk_i, word_r);
  #1;
end
`endif


endmodule
