# RISC-V SoC trên FPGA

Project thiết kế một **System-on-Chip (SoC)** bằng Verilog HDL để triển
khai trên FPGA. Hệ thống sử dụng CPU **RISC-V RV32I 32-bit** với Pipeline
5 tầng, kết nối với memory và các peripheral UART, GPIO, I2C thông qua
Memory-Mapped I/O.

Mục tiêu của project là chạy chương trình RISC-V trực tiếp trên FPGA và
điều khiển peripheral tương tự một vi điều khiển đơn giản.

## Kiến trúc hệ thống

```text
                    RISC-V RV32I CPU Core
                    IF → ID → EX → MEM → WB
                         │             │
             Instruction bus      Data/MMIO bus
                         │             │
             Instruction Memory   Address Decoder
                                       │
                                      ├── Data Memory
                                      ├── UART ── PC
                                      ├── GPIO ── LED/Switch
                                      └── I2C ─── LCD I2C
```

CPU xử lý instruction qua 5 Pipeline stage:

- **IF:** lấy instruction từ Instruction Memory.
- **ID:** decode instruction và đọc Register File.
- **EX:** thực hiện phép toán hoặc tính địa chỉ.
- **MEM:** truy cập Data Memory hoặc peripheral.
- **WB:** ghi kết quả về Register File.

Datapath dự kiến hỗ trợ Forwarding, Hazard Detection, Stall và Flush để
xử lý data hazard và control hazard.

## Chức năng chính

- Thực thi chương trình theo kiến trúc RISC-V RV32I 32-bit.
- Tổ chức CPU theo Pipeline 5 tầng.
- Đọc và ghi Instruction Memory, Data Memory.
- Truy cập peripheral bằng Memory-Mapped I/O.
- Giao tiếp với PC và xuất thông tin debug qua UART.
- Điều khiển LED, đọc switch hoặc button qua GPIO.
- Điều khiển thiết bị ngoài qua I2C.
- Tổng hợp và triển khai Full SoC trên FPGA bằng Intel Quartus Prime.

## Trạng thái

Project đang trong quá trình phát triển. Module I2C đã được implement,
kiểm thử và xác nhận hoạt động thực tế với LCD I2C. CPU, memory, UART,
GPIO và lớp tích hợp Memory-Mapped I/O được phát triển theo các mốc trong
phần roadmap.

## Roadmap

- [ ] Hoàn thiện các khối cơ bản của CPU: PC, ALU, Register File,
      Decoder, Control Unit và Immediate Generator.
- [ ] Hoàn thiện datapath và kiểm thử các nhóm instruction RV32I.
- [ ] Tích hợp Pipeline 5 tầng.
- [ ] Hoàn thiện Forwarding, Hazard Detection, Stall và Flush.
- [ ] Tích hợp Instruction Memory, Data Memory và address decoder.
- [ ] Tích hợp UART qua Memory-Mapped I/O.
- [ ] Tích hợp GPIO qua Memory-Mapped I/O.
- [x] Implement và kiểm thử module I2C với LCD I2C.
- [ ] Tích hợp module I2C vào SoC qua Memory-Mapped I/O.
- [ ] Tổng hợp, kiểm tra timing và chạy Full SoC trên FPGA.

## Mục tiêu demo

Chương trình RISC-V chạy trên CPU sẽ:

1. Gửi thông báo khởi động tới terminal PC qua UART.
2. Đọc trạng thái switch hoặc button qua GPIO.
3. Điều khiển LED theo kết quả xử lý.
4. Gửi dữ liệu tới LCD thông qua I2C.

Demo cuối cùng phải chứng minh UART, GPIO và I2C được điều khiển bởi
software chạy trên CPU của SoC.

## Verification

Thiết kế được kiểm thử theo từng module trước khi tích hợp. Các nội dung
verification chính gồm:

- Chức năng của ALU, Register File, Decoder và Control Unit.
- Kết quả thực thi từng nhóm instruction được hỗ trợ.
- Forwarding, load-use stall và branch flush.
- Hoạt động đọc/ghi memory và giải mã vùng địa chỉ.
- Giao tiếp UART, GPIO và I2C độc lập.
- Chương trình kiểm thử và demo trên Full SoC.
- Kết quả synthesis, resource utilization và timing trên FPGA.

## Phạm vi

Project tập trung vào:

- CPU RISC-V RV32I Pipeline 5 tầng.
- Instruction Memory và Data Memory.
- Memory-Mapped I/O.
- UART, GPIO và I2C.
- Simulation, verification và triển khai trên FPGA.

Các thành phần sau không nằm trong phạm vi hiện tại:

- Cache và MMU.
- DDR và AXI.
- Linux.
- Multi-core.
- FPU.
- Out-of-Order Execution.

## Công cụ và tài liệu

- [RISC-V ISA Manual](https://github.com/riscv/riscv-isa-manual) — đặc
  tả kiến trúc RISC-V.
- [RISC-V Opcodes](https://github.com/riscv/riscv-opcodes) — encoding
  của instruction.
- [RISC-V GNU Toolchain](https://github.com/riscv-collab/riscv-gnu-toolchain)
  — compiler và assembler cho chương trình RISC-V.
- [RISC-V Architectural Tests](https://github.com/riscv-non-isa/riscv-arch-test)
  — tài liệu và test tham khảo cho verification.
- [Intel Quartus Prime](https://www.intel.com/content/www/us/en/software/programmable/quartus-prime/overview.html)
  — synthesis, timing analysis và cấu hình FPGA.
- [PicoRV32](https://github.com/YosysHQ/picorv32) và
  [Ibex](https://github.com/lowRISC/ibex) — CPU core mã nguồn mở dùng để
  tham khảo kiến trúc và phương pháp verification.
