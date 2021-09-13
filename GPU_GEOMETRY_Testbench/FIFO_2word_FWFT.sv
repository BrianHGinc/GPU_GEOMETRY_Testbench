// *****************************************************************
// *** FIFO_2word_FWFT.sv V1.0, August 15, 2020
// ***
// *** This 1 word FIFO with first word feed through (FWFT)
// *** This was designed to be backwards compatible with the
// *** FIFO_3word_0_latency.sv with the 'zero latency' disabled.
// *** written by Brian Guralnick.
// ***
// *** See the included 'FIFO_2word_FWFT.png' simulation for functionality.
// ***
// *** Using System Verilog code which only uses synchronous logic.
// *** Well commented for educational purposes.
// *****************************************************************

module FIFO_2word_FWFT #(
//*************************************************************************************************************************************
parameter  int bits = 8                // sets the width of the fifo
//*************************************************************************************************************************************
)(
input  logic clk,                 // CLK input
input  logic reset,               // reset FIFO

input  logic shift_in,            // load a word into the FIFO.
input  logic shift_out,           // shift data out of the FIFO.
input  logic [bits-1:0] data_in,  // data word input.

output logic fifo_not_empty,      // High when data_out has valid data.
output logic fifo_full,           // High when the FIFO's 1 word elastic memory is
                                  // filled and there isn't a 'shift_out'

output logic [bits-1:0] data_out  // FIFO data word output
);


logic  [bits-1:0]  source            = 0 ; // The result from a mux which selects between the data_in and memory register.
logic              source_ready      = 0 ; // This goes high when there is a shift_in, or when the memory_filled is high.
logic  [bits-1:0]  memory            = 0 ;
logic              memory_filled     = 0 ;
//logic              source_sel_memory = 0 ;
logic              data_out_ready    = 0 ;

always_comb begin
source            = memory_filled ? memory : data_in  ; // A Mux which selects the source of the next value for the 'data_out' register.
source_ready      = memory_filled ? 1'b1   : shift_in ; // A Mux which selects the source of the next value for the 'data_out_ready' register.

fifo_not_empty    = data_out_ready                    ; // the data_out register has data ready to be received.
fifo_full         = memory_filled && !shift_out       ; // if the memory is filled and currently there is no shift_out
                                                        // in progress, report that the FIFO is full.
end // always_comb

always_ff @(posedge clk  or posedge reset ) begin
if (reset) begin
    memory           <= 0;             // clear the FIFO memory register
    memory_filled    <= 0;             // clear the FIFO memory_filled flag
    data_out         <= (bits)'(0);    // clear the data_out register, when simulating, show that the data out hs no valid data
    data_out_ready   <= 0;             // clear the data_out ready register
    end else begin

             if (shift_out || !data_out_ready) begin          // Shift out when told to, or if the data_out_ready is not ready,
                                                              // keep on feeding this register until the first valid word comes in (FWFT)
                                               data_out       <= source_ready ? source : (bits)'(0); // If there are words left coming in from the source, show that theer is no valid data
                                               data_out_ready <= source_ready;
                                               end

             if (shift_in && data_out_ready)   begin
                                               memory         <= data_in;
                                               memory_filled  <= source_ready && (!shift_out || memory_filled);

                     end else if (shift_out)   memory_filled  <= 0;            // A shift_out without a (shift_in && data_out_ready)
                                                                               // empties the memory_filled flag.

  end // !reset
end // always_ff
endmodule
