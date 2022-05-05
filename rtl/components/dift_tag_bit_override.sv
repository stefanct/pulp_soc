// Jakob Sailer
// FH Technikum Wien / UAS Technikum Wien
// created: 2021-04-21
// ESP: DIFT extension
//
// Address-range based Tag Bit Read Override Module
//   may be used for HW Tag Initialization

module dift_tag_bit_override
    import pkg_soc_interconnect::addr_map_rule_t;
    #(
      parameter int unsigned NR_ADDR_MAP_RULES
    )
    (
      input  logic  clk_i,
      input  logic  rst_ni,

      XBAR_TCDM_BUS_36.Slave                       slave,
      XBAR_TCDM_BUS_36.Master                      master,
      input addr_map_rule_t[NR_ADDR_MAP_RULES-1:0] addr_map_rules
    );
    // const parameters
    localparam int unsigned TAG_BITS_NUM   = 4;
    localparam int unsigned SEL_PATHS      = 3;
    localparam int unsigned ADDR_BUF_DEPTH = 8;

    // internal signals
    ////logic[SEL_PATHS-1:0] port_sel;
    logic[1:0] port_sel;
    logic[TAG_BITS_NUM-1:0] tag_bits[SEL_PATHS];

    int unsigned pos_store;
    int unsigned pos_read;
    logic[31:0] buffer_value[ADDR_BUF_DEPTH];
    logic[31:0] addr_int;


    // assignments: master <= slave (everything original)
    assign master.req = slave.req;
    assign master.add = slave.add;
    assign master.wen = slave.wen;
    assign master.be  = slave.be;
    assign master.wdata = slave.wdata;
    // assignments: slave <= master (with either original tag bits, or forced to '0 or '1)
    assign slave.gnt     = master.gnt;
    assign slave.r_opc   = master.r_opc;
    assign slave.r_valid = master.r_valid;
    assign slave.r_rdata[31: 0] = master.r_rdata[31: 0];
    assign slave.r_rdata[35:32] = tag_bits[port_sel];

    // different selection paths for the tag bits
    assign tag_bits[0] = master.r_rdata[35:32]; // NO override: uses original tag bits
    assign tag_bits[1] = '1;  // TAG override: sets all tag bits to tainted
    assign tag_bits[2] = '0;  // UNTAG override: sets all tag bits to untainted

    // Address Decoder module generates the select signal for the demux. If there is no match in the input rules, the
    // select port 0 (i.e. NO override) by default
    addr_decode #(
                  .NoIndices(SEL_PATHS),
                  .NoRules(NR_ADDR_MAP_RULES),
                  .addr_t(logic[31:0]),
                  .rule_t(pkg_soc_interconnect::addr_map_rule_t)
                  ) i_addr_decode (
                                   .addr_i(addr_int),
                                   .addr_map_i(addr_map_rules),
                                   .idx_o(port_sel),
                                   .dec_valid_o(),
                                   .dec_error_o(),
                                   .en_default_idx_i(1'b1),
                                   .default_idx_i('0) // if no address space matches: route to the first selection path (NO override)
                                   );


    // FIFO ring buffer (queue) for up to 8 addresses (can queue max. 8 transactions)
    //   if rvalid == 1 -> pop
    //   if req==1 and gnt==1 -> push
    always_ff @(posedge clk_i , negedge rst_ni)
    begin : FIFO_RING_BUF
      if (rst_ni == 1'b0) begin
        pos_store  = 0;
        pos_read   = 0;
        buffer_value[0] = '0;
        buffer_value[1] = '0;
        buffer_value[2] = '0;
        buffer_value[3] = '0;
        buffer_value[4] = '0;
        buffer_value[5] = '0;
        buffer_value[6] = '0;
        buffer_value[7] = '0;
      end
      else begin
        if (slave.req == 1'b1 && master.gnt == 1'b1) begin
          buffer_value[pos_store] = slave.add;
          pos_store = (pos_store+1)%ADDR_BUF_DEPTH;
        end

        if (master.r_valid == 1'b1) begin
          pos_read = (pos_read+1)%ADDR_BUF_DEPTH;
        end
      end
    end

    assign addr_int = buffer_value[pos_read];

endmodule
