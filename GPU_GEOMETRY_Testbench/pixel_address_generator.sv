module pixel_address_generator (

    // inputs
    input logic        clk,              // System clock
    input logic        reset,            // Force reset
    
    input logic        draw_cmd_rdy,     // Pulsed HIGH when data on draw_cmd[15:0] is valid
    input logic[35:0]  draw_cmd,         // Bits [35:32] hold AUX function number 0-15:
    input logic        draw_busy,        // HIGH when pixel writer is busy

    // outputs
    output logic       pixel_cmd_rdy,
    output logic[39:0] pixel_cmd
);

parameter  bit  USE_ALTERA_IP       = 1 ;  // Selects if Altera's LPM_MULT should be used.

// pixel_cmd format:
// 3     3 3             2 2     2 2     2 1                                     0
// 9     6 5             8 7     4 3     0 9                                     0
// |     | |             | |     | |     | |                                     |
// 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
// |-CMD-| |----COLOUR---| |WIDTH| |-BIT-| |-----------MEMORY ADDRESS------------|
//
// Where CMD:
// bit 36 = COLOUR (HIGH for colour data included, LOW for none)
// bit 35 = WRITE bit (HIGH for WR, LOW for RD)
// bit 34 = TRANSPARENT bit (HIGH for transparent mask, LOW for none, ignored if bit 35 is LOW)
// bit 33 = READ/MODIFY/WRITE (ignored if bit 35 is LOW)
//
// WIDTH is bits per pixel (screen mode)
//
// BIT is the bit in the addressed word that is the target of the RD/WR operation
//
    

// 3     3 3             2 2               1     1 1     0 0             0
// 5     2 1             4 3               5     2 1     8 7             0
// |     | |             | |               |     | |     | |             |
// 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0
// |AUX01| |----COLOUR---| |-----Y COORDINATE----| |-----X COORDINATE----|
// |AUX02| |----COLOUR---| |-----Y COORDINATE----| |-----X COORDINATE----|
// |AUX03|                 |-----Y COORDINATE----| |-----X COORDINATE----|
// |AUX04|                 |-----Y COORDINATE----| |-----X COORDINATE----|
// ...
// |AUX06|                 |-----Y COORDINATE----| |-----X COORDINATE----|  READ
// |AUX07| |-ALPHA BLEND-| |-------------24-bit RGB COLOUR---------------|
// ...
// |AUX10| |-TRANSP MASK-| |RGB 24-bit MASK COLOUR OR 3 ADD TRANS COLOURS|
// |AUX11| |-TRANSP MASK-| |RGB 24-bit MASK COLOUR OR 3 ADD TRANS COLOURS|
// |AUX12| |BITPLANE MODE|                 |---DEST RASTER IMAGE WIDTH---|
// |AUX13| |BITPLANE MODE|                 |--SOURCE RASTER IMAGE WIDTH--|
// |AUX14|                 |-------DESTINATION BASE MEMORY ADDRESS-------|
// |AUX15|                 |----------SOURCE BASE MEMORY ADDRESS---------|
//

logic [2:0] LUT_bits_to_shift[0:15] = '{ 4,3,3,2,2,2,2,1,1,1,1,1,1,1,1,0 };  // shift bits/pixel-1  0=1 bit, 1=2bit, 3=4bit, 7=8bit, 15-16bit.
/*
localparam CMD_IN_NOP           = 0;
localparam CMD_IN_PXWRI         = 1;
localparam CMD_IN_PXWRI_M       = 2;
localparam CMD_IN_PXPASTE       = 3;
localparam CMD_IN_PXPASTE_M     = 4;

localparam CMD_IN_PXCOPY        = 6;
localparam CMD_IN_SETARGB       = 7;

localparam CMD_IN_RST_PXWRI_M   = 10;
localparam CMD_IN_RST_PXPASTE_M = 11;
localparam CMD_IN_DSTRWDTH      = 12;
localparam CMD_IN_SRCRWDTH      = 13;
localparam CMD_IN_DSTMADDR      = 14;
localparam CMD_IN_SRCMADDR      = 15;

// CMD_OUT:
localparam CMD_OUT_NOP           = 0;
localparam CMD_OUT_PXWRI         = 1;
localparam CMD_OUT_PXWRI_M       = 2;
localparam CMD_OUT_PXPASTE       = 3;
localparam CMD_OUT_PXPASTE_M     = 4;
localparam CMD_OUT_PXCOPY        = 6;
localparam CMD_OUT_SETARGB       = 7;
localparam CMD_OUT_RST_PXWRI_M   = 10;
localparam CMD_OUT_RST_PXPASTE_M = 11;
*/
//logic [3:0] CMD_IN_NOP           = 0;
logic [3:0] CMD_IN_PXWRI         = 1;
logic [3:0] CMD_IN_PXWRI_M       = 2;
logic [3:0] CMD_IN_PXPASTE       = 3;
logic [3:0] CMD_IN_PXPASTE_M     = 4;

