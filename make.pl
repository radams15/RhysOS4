#!/usr/bin/perl

use warnings;
use strict;

use File::Basename;
use File::Path qw/make_path/;
use File::Find::Rule;

my $ASM = 'nasm';
my $CC = 'bcc';
my $LD = 'ld86';

# Must be strings for some reason
my $KERNEL_ADDR = '0x1000';
my $SHELL_ADDR = '0x2000';
my $EXE_ADDR = '0x6000';
my $HEAP_ADDR = '0x20000';
my $KERNEL_SECTORS = '15';


my $KERNEL_FLAGS = "-DHEAP_ADDRESS=$HEAP_ADDR -DEXE_ADDRESS=$EXE_ADDR -DSHELL_ADDRESS=$SHELL_ADDR";

sub run {
	my ($cmd) = @_;
	
	print "$cmd\n";
	my $ret = system($cmd);

	die if $ret;

	$ret;
}

sub find {
	my ($rule) = @_;
	
	File::Find::Rule->name(basename($rule))->in(dirname($rule));
}

sub bootloader {
	make_path("build") if !(-e 'build/');
	&run("$ASM -fbin bootloader/boot.nasm -DKERNEL_ADDR=$KERNEL_ADDR -DKERNEL_SECTORS=$KERNEL_SECTORS -Ibootloader -o build/boot.bin");
	
	"build/boot.bin";
}

sub kernel {
	my @objs;
	
	for my $c_file (&find('kernel/*.c')) {
		(my $out = $c_file) =~ s:(kernel/.*)\.c:build/$1.o:;
		my $folder = dirname($out);
		make_path($folder) if !(-e $folder);

		&run("$CC -ansi -Ikernel/ $KERNEL_FLAGS -c $c_file -o $out");
		(push @objs, $out) unless $c_file =~ /kernel.c/;
	}
	
	for my $asm_file (&find('kernel/*.nasm')) {
		(my $out = $asm_file) =~ s:(kernel/.*)\.nasm:build/$1_nasm.o:;
		my $folder = dirname($out);
		make_path($folder) if !(-e $folder);
		
		&run("$ASM -fas86 $asm_file -o $out");
		push @objs, $out;
	}
	
	&run("$LD -o build/kernel.bin -d build/kernel/kernel.o ".(join ' ', @objs));
	
	"build/kernel.bin";
}

sub stdlib {	
	make_path("build/stdlib/") if !(-e 'build/stdlib/');
	my @objs;
	
	for my $c_file (&find('stdlib/*.c')) {		
		(my $out = $c_file) =~ s:stdlib/(.*)\.c:build/stdlib/$1.o:;
		&run("$CC -ansi -c $c_file -Istdlib/ -o $out");
		
		push @objs, $out;
	}
	
	for my $asm_file (&find('stdlib/*.nasm')) {
		(my $out = $asm_file) =~ s:stdlib/(.*)\.nasm:build/stdlib/$1_nasm.o:;
		&run("$ASM -fas86 $asm_file -Istdlib/ -o $out");
		push @objs, $out;
	}
	
	&run("ar -rcs build/stdlib/libstdlib.a ".(join ' ', @objs));
	
	"-Lbuild/stdlib -lstdlib";
}

sub programs {
	my ($stdlib) = @_;
	
	make_path("build/programs/") if !(-e 'build/programs/');
	
	my @programs;
	
	for my $program (<programs/*/>) {
		my $folder = "build/$program";
		make_path($folder) if !(-e $folder);
		
		my @objs;
		
		my $load_addr = $program =~ 'programs/shell/' ? $SHELL_ADDR : $EXE_ADDR;
		
		for my $c_file (&find("$program/*.c")) {
			
			(my $out_obj = $c_file) =~ s:programs/(.*)\.c:build/programs/$1.o:;
			(my $out = $out_obj) =~ s:\.o$::;
			&run("$CC -ansi -c $c_file -Iprograms/ -Istdlib -o $out_obj");
			
			push @objs, $out_obj;
		}
		
		for my $asm_file (&find("$program/*.nasm")) {
			(my $out_obj = $asm_file) =~ s:programs/(.*)\.nasm:build/programs/$1.o:;
			
			&run("$ASM -fas86 $asm_file -Iprograms/ -Istdlib -o $out_obj");
			
			push @objs, $out_obj;
		}
		
		my $out = "$folder/".basename($program);
		
		print "Program: $out\n";
		
		&run("$LD -o $out -T$load_addr -d ".join(' ', @objs)." $stdlib");
	}
	
	@programs;
}

sub initrd {
	&run("tar --format=ustar --xform s:^.*/:: -cf build/initrd.tar ".(join ' ', @_));
	
	"build/initrd.tar";
}

sub img {
	my ($bootloader, $kernel, $programs, $extra_files) = @_;
	
	&run("dd if=/dev/zero of=build/system.img bs=512 count=2880");
	
	my $initrd = &initrd($kernel, @$programs, @$extra_files);
	
	&run("dd if=$bootloader of=build/system.img bs=512 count=1 conv=notrunc");
	&run("dd if=$initrd of=build/system.img bs=512 seek=1 conv=notrunc");
	
	"build/system.img";
}

sub qemu {
	&run("qemu-system-i386 -machine pc -fda build/system.img -boot a -m 1M");
}

sub build {
	my $bootloader = &bootloader;
	my $kernel = &kernel;
	my $stdlib = &stdlib;
	my @programs = &programs($stdlib);
	&img($bootloader, $kernel, \@programs, ['fs_structs.h']);
}

sub clean {
	&run("rm -rf build");
}

if($ARGV[0] eq 'build') {
	&build;
}

if($ARGV[0] eq 'clean') {
	&clean;
}

if($ARGV[0] eq 'run') {
	&build;
	&qemu;
}
