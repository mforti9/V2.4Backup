# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

This is a Klipper 3D printer data directory for a **Voron 2.4 350mm** running on a Raspberry Pi. It is not a software project — it contains configuration files, G-code, logs, and databases for the Klipper/Moonraker/Mainsail stack.

## Printer Hardware

- **Printer**: Voron 2.4 ~350mm CoreXY
- **MCU**: Fysetc Spider (STM32F446, 12MHz crystal), firmware flashed to 0x08000000
- **Toolhead MCU**: Fly SB2040 (CAN bus, UUID: `c01c449c67ae`)
- **Extruder**: Galileo 2 (gear ratio 9:1)
- **Nozzle**: 0.6mm Nozzle-X
- **Hotend sensor**: PT1000 (with 4700 ohm pullup)
- **Probe**: Tap-style (nozzle contact, `probe:z_virtual_endstop`), probes at 150C extruder temp
- **Bed**: Generic 3950 thermistor, max power 0.6
- **Stepper drivers**: TMC2209 (UART) on all axes
- **Filament sensors**: Switch sensor (PB14) + encoder/motion sensor (PB13, 8.5mm detection length)
- **Accelerometer**: ADXL345 on SB2040 (axes remapped: -z, -y, -x)
- **Input shaper**: X=84.2Hz (3hump_ei), Y=31.4Hz (mzv)

## Directory Structure

- `config/` — Active Klipper config and timestamped backups (`printer-YYYYMMDD_HHMMSS.cfg`)
- `config/macros/` — G-code macro files included via `[include macros/*.cfg]`
- `config/moonraker.conf` — Moonraker API server config
- `config/mainsail.cfg` — Mainsail web UI client macros (PAUSE/RESUME/CANCEL_PRINT)
- `config/ShakeTune_results/` — Klippain Shake&Tune diagnostic plots
- `gcodes/` — Uploaded G-code files with thumbnail subdirectory
- `logs/` — Klipper, Moonraker, KlipperScreen logs
- `database/` — Moonraker LMDB database
- `comms/` — Klippy Unix socket and serial
- `systemd/` — Service environment files (klipper.env, moonraker.env)

## Active Config

The most recent `config/printer-*.cfg` file is the active configuration (Klipper auto-creates dated backups). The active config includes:
- `mainsail.cfg` — client macros
- `macros/*.cfg` — all macro files via glob include
- `shell_command.cfg` — shell command extensions

## Key Macros

Defined in `config/macros/macros.cfg`:
- `PRINT_START` — Full start sequence: nozzle clean, heat soak, QGL, bed mesh, line purge. Params: `BED_TEMP`, `EXTRUDER_TEMP`
- `QUICK_START` — Same as PRINT_START but skips bed mesh calibration
- `PRINT_END` — Retract, raise Z, park at rear (X303 Y354), heaters off
- `PAUSE` / `RESUME` / `CANCEL_PRINT` — Override base macros with filament sensor enable/disable, z-hop, hotend temp save/restore
- `M600` — Filament change (calls PAUSE)
- `M109` — Overridden to use TEMPERATURE_WAIT with +/-1C tolerance
- `TEST_SPEED` — Velocity/accel stress test. Params: `SPEED`, `ITERATIONS`, `ACCEL`

Other macro files:
- `CLEAN_NOZZLE` / `CLEAN_NOZZLE_PARK` — Nozzle wipe at X303 Y351 Z4
- `LOAD_FILAMENT` / `UNLOAD_FILAMENT` — 115mm load/unload distance
- `LINE_PURGE` — KAMP-style purge line
- `Adaptive_Mesh.cfg` — KAMP adaptive bed mesh
- `stealthburner_leds.cfg` — LED control macros
- `heatsoak.cfg`, `flow_calibration.cfg`, `PA_Advance.cfg`, `singlelayertest.cfg`

## Software Stack (via moonraker.conf update_manager)

- **Klipper** — Firmware and host software
- **Moonraker** — API server (host 0.0.0.0, klippy socket at `~/printer_data/comms/klippy.sock`)
- **Mainsail** — Web interface (stable channel)
- **Katapult** (formerly CanBoot) — CAN bus bootloader
- **Crowsnest** — Webcam streaming
- **Sonar** — Network keepalive
- **Klippain Shake&Tune** — Resonance analysis tooling
- **klipper-backup** — Config backup to GitHub
- **Mobileraker** — Mobile companion app
- **KlipperScreen** — Touchscreen UI

## Important Notes When Editing Configs

- The `[probe] activate_gcode` lowers extruder to 150C before probing — do not remove this or probing with a hot nozzle will give bad results
- `mainsail.cfg` defines PAUSE/RESUME/CANCEL_PRINT but `macros/macros.cfg` also redefines them with `rename_existing` — the macros.cfg versions take precedence and handle filament sensor toggling
- Bed mesh is 6x6, range 40-310mm, with bicubic interpolation and zero reference at center (175, 175)
- QGL retry tolerance is set loose at 0.1mm (was 0.0075) with max_adjust of 10mm
- `max_extrude_cross_section: 2.5` is elevated from default to support purge operations
- Pressure advance is tuned to 0.051
- Extruder `min_temp: -50` is set to allow PT1000 readings below 0C (cold environment startup)