logic [3:0] CMD_IN_PXCOPY        = 6;
logic [3:0] CMD_IN_SETARGB       = 7;

logic [3:0] CMD_IN_RST_PXWRI_M   = 10;
logic [3:0] CMD_IN_RST_PXPASTE_M = 11;
logic [3:0] CMD_IN_DSTRWDTH      = 12;
logic [3:0] CMD_IN_SRCRWDTH      = 13;
logic [3:0] CMD_IN_DSTMADDR      = 14;
logic [3:0] CMD_IN_SRCMADDR      = 15;

// CMD_OUT:
//logic [3:0] CMD_OUT_NOP           = 0;
//logic [3:0] CMD_OUT_PXWRI         = 1;
//logic [3:0] CMD_OUT_PXWRI_M       = 2;
//logic [3:0] CMD_OUT_PXPASTE       = 3;
//logic [3:0] CMD_OUT_PXPASTE_M     = 4;
//logic [3:0] CMD_OUT_PXCOPY        = 6;
//logic [3:0] CMD_OUT_SETARGB       = 7;
//logic [3:0] CMD_OUT_RST_PXWRI_M   = 10;
//logic [3:0] CMD_OUT_RST_PXPASTE_M = 11;

logic[27:0] dest_base_address_offset_int  ;
logic[27:0] srce_base_address_offset_int  ;
logic[23:0] dest_base_address_offset     = 0 ;
logic[23:0] srce_base_address_offset     = 0 ;
//logic[23:0] s2_dest_base_address_offset  = 0 ;
//logic[23:0] s2_srce_base_address_offset  = 0 ;
logic[3:0]  dest_target_bit              = 0 ;
logic[3:0]  srce_target_bit              = 0 ;
logic[3:0]  aux_cmd_in                   = 0 ;
logic[7:0]  bit_mode                     = 0 ;
logic[7:0]  s2_bit_mode                  = 0 ;
logic[11:0] x                            = 0 ;
logic[11:0] x_dl                         = 0 ;
logic[11:0] y                            = 0 ;

// internal registers
logic[3:0]  dest_bits_per_pixel = 4'b0  ; // how many bits make up one pixel (1-16) - screen mode
logic[3:0]  srce_bits_per_pixel = 4'b0  ; // how many bits make up one pixel (1-16) - screen mode
//
logic[15:0] dest_rast_width     = 16'b0 ; // number of bits in a horizontal raster line
logic[15:0] srce_rast_width     = 16'b0 ; // number of bits in a horizontal raster line
//
logic[23:0] dest_base_address   = 24'b0 ; // points to first byte in the graphics display memory
logic[23:0] srce_base_address   = 24'b0 ; // points to first byte in the graphics display memory

logic[19:0] dest_address   = 20'b0 ; // points to first byte in the graphics display memory
logic[19:0] srce_address   = 20'b0 ; // points to first byte in the graphics display memory

// Logic registers for STAGE CLOCK #2
logic       s2_draw_cmd_rdy        = 0 ;
logic[3:0]  s2_aux_cmd_in          = 0 ;
logic[35:0] s2_draw_cmd            = 0 ;

logic       pixel_cmd_reg          = 0 ;


// This generate code selects between using Altera LPM IP vs normal SystemVerilog function.

