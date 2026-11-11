module apb_master
(
    input pclk,                    // синхросигнал
    input presetn,                 // сброс (инверсный)
    input pready,                  // готовность от slave
    input pslverr,                 // ошибка от slave
    input [31:0] prdata,           // данные от slave
    output logic psel,             // выбор устройства
    output logic penable,          // вторая фаза обмена
    output logic pwrite,           // 1 - запись, 0 - чтение
    output logic [31:0] paddr,     // адрес
    output logic [31:0] pwdata     // данные для записи
);

parameter p_device_offset = 32'h7000_0000;

logic [31:0] data;                 // прочитанное значение
logic [31:0] data2;                // второе прочитанное значение

// запись по APB
task apb_write(input [31:0] addr, [31:0] wdata);
    wait ((penable==0) && (pready == 0));
    @(posedge pclk);
    psel <= 1'b1;
    paddr[31:0] <= addr[31:0];
    pwdata[31:0] <= wdata[31:0];
    pwrite <= 1'b1;
    @(posedge pclk);
    penable <= 1'b1;
    @(posedge pclk);
    wait (pready == 1'b1);
    @(posedge pclk);
    if (pslverr) $display("MASTER: slave returned error on write addr=%h", addr);
    psel <= 1'b0;
    penable <= 1'b0;
    pwrite <= 1'b0;
    @(posedge pclk);
endtask

// чтение по APB
task apb_read(input [31:0] addr, output logic [31:0] rdata);
    wait ((penable==0) && (pready == 0));
    @(posedge pclk);
    psel <= 1'b1;
    pwrite <= 1'b0;
    paddr[31:0] <= addr[31:0];
    @(posedge pclk);
    penable <= 1'b1;
    @(posedge pclk);
    wait (pready == 1'b1);
    @(posedge pclk);
    if (pslverr) $display("MASTER: slave returned error on read addr=%h", addr);
    rdata[31:0] <= prdata[31:0];
    psel <= 1'b0;
    penable <= 1'b0;
    @(posedge pclk);
endtask

// проверка значения: got должно быть равно expected
task check(input [31:0] got, input [31:0] expected);
    if (got === expected)
        $display("CHECK OK:   got=0x%h", got);
    else
        $display("CHECK FAIL: got=0x%h expected=0x%h", got, expected);
endtask

// тестовая последовательность
initial
begin
    psel = '0;
    penable = '0;
    pwrite = '0;
    paddr = '0;
    pwdata = '0;

    // ждём, пока пройдёт сброс
    wait (presetn == 1'b0);
    wait (presetn == 1'b1);
    repeat (5) @(posedge pclk);

    // 1. после сброса все регистры равны 0
    $display("--- 1. values after reset");
    apb_read(p_device_offset + 32'h0, data); check(data, 32'h0);
    apb_read(p_device_offset + 32'h4, data); check(data, 32'h0);
    apb_read(p_device_offset + 32'h8, data); check(data, 32'h0);

    // 2. записываем максимум 5 и читаем обратно
    $display("--- 2. max = 9");
    apb_write(p_device_offset + 32'h0, 32'd9);
    apb_read(p_device_offset + 32'h0, data); check(data, 32'd9);

    // 3. запуск счёта, читаем текущее значение несколько раз
    $display("--- 3. start counter, values must be from 0 to 5");
    apb_write(p_device_offset + 32'h4, 32'h1);
    apb_read(p_device_offset + 32'h4, data); check(data, 32'h1);
    repeat (20)
    begin
        //repeat (1) @(posedge pclk);       // пауза, чтобы значения шли подряд
        apb_read(p_device_offset + 32'h8, data);
        $display("counter = %0d", data);
        if (data > 32'd9) $display("CHECK FAIL: counter above max");
    end

    // 4. остановка: два чтения подряд дают одно и то же значение
    $display("--- 4. stop counter");
    apb_write(p_device_offset + 32'h4, 32'h0);
    apb_read(p_device_offset + 32'h8, data);
    repeat (5) @(posedge pclk);
    apb_read(p_device_offset + 32'h8, data2);
    check(data2, data);

    // 5. сброс счётчика (бит 1 контрольного регистра)
    $display("--- 5. reset counter");
    apb_write(p_device_offset + 32'h4, 32'h2);
    apb_read(p_device_offset + 32'h8, data); check(data, 32'h0);

    // 6. максимум 0: счётчик остаётся нулём
    $display("--- 6. max = 0");
    apb_write(p_device_offset + 32'h0, 32'd0);
    apb_write(p_device_offset + 32'h4, 32'h1);
    repeat (5) @(posedge pclk);
    apb_read(p_device_offset + 32'h8, data); check(data, 32'h0);
    apb_write(p_device_offset + 32'h4, 32'h0);

    // 7. максимум 1: счётчик переключается между 0 и 1
    $display("--- 7. max = 1");
    apb_write(p_device_offset + 32'h0, 32'd1);
    apb_write(p_device_offset + 32'h4, 32'h1);
    repeat (6)
    begin
        apb_read(p_device_offset + 32'h8, data);
        $display("counter = %0d", data);
        if (data > 32'd1) $display("CHECK FAIL: counter above max");
    end
    apb_write(p_device_offset + 32'h4, 32'h0);

    // 8. ошибочные обращения: запись в 0x8 и чтение/запись по несуществующему адресу
    $display("--- 8. checking for incorrect adresses (expect errors)");
    apb_write(p_device_offset + 32'h8, 32'h1);
    apb_write(p_device_offset + 32'hC, 32'h1);
    apb_read(p_device_offset + 32'hC, data);

    repeat (10) @(posedge pclk);
    $stop();
end

endmodule
