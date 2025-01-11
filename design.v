
// adder
module adder(input [31:0] a, b, output [31:0] y);
    assign y = a + b;
endmodule

// 2-to-1 multiplexer
module mux2 #(parameter WIDTH = 8) (input [WIDTH-1:0] d0, d1, input s, output [WIDTH-1:0] y);
    assign y = s ? d1 : d0;
endmodule

// flip-flop
module flipflop #(parameter WIDTH = 8) (
    input clk, reset,
    input [WIDTH-1:0] d,
    output reg [WIDTH-1:0] q
);
    always @(posedge clk or posedge reset)
        if (reset)
            q <= 0;
        else
            q <= d;
endmodule

// shift left 2
module shiftleft2(input [31:0] a, output [31:0] y);
    assign y = {a[29:0], 2'b00};
endmodule

// sign extend
module signextend(input [15:0] a, output [31:0] y);
    assign y = {{16{a[15]}}, a};
endmodule

// register file
module regfile(
    input clk,
    input we3,
    input [4:0] ra1, ra2, wa3,
    input [31:0] wd3,
    output [31:0] rd1, rd2
);
    reg [31:0] rf[31:0];
    always @(posedge clk)
        if (we3)
            rf[wa3] <= wd3;

    assign rd1 = (ra1 != 0) ? rf[ra1] : 0;
    assign rd2 = (ra2 != 0) ? rf[ra2] : 0;
endmodule

// instruction memory
module instmem(input [5:0] a, output [31:0] rd);
    // insert some initial values for testbench
    reg [31:0] INSTMEM[1023:0];
    initial
    begin
        INSTMEM[0] = 32'h20020005;
        INSTMEM[1] = 32'h2003000c;
        INSTMEM[2] = 32'h2067fff7;
        INSTMEM[3] = 32'h00e22025;
        INSTMEM[4] = 32'h00642824;
        INSTMEM[5] = 32'h00a42820;
        INSTMEM[6] = 32'h10a7000a;
        INSTMEM[7] = 32'h0064202a;
        INSTMEM[8] = 32'h10800001;
        INSTMEM[9] = 32'h20050000;
        INSTMEM[10] = 32'h00e2202a;
        INSTMEM[11] = 32'h00853820;
        INSTMEM[12] = 32'h00e23822;
        INSTMEM[13] = 32'hac670044;
        INSTMEM[14] = 32'h8c020050;
        INSTMEM[15] = 32'h08000011;
        INSTMEM[16] = 32'h20020001;
        INSTMEM[17] = 32'hac020054;
    end
    assign rd = INSTMEM[a]; // word aligned
endmodule

// data memory
module datamem(
    input clk, we,
    input [31:0] a, wd,
    output [31:0] rd
);
    reg [31:0] DATAMEM[4095:0];
    assign rd = DATAMEM[a[31:2]]; // word aligned
    always @(posedge clk)
        if (we)
            DATAMEM[a[31:2]] <= wd;
endmodule

// alu
module alu(
    input [31:0] srca,                                          // first operand
    input [31:0] srcb,                                          // second operand
    input [2:0]  alucontrolsignal,                              // alu control signal
    output reg [31:0] aluout,                                   // result of operation
    output zero                                                 // zero flag
);
    assign zero = (aluout == 32'b0);                            // zero flag: set to 1 if aluout is 0
    always @(*) begin
        case (alucontrolsignal)
            3'b010: aluout = srca + srcb;                       // add operation
            3'b110: aluout = srca - srcb;                       // sub operation
            3'b000: aluout = srca & srcb;                       // and operation
            3'b001: aluout = srca | srcb;                       // or operation
            3'b111: aluout = (srca < srcb) ? 32'b1 : 32'b0;     // slt operation
            default: aluout = 32'b0;                            // default to 0 for undefined alu control signal
        endcase
    end
endmodule

// alu control
module alucontrol(
    input [5:0] funct,
    input [1:0] aluop,
    output reg [2:0] alucontrolsignal
);
    always @(*) begin
        case (aluop)
            2'b00: alucontrolsignal <= 3'b010; // Add (for lw/sw/addi)
            2'b01: alucontrolsignal <= 3'b110; // Sub (for beq)
            default: begin
                case (funct) // R-type instructions
                    6'b100000: alucontrolsignal <= 3'b010; // add
                    6'b100010: alucontrolsignal <= 3'b110; // sub
                    6'b100100: alucontrolsignal <= 3'b000; // and
                    6'b100101: alucontrolsignal <= 3'b001; // or
                    6'b101010: alucontrolsignal <= 3'b111; // slt
                    default: alucontrolsignal <= 3'bxxx;         // illegal funct 
                endcase
            end
        endcase
    end
endmodule

// control
module control(
    input [5:0] op,
    output memtoreg, memwrite,
    output branch, alusrc,
    output regdst, regwrite,
    output jump,
    output [1:0] aluop
);
    reg [8:0] controls;

    assign {regwrite, regdst, alusrc, branch, memwrite,
            memtoreg, jump, aluop} = controls;

    always @(*) begin
        case (op)
            6'b000000: controls <= 9'b110000010; // R-type instruction format
            6'b100011: controls <= 9'b101001000; // lw
            6'b101011: controls <= 9'b001010000; // sw
            6'b000100: controls <= 9'b000100001; // beq
            6'b001000: controls <= 9'b101000000; // addi
            6'b000010: controls <= 9'b000000100; // j
            default: controls <= 9'bxxxxxxxxx;   // illegal op
        endcase
    end
endmodule

// mipc cpu
module mips_cpu(
    input clk, reset,
    output [31:0] writedata, dataadr,
    output memwrite
);
    wire [31:0] pc, instr, readdata;
    wire [31:0] pcnext, pcnextbr, pcplus4, pcbranch;
    wire [31:0] signimm, signimmsh;
    wire [31:0] srca, srcb;
    wire [31:0] result;
    wire [4:0]  writereg;
    wire [2:0]  alucontrolsignal;
    wire [1:0]  aluop;
    wire memtoreg, alusrc, regdst, regwrite, jump, branch, pcsrc, zero;
    assign pcsrc = branch & zero;

    control c(
        .op(instr[31:26]),
        .memtoreg(memtoreg),
        .memwrite(memwrite),
        .branch(branch),
        .alusrc(alusrc),
        .regdst(regdst),
        .regwrite(regwrite),
        .jump(jump),
        .aluop(aluop)
    );

    alucontrol ac(
        .funct(instr[5:0]),
        .aluop(aluop),
        .alucontrolsignal(alucontrolsignal)
    );

    instmem im(
        .a(pc[7:2]),
        .rd(instr)
    );

    datamem dm(
        .clk(clk),
        .we(memwrite),
        .a(dataadr),
        .wd(writedata),
        .rd(readdata)
    );

    // next pc logic
    flipflop #(32) pcreg(clk, reset, pcnext, pc);
    adder pcadd1(pc, 32'b100, pcplus4);
    shiftleft2 immsh(signimm, signimmsh);
    adder pcadd2(pcplus4, signimmsh, pcbranch);
    mux2 #(32) pcbrmux(pcplus4, pcbranch, pcsrc, pcnextbr);
    mux2 #(32) pcmux(pcnextbr, {pcplus4[31:28], instr[25:0], 2'b00}, jump, pcnext);

    // register file logic
    regfile rf(clk, regwrite, instr[25:21], instr[20:16], writereg, result, srca, writedata);
    mux2 #(5) wrmux(instr[20:16], instr[15:11], regdst, writereg);
    mux2 #(32) resmux(dataadr, readdata, memtoreg, result);
    signextend se(instr[15:0], signimm);

    // alu logic
    mux2 #(32) srcbmux(writedata, signimm, alusrc, srcb);
    alu alu(srca, srcb, alucontrolsignal, dataadr, zero);

endmodule



