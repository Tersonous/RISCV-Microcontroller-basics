module risc_v_core (
    input wire clk,
    input wire reset,
    input wire [31:0] instruction,
    output reg [31:0] pc,
    output reg [31:0] result
);

reg [31:0] regs [0:31];  
reg [31:0] IF_ID_instr, IF_ID_pc;
reg [31:0] ID_EX_instr, ID_EX_pc, ID_EX_imm;
reg [31:0] EX_MEM_instr, EX_MEM_pc, EX_MEM_result;
reg [31:0] MEM_WB_instr, MEM_WB_pc, MEM_WB_result;
reg [4:0] EX_MEM_rd, MEM_WB_rd; // FIX: Declare register write-back variables

reg [6:0] opcode;
reg [4:0] rs1, rs2, rd;
reg [11:0] imm;
reg [2:0] funct3;
reg [6:0] funct7;
reg branch_taken;

// FIX: Register initialization using an explicit loop
integer i;
initial begin
    for (i = 0; i < 32; i = i + 1) begin
        regs[i] = 0;
    end
    pc = 0;
    result = 0;
    branch_taken = 0;
end


always @(posedge clk or posedge reset) begin
    if (reset) begin
        pc <= 0;
        result <= 0;
        branch_taken <= 0;
    end else begin
        IF_ID_instr <= instruction;
        IF_ID_pc <= pc;
        
        if (!branch_taken) begin
            pc <= pc + 4;
        end
        branch_taken <= 0; // Reset branch flag

        
        opcode  <= IF_ID_instr[6:0];
        rd      <= IF_ID_instr[11:7];
        funct3  <= IF_ID_instr[14:12];
        rs1     <= IF_ID_instr[19:15];
        rs2     <= IF_ID_instr[24:20];
        imm     <= IF_ID_instr[31:20];
        funct7  <= IF_ID_instr[31:25];

        ID_EX_instr <= IF_ID_instr;
        ID_EX_pc <= IF_ID_pc;
        ID_EX_imm <= {{20{imm[11]}}, imm}; 

        
        $display("Time=%0t | PC=%h | Decoding: OPCODE=%b, RD=%d, RS1=%d, RS2=%d, IMM=%d", 
                 $time, pc, opcode, rd, rs1, rs2, ID_EX_imm);

        // Execute Stage
        EX_MEM_instr <= ID_EX_instr;
        EX_MEM_pc <= ID_EX_pc;
        EX_MEM_rd <= rd;  // FIX: Store RD for write-back

        case (opcode)
            7'b0110011: begin 
                case (funct3)
                    3'b000: begin
                        if (funct7 == 7'b0000000) begin
                            EX_MEM_result <= regs[rs1] + regs[rs2]; // ADD
                        end else if (funct7 == 7'b0100000) begin
                            EX_MEM_result <= regs[rs1] - regs[rs2]; // SUB
                        end
                    end
                endcase
            end
            7'b0010011: begin // I-type (ADDI)
                case (funct3)
                    3'b000: begin
                        EX_MEM_result <= regs[rs1] + ID_EX_imm; // ADDI
                    end
                endcase
            end
            7'b1100011: begin // Branch (BEQ, BNE)
                case (funct3)
                    3'b000: begin // BEQ
                        if (regs[rs1] == regs[rs2]) begin
                            pc <= ID_EX_pc + {{19{ID_EX_instr[31]}}, ID_EX_instr[31], ID_EX_instr[7], ID_EX_instr[30:25], ID_EX_instr[11:8], 1'b0};
                            branch_taken <= 1;
                        end
                    end
                    3'b001: begin // BNE
                        if (regs[rs1] != regs[rs2]) begin
                            pc <= ID_EX_pc + {{19{ID_EX_instr[31]}}, ID_EX_instr[31], ID_EX_instr[7], ID_EX_instr[30:25], ID_EX_instr[11:8], 1'b0};
                            branch_taken <= 1;
                        end
                    end
                endcase
            end
            7'b1101111: begin // JAL
                EX_MEM_result <= ID_EX_pc + 4;
                pc <= ID_EX_pc + {{11{ID_EX_instr[31]}}, ID_EX_instr[31], ID_EX_instr[19:12], ID_EX_instr[20], ID_EX_instr[30:21], 1'b0};
                branch_taken <= 1;
            end
            7'b1100111: begin // JALR
                EX_MEM_result <= ID_EX_pc + 4;
                pc <= (regs[rs1] + ID_EX_imm) & ~1;
                branch_taken <= 1;
            end
        endcase

        
        $display("Time=%0t | ALU Result=%h, Writing to RD=%d", $time, EX_MEM_result, EX_MEM_rd);

        
        MEM_WB_instr <= EX_MEM_instr;
        MEM_WB_pc <= EX_MEM_pc;
        MEM_WB_result <= EX_MEM_result;
        MEM_WB_rd <= EX_MEM_rd; // FIX: Store RD correctly

       
        if (MEM_WB_instr[6:0] != 7'b1100011 && MEM_WB_instr[6:0] != 7'b1101111 && MEM_WB_instr[6:0] != 7'b1100111) begin
            if (MEM_WB_rd != 5'b00000) begin // Don't write to x0
                regs[MEM_WB_rd] <= MEM_WB_result;
                $display("Time=%0t | Writing %h to x%d", $time, MEM_WB_result, MEM_WB_rd);
            end
        end
    end
end

endmodule
