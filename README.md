# snekOS — QEMU Guide

A tiny 16-bit real-mode Snake game that boots directly as an OS, built from a
custom boot sector, a menu, and the game itself.

## Prerequisites

- [NASM](https://www.nasm.us/) (assembler)
- [QEMU](https://www.qemu.org/) (`qemu-system-x86_64`)



### Debian/Ubuntu
```bash
sudo apt install nasm qemu-system-x86
 ```
### Fedora
```bash
sudo dnf install nasm qemu-system-x86
  ```
### Arch Linux / Manjaro
```bash
sudo pacman -S nasm qemu-system-x86
  ```
### openSUSE
```bash
sudo zypper install nasm qemu-x86
  ```
### Alpine
```bash
sudo apk add nasm qemu-system-x86_64
```
 
## Build & Run
 
```bash
make run
```


This assembles `boot.asm`, `menu.asm`, and `program.asm`, combines them into
`disk.img`, and boots it in QEMU (via its built-in SeaBIOS — legacy BIOS
boot, no UEFI/CSM needed).

To only build the image without running it:

```bash
make disk.img
```

To boot the image manually:

```bash
qemu-system-x86_64 -drive format=raw,file=disk.img
```

## Controls

- **Enter** — start the game from the menu
- **Arrow keys** — move the snake

## Clean up

```bash
make clean
```

## Note

This only runs in **legacy BIOS mode**. It cannot boot on real UEFI-only
hardware without CSM, QEMU works because it emulates its own BIOS
regardless of the host machine's firmware.
