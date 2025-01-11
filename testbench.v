
// testbench
module testbench();
    reg clk;
    reg reset;
    wire [31:0] writedata, dataadr;
    wire memwrite;

    // create the mips cpu
    mips_cpu mcpu (
        .clk(clk),
        .reset(reset),
        .writedata(writedata),
        .dataadr(dataadr),
        .memwrite(memwrite)
    );

    // initialize the cpu
    // and monitor the memory
    initial begin
        reset <= 1; #22;
        reset <= 0;
        $display("\t\ttime\t\tdataadr\t\twritedata");
        $monitor("%d\t%d\t%d", $time, dataadr, writedata);
    end

    // generate clk signal
    always begin
        clk <= 1; #5;
        clk <= 0; #5;
    end

    // Check for successful write to address 84 with data 7
    // if so then stop the simulation
    always @(negedge clk) begin
        if (memwrite) begin
            if (dataadr === 84 && writedata === 7) begin
                $display("SIMULATION DONE");
                $stop;
            end
        end
    end
endmodule

