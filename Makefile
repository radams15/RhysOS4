KERNEL_ADDR?=0x1000
SHELL_ADDR?=0x3000
EXE_ADDR?=0x12000
HEAP_ADDR?=0x20000
KERNEL_SECTORS?=15

all: img

bload:
	@mkdir -p build
	nasm -fbin bootloader/boot.nasm -DKERNEL_ADDR=${KERNEL_ADDR} -DKERNEL_SECTORS=${KERNEL_SECTORS} -Ibootloader -o build/boot.bin
	
make_dir:
	gcc make_dir.c -DKERNEL_SECTORS=${KERNEL_SECTORS} -o make_dir
	
load_file:
	gcc load_file.c -o load_file

krnl:
	bcc -ansi -c kernel/kernel.c -o build/kernel.o
	bcc -ansi -c kernel/fat.c -o build/fat.o
	bcc -ansi -c kernel/tty.c -o build/tty.o
	bcc -ansi -c kernel/util.c -o build/util.o
	bcc -ansi -DHEAP_ADDRESS=${HEAP_ADDR} -c kernel/malloc.c -o build/malloc.o
	bcc -ansi -DEXE_ADDRESS=${EXE_ADDR} -DSHELL_ADDRESS=${SHELL_ADDR} -c kernel/proc.c -o build/proc.o
	
	nasm -fas86 kernel/interrupt.nasm -o build/interrupt.o
	nasm -fas86 kernel/proc.nasm -o build/proc_nasm.o
	
	ld86 -o build/kernel.bin -d build/kernel.o build/tty.o build/fat.o build/interrupt.o build/proc_nasm.o build/proc.o build/util.o build/malloc.o

stdlb:
	@mkdir -p build/stdlib
	bcc -ansi -c stdlib/stdio.c -Istdlib/ -o build/stdlib/stdio.o
	bcc -ansi -c stdlib/string.c -Istdlib/ -o build/stdlib/string.o
	bcc -ansi -c stdlib/syscall.c -Istdlib/ -o build/stdlib/syscall.o
	
	nasm -fas86 stdlib/syscall.nasm -Istdlib/ -o build/stdlib/syscall_nasm.o
	
	ar -rcs build/stdlib/libstdlib.a build/stdlib/*.o

progs: stdlb
	@mkdir -p build/programs
	bcc -ansi -c programs/test.c -Iprograms/ -Istdlib -o build/programs/test.bin.o
	ld86 -o build/programs/test.bin -T${EXE_ADDR} -d build/programs/test.bin.o -Lbuild/stdlib -lstdlib
	
	bcc -ansi -c programs/shell.c -Iprograms/ -Istdlib -o build/programs/shell.bin.o
	ld86 -o build/programs/shell.bin -T${SHELL_ADDR} -d build/programs/shell.bin.o -Lbuild/stdlib -lstdlib

img: bload krnl progs make_dir load_file
	dd if=/dev/zero of=build/system.img bs=512 count=2880 # Empty disk
	
	dd if=build/boot.bin of=build/system.img bs=512 count=1 conv=notrunc
	#dd if=build/kernel.bin of=build/system.img bs=512 seek=3 conv=notrunc
	#dd if=map.img of=build/system.img bs=512 count=1 seek=1 conv=notrunc

	#./make_dir
	#cp build/programs/test.bin . && ./load_file test.bin && rm test.bin
	#cp build/programs/shell.bin . && ./load_file shell.bin && rm shell.bin
	
	tar --xform s:^.*/:: -cf build/initrd.tar build/kernel.bin build/programs/test.bin build/programs/shell.bin
	dd if=build/initrd.tar of=build/system.img bs=512 seek=1 conv=notrunc
	
run: img
	qemu-system-i386 -machine pc -fda build/system.img -boot a -m 1M
	
clean:
	rm -rf build
	rm -f make_dir
	rm -f load_file
