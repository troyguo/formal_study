//
// Combination Lock demo
// Created to demo FPV basics, not claiming to be a good RTL design!
// For the purpose of illustrating the power of FPV, we made this a bit
// convoluted so you can't easily read the correct combo value by looking
// at the code.
//

// Define consts for one-asserted digit values
parameter bit [9:0]  C0 = 10'b1;
parameter bit [9:0]  C1 = 10'b10;
parameter bit [9:0]  C2 = 10'b100;
parameter bit [9:0]  C3 = 10'b1000;
parameter bit [9:0]  C4 = 10'b10000;
parameter bit [9:0]  C5 = 10'b100000;
parameter bit [9:0]  C6 = 10'b1000000;
parameter bit [9:0]  C7 = 10'b10000000;
parameter bit [9:0]  C8 = 10'b100000000;
parameter bit [9:0]  C9 = 10'b1000000000;


//`define PAST_FIRST_DEBUG_STAGE 1
//`define PAST_SECOND_DEBUG_STAGE 1
//`define PAST_THIRD_DEBUG_STAGE 1

parameter bit [63:0] INTERNAL_COMBO = 64'h000aaa0000000aaa;
`ifndef PAST_SECOND_DEBUG_STAGE
parameter bit [9:0]  COMBO_FIRST_PART [3:0]  = '{C0,C1,C2,C3};
parameter bit [9:0]  COMBO_SECOND_PART [3:0] = '{C0,C1,C2,C3};
parameter bit [9:0]  COMBO_THIRD_PART [3:0]  = '{C0,C1,C2,C3};
`else 
`ifndef PAST_THIRD_DEBUG_STAGE
parameter bit [9:0]  COMBO_FIRST_PART [3:0]  = '{C2,C7,C3,C3};
parameter bit [9:0]  COMBO_SECOND_PART [3:0] = '{C0,C0,C0,C3};
parameter bit [9:0]  COMBO_THIRD_PART [3:0]  = '{C2,C7,C3,C3};
`else
parameter bit [9:0]  COMBO_FIRST_PART [3:0]  = '{C2,C7,C3,C0};
parameter bit [9:0]  COMBO_SECOND_PART [3:0] = '{C0,C0,C0,C0};
parameter bit [9:0]  COMBO_THIRD_PART [3:0]  = '{C2,C7,C3,C0};
`endif
`endif


`ifndef PAST_THIRD_DEBUG_STAGE
parameter bit [13:0] ONE = 14'd0;
`else
parameter bit [13:0] ONE = 14'd1;
`endif

module decoder (
    input bit clk, rst,
    input bit [9:0] digits [3:0],
    output bit [63:0] combo
);

    // Store the last two values of 'digits'
    bit [9:0] digits_save[2:0][3:0];
    assign digits_save[0] = digits;
    always @(posedge clk or posedge rst) begin
        if (rst) begin
           digits_save[1] <= '{0,0,0,0};
           digits_save[2] <= '{0,0,0,0};
        end else begin
           digits_save[1] <= digits_save[0];
           digits_save[2] <= digits_save[1];
        end
    end

    // Convert to our binary combo.  To simplify, each 4-digit
    // subfield gets its own 20-bit slot.
    int i,j,k, cur, digit_val;
    always_comb begin
        combo = 0;
        for (i=0;i<3;i++) begin
            cur = 0;
            for (j=0;j<4;j++) begin
                digit_val = (j==0) ? ONE : 
                                (j==1) ? 14'd10 :
                                (j==2) ? 14'd100 : 
                                14'd1000; 
                for (k=0;k<10;k++) begin
                    cur = cur + (digits_save[i][j][k]*digit_val*k);
                end
            end
            combo = combo + (cur<<(i*20));
        end
    end
endmodule

module combination_checker (
    input bit clk, rst, override,
    input bit [63:0] combo,
    output bit open
);
    always @(posedge clk or posedge rst) begin
        if (rst) open <= 0;
        else open <= ((combo==INTERNAL_COMBO)||override);
    end

endmodule   


module combination_lock (
    input bit [9:0] digits [3:0], 
    input bit override,
    input bit clk, rst,
    output bit open
    );

    bit [63:0] combo;
    decoder d1(clk, rst, digits, combo);
    combination_checker cc(clk, rst, override, combo, open);

    // Properties
    default clocking @(posedge clk); endclocking
    default disable iff (rst);
	
	//1. cover point
    //lock&unclock
    c1: cover property (open == 0);
    c2: cover property (open == 1);

    generate for (genvar i=0; i<4; i++) begin
        for (genvar j=0; j<10; j++) begin
            c3: cover property (digits[i][j] == 1);
        end
    end
    endgenerate

    generate for (genvar i = 0; i<4; i++) begin
        a1: assume property ($onehot(digits[i]));
    end
    endgenerate

    sequence correct_combo_entered;
             (digits == COMBO_FIRST_PART) ##1 
             (digits == COMBO_SECOND_PART) ##1
             (digits == COMBO_THIRD_PART);
    endsequence

    open_good:  assert property (correct_combo_entered |=> open);
	
    open_ok2: assert property(open |-> $past(digits, 3) == COMBO_FIRST_PART);
    open_ok1: assert property(open |-> $past(digits, 2) == COMBO_SECOND_PART);
    open_ok0: assert property(open |-> $past(digits, 1) == COMBO_THIRD_PART);


    // Assumption added after first stage of debug
    `ifdef PAST_FIRST_DEBUG_STAGE
    Page99_fix1:  assume property (override == 0);
    `endif

    

endmodule 



