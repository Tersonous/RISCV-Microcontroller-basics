// RiscV nanocore (microcontroller) in verilog, tested through Icarus Verilog
// Licence MIT
// Software provided as "as if", be careful to not break your computer :)S



module risc_v_core (
    input wire clk,              
    input wire reset,             
    input wire [31:0] instruction, 
    output reg [31:0] pc,        
    output reg [31:0] result     
);

// Les 32 0registres (nous travaillons ici en 32 bits)
reg [31:0] regs [0:31];

// Instruction decode signals


reg [6:0] opcode;
reg [4:0] rs1, rs2, rd;
reg [11:0] imm;
reg [2:0] funct3;
reg [6:0] funct7;

// PC initial
initial begin
    pc = 0;
    result = 0;
    // Optionelle initialisation
    regs[0] = 0;  // x0 = 0 en RISCV
end

// DECODER
always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc <= 0;
        result <= 0;
    end else begin
        opcode <= instruction[6:0];
        rd <= instruction[11:7];
        funct3 <= instruction[14:12];
        rs1 <= instruction[19:15];
        rs2 <= instruction[24:20];
        imm <= instruction[31:20];

        // ADD
        case (opcode)
            7'b0110011: begin // R-type (ADD)
                if (funct3 == 3'b000 && funct7 == 7'b0000000) begin
                    result <= regs[rs1] + regs[rs2];  // ADD operation
                    regs[rd] <= result;               // result in rd
                    pc <= pc + 4;                     // Increment PC
                end
            end
            // LW
            7'b0000011: begin // I-type (LW)
                if (funct3 == 3'b010) begin
                    result <= regs[rs1] + imm;      // Address computation
                    pc <= pc + 4;                   // Increment PC
                end
            end
            // Autres instructions a venir
            default: begin
                result <= 32'b0;                  //  (error case)
            end
        endcase
    end
end

endmodule
