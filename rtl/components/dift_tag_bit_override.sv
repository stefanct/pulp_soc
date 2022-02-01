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
      XBAR_TCDM_BUS_36.Slave                       slave,
      XBAR_TCDM_BUS_36.Master                      master,
      input addr_map_rule_t[NR_ADDR_MAP_RULES-1:0] addr_map_rules
    );
    // const parameters
    localparam int unsigned TAG_BITS_NUM = 4;
    localparam int unsigned SEL_PATHS    = 3;
    
    // internal signals
    ////logic[SEL_PATHS-1:0] port_sel;
    logic[1:0] port_sel;
    logic[TAG_BITS_NUM-1:0] tag_bits[SEL_PATHS];
    
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
                                   .addr_i(slave.add),
                                   .addr_map_i(addr_map_rules),
                                   .idx_o(port_sel),
                                   .dec_valid_o(),
                                   .dec_error_o(),
                                   .en_default_idx_i(1'b1),
                                   .default_idx_i('0) // if no address space matches: route to the first selection path (NO override)
                                   );

endmodule
