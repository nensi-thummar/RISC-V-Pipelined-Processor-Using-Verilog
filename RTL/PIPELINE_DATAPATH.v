module instr_mem(
    input rst,
    input [31:0] add,
    output [31:0] data
);
reg [31:0] mem [1023:0];

initial begin
    integer i;
    for(i = 0; i < 1024; i = i+1)
        mem[i] = 32'h00000013; // NOP default
    $readmemh("program.mem", mem);
end

assign data = (!rst) ? 32'd0 : mem[add[31:2]];
endmodule


module pc(
    input StallF,
    input clk,
    input rst,
    input [31:0] pcnext,
    output reg [31:0] pc
);
always @(posedge clk) begin
    if(!rst)
        pc <= 0;
    else if(!StallF)
        pc <= pcnext;
end
endmodule


module reg_file(
    input clk,
    input rst,
    input [4:0] a1,
    input [4:0] a2,
    input [4:0] a3,
    input [31:0] write_data,
    input write_en_reg,
    output [31:0] read_data1,
    output [31:0] read_data2
);
reg [31:0] registers [31:0];
integer i;
initial begin
    for(i = 0; i < 32; i = i+1)
        registers[i] = 32'd0;
end

// Forward write data to read ports on same cycle
assign read_data1 = (a1==0)?32'd0:(write_en_reg && a3!= 0 && a3==a1)?write_data:registers[a1];
assign read_data2 = (a2==0)?32'd0:(write_en_reg && a3!= 0 && a3==a2)?write_data:registers[a2];

always @(posedge clk) begin
    if(write_en_reg && (a3 != 0))
        registers[a3] <= write_data;
end
endmodule


module pcplus(
    input [31:0] a,
    input [31:0] b,
    output [31:0] c
);
assign c = a + b;
endmodule


module pctarget(
    input [31:0] pc,
    input [31:0] immext,
    output [31:0] pc_target
);
assign pc_target = pc + immext;
endmodule


module data_mem(
    input clk,
    input rst,
    input write_en_data,
    input [31:0] write_data,
    input [31:0] add,
    output [31:0] read_data
);
reg [31:0] d_mem [1023:0];

initial begin
    integer i;
    for(i = 0; i < 1024; i = i+1)
        d_mem[i] = 32'd0;
end

assign read_data = (!rst) ? 32'd0 : d_mem[add[31:2]];
always @(posedge clk) begin
    if(write_en_data)
        d_mem[add[31:2]] <= write_data;
end
endmodule


module maindecoder(
    input [6:0] opcode,
    input [2:0] fun3,
    input zero,
    input negative,
    output regwrite,
    output memwrite,
    output ALUsrc,
    output [1:0] resultsrc,
    output [1:0] pcsrc,
    output [1:0] ALUop,
    output [2:0] immsrc,
    output branch
);

