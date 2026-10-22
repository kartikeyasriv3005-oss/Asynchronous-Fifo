
module async_fifo (
    input  wire       wr_clk,
    input  wire       rd_clk,
    input  wire       rst_n,
    input  wire       wr_en,
    input  wire [7:0] din,
    input  wire       rd_en,
    output reg  [7:0] dout,
    output reg        empty,
    output reg        full
);

    reg [7:0] mem [0:15];

    reg [4:0] wbin;
    reg [4:0] rbin;

    wire [4:0] wgray;
    wire [4:0] rgray;

    reg [4:0] wgray_r1, wgray_r2;
    reg [4:0] rgray_w1, rgray_w2;

    wire [4:0] wbin_next;
    wire [4:0] rbin_next;
    wire [4:0] wgray_next;
    wire [4:0] rgray_next;

    wire full_next;
    wire empty_next;

    assign wgray = wbin ^ (wbin >> 1);
    assign rgray = rbin ^ (rbin >> 1);

    assign wbin_next =
        wbin + ((wr_en && !full) ? 5'd1 : 5'd0);

    assign rbin_next =
        rbin + ((rd_en && !empty) ? 5'd1 : 5'd0);

    assign wgray_next = wbin_next ^ (wbin_next >> 1);
    assign rgray_next = rbin_next ^ (rbin_next >> 1);

    assign empty_next = (rgray_next == wgray_r2);

    assign full_next =
        (wgray_next == {~rgray_w2[4:3], rgray_w2[2:0]});

    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            wbin <= 5'b00000;
            full <= 1'b0;
        end else begin
            full <= full_next;

            if (wr_en && !full) begin
                mem[wbin[3:0]] <= din;
                wbin <= wbin_next;
            end
        end
    end

    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            rbin  <= 5'b00000;
            dout  <= 8'b00000000;
            empty <= 1'b1;
        end else begin
            empty <= empty_next;

            if (rd_en && !empty) begin
                dout <= mem[rbin[3:0]];
                rbin <= rbin_next;
            end
        end
    end

    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            wgray_r1 <= 5'b00000;
            wgray_r2 <= 5'b00000;
        end else begin
            wgray_r1 <= wgray;
            wgray_r2 <= wgray_r1;
        end
    end

    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            rgray_w1 <= 5'b00000;
            rgray_w2 <= 5'b00000;
        end else begin
            rgray_w1 <= rgray;
            rgray_w2 <= rgray_w1;
        end
    end

endmodule
