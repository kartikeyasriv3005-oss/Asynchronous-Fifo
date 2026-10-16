# Asynchronous FIFO with Clock Domain Crossing (CDC)

## Overview

This project implements a **16-entry, 8-bit asynchronous FIFO** in Verilog HDL. It enables data transfer between independent write and read clock domains using Gray-coded pointers, two-stage synchronizers, and full/empty detection logic.

The design focuses on fundamental RTL design concepts, clock domain crossing (CDC), pointer management, and self-checking functional verification.

## Features

- 16-entry FIFO with 8-bit data width
- Independent write and read clocks
- 5-bit binary read and write pointers, including wraparound bits
- Binary-to-Gray code pointer conversion
- Two-stage synchronizers for pointer crossings between clock domains
- Full and empty flag generation
- Protection against writes while full and reads while empty
- Self-checking testbench with a reference scoreboard
- Directed tests and randomized traffic testing

## Architecture

### Block-level overview

The FIFO consists of four main components:

1. **Storage memory:** A 16 × 8 memory array that stores the data.
2. **Write control:** Manages accepted writes, the write pointer, and full detection.
3. **Read control:** Manages accepted reads, the read pointer, and empty detection.
4. **CDC synchronizers:** Transfer Gray-coded pointers safely between the two clock domains.

### Pointer management

The FIFO uses 5-bit binary pointers:

- The lower four bits select one of the 16 memory locations.
- The most significant bit tracks pointer wraparound.

Gray-coded pointers are generated using:

`gray = binary ^ (binary >> 1)`

Only one Gray-code bit changes during a normal increment, reducing the risk of inconsistent multi-bit pointer sampling during clock domain crossings.

### Clock domain crossing

The write pointer is synchronized into the read-clock domain using two registers:

`wgray → wgray_r1 → wgray_r2`

The read pointer is synchronized into the write-clock domain similarly:

`rgray → rgray_w1 → rgray_w2`

Each synchronizer chain is clocked by the destination clock.

### Full and empty detection

**Empty detection:** The FIFO is empty when the next read Gray pointer equals the synchronized write Gray pointer.

**Full detection:** The FIFO is full when the next write Gray pointer matches the synchronized read Gray pointer with its two most significant bits inverted.

The full and empty flags are registered in their respective clock domains.

## RTL Implementation

The design is implemented in Verilog HDL and includes:

- Binary pointer registers
- Gray-code conversion logic
- Next-state pointer calculations
- Full and empty detection logic
- Independent read and write sequential blocks
- Two-stage pointer synchronizers

## Verification

The testbench uses independent clocks and a scoreboard to compare returned data against expected data.

### Test scenarios

| Test | Purpose |
|---|---|
| Reset | Verify initial full and empty flags |
| Read while empty | Check underflow protection |
| Fill FIFO | Verify full detection after 16 accepted writes |
| Write while full | Check overflow protection |
| Ordered readback | Verify data integrity and FIFO ordering |
| Pointer wraparound | Exercise repeated pointer wraparound |
| Simultaneous traffic | Exercise concurrent read and write requests |
| Randomized stress | Exercise varying data and read/write activity |

The testbench reports data mismatches and other detected failures and generates a VCD waveform file for debugging.

## Tools Used

- Verilog HDL
- Icarus Verilog
- GTKWave
- Vivado (for planned synthesis and implementation analysis)

Inspect the clocks, pointer registers, synchronizer stages, full/empty flags, read/write enables, and data signals to debug failures.

## Future Improvements

- Run randomized stress tests with repeatable seeds and robust transaction checking.
- Perform synthesis and analyze inferred hardware resources.
- Run static timing analysis (STA) with appropriate clock constraints.
- Perform CDC analysis to inspect synchronizer chains and asynchronous crossings.
- Review reset deassertion behavior in both clock domains.
- Add more extensive corner-case tests and document measured implementation results.

## Learning Outcomes

This project demonstrates practical understanding of:

- RTL design using Verilog
- Asynchronous FIFO architecture
- Binary and Gray-code pointers
- Clock domain crossing fundamentals
- Full and empty detection
- Self-checking testbench design
- Scoreboard-based functional verification
- Simulation and waveform debugging

## Project Status

**Functional RTL implementation with initial directed verification.** Further verification, synthesis, timing analysis, and CDC review are required before claiming complete implementation sign-off.
