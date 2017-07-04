`include "vga_adapter/vga_adapter.v"
`include "vga_adapter/vga_address_translator.v"
`include "vga_adapter/vga_controller.v"
`include "vga_adapter/vga_pll.v"


// Part 2 skeleton

module lab6
	(
		CLOCK_50,						//	On Board 50 MHz
		// Your inputs and outputs here
        KEY,
        SW,
		// The ports below are for the VGA output.  Do not change.
		VGA_CLK,   						//	VGA Clock
		VGA_HS,							//	VGA H_SYNC
		VGA_VS,							//	VGA V_SYNC
		VGA_BLANK_N,						//	VGA BLANK
		VGA_SYNC_N,						//	VGA SYNC
		VGA_R,   						//	VGA Red[9:0]
		VGA_G,	 						//	VGA Green[9:0]
		VGA_B   						//	VGA Blue[9:0]
	);

	input			CLOCK_50;				//	50 MHz
	input   [17:0]   SW;
	input   [3:0]   KEY;

	// Declare your inputs and outputs here
	// Do not change the following outputs
	output			VGA_CLK;   				//	VGA Clock
	output			VGA_HS;					//	VGA H_SYNC
	output			VGA_VS;					//	VGA V_SYNC
	output			VGA_BLANK_N;				//	VGA BLANK
	output			VGA_SYNC_N;				//	VGA SYNC
	output	[9:0]	VGA_R;   				//	VGA Red[9:0]
	output	[9:0]	VGA_G;	 				//	VGA Green[9:0]
	output	[9:0]	VGA_B;   				//	VGA Blue[9:0]
	
	wire resetn;
	assign resetn = SW[17];
	
	// Create the colour, x, y and writeEn wires that are inputs to the controller.
	wire [2:0] colour;
	wire [7:0] x;
	wire [6:0] y;
	wire writeEn;
	wire [7:0] x_offset;
	wire [6:0] y_offset;

			
	// Put your code here. Your code should produce signals x,y,colour and writeEn/plot
	// for the VGA controller, in addition to any other functionality your design may require.
	wire ld_x, ld_y;
	
	
	
   // Instansiate FSM control
   control c0(.clk(CLOCK_50), .resetn(resetn), .go(KEY[3]), .update(KEY[1]), .ld_x(ld_x), .ld_y(ld_y), .x_offset(x_offset), .y_offset(y_offset), .writeEn(writeEn));
   
	
   // Instansiate datapath
	datapath d0(.clk(CLOCK_50), .in(SW[6:0]), .ld_x(ld_x), .ld_y(ld_y), .x_offset(x_offset), .y_offset(y_offset), .clr(SW[9:7]), .reset_n(resetn), .xOUT(x), .yOUT(y), .clrOUT(colour));

	

	// Create an Instance of a VGA controller - there can be only one!
	// Define the number of colours as well as the initial background
	// image file (.MIF) for the controller.

	vga_adapter VGA(
			.resetn(resetn),
			.clock(CLOCK_50),
					.colour(colour),
					.x(x),
					.y(y),
					.plot(writeEn),
					/* Signals for the DAC to drive the monitor. */
					.VGA_R(VGA_R),
					.VGA_G(VGA_G),
					.VGA_B(VGA_B),
					.VGA_HS(VGA_HS),
					.VGA_VS(VGA_VS),
					.VGA_BLANK(VGA_BLANK_N),
					.VGA_SYNC(VGA_SYNC_N),
					.VGA_CLK(VGA_CLK));
					defparam VGA.RESOLUTION = "160x120";
	         	defparam VGA.MONOCHROME = "FALSE";
	         	defparam VGA.BITS_PER_COLOUR_CHANNEL = 1;
	         	defparam VGA.BACKGROUND_IMAGE = "black.mif";
endmodule




module datapath(input clk,
	input [6:0] in, // 7 bits input
	input ld_x,      // 1 bit signal to tell you to load the x value 
	input ld_y, 	 // 1 bit signal to tell you to load the y value
	input x_offset,
	input y_offset,
	input [2:0] clr, // 3 bit colour
	input reset_n,

	output reg [7:0] xOUT, // xOUT is 8 bits
	output reg [6:0] yOUT,
	output reg [2:0] clrOUT // 3 bit color out
);



always@(posedge clk) begin
   clrOUT <= clr;
	if(!reset_n) begin
		xOUT <= 8'b0;
		yOUT <= 7'b0;
		
	end

	else begin
		if(ld_x)
			xOUT <= {1'b0, in} + x_offset;  // Add extra bit for xIN
		if(ld_y)
			yOUT <= in + y_offset;

	end

end

endmodule





module control(
    input clk,
    input resetn,
    input go,
	 input update,

    output reg ld_x, ld_y,
	 output reg x_offset, y_offset;
    output reg writeEn // tells screen when to update
    );

    reg [5:0] current_state, next_state; 
    reg next_sq;
    
    localparam  S_LOAD_X        = 5'd0,
                S_LOAD_X_WAIT   = 5'd1,
                S_LOAD_Y        = 5'd2,
                S_LOAD_Y_WAIT   = 5'd3,
                S_CYCLE_0       = 5'd4,
			S_CYCLE_1       = 5'd5;
		
	 assign x_offset = 8'b0;
	 assign y_offset = 7'b0;
	 
	 // Next state logic aka our state table
    always@(*)
    begin: state_table 
            case (current_state)
                S_LOAD_X: next_state = go ? S_LOAD_X_WAIT : S_LOAD_X; // Loop in current state until value is input
                S_LOAD_X_WAIT: next_state = go ? S_LOAD_X_WAIT : S_LOAD_Y; // Loop in current state until go signal goes low
                S_LOAD_Y: next_state = go ? S_LOAD_Y_WAIT : S_LOAD_Y; // Loop in current state until value is input
                S_LOAD_Y_WAIT: next_state = go ? S_LOAD_Y_WAIT : S_CYCLE_0; // Loop in current state until go signal goes low
					 
					 S_CYCLE_0: next_state = update ? S_CYCLE_1 : S_CYCLE_0;  // UPDATE signal starts drawing the sq
					 S_CYCLE_1: next_state = S_CYCLE_2;  
                S_CYCLE_2: next_state = next_px ? S_CYCLE_1 : S_LOAD_X; // IF DONE DRAWING all squares, start over afte, ELSE draw the next square
            default:     next_state = S_LOAD_X;
        endcase
    end // state_table


    // Output logic aka all of our datapath control signals
    always @(*)
    begin: enable_signals
        // By default make all our signals 0
        ld_x = 1'b0;
        ld_y = 1'b0;
        writeEn = 1'b0;

        case (current_state)
            S_LOAD_X: begin
                ld_x = 1'b1;
                end
            S_LOAD_Y: begin
                ld_y = 1'b1;
                end
				
            S_CYCLE_1: begin
                writeEn = 1'b1;
                end
				S_CYCLE_2: begin
					 
					 // output offset values
					 if (x_offset < sz)
						x_offset = x_offset + 1'b1;
						next_px = 1'b1;
					else
						x_offset = 0;
						if(y_offset < sz)
							y_offset = y_offset + 1'b1;
							next_px = 1'b1;
						else
							// reset y
							y_offset = 0;
							// Go to Load x
							next_px = 1'b0;
					 
					 end
                
        // default:    // don't need default since we already made sure all of our outputs were assigned a value at the start of the always block
        endcase
    end // enable_signals


    // current_state registers
    always@(posedge clk)
    begin: state_FFs
        if(!resetn)
            current_state <= S_LOAD_X;
        else
            current_state <= next_state;
    end // state_FFS

endmodule




