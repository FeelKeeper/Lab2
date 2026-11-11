module apb_counter
(
    input pclk,                  // синхросигнал
    input presetn,               // сброс (инверсный)
    input [31:0] paddr,          // адрес обращения
    input [31:0] pwdata,         // данные для записи
    input psel,                  // признак выбора устройства
    input penable,               // вторая фаза обмена
    input pwrite,                // 1 - запись, 0 - чтение
    output logic pready,         // готовность
    output logic pslverr,        // признак ошибки обращения
    output logic [31:0] prdata   // прочитанные данные
);

logic [31:0] max_value;          // регистр 0x0
logic run;                       // бит 0 контрольного регистра
logic clear;                     // бит 1 контрольного регистра (на один такт)
logic [31:0] counter;            // регистр 0x8

// состояния автомата APB
enum logic [1:0] {
    APB_SETUP,
    APB_W_ENABLE,
    APB_R_ENABLE
} apb_st;

// автомат обмена по APB
always @(posedge pclk)
    if (!presetn)
    begin
        prdata <= '0;
        pslverr <= 1'b0;
        pready <= 1'b0;
        max_value <= 32'h0;
        run <= 1'b0;
        clear <= 1'b0;
        apb_st <= APB_SETUP;
    end
    else
    begin
        case (apb_st)
            APB_SETUP:
            begin
                prdata <= '0;
                pready <= 1'b0;
                pslverr <= 1'b0;
                clear <= 1'b0;
                if (psel && !penable)
                begin
                    if (pwrite)
                        apb_st <= APB_W_ENABLE;
                    else
                        apb_st <= APB_R_ENABLE;
                end
            end

            APB_W_ENABLE:
            begin
                pready <= 1'b1;
                case (paddr[7:0])
                    8'h0: begin
                        max_value <= pwdata;
                        $display("SLAVE: WRITE max_value addr=%h data=%h", paddr, pwdata);
                    end
                    8'h4: begin
                        run <= pwdata[0];
                        clear <= pwdata[1];
                        $display("SLAVE: WRITE control addr=%h data=%h", paddr, pwdata);
                    end
                    default: begin
                        // 0x8 только для чтения, другие адреса не существуют
                        pslverr <= 1'b1;
                        $display("SLAVE: WRITE ERROR addr=%h", paddr);
                    end
                endcase
                apb_st <= APB_SETUP;
            end

            APB_R_ENABLE:
            begin
                pready <= 1'b1;
                case (paddr[7:0])
                    8'h0: begin
                        prdata <= max_value;
                        $display("SLAVE: READ max_value addr=%h data=%d", paddr, max_value);
                    end
                    8'h4: begin
                        prdata <= {31'b0, run};
                        $display("SLAVE: READ control addr=%h data=%d", paddr, {31'b0, run});
                    end
                    8'h8: begin
                        prdata <= counter;
                        $display("SLAVE: READ counter addr=%h data=%d", paddr, counter);
                    end
                    default: begin
                        pslverr <= 1'b1;
                        $display("SLAVE: READ ERROR addr=%h", paddr);
                    end
                endcase
                apb_st <= APB_SETUP;
            end

            default:
                apb_st <= APB_SETUP;
        endcase
    end

// сам счётчик: считает на каждом такте, пока run = 1
always @(posedge pclk)
    if (!presetn)
        counter <= 32'h0;
    else if (clear)
        counter <= 32'h0;                 // сброс по команде
    else if (run)
    begin
        repeat(4) @(posedge pclk);
        if (counter >= max_value)
            counter <= 32'h0;             // дошли до максимума - начинаем заново
        else
            counter <= counter + 1;
    end

endmodule
