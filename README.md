# IEEE-754 Floating-Point Divider on FPGA

## Overview
This project implements and evaluates multiple IEEE-754 single-precision
floating-point divider architectures on FPGA. The goal is to compare
area, power, latency, and throughput trade-offs between a Xilinx IEEE-754
Divider IP core and custom subtractive divider designs.

## Implemented Architectures
- IEEE-754 Floating-Point Divider IP (Xilinx Vivado)
- Custom Subtractive Divider (Non-Pipelined)
- Custom Subtractive Divider (Pipelined)

All designs follow IEEE-754 single-precision format:
(-1)^sign × 1.fraction × 2^(exponent − 127)

## Key Concepts
- **Latency:** Number of clock cycles between valid input and valid output
- **Throughput:** Number of results produced per clock cycle after pipeline fill
- **Resource Usage:** LUTs, FFs, DSPs, and BRAM utilization
- **Maximum Clock Frequency (Fmax):** Determined by critical path timing

## Methodology
1. Implemented IEEE-754 field extraction (sign, exponent, mantissa)
2. Designed subtractive mantissa division logic
3. Used FSM-based control for non-pipelined architecture
4. Introduced deep pipelining for high-throughput design
5. Verified functionality using simulation waveforms
6. Synthesized and implemented designs in Xilinx Vivado
7. Extracted timing, utilization, and power reports

## Design Variants

### IEEE-754 Divider IP
- Latency: 29 cycles (configured)
- Throughput: 1 result per cycle
- Area: Medium (uses DSP blocks)
- Power: Highest (~53 mW dynamic)
- Best for full compliance and robust corner-case handling

### Non-Pipelined Subtractive Divider
- Latency: ~28 cycles
- Throughput: 1 result every 28 cycles
- Area: Very small (~0.75% LUT, ~0.42% FF)
- Power: Lowest (~6 mW dynamic)
- Best for low-power, low-area systems

### Pipelined Subtractive Divider
- Latency: ~27 cycles
- Throughput: 1 result per cycle (~100 M div/s at 100 MHz)
- Area: Largest (~7.95% LUT, ~3.81% FF)
- Power: Medium (~37 mW dynamic)
- Best for high-throughput custom FP division

## Key Observations
- Pipelining improves throughput by ~28× with marginal latency reduction
- Area increases significantly due to hardware replication across stages
- Non-pipelined design minimizes switching activity and power
- IP core achieves compliance at the cost of higher power
- Frequency is not a limiting factor in any architecture

## Tools Used
- Verilog HDL
- Xilinx Vivado
- FPGA timing, power, and utilization analysis

## Notes
Vivado-generated files (.runs, .sim, .cache, logs, reports) are excluded
from version control using `.gitignore`.

## Conclusion
This project highlights the fundamental trade-offs between throughput,
area, and power in floating-point divider design. Custom pipelined
architectures offer extreme throughput, while iterative designs excel
in power-constrained environments.

