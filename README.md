# RISC-V SoC trên FPGA

## Mục tiêu project

Project hướng tới thiết kế một **System-on-Chip (SoC)** bằng Verilog/SystemVerilog và triển khai trên kit FPGA.
SoC sử dụng CPU RISC-V RV32I 32-bit làm trung tâm xử lý. CPU sẽ chạy chương trình trong Instruction Memory,
truy cập Data Memory và điều khiển các peripheral thông qua cơ chế **Memory-Mapped I/O**.

Mục tiêu của project là xây dựng một hệ thống có cách hoạt động tương tự một vi điều khiển đơn giản:
software chạy trên CPU sẽ đọc input, xử lý dữ liệu và điều khiển các thiết bị bên ngoài thông qua các địa chỉ
được ánh xạ trong không gian memory.

## Kiến trúc dự kiến

```text
                         RISC-V RV32I CPU
                                  │
                ┌─────────────────┴─────────────────┐
                │                                   │
        Instruction bus                       Data/MMIO bus
                │                                   │
       Instruction Memory                  Address Decoder
                                                    │
                                  ┌─────────────────┼─────────────────┐
                                  │                 │                 │
                             Data Memory         GPIO              UART
                                  │                 │                 │
                                  │           LED/Switch       Laptop terminal
                                  │
                                  └────────────── I2C ────────────────┐
                                                                         │
                                                                        LCD
```

CPU được tổ chức theo pipeline 5 tầng:

1. **IF — Instruction Fetch:** lấy instruction từ Instruction Memory.
2. **ID — Instruction Decode:** giải mã instruction và đọc Register File.
3. **EX — Execute:** thực hiện phép toán hoặc tính địa chỉ.
4. **MEM — Memory Access:** truy cập memory hoặc peripheral.
5. **WB — Write Back:** ghi kết quả về Register File.

Các khối chính cần hoàn thiện gồm PC, ALU, Register File, Decoder, Control Unit, Immediate Generator,
datapath pipeline, hazard handling, Instruction Memory, Data Memory và address decoder.

## Peripheral và chức năng demo

### GPIO

GPIO dùng để đọc các input vật lý như switch hoặc button và điều khiển LED trên kit FPGA.
Ví dụ demo: CPU đọc trạng thái switch rồi bật/tắt LED tương ứng. GPIO được truy cập thông qua các
register Memory-Mapped I/O.

### UART

UART dùng để giao tiếp serial giữa FPGA và laptop:

- `TX`: FPGA gửi thông báo khởi động, log debug hoặc kết quả xử lý tới terminal trên laptop.
- `RX`: FPGA nhận lệnh hoặc dữ liệu từ laptop.

Tốc độ baud rate, cách ánh xạ register và giao diện vật lý sẽ được xác định theo kit FPGA và mạch
USB-UART được sử dụng.

### I2C và LCD

I2C chỉ được sử dụng để demo điều khiển LCD. LCD có thể hiển thị thông báo khởi động, trạng thái input,
kết quả xử lý hoặc dữ liệu nhận từ UART.

Về kiến trúc SoC, I2C nên được tích hợp như một peripheral có các register Memory-Mapped I/O để software
trên CPU điều khiển việc truyền dữ liệu tới LCD.

## Demo cuối cùng dự kiến

Chương trình RISC-V chạy trên CPU sẽ thực hiện một chu trình đơn giản:

1. Khởi động và gửi thông báo tới laptop qua UART TX.
2. Đọc switch hoặc button thông qua GPIO.
3. Xử lý input và điều khiển LED.
4. Hiển thị trạng thái hoặc kết quả lên LCD thông qua I2C.
5. Có thể nhận lệnh điều khiển từ laptop qua UART RX.

Demo cần chứng minh rằng CPU có thể điều khiển GPIO, UART và I2C thông qua Memory-Mapped I/O.

## Trạng thái hiện tại

Project đang được phát triển theo từng lớp, từ các module cơ bản đến hệ thống SoC hoàn chỉnh.
Phần I2C-LCD được xem là nền tảng cho peripheral hiển thị, nhưng chưa được kết nối với CPU thông qua
Memory-Mapped I/O.

Các phần còn cần triển khai cho mục tiêu SoC gồm:

- CPU RISC-V RV32I và pipeline 5 tầng.
- Instruction Memory, Data Memory và address decoder.
- UART TX/RX dạng Memory-Mapped peripheral.
- GPIO dạng Memory-Mapped peripheral cho LED, switch và button.
- I2C peripheral dạng Memory-Mapped để điều khiển LCD.
- Chương trình firmware RISC-V dùng để chạy demo.
- Simulation, verification, synthesis, timing analysis và triển khai trên FPGA.

## Phạm vi project

Project tập trung vào:

- CPU RISC-V RV32I 32-bit.
- Pipeline 5 tầng và xử lý hazard cần thiết.
- Instruction Memory và Data Memory.
- Memory-Mapped I/O.
- UART TX/RX với laptop.
- GPIO cho LED, switch và button.
- I2C cho LCD.
- Simulation, verification và triển khai trên kit FPGA.

Các thành phần không thuộc phạm vi hiện tại:

- Cache và MMU.
- DDR và AXI.
- Linux.
- Multi-core.
- FPU.
- Out-of-Order Execution.

## Công cụ và phần cứng

Project không bị ràng buộc trong README này bởi một FPGA vendor, kit cụ thể hoặc một công cụ EDA cụ thể.
Các lựa chọn về FPGA kit, pin assignment, toolchain, synthesis tool và USB-UART interface sẽ được cập nhật
theo phần cứng và môi trường triển khai thực tế.
