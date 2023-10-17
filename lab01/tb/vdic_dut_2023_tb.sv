/*
 Copyright 2013 Ray Salemi

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.

 History:
 2021-10-05 RSz, AGH UST - test modified to send all the data on negedge clk
 and check the data on the correct clock edge (covergroup on posedge
 and scoreboard on negedge). Scoreboard and coverage removed.
 */

module top;

//------------------------------------------------------------------------------
// Type definitions
//------------------------------------------------------------------------------

typedef enum bit[2:0] {
    no_op  = 3'b000,
    add_op = 3'b001,
    and_op = 3'b010,
    xor_op = 3'b011,
    mul_op = 3'b100,
    rst_op = 3'b111
} operation_t;

typedef enum bit {
    TEST_PASSED,
    TEST_FAILED
} test_result_t;

typedef enum {
    COLOR_BOLD_BLACK_ON_GREEN,
    COLOR_BOLD_BLACK_ON_RED,
    COLOR_BOLD_BLACK_ON_YELLOW,
    COLOR_BOLD_BLUE_ON_WHITE,
    COLOR_BLUE_ON_WHITE,
    COLOR_DEFAULT
} print_color_t;

//------------------------------------------------------------------------------
// Local variables
//------------------------------------------------------------------------------

logic signed    [15:0]  arg_a;
logic signed    [15:0]  arg_b;
logic                   clk;
logic                   rst_n;
logic 				    arg_a_parity;
logic 				    arg_b_parity;
logic				    ack;
logic 				    req;
logic           [31:0]  result;
logic 				    result_parity;
logic 				    result_rdy;
logic 				    arg_parity_error;

test_result_t        test_result = TEST_PASSED;

//------------------------------------------------------------------------------
// DUT instantiation
//------------------------------------------------------------------------------

vdic_dut_2023 DUT (.arg_a, .arg_b, .clk, .rst_n, .arg_a_parity, .arg_b_parity, .ack, .req,
 .result, .result_parity, .result_rdy, .arg_parity_error);

//------------------------------------------------------------------------------
// Clock generator
//------------------------------------------------------------------------------

initial begin : clk_gen_blk
    clk = 0;
    forever begin : clk_frv_blk
        #10;
        clk = ~clk;
    end
end

// timestamp monitor
initial begin
    longint clk_counter;
    clk_counter = 0;
    forever begin
        @(posedge clk) clk_counter++;
        if(clk_counter % 1000 == 0) begin
            $display("%0t Clock cycles elapsed: %0d", $time, clk_counter);
        end
    end
end

//------------------------------------------------------------------------------
// Tester
//------------------------------------------------------------------------------

//---------------------------------
// Random data generation functions

//cos tu trzeba XD

//---------------------------------
function logic signed [15:0] get_data();

    bit [2:0] zero_ones;
    zero_ones = 3'($random);

    if (zero_ones == 3'b000)
        return 16'sh8000;
    else if (zero_ones == 3'b111)
        return 16'sh7FFF;
    else
        return 16'($random);
endfunction : get_data

//------------------------
// Tester main

initial begin : tester
	logic signed [31:0] expected;
    reset();
    repeat (1000) begin : tester_main_blk
        @(posedge clk)
        arg_a = get_data();
        arg_b = get_data();
        req  = 1'b1;
        
        arg_a_parity = ^arg_a;
	    arg_b_parity = ^arg_b;
	    if(arg_parity_error) begin
		    $display("Parity error:%0d", result_parity);
		   end
        wait(ack);
	    wait(result_rdy);
                    expected = get_expected(arg_a, arg_b);
                    if(result === expected && result_parity ==^expected) begin
                        $display("Test passed for arg_a=%0d arg_b=%0d", arg_a, arg_b);
                    end
                    else begin
                        $display("Test FAILED for arg_a=%0d arg_b=%0d", arg_a, arg_b);
                        $display("Expected: %d  received: %d", expected, result);
                        test_result = TEST_FAILED;
                    end
    end : tester_main_blk
    $finish;
end : tester

//------------------------------------------------------------------------------
// reset task
//------------------------------------------------------------------------------

task reset();
    req   = 1'b0;
    rst_n = 1'b0;
    @(negedge clk);
    rst_n = 1'b1;
endtask : reset

//------------------------------------------------------------------------------
// calculate expected result
//------------------------------------------------------------------------------

function logic [31:0] get_expected(
        logic signed [15:0] arg_a,
        logic signed [15:0] arg_b
    );
    logic signed [31:0] ret;
    ret = arg_a*arg_b;
    return(ret);
endfunction : get_expected

//------------------------------------------------------------------------------
// Temporary. The scoreboard will be later used for checking the data
final begin : finish_of_the_test
    print_test_result(test_result);
end

//------------------------------------------------------------------------------
// Other functions
//------------------------------------------------------------------------------

// used to modify the color of the text printed on the terminal
function void set_print_color ( print_color_t c );
    string ctl;
    case(c)
        COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m";
        COLOR_BOLD_BLACK_ON_RED : ctl    = "\033\[1;30m\033\[101m";
        COLOR_BOLD_BLACK_ON_YELLOW : ctl = "\033\[1;30m\033\[103m";
        COLOR_BOLD_BLUE_ON_WHITE : ctl   = "\033\[1;34m\033\[107m";
        COLOR_BLUE_ON_WHITE : ctl        = "\033\[0;34m\033\[107m";
        COLOR_DEFAULT : ctl              = "\033\[0m\n";
        default : begin
            $error("set_print_color: bad argument");
            ctl                          = "";
        end
    endcase
    $write(ctl);
endfunction

function void print_test_result (test_result_t r);
    if(r == TEST_PASSED) begin
        set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
        $write ("-----------------------------------\n");
        $write ("----------- Test PASSED -----------\n");
        $write ("-----------------------------------");
        set_print_color(COLOR_DEFAULT);
        $write ("\n");
    end
    else begin
        set_print_color(COLOR_BOLD_BLACK_ON_RED);
        $write ("-----------------------------------\n");
        $write ("----------- Test FAILED -----------\n");
        $write ("-----------------------------------");
        set_print_color(COLOR_DEFAULT);
        $write ("\n");
    end
endfunction


endmodule : top
