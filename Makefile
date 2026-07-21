all: run

boot.bin: boot.asm
	nasm -f bin boot.asm -o boot.bin

menu.bin: menu.asm
	nasm -f bin menu.asm -o menu.bin
	truncate -s 512 menu.bin      # ← auf genau 512 Byte auffüllen

program.bin: program.asm
	nasm -f bin program.asm -o program.bin

disk.img: boot.bin menu.bin program.bin
	cat boot.bin menu.bin program.bin > disk.img
	truncate -s 1M disk.img

run: disk.img
	qemu-system-x86_64 -drive format=raw,file=disk.img

clean:
	rm -f *.bin disk.img
