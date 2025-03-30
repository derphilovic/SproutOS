all: os.iso

os.iso: os.elf
	mkdir -p isodir/boot/grub
	cp os.elf isodir/boot/
	echo 'menuentry "psy-os" { multiboot2 /boot/os.elf }' > isodir/boot/grub/grub.cfg
	grub-mkrescue -o os.iso isodir --modules="multiboot2 normal part_msdos" --fonts= --themes= --locales= -v

os.elf: kernel.asm kernel.c
	nasm -f elf64 kernel.asm -o kernel_asm.o
	gcc -c kernel.c -o kernel_c.o -ffreestanding -nostdlib -mno-red-zone -mgeneral-regs-only -O0
	ld -nostdlib -T linker.ld -o os.elf kernel_asm.o kernel_c.o

run: os.iso
	qemu-system-x86_64 -cdrom os.iso -vga std -serial stdio

clean:
	rm -rf *.o *.elf *.iso isodir