generate
if (USE_ALTERA_IP) begin
// Initiate Altera's megafunction 'lpm_mult' which will gives us a better FMAX,
// and if needed, it has a pipeline feature to increase FMAX even further.

	lpm_mult	lpm_mult_dest (
				.dataa  ( y                            ),
				.datab  ( dest_rast_width[15:0]        ),
				.clken  ( !draw_busy && draw_cmd_rdy   ),
				.clock  ( clk                          ),
				.result ( dest_base_address_offset_int ),
				.aclr   ( 1'b0                         ),
				.sum    ( 1'b0                         ));
	defparam
		lpm_mult_dest.lpm_hint = "MAXIMIZE_SPEED=9",
		lpm_mult_dest.lpm_pipeline = 1,
		lpm_mult_dest.lpm_representation = "UNSIGNED",
		lpm_mult_dest.lpm_type = "LPM_MULT",
		lpm_mult_dest.lpm_widtha = 12,
		lpm_mult_dest.lpm_widthb = 16,
		lpm_mult_dest.lpm_widthp = 28;

			lpm_mult	lpm_mult_srce (
				.dataa  ( y                            ),
				.datab  ( srce_rast_width[15:0]        ),
				.clken  ( !draw_busy && draw_cmd_rdy   ),
				.clock  ( clk                          ),
				.result ( srce_base_address_offset_int ),
				.aclr   ( 1'b0                         ),
				.sum    ( 1'b0                         ));
	defparam
		lpm_mult_srce.lpm_hint = "MAXIMIZE_SPEED=9",
		lpm_mult_srce.lpm_pipeline = 1,
		lpm_mult_srce.lpm_representation = "UNSIGNED",
		lpm_mult_srce.lpm_type = "LPM_MULT",
		lpm_mult_srce.lpm_widtha = 12,
		lpm_mult_srce.lpm_widthb = 16,
		lpm_mult_srce.lpm_widthp = 28;

end else begin
// (USE_ALTERA_IP) is disabled, use these 2 regular multiplies instead.

     always_ff @(posedge clk) if (!draw_busy && draw_cmd_rdy) begin
          dest_base_address_offset_int <= y * dest_rast_width[15:0];
          srce_base_address_offset_int <= y * srce_rast_width[15:0];
          end

end

endgenerate

always_comb begin

    aux_cmd_in[3:0] = draw_cmd[35:32] ;
    bit_mode[7:0]   = draw_cmd[31:24] ;   // number of bits per pixel - needs to be sourced from elsewhere (MAGGIE#?)
    y[11:0]         = draw_cmd[23:12] ;
    x[11:0]         = draw_cmd[11:0]  ;
    
    pixel_cmd_rdy = pixel_cmd_reg && !draw_busy;

    dest_base_address_offset[19:1] = dest_base_address_offset_int[18:0] + x_dl;
    dest_base_address_offset[0]    = 1'b0;
    srce_base_address_offset[19:1] = srce_base_address_offset_int[18:0] + x_dl;
    srce_base_address_offset[0]    = 1'b0;
	 
    dest_target_bit[3:0]           = 4'(dest_base_address_offset_int[3:0] + x_dl);
    srce_target_bit[3:0]           = 4'(srce_base_address_offset_int[3:0] + x_dl);

    dest_address = dest_base_address[19:0] + (dest_base_address_offset[19:0] >> LUT_bits_to_shift[dest_bits_per_pixel[3:0]]);
    srce_address = srce_base_address[19:0] + (srce_base_address_offset[19:0] >> LUT_bits_to_shift[srce_bits_per_pixel[3:0]]);
    
end // always_comb


always_ff @(posedge clk or posedge reset) begin

    if (reset) begin

        dest_bits_per_pixel <= 4'b0 ;
        srce_bits_per_pixel <= 4'b0 ;
        dest_rast_width     <= 16'b0;
        srce_rast_width     <= 16'b0;
        dest_base_address   <= 24'b0;
        srce_base_address   <= 24'b0;
        pixel_cmd[39:0]     <= 40'b0;
        
    end else begin
  
if (!draw_busy) begin
s2_bit_mode     <= bit_mode;
s2_draw_cmd_rdy <= draw_cmd_rdy;
s2_aux_cmd_in   <= aux_cmd_in;
s2_draw_cmd     <= draw_cmd;

        if ( draw_cmd_rdy ) begin

    x_dl <= x;
    //dest_base_address_offset_int <=  (y * dest_rast_width[15:0]) ; // This calculation will only be ready for the S2 - second stage clock cycle.
    //srce_base_address_offset_int <=  (y * srce_rast_width[15:0]) ; // This calculation will only be ready for the S2 - second stage clock cycle.

    //dest_base_address_offset <=  (y * dest_rast_width[15:0]  + x) << 1 ; // This calculation will only be ready for the S2 - second stage clock cycle.
    //srce_base_address_offset <=  (y * srce_rast_width[15:0]  + x) << 1 ; // This calculation will only be ready for the S2 - second stage clock cycle.
    //dest_target_bit[3:0]     <=  (y * dest_rast_width[15:0]  + x) ;
    //srce_target_bit[3:0]     <=  (y * srce_rast_width[15:0]  + x) ;


            case (aux_cmd_in) //  These functions will happen on the first stage clock cycle
                              // no output functions are to take place
                
                CMD_IN_DSTRWDTH : begin
                    dest_rast_width[15:0]    <= draw_cmd[15:0] ;    // set destination raster image width
                    dest_bits_per_pixel[3:0] <= bit_mode[3:0] ;     // set screen mode (bits per pixel)
                end
                
                CMD_IN_SRCRWDTH : begin
                    srce_rast_width[15:0]    <= draw_cmd[15:0] ;    // set source raster image width
                    srce_bits_per_pixel[3:0] <= bit_mode[3:0] ;     // set screen mode (bits per pixel)
                end
            
                CMD_IN_DSTMADDR : begin
                    dest_base_address[23:0]  <= draw_cmd[23:0] ;    // set destination base memory address
                end
                
                CMD_IN_SRCMADDR : begin
                    srce_base_address[23:0]  <= draw_cmd[23:0] ;    // set source base memory address (even addresses only?)
                end                
            endcase

        end // if ( draw_cmd_RDY_Ff ) 


        if ( s2_draw_cmd_rdy ) begin
            case (s2_aux_cmd_in) //  These functions will happen on the second stage clock cycle
        
                CMD_IN_PXWRI, CMD_IN_PXWRI_M, CMD_IN_PXPASTE, CMD_IN_PXPASTE_M : begin   // write pixel with colour command through pixel paste with mask command.
                    pixel_cmd[0]     <= 1'b0 ;                       // generate address for the pixel
                    pixel_cmd[19:1]  <= dest_address[19:1] ;         // generate address for the pixel
                    pixel_cmd[23:20] <= dest_target_bit[3:0] ;       // which bit to edit in the addressed byte
                    pixel_cmd[27:24] <= dest_bits_per_pixel[3:0] ;   // set bits per pixel for current screen mode
                    pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;          // include colour information
                    pixel_cmd[39:36] <= s2_aux_cmd_in ;         // COLOUR, WRITE, NO TRANSPARENCY, NO R/M/W
                    pixel_cmd_reg    <= 1'b1 ;
                end
               
                CMD_IN_PXCOPY : begin   // read pixel with x & y
                    pixel_cmd[0]     <= 1'b0 ;                       // generate address for the pixel
                    pixel_cmd[19:1]  <= srce_address[19:1] ;         // generate address for the pixel
                    pixel_cmd[23:20] <= srce_target_bit[3:0] ;       // which bit to read from the addressed byte
                    pixel_cmd[27:24] <= srce_bits_per_pixel[3:0] ;   // set bits per pixel for current screen mode
                    pixel_cmd[35:28] <= s2_draw_cmd[31:24] ;         // transparent color value used for read pixel collision counter
                    pixel_cmd[39:36] <= s2_aux_cmd_in ;        // NO COLOUR, READ, NO TRANS, NO R/M/W
                    pixel_cmd_reg    <= 1'b1 ;
                end

                CMD_IN_SETARGB       : begin
                    pixel_cmd[31:0]  <= s2_draw_cmd[31:0] ;    // pass through first 32-bits of input to output ( Alpha Blend and 24-bit RGB colour data)
                    pixel_cmd[39:36] <= s2_aux_cmd_in ;   // pass through command only
                    pixel_cmd_reg    <= 1'b1 ;
                end
                
                CMD_IN_RST_PXWRI_M   : begin
                    pixel_cmd[31:0]  <= s2_draw_cmd[31:0] ;          // pass through first 32-bits of input to output ( Alpha Blend and 24-bit RGB colour data)
                    pixel_cmd[39:36] <= s2_aux_cmd_in ;   // pass through command only
                    pixel_cmd_reg    <= 1'b1 ;
                end
                
                CMD_IN_RST_PXPASTE_M : begin
                    pixel_cmd[31:0]  <= s2_draw_cmd[31:0] ;           // pass through first 32-bits of input to output ( Alpha Blend and 24-bit RGB colour data)
                    pixel_cmd[39:36] <= s2_aux_cmd_in ;  // pass through command only
                    pixel_cmd_reg    <= 1'b1 ;
                end
                
                default : pixel_cmd_reg      <= 1'b0 ;              // NOP - reset pixel_cmd_reg for one-clock operation
                
            endcase

        end else pixel_cmd_reg      <= 1'b0 ; //if ( s2_draw_cmd_rdy )



  end // if !draw_busy
 end // if !reset

end // always_ff @ posedge clk or reset

endmodule
