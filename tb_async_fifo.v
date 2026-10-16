
`timescale 1ns/1ps

module tb_async_fifo;

    reg wr_clk = 0;
    reg rd_clk = 0;
    reg rst_n = 0;
    reg wr_en = 0;
    reg rd_en = 0;
    reg [7:0] din = 0;

    wire [7:0] dout;
    wire empty;
    wire full;

    localparam DEPTH = 16;
    localparam MAX_ITEMS = 4096;

    reg [7:0] expected [0:MAX_ITEMS-1];

    integer head = 0;
    integer tail = 0;
    integer errors = 0;

    integer i;
    integer wr_i;
    integer rd_i;
    integer drain_i;
    integer timeout;
    integer before_count;

    integer wr_seed;
    integer rd_seed;

    reg [31:0] wr_rand;
    reg [31:0] rd_rand;
    reg [7:0] wanted;

    async_fifo dut (
        .wr_clk(wr_clk),
        .rd_clk(rd_clk),
        .rst_n(rst_n),
        .wr_en(wr_en),
        .din(din),
        .rd_en(rd_en),
        .dout(dout),
        .empty(empty),
        .full(full)
    );

    always #5 wr_clk = ~wr_clk;
    always #7 rd_clk = ~rd_clk;


    // Scoreboard: record every accepted write.
    always @(posedge wr_clk) begin
        if (rst_n && wr_en && !full) begin
            if (tail < MAX_ITEMS) begin
                expected[tail] = din;
                tail = tail + 1;
            end
            else begin
                $display("ERROR: scoreboard capacity exceeded");
                errors = errors + 1;
            end
        end
    end


    // Scoreboard: check every accepted read.
    always @(posedge rd_clk) begin
        if (rst_n && rd_en && !empty) begin
            if (head >= tail) begin
                $display("ERROR at %0t: read with no expected data",
                         $time);
                errors = errors + 1;
            end
            else begin
                wanted = expected[head];

                #1;

                if (dout !== wanted) begin
                    $display(
                        "ERROR at %0t: expected=%02h actual=%02h",
                        $time, wanted, dout
                    );
                    errors = errors + 1;
                end
                else begin
                    $display(
                        "PASS at %0t: read=%02h",
                        $time, dout
                    );
                end

                head = head + 1;
            end
        end
    end


    // Write one item.
    task automatic write_item(input [7:0] value);
        begin
            @(negedge wr_clk);

            timeout = 0;
            while (full !== 1'b0 && timeout < 100) begin
                @(negedge wr_clk);
                timeout = timeout + 1;
            end

            if (full !== 1'b0) begin
                $display("ERROR: write timeout at %0t", $time);
                errors = errors + 1;
            end
            else begin
                din = value;
                wr_en = 1'b1;

                @(negedge wr_clk);
                wr_en = 1'b0;
            end
        end
    endtask


    // Read and verify one item.
    task automatic read_item;
        begin
            @(negedge rd_clk);

            timeout = 0;
            while (empty !== 1'b0 && timeout < 100) begin
                @(negedge rd_clk);
                timeout = timeout + 1;
            end

            if (empty !== 1'b0) begin
                $display("ERROR: read timeout at %0t", $time);
                errors = errors + 1;
            end
            else begin
                rd_en = 1'b1;

                @(negedge rd_clk);
                rd_en = 1'b0;
            end
        end
    endtask


    task automatic wait_for_full;
        begin
            timeout = 0;

            while (full !== 1'b1 && timeout < 100) begin
                @(posedge wr_clk);
                #1;
                timeout = timeout + 1;
            end

            if (full !== 1'b1) begin
                $display("ERROR: FIFO did not become full");
                errors = errors + 1;
            end
            else begin
                $display("PASS: FIFO reached full");
            end
        end
    endtask


    task automatic wait_for_empty;
        begin
            timeout = 0;

            while (empty !== 1'b1 && timeout < 100) begin
                @(posedge rd_clk);
                #1;
                timeout = timeout + 1;
            end

            if (empty !== 1'b1) begin
                $display("ERROR: FIFO did not become empty");
                errors = errors + 1;
            end
            else begin
                $display("PASS: FIFO reached empty");
            end
        end
    endtask


    initial begin
        $dumpfile("tb_async_fifo.vcd");
        $dumpvars(0, tb_async_fifo);

        rst_n = 1'b0;
        wr_en = 1'b0;
        rd_en = 1'b0;

        repeat (4) @(posedge wr_clk);
        @(negedge wr_clk);
        rst_n = 1'b1;

        repeat (4) @(posedge wr_clk);
        repeat (4) @(posedge rd_clk);
        #1;

        // TEST 1: RESET
        $display("\nTEST 1: RESET");

        if (empty === 1'b1 && full === 1'b0)
            $display("PASS: reset state");
        else begin
            $display("ERROR: reset flags incorrect");
            errors = errors + 1;
        end


        // TEST 2: READ WHILE EMPTY
        $display("\nTEST 2: READ WHILE EMPTY");

        before_count = head;

        @(negedge rd_clk);
        rd_en = 1'b1;

        @(posedge rd_clk);
        #1;

        if (empty !== 1'b1 || head != before_count) begin
            $display("ERROR: empty-read protection failed");
            errors = errors + 1;
        end
        else begin
            $display("PASS: read rejected while empty");
        end

        @(negedge rd_clk);
        rd_en = 1'b0;


        // TEST 3: FILL FIFO
        $display("\nTEST 3: FILL FIFO");

        for (i = 0; i < DEPTH; i = i + 1)
            write_item(8'h40 + i);

        wait_for_full();


        // TEST 4: WRITE WHILE FULL
        $display("\nTEST 4: WRITE WHILE FULL");

        before_count = tail;

        @(negedge wr_clk);
        din = 8'hEE;
        wr_en = 1'b1;

        @(posedge wr_clk);
        #1;

        if (full !== 1'b1 || tail != before_count) begin
            $display("ERROR: full-write protection failed");
            errors = errors + 1;
        end
        else begin
            $display("PASS: write rejected while full");
        end

        @(negedge wr_clk);
        wr_en = 1'b0;


        // TEST 5: READ ALL ITEMS IN ORDER
        $display("\nTEST 5: READ FIFO IN ORDER");

        for (i = 0; i < DEPTH; i = i + 1)
            read_item();

        wait_for_empty();


        // TEST 6: POINTER WRAPAROUND
        $display("\nTEST 6: POINTER WRAPAROUND");

        for (i = 0; i < 3; i = i + 1) begin
            for (wr_i = 0; wr_i < 12; wr_i = wr_i + 1)
                write_item(8'h60 + wr_i);

            for (rd_i = 0; rd_i < 12; rd_i = rd_i + 1)
                read_item();
        end

        wait_for_empty();


        // TEST 7: SIMULTANEOUS READ AND WRITE
        $display("\nTEST 7: SIMULTANEOUS READ AND WRITE");

        for (i = 0; i < 8; i = i + 1)
            write_item(8'hC0 + i);

        fork
            begin : writer_process
                for (wr_i = 0; wr_i < 20; wr_i = wr_i + 1)
                    write_item(8'hD0 + wr_i);
            end

            begin : reader_process
                for (rd_i = 0; rd_i < 20; rd_i = rd_i + 1)
                    read_item();
            end
        join

        for (i = 0; i < 8; i = i + 1)
            read_item();

        wait_for_empty();


        // TEST 8: RANDOMIZED STRESS
        $display("\nTEST 8: RANDOMIZED STRESS");

        wr_seed = 32'h13579BDF;
        rd_seed = 32'h2468ACE1;

        fork
            begin : random_writer
                repeat (300) begin
                    @(negedge wr_clk);

                    wr_rand = $urandom(wr_seed);
                    din = wr_rand[7:0];
                    wr_en = ((wr_rand % 100) < 65);
                end

                @(negedge wr_clk);
                wr_en = 1'b0;
            end

            begin : random_reader
                repeat (300) begin
                    @(negedge rd_clk);

                    rd_rand = $urandom(rd_seed);
                    rd_en = ((rd_rand % 100) < 65);
                end

                @(negedge rd_clk);
                rd_en = 1'b0;
            end
        join

        // Allow outstanding synchronizer updates to settle.
        repeat (4) @(posedge wr_clk);
        repeat (4) @(posedge rd_clk);

        // Drain the remaining accepted data.
        drain_i = 0;

        while (head < tail && drain_i < DEPTH) begin
            read_item();
            drain_i = drain_i + 1;
        end

        if (head < tail) begin
            $display("ERROR: unable to drain remaining FIFO data");
            errors = errors + 1;
        end

        wait_for_empty();


        // FINAL RESULT
        $display("\n==============================");

        if (head == tail && errors == 0)
            $display("ALL TESTS PASSED");
        else begin
            $display("TESTBENCH FAILED: errors=%0d head=%0d tail=%0d",
                     errors, head, tail);
        end

        $display("==============================");

        #20;
        $finish;
    end

endmodule
