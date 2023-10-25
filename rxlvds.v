//////////////////////////////////////////////////////////////////////////////

`timescale 1ps/1ps

module rx_channel_1to8 # (
      parameter integer LINES        = 8,          // Number of data lines 
      parameter real    CLKIN_PERIOD = 6.600,      // Clock period (ns) of input clock on clkin_p
      parameter real    REF_FREQ     = 300.0,      // Reference clock frequency for idelay control
      parameter         DIFF_TERM    = "TRUE",    // Enable internal differential termination
      parameter         USE_PLL      = "FALSE",    // Enable PLL use rather than MMCM use
      parameter         DATA_FORMAT  = "PER_CLOCK",// Mapping input lines to output bus
      parameter         RX_SWAP_MASK = 16'b0,       // Allows P/N inputs to be invered to ease PCB routing


      // Width of S_AXI data bus
      parameter integer C_S_AXI_DATA_WIDTH	= 32,
      // Width of S_AXI address bus
      parameter integer C_S_AXI_ADDR_WIDTH	= 8

   )
   (
      input  wire              clk300_g,
      input  wire              clkin_p,              // Clock input LVDS P-side
      input  wire              clkin_n,              // Clock input LVDS N-side
      input  wire [LINES-1:0]   datain_p,             // Data input LVDS P-side
      input  wire [LINES-1:0]   datain_n,             // Data input LVDS N-side
      input  wire              reset,                // Asynchronous interface reset
      output wire              px_clk,               // Pixel clock output
      output wire [LINES*12-1:0] px_tdata,              // Pixel data bus output
      output wire                px_tvalid,              // Pixel data ready
      input  wire                px_tready,
      output wire                px_tlast,
      output wire [0:0]          px_tuser,
      output wire [47+8:0]        debug,
      input  wire XHS,
      output reg XHS_reg,
      input  wire XVS,
      output reg XVS_reg,
      
	// User ports ends
		// Do not modify the ports beyond this line

		// Global Clock Signal
		input wire  S_AXI_ACLK,
		// Global Reset Signal. This Signal is Active LOW
		input wire  S_AXI_ARESETN,
		// Write address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_AWADDR,
		// Write channel Protection type. This signal indicates the
    		// privilege and security level of the transaction, and whether
    		// the transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_AWPROT,
		// Write address valid. This signal indicates that the master signaling
    		// valid write address and control information.
		input wire  S_AXI_AWVALID,
		// Write address ready. This signal indicates that the slave is ready
    		// to accept an address and associated control signals.
		output wire  S_AXI_AWREADY,
		// Write data (issued by master, acceped by Slave) 
		input wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_WDATA,
		// Write strobes. This signal indicates which byte lanes hold
    		// valid data. There is one write strobe bit for each eight
    		// bits of the write data bus.    
		input wire [(C_S_AXI_DATA_WIDTH/8)-1 : 0] S_AXI_WSTRB,
		// Write valid. This signal indicates that valid write
    		// data and strobes are available.
		input wire  S_AXI_WVALID,
		// Write ready. This signal indicates that the slave
    		// can accept the write data.
		output wire  S_AXI_WREADY,
		// Write response. This signal indicates the status
    		// of the write transaction.
		output wire [1 : 0] S_AXI_BRESP,
		// Write response valid. This signal indicates that the channel
    		// is signaling a valid write response.
		output wire  S_AXI_BVALID,
		// Response ready. This signal indicates that the master
    		// can accept a write response.
		input wire  S_AXI_BREADY,
		// Read address (issued by master, acceped by Slave)
		input wire [C_S_AXI_ADDR_WIDTH-1 : 0] S_AXI_ARADDR,
		// Protection type. This signal indicates the privilege
    		// and security level of the transaction, and whether the
    		// transaction is a data access or an instruction access.
		input wire [2 : 0] S_AXI_ARPROT,
		// Read address valid. This signal indicates that the channel
    		// is signaling valid read address and control information.
		input wire  S_AXI_ARVALID,
		// Read address ready. This signal indicates that the slave is
    		// ready to accept an address and associated control signals.
		output wire  S_AXI_ARREADY,
		// Read data (issued by slave)
		output wire [C_S_AXI_DATA_WIDTH-1 : 0] S_AXI_RDATA,
		// Read response. This signal indicates the status of the
    		// read transfer.
		output wire [1 : 0] S_AXI_RRESP,
		// Read valid. This signal indicates that the channel is
    		// signaling the required read data.
		output wire  S_AXI_RVALID,
		// Read ready. This signal indicates that the master can
    		// accept the read data and response information.
		input wire  S_AXI_RREADY            
   );

wire              clk300_g;

wire              ref_clk_p;
wire              ref_clk_n;

wire               rx_clk;
wire               rx_clkdiv4;
wire               rx_reset;
wire         [LINES*9-1:0] rx_cntval;
reg         [LINES*9-1:0] rx_cntval_reg;
reg               rx_dlyload;
wire               rx_ready;

wire [LINES*8-1:0] px_raw;


genvar             i;
genvar             j;

//wire       clkin_p_i;
//wire       clkin_n_i;
//wire       clkin_p_d;
//wire       clkin_n_d;
wire       rx_idelay_rdy;


	// AXI4LITE signals
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_awaddr;
	reg  	axi_awready;
	reg  	axi_wready;
	reg [1 : 0] 	axi_bresp;
	reg  	axi_bvalid;
	reg [C_S_AXI_ADDR_WIDTH-1 : 0] 	axi_araddr;
	reg  	axi_arready;
	reg [C_S_AXI_DATA_WIDTH-1 : 0] 	axi_rdata;
	reg [1 : 0] 	axi_rresp;
	reg  	axi_rvalid;


// This is input step 
    wire  [4:0] Input_DIR;
    wire  [4:0] Input_STEP;

	// Example-specific design signals
	// local parameter for addressing 32 bit / 64 bit C_S_AXI_DATA_WIDTH
	// ADDR_LSB is used for addressing 32/64 bit registers/memories
	// ADDR_LSB = 2 for 32 bits (n downto 2)
	// ADDR_LSB = 3 for 64 bits (n downto 3)
	localparam integer ADDR_LSB = (C_S_AXI_DATA_WIDTH/32) + 1;
	localparam integer OPT_MEM_ADDR_BITS = 5;
	//----------------------------------------------
	//-- Signals for user logic register space example
	//------------------------------------------------
	//-- Number of Slave Registers 8
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg0;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg1;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg2;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg3;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg4;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg5;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg6;
	reg [C_S_AXI_DATA_WIDTH-1:0]	slv_reg7;

	wire	 slv_reg_rden;
	wire	 slv_reg_wren;
	reg [C_S_AXI_DATA_WIDTH-1:0]	 reg_data_out;
	integer	 byte_index;
	reg	 aw_en;

	// I/O Connections assignments

	assign S_AXI_AWREADY	= axi_awready;
	assign S_AXI_WREADY	= axi_wready;
	assign S_AXI_BRESP	= axi_bresp;
	assign S_AXI_BVALID	= axi_bvalid;
	assign S_AXI_ARREADY	= axi_arready;
	assign S_AXI_RDATA	= axi_rdata;
	assign S_AXI_RRESP	= axi_rresp;
	assign S_AXI_RVALID	= axi_rvalid;
	// Implement axi_awready generation
	// axi_awready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_awready is
	// de-asserted when reset is low.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awready <= 1'b0;
	      aw_en <= 1'b1;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // slave is ready to accept write address when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_awready <= 1'b1;
	          aw_en <= 1'b0;
	        end
	        else if (S_AXI_BREADY && axi_bvalid)
	            begin
	              aw_en <= 1'b1;
	              axi_awready <= 1'b0;
	            end
	      else           
	        begin
	          axi_awready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_awaddr latching
	// This process is used to latch the address when both 
	// S_AXI_AWVALID and S_AXI_WVALID are valid. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_awaddr <= 0;
	    end 
	  else
	    begin    
	      if (~axi_awready && S_AXI_AWVALID && S_AXI_WVALID && aw_en)
	        begin
	          // Write Address latching 
	          axi_awaddr <= S_AXI_AWADDR;
	        end
	    end 
	end       

	// Implement axi_wready generation
	// axi_wready is asserted for one S_AXI_ACLK clock cycle when both
	// S_AXI_AWVALID and S_AXI_WVALID are asserted. axi_wready is 
	// de-asserted when reset is low. 

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_wready <= 1'b0;
	    end 
	  else
	    begin    
	      if (~axi_wready && S_AXI_WVALID && S_AXI_AWVALID && aw_en )
	        begin
	          // slave is ready to accept write data when 
	          // there is a valid write address and write data
	          // on the write address and data bus. This design 
	          // expects no outstanding transactions. 
	          axi_wready <= 1'b1;
	        end
	      else
	        begin
	          axi_wready <= 1'b0;
	        end
	    end 
	end       


	// Implement memory mapped register select and write logic generation
	// The write data is accepted and written to memory mapped registers when
	// axi_awready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted. Write strobes are used to
	// select byte enables of slave registers while writing.
	// These registers are cleared when reset (active low) is applied.
	// Slave register write enable is asserted when valid address and data are available
	// and the slave is ready to accept the write address and write data.
	assign slv_reg_wren = axi_wready && S_AXI_WVALID && axi_awready && S_AXI_AWVALID;

//    reg [7:0] counter = 0;
     reg [3:0] loadval = 0;
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      slv_reg0 <= 0;
	      slv_reg1 <= 0;
	      slv_reg2 <= 0;
	      slv_reg3 <= 0;
	      slv_reg4 <= 0;
	      slv_reg5 <= 0;
	      slv_reg6 <= 0;
	      slv_reg7 <= 0;
	    end 
	  else begin
	    if (slv_reg_wren)
	      begin
	        loadval<=10;
	        case ( axi_awaddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	          5'h0:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 0
	                slv_reg0[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h1:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 1
	                slv_reg1[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h2:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 2
	                slv_reg2[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h3:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 3
	                slv_reg3[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h4:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 4
	                slv_reg4[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h5:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 5
	                slv_reg5[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h6:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 6
	                slv_reg6[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end  
	          5'h7:
	            for ( byte_index = 0; byte_index <= (C_S_AXI_DATA_WIDTH/8)-1; byte_index = byte_index+1 )
	              if ( S_AXI_WSTRB[byte_index] == 1 ) begin
	                // Respective byte enables are asserted as per write strobes 
	                // Slave register 7
	                slv_reg7[(byte_index*8) +: 8] <= S_AXI_WDATA[(byte_index*8) +: 8];
	              end                	              
	          default : begin
	                      slv_reg0 <= slv_reg0;                          
	                      slv_reg1 <= slv_reg1;
	                      slv_reg2 <= slv_reg2;
	                      slv_reg3 <= slv_reg3;
	                      slv_reg4 <= slv_reg4;
	                      slv_reg5 <= slv_reg5;
	                      slv_reg6 <= slv_reg6;
	                      slv_reg7 <= slv_reg7;

//ALLINPUTs
	                    end
	        endcase
	      end else
	     begin
	        if (loadval >0)
	           loadval <= loadval - 1;
	        else
                loadval<=0;
              // Let's have only 4 for now,
//              if(count_enable[4]) begin if(count_direction[4]) slv_reg8<=slv_reg8+1; else slv_reg28<=slv_reg8-1; end            
            
	     end
	     

	     
	  end
	end    

//    wire  [4:0] Input_DIR;
//    wire  [4:0] Input_STEP;
	

	// Implement write response logic generation
	// The write response and response valid signals are asserted by the slave 
	// when axi_wready, S_AXI_WVALID, axi_wready and S_AXI_WVALID are asserted.  
	// This marks the acceptance of address and indicates the status of 
	// write transaction.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_bvalid  <= 0;
	      axi_bresp   <= 2'b0;
	    end 
	  else
	    begin    
	      if (axi_awready && S_AXI_AWVALID && ~axi_bvalid && axi_wready && S_AXI_WVALID)
	        begin
	          // indicates a valid write response is available
	          axi_bvalid <= 1'b1;
	          axi_bresp  <= 2'b0; // 'OKAY' response 
	        end                   // work error responses in future
	      else
	        begin
	          if (S_AXI_BREADY && axi_bvalid) 
	            //check if bready is asserted while bvalid is high) 
	            //(there is a possibility that bready is always asserted high)   
	            begin
	              axi_bvalid <= 1'b0; 
	            end  
	        end
	    end
	end   

	// Implement axi_arready generation
	// axi_arready is asserted for one S_AXI_ACLK clock cycle when
	// S_AXI_ARVALID is asserted. axi_awready is 
	// de-asserted when reset (active low) is asserted. 
	// The read address is also latched when S_AXI_ARVALID is 
	// asserted. axi_araddr is reset to zero on reset assertion.

	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_arready <= 1'b0;
	      axi_araddr  <= 32'b0;
	    end 
	  else
	    begin    
	      if (~axi_arready && S_AXI_ARVALID)
	        begin
	          // indicates that the slave has acceped the valid read address
	          axi_arready <= 1'b1;
	          // Read address latching
	          axi_araddr  <= S_AXI_ARADDR;
	        end
	      else
	        begin
	          axi_arready <= 1'b0;
	        end
	    end 
	end       

	// Implement axi_arvalid generation
	// axi_rvalid is asserted for one S_AXI_ACLK clock cycle when both 
	// S_AXI_ARVALID and axi_arready are asserted. The slave registers 
	// data are available on the axi_rdata bus at this instance. The 
	// assertion of axi_rvalid marks the validity of read data on the 
	// bus and axi_rresp indicates the status of read transaction.axi_rvalid 
	// is deasserted on reset (active low). axi_rresp and axi_rdata are 
	// cleared to zero on reset (active low).  
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rvalid <= 0;
	      axi_rresp  <= 0;
	    end 
	  else
	    begin    
	      if (axi_arready && S_AXI_ARVALID && ~axi_rvalid)
	        begin
	          // Valid read data is available at the read data bus
	          axi_rvalid <= 1'b1;
	          axi_rresp  <= 2'b0; // 'OKAY' response
	        end   
	      else if (axi_rvalid && S_AXI_RREADY)
	        begin
	          // Read data is accepted by the master
	          axi_rvalid <= 1'b0;
	        end                
	    end
	end    

	// Implement memory mapped register select and read logic generation
	// Slave register read enable is asserted when valid address is available
	// and the slave is ready to accept the read address.
	assign slv_reg_rden = axi_arready & S_AXI_ARVALID & ~axi_rvalid;
	always @(*)
	begin
	      // Address decoding for reading registers
//	      reg_data_out <= spi_dac_readout;
	      case ( axi_araddr[ADDR_LSB+OPT_MEM_ADDR_BITS:ADDR_LSB] )
	        5'h0   : reg_data_out <= slv_reg0;
	        5'h1   : reg_data_out <= slv_reg1;
	        5'h2   : reg_data_out <= slv_reg2;
	        5'h3   : reg_data_out <= slv_reg3;
	        5'h4   : reg_data_out <= slv_reg4;
	        5'h5   : reg_data_out <= slv_reg5;
	        5'h6   : reg_data_out <= slv_reg6;
	        5'h7   : reg_data_out <= slv_reg7;
	        default : reg_data_out <= 0;
	      endcase
	end

	// Output register or memory read data
	always @( posedge S_AXI_ACLK )
	begin
	  if ( S_AXI_ARESETN == 1'b0 )
	    begin
	      axi_rdata  <= 0;
	    end 
	  else
	    begin    
	      // When there is a valid read address (S_AXI_ARVALID) with 
	      // acceptance of read address by the slave (axi_arready), 
	      // output the read dada 
	      if (slv_reg_rden)
	        begin
	          axi_rdata <= reg_data_out;     // register read data
	        end   
	    end
	end    

IDELAYCTRL #( // Instantiate input delay control block
      .SIM_DEVICE ("ULTRASCALE"))
   icontrol (
      .REFCLK (clk300_g),
      .RST    (reset),
      .RDY    (rx_idelay_rdy)
   );


//IBUFGDS
IBUFGDS # (
      .DIFF_TERM        (DIFF_TERM)
   )
   iob_clk_in (
      .I                (clkin_p),
      .IB               (clkin_n),
      .O                (clkin_p_i)
//      .OB               (clkin_n_i)
   );
   
//wire px_pllmmcm;
//wire cmt_locked;
//wire rx_pll;
//PLLE3_BASE # (
//     .CLKIN_PERIOD       (CLKIN_PERIOD),
//     .CLKFBOUT_MULT      (4),
//     .CLKFBOUT_PHASE     (0.0),
//     .CLKOUT0_DIVIDE     (4),
//     .CLKOUT0_DUTY_CYCLE (0.5),
//     .REF_JITTER         (0.100),
//     .DIVCLK_DIVIDE      (1)
//  )
//  rx_plle2_adv_inst (
//      .CLKFBOUT       (px_pllmmcm),
//      .CLKOUT0        (rx_pll),
//      .CLKOUT0B       (),
//      .CLKOUT1        (),
//      .CLKOUT1B       (),
//      .CLKOUTPHY      (),
//      .LOCKED         (cmt_locked),
//      .CLKFBIN        (px_pllmmcm),
//      .CLKIN          (clkin_p_i),
//      .CLKOUTPHYEN    (1'b0),
//      .PWRDWN         (1'b0),
//      .RST            (reset)
//  );
//assign rx_clk = clkin_p_i;
BUFG  bg_rx (.I(clkin_p_i), .O(rx_clk)) ;
BUFGCE_DIV  # (
       .BUFGCE_DIVIDE(4)
     )
     bg_rxdiv8 (
       .I(clkin_p_i),
       .CLR(!1),
       .CE(1'b1),
       .O(rx_clkdiv4)
      );
      
      
assign rx_cntval = {  slv_reg3[8:0], slv_reg2[8:0], slv_reg1[8:0], slv_reg0[8:0]};
assign px_clk = rx_clkdiv4;

always @(posedge rx_clkdiv4) begin
    rx_dlyload  <= (loadval>0);
    rx_cntval_reg <= rx_cntval;
end;


reg[ 7:0] cnt = 0;
always @(posedge px_clk)
    if (cnt[5] == 0)
        cnt <= cnt + 1;
   
always @(posedge px_clk) begin
    XHS_reg <= XHS;   
    XVS_reg <= XVS;
end
   

assign rx_reset = !cnt[5];
assign rx_ready = 1;
// //
// // Data Input 1:8 Deserialization
// //
wire [LINES-1:0] ready;
wire [2*LINES-1:0] linetypes;
wire [LINES-1:0] last;

wire [12*LINES-1:0] px_data;
wire [47+8:0]debug;

wire word_reset = ~XHS; //reset_i;
generate
   for (i = 0 ; i < LINES ; i = i+1) begin : rxd
      rx_sipo_1to8 # (
            .DIFF_TERM    (DIFF_TERM),         // Enable internal differential termination
            .RX_SWAP_MASK (RX_SWAP_MASK[i]),    // Invert data line
            .REF_FREQ     (REF_FREQ)
         )
         sipo
         (
            .datain_p     (datain_p[i]),       // Input from LVDS data pins
            .datain_n     (datain_n[i]),       // Input from LVDS data pins
            //
            .rx_clk       (rx_clk),        // RX clock DDR rate
            .rx_clkdiv4   (rx_clkdiv4),        // RX clock QDDR rate
      //      .idly_clk     (S_AXI_ACLK),
            .rx_reset     (rx_reset),          // RX reset
            .rx_ready     (rx_ready),          // RX ready
            .rx_cntval    (rx_cntval_reg[((i+1)*9-1):(i*9)]),         // RX input delay count value
            .rx_dlyload   (rx_dlyload),        // RX input delay load
            //
            .px_clk       (px_clk),            // Pixel clock
            // .px_rd_addr   (px_rd_addr),        // Pixel read address
            // .px_rd_seq    (px_rd_seq),         // Pixel read sequence
//            .px_data      (px_raw[(i+1)*8-1 -:8]) // Pixel data output
            .px_data      (px_raw[i*8 +: 8]) // Pixel data output
         );

// 

//          if (i == 0) begin
//          word_aligner w(
//					    .clk_i(px_clk),
//						.reset_i(word_reset),
//						//.word_i(px_raw[(i+1)*8-1 -:8]),
//						//.word_o(px_data[(i+1)*8-1 -:8]),
//						.word_i(px_raw[i*8 +: 8]),
//						.word_o(px_data[i*12 +: 12]),    						
//						.word_valid_o(ready[i]),
//                        .line_type(linetypes[i*2+:2]),   // 1 8 bits, 2 10bits, 3- 12 bits
//                        .debug(debug),
//                        .last(last[i])
//						);
//    		end else begin
//          word_aligner w(
//					    .clk_i(px_clk),
//						.reset_i(word_reset),
//						//.word_i(px_raw[(i+1)*8-1 -:8]),
//						//.word_o(px_data[(i+1)*8-1 -:8]),
//						.word_i(px_raw[i*8 +: 8]),
//						.word_o(px_data[i*12 +: 12]),    						
//						.word_valid_o(ready[i]),
//                        .line_type(linetypes[i*2+:2]),   // 1 8 bits, 2 10bits, 3- 12 bits
//                        .last(last[i])
//						);
//    		end
          word_aligner w(
					    .clk_i(px_clk),
						.reset_i(word_reset),
						//.word_i(px_raw[(i+1)*8-1 -:8]),
						//.word_o(px_data[(i+1)*8-1 -:8]),
						.word_i(px_raw[i*8 +: 8]),
						.word_o(px_data[i*12 +: 12]),    						
						.word_valid_o(ready[i]),
                        .line_type(linetypes[i*2+:2]),   // 1 8 bits, 2 10bits, 3- 12 bits
                        .debug(debug[i*8 +: 8]),
                        .last(last[i])
						);
   end
endgenerate
assign debug[32] = ready[0];
assign debug[33] = ready[1];
assign debug[34] = ready[2];
assign debug[35] = ready[3];

wire fsync;
reg newframe;
always @(posedge px_clk)
begin
    if (rx_reset) 
//        fsync <= 0;
        newframe <=0;
    else
    begin
         if (newframe & ready[0]) begin
            newframe <= 0;
        end else
        if (XVS_reg == 0) begin
            newframe<=1;
        end 

    
    end
end

assign fsync = newframe & ready[0];

// For Axisream

assign px_tlast =  last[0];
assign px_tuser[0] = fsync;
assign px_tdata = px_data;
assign px_tvalid = ready[0] | last[0];

endmodule