wire jal, jalr;
assign jal    = (opcode == 7'b1101111);
assign jalr   = (opcode == 7'b1100111);
assign branch = (opcode == 7'b1100011);

assign regwrite =
    (opcode == 7'b0110011) ||
    (opcode == 7'b0010011) ||
    (opcode == 7'b0000011) ||
    (opcode == 7'b1101111) ||
    (opcode == 7'b1100111) ||
    (opcode == 7'b0110111);

assign memwrite = (opcode == 7'b0100011);

assign ALUsrc =
    (opcode == 7'b0000011) ||
    (opcode == 7'b0100011) ||
    (opcode == 7'b0010011) ||
    (opcode == 7'b0110111) ||
    (opcode == 7'b1100111);

assign resultsrc =
    (opcode == 7'b0000011) ? 2'b01 :
    (opcode == 7'b1101111) ? 2'b10 :
    (opcode == 7'b1100111) ? 2'b10 :
    (opcode == 7'b0110111) ? 2'b11 :
                             2'b00;

assign ALUop =
    (opcode == 7'b0000011 || opcode == 7'b0100011) ? 2'b00 :
    (opcode == 7'b1100011)                          ? 2'b01 :
                                                      2'b10;

assign immsrc =
    (opcode == 7'b0000011) ? 3'b000 :
    (opcode == 7'b0010011) ? 3'b000 :
    (opcode == 7'b1100111) ? 3'b000 :
    (opcode == 7'b0100011) ? 3'b001 :
    (opcode == 7'b1100011) ? 3'b010 :
    (opcode == 7'b1101111) ? 3'b011 :
    (opcode == 7'b0110111) ? 3'b100 :
                             3'b000;

assign pcsrc =
    (jal)  ? 2'b01 :
    (jalr) ? 2'b10 :
             2'b00;

endmodule


module aludecoder(
    input [6:0] opcode,
    input [6:0] fun7,
    input [2:0] fun3,
    input [1:0] ALUop,
    output reg [3:0] ALUcontrol
);
always @(*) begin
    case(ALUop)
        2'b00: ALUcontrol = 4'b0000;
        2'b01: ALUcontrol = 4'b0001;
        2'b10: begin
            case(fun3)
                3'b000:
                    if(opcode == 7'b0110011 && fun7 == 7'b0100000)
                        ALUcontrol = 4'b0001;
                    else
                        ALUcontrol = 4'b0000;
                3'b111: ALUcontrol = 4'b0010;
                3'b110: ALUcontrol = 4'b0011;
                3'b100: ALUcontrol = 4'b0100;
                3'b010: ALUcontrol = 4'b0101;
                3'b011: ALUcontrol = 4'b0110;
                3'b001: ALUcontrol = 4'b1000;
                3'b101:
                    if(fun7 == 7'b0100000)
                        ALUcontrol = 4'b1001;
                    else
                        ALUcontrol = 4'b0111;
                default: ALUcontrol = 4'b0000;
            endcase
        end
        default: ALUcontrol = 4'b0000;
    endcase
end
endmodule


module control_unit_top(
    input [6:0] opcode,
    input [6:0] fun7,
    input [2:0] fun3,
    input zero,
    input negative,
    output regwrite,
    output memwrite,
    output ALUsrc,
    output [1:0] resultsrc,
    output [1:0] pcsrc,
    output [2:0] immsrc,
    output [3:0] ALUcontrol,
    output branch
);
wire [1:0] ALUop;

maindecoder maindecoder(
    .opcode(opcode), .fun3(fun3),
    .zero(zero), .negative(negative),
    .regwrite(regwrite), .memwrite(memwrite), .ALUsrc(ALUsrc),
    .resultsrc(resultsrc), .pcsrc(pcsrc),
    .ALUop(ALUop), .immsrc(immsrc),
    .branch(branch)
);

aludecoder aludecoder(
    .opcode(opcode), .fun7(fun7), .fun3(fun3),
    .ALUop(ALUop),
    .ALUcontrol(ALUcontrol)
);
endmodule


module extend(
    input [31:0] in,
    input [2:0] immsrc,
    output reg [31:0] immext
);
always @(*) begin
    case(immsrc)
        3'b000: immext = {{20{in[31]}}, in[31:20]};
        3'b001: immext = {{20{in[31]}}, in[31:25], in[11:7]};
        3'b010: immext = {{19{in[31]}}, in[31], in[7], in[30:25], in[11:8], 1'b0};
        3'b011: immext = {{11{in[31]}}, in[31], in[19:12], in[20], in[30:21], 1'b0};
        3'b100: immext = {in[31:12], 12'b0};
        default: immext = 32'd0;
    endcase
end
endmodule


module mux(
    input [31:0] a,
    input [31:0] b,
    input s,
    output [31:0] y
);
assign y = (s) ? b : a;
endmodule


module mux4(
    input [31:0] a,
    input [31:0] b,
    input [31:0] c,
    input [31:0] d,
    input [1:0] s,
    output [31:0] y
);
assign y =
    (s == 2'b00) ? a :
    (s == 2'b01) ? b :
    (s == 2'b10) ? c :
                   d;
endmodule


module ALU(
    input [31:0] a,
    input [31:0] b,
    input [3:0] alucontrol,
    output reg [31:0] result,
    output carry,
    output overflow,
    output zero,
    output negative
);
wire [31:0] not_b;
wire [31:0] mux1;
wire [32:0] sum;

assign not_b = ~b;
assign mux1  = (alucontrol == 4'b0001) ? not_b : b;
assign sum   = a + mux1 + (alucontrol == 4'b0001);
assign carry = sum[32];

always @(*) begin
    case(alucontrol)
        4'b0000: result = sum[31:0];
        4'b0001: result = sum[31:0];
        4'b0010: result = a & b;
        4'b0011: result = a | b;
        4'b0100: result = a ^ b;
        4'b0101: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
        4'b0110: result = (a < b)                   ? 32'd1 : 32'd0;
        4'b0111: result = a >> b[4:0];
        4'b1000: result = a << b[4:0];
        4'b1001: result = $signed(a) >>> b[4:0];
        default: result = 32'd0;
    endcase
end

assign zero     = (result == 32'd0);
assign negative =  result[31];

assign overflow =
    (alucontrol == 4'b0000) ? ((a[31] == b[31]) && (result[31] != a[31])) :
    (alucontrol == 4'b0001) ? ((a[31] != b[31]) && (result[31] != a[31])) :
    1'b0;
endmodule


module if_id(
    input clk,
    input rst,
    input StallD,
    input FlushD,
    input [31:0] InstrF,
    input [31:0] PCF,
    input [31:0] PCPlus4F,
    output reg [31:0] InstrD,
    output reg [31:0] PCD,
    output reg [31:0] PCPlus4D
);
always @(posedge clk) begin
    if(!rst || FlushD) begin
        InstrD   <= 32'd0;
        PCD      <= 32'd0;
        PCPlus4D <= 32'd0;
    end
    else if(!StallD) begin
        InstrD   <= InstrF;
        PCD      <= PCF;
        PCPlus4D <= PCPlus4F;
    end
end
endmodule


module id_ex(
    input clk,
    input rst,
    input FlushE,

    input [31:0] RD1D,
    input [31:0] RD2D,
    input [31:0] ImmExtD,
    input [31:0] PCD,
    input [31:0] PCPlus4D,

    input [4:0] Rs1D,
    input [4:0] Rs2D,
    input [4:0] RdD,

    input [2:0] Fun3D,
    input [6:0] OpcodeD,

    input RegWriteD,
    input MemWriteD,
    input ALUSrcD,
    input BranchD,

    input [1:0] ResultSrcD,
    input [1:0] PCSrcD,

    input [3:0] ALUControlD,

    output reg [31:0] RD1E,
    output reg [31:0] RD2E,
    output reg [31:0] ImmExtE,
    output reg [31:0] PCE,
    output reg [31:0] PCPlus4E,

    output reg [4:0] Rs1E,
    output reg [4:0] Rs2E,
    output reg [4:0] RdE,

    output reg [2:0] Fun3E,
    output reg [6:0] OpcodeE,

    output reg RegWriteE,
    output reg MemWriteE,
    output reg ALUSrcE,
    output reg BranchE,

    output reg [1:0] ResultSrcE,
    output reg [1:0] PCSrcE,

    output reg [3:0] ALUControlE
);

always @(posedge clk) begin
    if (!rst || FlushE) begin
        RD1E        <= 32'd0;
        RD2E        <= 32'd0;
        ImmExtE     <= 32'd0;
        PCE         <= 32'd0;
        PCPlus4E    <= 32'd0;
        Rs1E        <= 5'd0;
        Rs2E        <= 5'd0;
        RdE         <= 5'd0;
        Fun3E       <= 3'd0;
        OpcodeE     <= 7'd0;
        RegWriteE   <= 1'b0;
        MemWriteE   <= 1'b0;
        ALUSrcE     <= 1'b0;
        BranchE     <= 1'b0;
        ResultSrcE  <= 2'b00;
        PCSrcE      <= 2'b00;
        ALUControlE <= 4'd0;
    end
    else begin
        RD1E        <= RD1D;
        RD2E        <= RD2D;
        ImmExtE     <= ImmExtD;
        PCE         <= PCD;
        PCPlus4E    <= PCPlus4D;
        Rs1E        <= Rs1D;
        Rs2E        <= Rs2D;
        RdE         <= (RegWriteD) ? RdD : 5'd0;
        Fun3E       <= Fun3D;
        OpcodeE     <= OpcodeD;
        RegWriteE   <= RegWriteD;
        MemWriteE   <= MemWriteD;
        ALUSrcE     <= ALUSrcD;
        BranchE     <= BranchD;
        ResultSrcE  <= ResultSrcD;
        PCSrcE      <= PCSrcD;
        ALUControlE <= ALUControlD;
    end
end
endmodule


module ex_mem(
    input clk,
    input rst,

    input [31:0] ALUResultE,
    input [31:0] WriteDataE,
    input [31:0] PCPlus4E,
    input [31:0] ImmExtE,

    input [4:0] RdE,

    input RegWriteE,
    input MemWriteE,

    input [1:0] ResultSrcE,

    output reg [31:0] ALUResultM,
    output reg [31:0] WriteDataM,
    output reg [31:0] PCPlus4M,
    output reg [31:0] ImmExtM,

    output reg [4:0] RdM,

    output reg RegWriteM,
    output reg MemWriteM,

    output reg [1:0] ResultSrcM
);

always @(posedge clk) begin
    if(!rst) begin
        ALUResultM <= 0; WriteDataM <= 0;
        PCPlus4M   <= 0; ImmExtM    <= 0;
        RdM        <= 0;
        RegWriteM  <= 0; MemWriteM  <= 0;
        ResultSrcM <= 0;
    end
    else begin
        ALUResultM <= ALUResultE; WriteDataM <= WriteDataE;
        PCPlus4M   <= PCPlus4E;   ImmExtM    <= ImmExtE;
        RdM        <= RdE;
        RegWriteM  <= RegWriteE;  MemWriteM  <= MemWriteE;
        ResultSrcM <= ResultSrcE;
    end
end
endmodule


module mem_wb(
    input clk,
    input rst,

    input [31:0] ReadDataM,
    input [31:0] ALUResultM,
    input [31:0] PCPlus4M,
    input [31:0] ImmExtM,

    input [4:0] RdM,

    input RegWriteM,

    input [1:0] ResultSrcM,

    output reg [31:0] ReadDataW,
    output reg [31:0] ALUResultW,
    output reg [31:0] PCPlus4W,
    output reg [31:0] ImmExtW,

    output reg [4:0] RdW,

    output reg RegWriteW,

    output reg [1:0] ResultSrcW
);

always @(posedge clk) begin
    if(!rst) begin
        ReadDataW  <= 0; ALUResultW <= 0;
        PCPlus4W   <= 0; ImmExtW    <= 0;
        RdW        <= 0;
        RegWriteW  <= 0;
        ResultSrcW <= 0;
    end
    else begin
        ReadDataW  <= ReadDataM; ALUResultW <= ALUResultM;
        PCPlus4W   <= PCPlus4M;  ImmExtW    <= ImmExtM;
        RdW        <= RdM;
        RegWriteW  <= RegWriteM;
        ResultSrcW <= ResultSrcM;
    end
end
endmodule


module forwarding_unit(
    input [4:0] Rs1E,
    input [4:0] Rs2E,
    input [4:0] RdM,
    input [4:0] RdW,
    input RegWriteM,
    input RegWriteW,
    output reg [1:0] ForwardAE,
    output reg [1:0] ForwardBE
);

always @(*) begin
    ForwardAE = 2'b00;
    ForwardBE = 2'b00;

    // MEM-stage forwarding takes priority over WB-stage
    if(RegWriteM && (RdM != 0) && (RdM == Rs1E))
        ForwardAE = 2'b10;
    if(RegWriteM && (RdM != 0) && (RdM == Rs2E))
        ForwardBE = 2'b10;

    if(RegWriteW && (RdW != 0) &&
       !(RegWriteM && (RdM != 0) && (RdM == Rs1E)) &&
       (RdW == Rs1E))
        ForwardAE = 2'b01;

    if(RegWriteW && (RdW != 0) &&
       !(RegWriteM && (RdM != 0) && (RdM == Rs2E)) &&
       (RdW == Rs2E))
        ForwardBE = 2'b01;
end
endmodule


module hazard_unit(
    input [4:0] Rs1D,
    input [4:0] Rs2D,
    input [4:0] RdE,
    input [1:0] ResultSrcE,
    output StallF,
    output StallD,
    output FlushE
);
// Stall on load-use hazard
wire lwStall;
assign lwStall =
       (ResultSrcE == 2'b01)
    && (RdE != 0)
    && ((Rs1D == RdE) || (Rs2D == RdE));

assign StallF = lwStall;
assign StallD = lwStall;
assign FlushE = lwStall;
endmodule


module pipeline_top(
    input clk,
    input rst
);

wire StallF, StallD, FlushEHazard;

// ------------------- IF STAGE -------------------

wire [31:0] PCF, PCNextF, PCPlus4F, InstrF;

pc pc(
    .clk(clk), .rst(rst), .StallF(StallF),
    .pcnext(PCNextF), .pc(PCF)
);

instr_mem instr_mem(
    .rst(rst), .add(PCF), .data(InstrF)
);

pcplus pcplusf(
    .a(PCF), .b(32'd4), .c(PCPlus4F)
);

// ------------------- IF/ID REGISTER -------------------

wire [31:0] InstrD, PCD, PCPlus4D;
wire        branchTaken;

if_id if_id(
    .clk(clk), .rst(rst),
    .StallD(StallD), .FlushD(branchTaken),
    .InstrF(InstrF), .PCF(PCF), .PCPlus4F(PCPlus4F),
    .InstrD(InstrD), .PCD(PCD), .PCPlus4D(PCPlus4D)
);

// ------------------- ID STAGE -------------------

wire [31:0] RD1D, RD2D, ImmExtD;
wire [4:0]  Rs1D, Rs2D, RdD;
wire        RegWriteD, MemWriteD, ALUSrcD, BranchD;
wire [1:0]  ResultSrcD, PCSrcD;
wire [2:0]  ImmSrcD;
wire [3:0]  ALUControlD;

assign Rs1D = InstrD[19:15];
assign Rs2D = InstrD[24:20];
assign RdD  = InstrD[11:7];

wire [4:0]  RdW;
wire [31:0] ResultW;
wire        RegWriteW;

reg_file reg_file(
    .clk(clk), .rst(rst),
    .a1(Rs1D), .a2(Rs2D), .a3(RdW),
    .write_data(ResultW), .write_en_reg(RegWriteW),
    .read_data1(RD1D), .read_data2(RD2D)
);

control_unit_top control_unit_top(
    .opcode(InstrD[6:0]), .fun7(InstrD[31:25]), .fun3(InstrD[14:12]),
    .zero(1'b0), .negative(1'b0),
    .regwrite(RegWriteD), .memwrite(MemWriteD), .ALUsrc(ALUSrcD),
    .resultsrc(ResultSrcD), .pcsrc(PCSrcD),
    .immsrc(ImmSrcD), .ALUcontrol(ALUControlD),
    .branch(BranchD)
);

extend extend(
    .in(InstrD), .immsrc(ImmSrcD), .immext(ImmExtD)
);

// ------------------- HAZARD UNIT -------------------

wire [4:0]  RdE;
wire [1:0]  ResultSrcE;

hazard_unit hazard_unit(
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdE(RdE),
    .ResultSrcE(ResultSrcE),
    .StallF(StallF), .StallD(StallD), .FlushE(FlushEHazard)
);

// ------------------- ID/EX REGISTER -------------------

wire [31:0] RD1E, RD2E, ImmExtE, PCE, PCPlus4E;
wire [4:0]  Rs1E, Rs2E;
wire [2:0]  Fun3E;
wire [6:0]  OpcodeE;
wire        RegWriteE, MemWriteE, ALUSrcE, BranchE;
wire [1:0]  PCSrcE;
wire [3:0]  ALUControlE;

id_ex id_ex(
    .clk(clk), .rst(rst),
    .FlushE(branchTaken || FlushEHazard),
    .RD1D(RD1D), .RD2D(RD2D), .ImmExtD(ImmExtD),
    .PCD(PCD), .PCPlus4D(PCPlus4D),
    .Rs1D(Rs1D), .Rs2D(Rs2D), .RdD(RdD),
    .Fun3D(InstrD[14:12]), .OpcodeD(InstrD[6:0]),
    .RegWriteD(RegWriteD), .MemWriteD(MemWriteD),
    .ALUSrcD(ALUSrcD), .BranchD(BranchD),
    .ResultSrcD(ResultSrcD), .PCSrcD(PCSrcD),
    .ALUControlD(ALUControlD),
    .RD1E(RD1E), .RD2E(RD2E), .ImmExtE(ImmExtE),
    .PCE(PCE), .PCPlus4E(PCPlus4E),
    .Rs1E(Rs1E), .Rs2E(Rs2E), .RdE(RdE),
    .Fun3E(Fun3E), .OpcodeE(OpcodeE),
    .RegWriteE(RegWriteE), .MemWriteE(MemWriteE),
    .ALUSrcE(ALUSrcE), .BranchE(BranchE),
    .ResultSrcE(ResultSrcE), .PCSrcE(PCSrcE),
    .ALUControlE(ALUControlE)
);

// ------------------- FORWARDING UNIT -------------------

wire [1:0]  ForwardAE, ForwardBE;
wire [31:0] ALUResultM;
wire        RegWriteM;
wire [4:0]  RdM;

forwarding_unit forwarding_unit(
    .Rs1E(Rs1E), .Rs2E(Rs2E),
    .RdM(RdM), .RdW(RdW),
    .RegWriteM(RegWriteM), .RegWriteW(RegWriteW),
    .ForwardAE(ForwardAE), .ForwardBE(ForwardBE)
);

// ------------------- EX STAGE -------------------

wire [31:0] SrcAE, SrcBE, WriteDataE, ALUResultE, PCTargetE;
wire        ZeroE, NegativeE;

assign SrcAE =
    (ForwardAE == 2'b00) ? RD1E       :
    (ForwardAE == 2'b10) ? ALUResultM :
                           ResultW;

assign WriteDataE =
    (ForwardBE == 2'b00) ? RD2E       :
    (ForwardBE == 2'b10) ? ALUResultM :
                           ResultW;

mux mux_alu(
    .a(WriteDataE), .b(ImmExtE), .s(ALUSrcE), .y(SrcBE)
);

ALU ALU(
    .a(SrcAE), .b(SrcBE),
    .alucontrol(ALUControlE),
    .result(ALUResultE),
    .carry(), .overflow(),
    .zero(ZeroE), .negative(NegativeE)
);

pctarget pctarget(
    .pc(PCE), .immext(ImmExtE), .pc_target(PCTargetE)
);

// Gate branchTaken with rst to prevent false flush at reset
wire BranchTakenE;

assign BranchTakenE = rst && (
       (BranchE && Fun3E == 3'b000 &&  ZeroE)
    || (BranchE && Fun3E == 3'b001 && !ZeroE)
    || (BranchE && Fun3E == 3'b100 &&  NegativeE)
    || (BranchE && Fun3E == 3'b101 && (!NegativeE || ZeroE))
    || (BranchE && Fun3E == 3'b110 &&  NegativeE)
    || (BranchE && Fun3E == 3'b111 && (!NegativeE || ZeroE))
);

assign branchTaken = rst && (
       BranchTakenE
    || (PCSrcE == 2'b01)
    || (PCSrcE == 2'b10)
);

assign PCNextF =
    (PCSrcE == 2'b10) ? ALUResultE :
    (branchTaken)     ? PCTargetE  :
                        PCPlus4F;

// ------------------- EX/MEM REGISTER -------------------

wire [31:0] WriteDataM, PCPlus4M, ImmExtM;
wire        MemWriteM;
wire [1:0]  ResultSrcM;

ex_mem ex_mem(
    .clk(clk), .rst(rst),
    .ALUResultE(ALUResultE), .WriteDataE(WriteDataE),
    .PCPlus4E(PCPlus4E), .ImmExtE(ImmExtE),
    .RdE(RdE),
    .RegWriteE(RegWriteE), .MemWriteE(MemWriteE),
    .ResultSrcE(ResultSrcE),
    .ALUResultM(ALUResultM), .WriteDataM(WriteDataM),
    .PCPlus4M(PCPlus4M), .ImmExtM(ImmExtM),
    .RdM(RdM),
    .RegWriteM(RegWriteM), .MemWriteM(MemWriteM),
    .ResultSrcM(ResultSrcM)
);

// ------------------- MEM STAGE -------------------

wire [31:0] ReadDataM;

data_mem data_mem(
    .clk(clk), .rst(rst),
    .write_en_data(MemWriteM),
    .write_data(WriteDataM),
    .add(ALUResultM),
    .read_data(ReadDataM)
);

// ------------------- MEM/WB REGISTER -------------------

wire [31:0] ReadDataW, ALUResultW, PCPlus4W, ImmExtW;
wire [1:0]  ResultSrcW;

mem_wb mem_wb(
    .clk(clk), .rst(rst),
    .ReadDataM(ReadDataM), .ALUResultM(ALUResultM),
    .PCPlus4M(PCPlus4M), .ImmExtM(ImmExtM),
    .RdM(RdM), .RegWriteM(RegWriteM),
    .ResultSrcM(ResultSrcM),
    .ReadDataW(ReadDataW), .ALUResultW(ALUResultW),
    .PCPlus4W(PCPlus4W), .ImmExtW(ImmExtW),
    .RdW(RdW), .RegWriteW(RegWriteW),
    .ResultSrcW(ResultSrcW)
);

// ------------------- WB STAGE -------------------

mux4 result_mux(
    .a(ALUResultW), .b(ReadDataW),
    .c(PCPlus4W),   .d(ImmExtW),
    .s(ResultSrcW), .y(ResultW)
);

endmodule
