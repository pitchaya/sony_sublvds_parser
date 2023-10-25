
`timescale 1ps/1ps

module rx_sipo_1to8 # (
      parameter  DIFF_TERM    = "TRUE", // Enable internal LVDS termination
      parameter  RX_SWAP_MASK = 1'b0,     // Invert input line
      parameter real    REF_FREQ     = 300.0      // Reference clock frequency for idelay control
   )
   (
      input        datain_p,      // Data input LVDS P-side
      input        datain_n,      // Data input LVDS N-side
      //
      input        rx_clk,    // RX clock running at 1/2 data rate
      input        rx_clkdiv4,    // RX clock running at 1/8 data rate
      input        rx_reset,      // RX reset
      input  [8:0] rx_cntval,     // RX input delay count value
      input        rx_dlyload,    // RX input delay load
      input        rx_ready,      // RX input delay ready
      //
      input        px_clk,        // Pixel clock running at 1/7 transmit rate
      output reg [7:0] px_data    // Pixel 7-bit pixel data output
   );

wire        datain_i;
wire        datain_d;

wire [7:0]  rx_wr_curr;
wire [7:0]  rx_wr_curr_x;
//reg  [7:0]  rx_wr_data;


//wire [7:0]  px_rd_curr;
//reg  [7:1]  px_rd_last;

//
// Data Input LVDS Buffer
//

IBUFDS # (
      .DIFF_TERM     (DIFF_TERM)
   )
   iob_clk_in (
      .I                (datain_p),
      .IB               (datain_n),
      .O                (datain_i)
   );

//
// Data Input IDELAY
//
IDELAYE3 # (
      .DELAY_SRC        ("IDATAIN"),
      .CASCADE          ("NONE"),
      .DELAY_TYPE       ("VAR_LOAD"),
      .DELAY_VALUE      (0),
      .REFCLK_FREQUENCY (REF_FREQ),
      .DELAY_FORMAT     ("COUNT"),
      .UPDATE_MODE      ("ASYNC"),
      .SIM_DEVICE       ("ULTRASCALE_PLUS")
   )
   idelay_cm (
      .IDATAIN          (datain_i),
      .DATAOUT          (datain_d),
      .CLK              (rx_clkdiv4),
      .CE               (1'b0),
      .RST              (1'b0),
      .INC              (1'b0),
      .DATAIN           (1'b0),
      .LOAD             (rx_dlyload),
      .CNTVALUEIN       (rx_cntval),
      .EN_VTC           (rx_ready),
      .CASC_IN          (1'b0),
      .CASC_RETURN      (1'b0),
      .CASC_OUT         (),
      .CNTVALUEOUT      ());

//
// Date ISERDES
//
//ISERDESE3 #(
//       .DATA_WIDTH      (8),
//       .FIFO_ENABLE     ("FALSE"),
//       .FIFO_SYNC_MODE  ("FALSE"),
//       .SIM_DEVICE       ("ULTRASCALE_PLUS")
//   )
//   iserdes_m (
//       .D               (datain_d),
//       .RST             (rx_reset),
//       .CLK             ( rx_clk),
//       .CLK_B           (~rx_clk),
//       .CLKDIV          ( rx_clkdiv4),
//       .Q               (rx_wr_curr), 
//       .FIFO_RD_CLK     (1'b0),
//       .FIFO_RD_EN      (1'b0),
//       .FIFO_EMPTY      (),
//       .INTERNAL_DIVCLK ()
//   );
ISERDESE3 #(
       .DATA_WIDTH      (8),
       .IS_CLK_B_INVERTED(1'b1),
       .FIFO_ENABLE     ("FALSE"),
       .FIFO_SYNC_MODE  ("FALSE"),
       .SIM_DEVICE       ("ULTRASCALE_PLUS")
   )
   iserdes_m (
       .D               (datain_d),
       .RST             (rx_reset),
       .CLK             ( rx_clk),
       .CLK_B           ( rx_clk),
       .CLKDIV          ( rx_clkdiv4),
       .Q               (rx_wr_curr), 
       .FIFO_RD_CLK     (1'b0),
       .FIFO_RD_EN      (1'b0),
       .FIFO_EMPTY      (),
       .INTERNAL_DIVCLK ()
   );
   
assign rx_wr_curr_x = ~rx_wr_curr;   
always @ (posedge px_clk)
begin
//    px_data<=rx_wr_curr;
    px_data[0] <=rx_wr_curr_x[7] ^ RX_SWAP_MASK;
    px_data[1] <=rx_wr_curr_x[6] ^ RX_SWAP_MASK;
    px_data[2] <=rx_wr_curr_x[5] ^ RX_SWAP_MASK;
    px_data[3] <=rx_wr_curr_x[4] ^ RX_SWAP_MASK;
    px_data[4] <=rx_wr_curr_x[3] ^ RX_SWAP_MASK;
    px_data[5] <=rx_wr_curr_x[2] ^ RX_SWAP_MASK;
    px_data[6] <=rx_wr_curr_x[1] ^ RX_SWAP_MASK;
    px_data[7] <=rx_wr_curr_x[0] ^ RX_SWAP_MASK;
end

endmodule
  
