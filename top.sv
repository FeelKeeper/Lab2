module top;

logic pclk;
logic presetn;
logic psel;
logic penable;
logic pwrite;
logic [31:0] paddr;
logic [31:0] pwdata;
wire [31:0] prdata;
wire pready;
wire pslverr;

// мастер (тестовая последовательность)
apb_master master
(
    .pclk(pclk),
    .presetn(presetn),
    .pready(pready),
    .pslverr(pslverr),
    .prdata(prdata),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .paddr(paddr),
    .pwdata(pwdata)
);

// проверяемое устройство
apb_counter counter
(
    .pclk(pclk),
    .presetn(presetn),
    .paddr(paddr),
    .pwdata(pwdata),
    .psel(psel),
    .penable(penable),
    .pwrite(pwrite),
    .pready(pready),
    .pslverr(pslverr),
    .prdata(prdata)
);

// тактовый сигнал
always #10 pclk = ~pclk;

// сброс
initial
begin
    $dumpfile("wave.vcd"); // Задаёт имя файла для сохранения
    $dumpvars(0, top);
    pclk = 0;
    presetn = 1'b1;
    repeat (5) @(posedge pclk);
    presetn = 1'b0;
    repeat (5) @(posedge pclk);
    presetn = 1'b1;
end

endmodule
