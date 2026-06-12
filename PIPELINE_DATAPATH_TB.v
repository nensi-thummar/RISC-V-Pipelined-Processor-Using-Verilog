`timescale 1ns/1ps

module pipeline_top_tb;

reg clk;
reg rst;

pipeline_top dut(
    .clk(clk),
    .rst(rst)
);

initial begin
    clk = 0;
    forever #5 clk = ~clk;
end

initial begin
    rst = 0;

    #20;
    rst = 1;
end

initial begin

    #500;

    $finish;

end

initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0,pipeline_top_tb);
end

///////////////////////////////////////////////////////////
//////////////////// MONITOR //////////////////////////////
///////////////////////////////////////////////////////////

always @(posedge clk)
begin

    $display("=================================================");

    $display("TIME = %0t", $time);

    //---------------- IF ----------------
    $display("PCF        = %h", dut.PCF);
    $display("InstrF     = %h", dut.InstrF);

    //---------------- ID ----------------
    $display("InstrD     = %h", dut.InstrD);

    //---------------- EX ----------------
    $display("ALUResultE = %h", dut.ALUResultE);

    //---------------- MEM ----------------
    $display("ALUResultM = %h", dut.ALUResultM);

    //---------------- WB ----------------
    $display("ResultW    = %h", dut.ResultW);
    $display("RdW        = %d", dut.RdW);
    $display("RegWriteW  = %b", dut.RegWriteW);

    //---------------- REGISTER VALUES ----------------
    $display("x1 = %d", dut.reg_file.registers[1]);
    $display("x2 = %d", dut.reg_file.registers[2]);
    $display("x3 = %d", dut.reg_file.registers[3]);
    $display("x4 = %d", dut.reg_file.registers[4]);
    $display("x5 = %d", dut.reg_file.registers[5]);
  $display("x6 = %d", dut.reg_file.registers[6]);
  $display("x7 = %d", dut.reg_file.registers[7]);
  $display("x8 = %d", dut.reg_file.registers[8]);
  $display("x9 = %d", dut.reg_file.registers[9]);
  $display("x10 = %d", dut.reg_file.registers[10]);
  $display("x11 = %d", dut.reg_file.registers[11]);
  $display("x12 = %d", dut.reg_file.registers[12]);
  $display("x13 = %d", dut.reg_file.registers[13]);
  $display("x14 = %d", dut.reg_file.registers[14]);
  $display("x15 = %d", dut.reg_file.registers[15]);
  $display("x16 = %d", dut.reg_file.registers[16]);
  $display("x17 = %d", dut.reg_file.registers[17]);
  $display("x18 = %d", dut.reg_file.registers[18]);
  $display("x19 = %d", dut.reg_file.registers[19]);
  $display("x20 = %d", dut.reg_file.registers[20]);
  
  $display("x21 = %d", dut.reg_file.registers[21]);
  $display("x22 = %d", dut.reg_file.registers[22]);
  $display("x23 = %d", dut.reg_file.registers[23]);
  $display("x24 = %d", dut.reg_file.registers[24]);
  $display("x25 = %d", dut.reg_file.registers[25]);
  $display("x26 = %d", dut.reg_file.registers[26]);
  $display("x27 = %d", dut.reg_file.registers[27]);
  $display("x28 = %d", dut.reg_file.registers[28]);

    $display("=================================================");

end

endmodule