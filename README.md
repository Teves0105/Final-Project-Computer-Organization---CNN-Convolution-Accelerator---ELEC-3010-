# 2D Convolution Hardware Accelerator on Zynq FPGA 🚀

[![Course](https://img.shields.io/badge/Course-ELEC3010-blue)](https://vinuni.edu.vn/)
[![Institution](https://img.shields.io/badge/Institution-VinUniversity-red)](https://vinuni.edu.vn/)
[![FPGA](https://img.shields.io/badge/Board-ZCU104-orange)]()
[![Language](https://img.shields.io/badge/Language-Verilog%20%7C%20Python-green)]()

This repository contains the Final Project for **ELEC3010: Digital Logic and Computer Organization** at VinUniversity (Spring 2026). 

We designed, implemented, and verified a custom **2D Convolution Hardware Accelerator** written in Verilog, targeted for the Xilinx Zynq ZCU104 FPGA. The project features both a baseline serial architecture and an optimized partially parallel architecture.

---

## 🌟 Key Features

* **Baseline Serial Architecture:** A reliable, memory-mapped IP core utilizing a single Multiply-Accumulate (MAC) unit, managed by a robust Finite State Machine (FSM).
* **Partially Parallel Extension:** An upgraded architecture utilizing $K=3$ parallel multipliers and a custom multi-port SRAM. This reduces the processing time per output pixel from 9 cycles to 4 cycles.
* **Hardware-Accurate Software Model:** A Python-based CNN emulation utilizing `int8` quantization and bit-masking to perfectly mirror the hardware's truncation behavior and generate Golden Reference files.
* **Comprehensive Verification:** A rigorous Verilog testbench equipped with automatic sanity checks, memory latency handling, and automated pixel-by-pixel validation reporting.
<div align="center">
  <img width="800" src="https://github.com/user-attachments/assets/42e0c37a-9974-4086-963c-7537f34a28b3" alt="System Architecture Diagram V3">
  <br>
  <img width="800" src="https://github.com/user-attachments/assets/2c7377bc-b876-42d2-a582-696e316dd9cf" alt="FSM">
</div>

## 📊 Performance & Synthesis Results

The accelerator was synthesized on Vivado with a 10ns (100 MHz) timing constraint. The Partially Parallel Extension achieved a **2.71x speedup** over the baseline model.

| Metric | Partially Parallel (K=3) | Baseline (Serial) |
| :--- | :--- | :--- |
| **Input size (H × W)** | 16 × 16 | 16 × 16 |
| **Kernel size (K × K)** | 3 × 3 | 3 × 3 |
| **Total Clock Cycles** | **1,373** | 3,726 |
| **Max Frequency (MHz)**| 388.20 | 482.16 |
| **Throughput** | **128.48 MMAC/s** | 47.34 MMAC/s |
| **LUTs / LUTRAMs / FFs**| 423 / 184 / 98 | 218 / 88 / 69 |

> *Note: BRAM usage is 0 in the parallel version because the required 4-port SRAM (1 Write, 3 Read) was synthesized into Distributed RAM (LUTRAM) to bypass the dual-port limitation of physical Xilinx BRAM blocks.*

## 📁 Repository Structure

* `conv2d_accel.v` - Top-level wrapper (Memory-mapped interface).
* `conv_engine.v` / `conv_engine_parallel.v` - Core datapath and FSM.
* `simple_sram.v` / `multiport_sram.v` - Memory storage modules.
* `tb_conv2d_accel.v` - Automated Verification Testbench.
* `prepare_data.py` & `conv2d.py` - Python scripts for MNIST data cropping, quantization, and `.txt` hex file generation.
* `*.txt` - Input matrices and expected golden reference files.

## 🚀 How to Run

### 1. Data Preparation (Python)
1. Ensure you have `numpy` and `matplotlib` installed.
2. Run `prepare_data.py` to extract a random $16 \times 16$ image from the MNIST dataset.
3. The script will apply the $3 \times 3$ kernel, compute the convolution, and generate `input_feature_map.txt`, `kernel.txt`, and `expected_output.txt`.
<img width="1500" height="500" alt="visualization" src="https://github.com/user-attachments/assets/4b158381-1250-4018-adf3-707b6bd329c9" />

### 2. Hardware Simulation (Vivado)
1. Create a new Vivado project and add all `.v` files to the Design Sources.
2. Add `tb_conv2d_accel.v` and the generated `.txt` files to the Simulation Sources.
3. Run **Behavioral Simulation**.
4. The Tcl Console will print out a pixel-by-pixel validation report. A successful run will conclude with:
   > `Sign-off approved: Hardware verification complete with 0 errors`

---

## 👥 Team Members (Group 4)

* **Nguyen Huy Long** (Project Lead, Hardware) - Architecture, RTL Coding, Verification, Synthesis.
* **Pham Trung Kien** (Hardware Engineer) - RTL Integration, Behavioral Simulations, Timing Analysis.
* **Phung Minh Khoa** (Extension Developer) - Research & Implementation of Partially Parallel Architecture.
* **Bui Tuan Kien** (Software Engineer) - Python CNN modeling, Data Quantization, Golden Reference generation.

*Instructor: Prof. Pham Ngoc Nam | Lab Instructor: Duy Anh Nguyen*
