//based on HDMI1.4a, the xilinx appote 460, and a couple of tricks from a code pasted online

module TMDSencoder(input [7:0] DATA, input [1:0] CTRL, input VDE, output reg [9:0] TMDSencDATA, input PIXCLK);

wire [3:0] N1 = DATA[0]+DATA[1]+DATA[2]+DATA[3]+DATA[4]+DATA[5]+DATA[6]+DATA[7]; 
//create sum of 1's in the input byte

wire [3:0] N1q = q_m[0]+q_m[1]+q_m[2]+q_m[3]+q_m[4]+q_m[5]+q_m[6]+q_m[7];
//create sum of 1's in the 2nd pipeline stage (not including the flag bit)

wire [3:0] balance = N1q - 4'b1000;
//we are going to use bit 3 as sign, this will be convenient later

wire q_m_8 = (N1>4'd4) || (N1==4'd4 && DATA[0]==1'b0); 
//are there greater than four 1's, or are there exactly four and also a zero at bit0? this is the first 'flag bit'

wire [8:0] q_m = { ~q_m_8, 									 //new flag bit
						  q_m[6:0] ^ DATA[7:1] ^ {7{q_m_8}}, //next seven bits of data cascaded XOR (possibly inverted by ^{7{q_m_8}} to get xnor)
																		 //hopefully this cascades without having to write out all the lines one after another!
						  DATA[0]									 //last but is just the data bit 0 unmodified.
					}; 

wire invertNessisary = (balance==0 || disparity==0) ? ~q_m[8] : (balance[3] == disparity[3]); //(bit three is the sign) 
//inversion bit is controlled by qm8 if theres no current or previous disparity
//otherwise we set it depending on the sign o te previous disparity versus current

wire [3:0] disparity_change = balance - ({q_m[8] ^ ~(balance[3] == disparity[3])} & ~(balance==0 || disparity==0));
//increment amount is the current words disparity +/- a correction, and not when matching the above case (there are essentially three cases)

wire [9:0] out = {invertNessisary, 						//another flag.. making 10 bits now
						q_m[8],									//we dont invert this one
						q_m[7:0] ^ {8{invertNessisary}}	//invert the remaining 8 bits if we need
						};


wire [9:0] CTRLCODE;
case (CTRL)
  2'b00 : CTRLCODE = 10'b1101010100; //fiex encoding of these 4 symbols (not valid elsewhere)
  2'b01 : CTRLCODE = 10'b0010101011; //used for non video data and for embedding VSYNC & HSyNC
  2'b10 : CTRLCODE = 10'b0101010100;
  2'b11 : CTRLCODE = 10'b1010101011;  
endcase

reg [3:0] disparity = 0;

always @(posedge PIXCLK) 
    begin
        disparity <= VDE ? (invertNessisary ? (disparity - disparity_change) : (disparity + disparity_change)) : 4'b0000; 
		  //new value must be positive if no inversion nessisary..
		  //update disparity reg with new value, or clear if we exit the video area.
    end

always @(posedge PIXCLK) 
	 begin
	     TMDSencDATA <= VDE ? out : CTRLCODE; 
		  //clock out the 10b data or a fixed code if we are outside the video area.
	 end


endmodule
