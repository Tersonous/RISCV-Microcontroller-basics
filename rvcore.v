module risc_v_core (
    input wire clk,
    input wire reset,
    input wire [31:0] instruction,
    output reg [31:0] pc,
    output reg [31:0] result
);

reg [31:0] regs [0:31];


reg [6:0] opcode;
reg [4:0] rs1, rs2, rd;
reg [11:0] imm;
reg [2:0] funct3;
reg [6:0] funct7;


initial begin
    pc = 0;
    result = 0;
    regs[0] = 0;  
end

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
        funct7 <= instruction[31:25];

        case (opcode)
            // (ADD, SUB)
            7'b0110011: begin 
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            result <= regs[rs1] + regs[rs2]; // ADD
                        end else if (funct7 == 7'b0100000) begin
                            result <= regs[rs1] - regs[rs2]; // SUB
                        end
                    end
                endcase
                if (rd != 0) regs[rd] <= result; // Prevent writing to x0
            end

            //  (ADDI, LI)
            7'b0010011: begin
                case (funct3)
                    3'b000: begin 
                        result <= regs[rs1] + {{20{imm[11]}}, imm}; 
                    end
                endcase
                if (rd != 0) regs[rd] <= result;
            end

            
            7'b1100011: begin
                case (funct3)
                    3'b000: begin // BEQ
                        if (regs[rs1] == regs[rs2]) begin
                            pc <= pc + {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                        end
                    end
                    3'b001: begin // BNE
                        if (regs[rs1] != regs[rs2]) begin
                            pc <= pc + {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                        end
                    end
                endcase
            end

            //  (JAL)
            7'b1101111: begin
                result <= pc + 4; // Store return address
                if (rd != 0) regs[rd] <= result;
                pc <= pc + {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end

            // (JALR)
            7'b1100111: begin
                if (funct3 == 3'b000) begin
                    result <= pc + 4;
                    if (rd != 0) regs[rd] <= result;
                    pc <= (regs[rs1] + {{20{imm[11]}}, imm}) & ~1; // Ensure LSB is 0
                end
            end
        endcase

        // PC increment unless a branch or jump occurs
        if (opcode != 7'b1100011 && opcode != 7'b1101111 && opcode != 7'b1100111) begin
            pc <= pc + 4;
        end
    end
end

endmodule
