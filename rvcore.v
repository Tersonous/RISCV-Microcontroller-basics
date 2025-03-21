module risc_v_core (
    input wire clk,
    input wire reset,
    input wire [31:0] instruction,  // Instruction input
    output reg [31:0] pc,           
    output reg [31:0] result        
);


reg [31:0] regs [0:31]; // RISV 32 registers (x0 to x31x)

// Pipeline registers for FETCH , DECODE ,EXECUTE (3 stages pipeline)
reg [31:0] IF_pc, IF_instruction; 
reg [31:0] ID_pc, ID_instruction;  
reg [31:0] EX_pc, EX_instruction, EX_result; 

// Control signals for instruction decoding
reg [6:0] opcode;
reg [4:0] rs1, rs2, rd;
reg [11:0] imm;
reg [2:0] funct3;
reg [6:0] funct7;
reg [31:0] jump_target;

initial begin
    pc = 0;
    result = 0;
    regs[0] = 0;  // x0 is always 0
end

// Fetch instruction and increment PC
always @(posedge clk or posedge reset) begin
    if (reset) begin
        IF_pc <= 0;
        IF_instruction <= 0;
    end else begin
        IF_pc <= pc;
        IF_instruction <= instruction;
    end
end

// ID stage: Decode instruction
always @(posedge clk or posedge reset) begin
    if (reset) begin
        ID_pc <= 0;
        ID_instruction <= 0;
    end else begin
        ID_pc <= IF_pc;
        ID_instruction <= IF_instruction;
        
        //  decoding
        opcode <= ID_instruction[6:0];
        rd <= ID_instruction[11:7];
        funct3 <= ID_instruction[14:12];
        rs1 <= ID_instruction[19:15];
        rs2 <= ID_instruction[24:20];
        imm <= ID_instruction[31:20];
        funct7 <= ID_instruction[31:25];
    end
end

// Execute the instruction (ALU, Branches, Jumps)
always @(posedge clk or posedge reset) begin
    if (reset) begin
        EX_pc <= 0;
        EX_instruction <= 0;
        EX_result <= 0;
        jump_target <= 0;
    end else begin
        EX_pc <= ID_pc;
        EX_instruction <= ID_instruction;

        // ALU execution and branch/jump address calculation
        case (opcode)
            // ADD/SUB
            7'b0110011: begin
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            EX_result <= regs[rs1] + regs[rs2]; // ADD
                        end else if (funct7 == 7'b0100000) begin
                            EX_result <= regs[rs1] - regs[rs2]; // SUB
                        end
                    end
                endcase
            end

            // ADDI
            7'b0010011: begin
                case (funct3)
                    3'b000: begin
                        EX_result <= regs[rs1] + {{20{imm[11]}}, imm}; // ADDI
                    end
                endcase
            end

            // BEQ (Branch if Equal)
            7'b1100011: begin
                case (funct3)
                    3'b000: begin // BEQ
                        if (regs[rs1] == regs[rs2]) begin
                            jump_target <= EX_pc + {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                        end
                    end
                    3'b001: begin // BNE
                        if (regs[rs1] != regs[rs2]) begin
                            jump_target <= EX_pc + {{19{instruction[31]}}, instruction[31], instruction[7], instruction[30:25], instruction[11:8], 1'b0};
                        end
                    end
                endcase
            end

            // JAL (Jump and Link)
            7'b1101111: begin
                EX_result <= EX_pc + 4; // Store return address
                jump_target <= EX_pc + {{11{instruction[31]}}, instruction[31], instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end

            // JALR (Jump and Link Register)
            7'b1100111: begin
                if (funct3 == 3'b000) begin
                    EX_result <= EX_pc + 4;
                    jump_target <= (regs[rs1] + {{20{imm[11]}}, imm}) & ~1; // Ensure LSB is 0
                end
            end

        endcase
    end
end

// Write-back (WB) stage: Write result to register file if needed
always @(posedge clk or posedge reset) begin
    if (reset) begin
        result <= 0;
    end else begin
        // Writing the result back to the register file if rd is not 0
        if (rd != 0) regs[rd] <= EX_result;
        result <= EX_result; 
    end
end

// PC update
always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc <= 0;
    end else begin
        if (opcode == 7'b1100011 || opcode == 7'b1101111 || opcode == 7'b1100111) begin
            pc <= jump_target; // Update PC on branch or jump
        end else if (opcode != 7'b1100011 && opcode != 7'b1101111 && opcode != 7'b1100111) begin
            pc <= pc + 4;  
        end
    end
end

endmodule
