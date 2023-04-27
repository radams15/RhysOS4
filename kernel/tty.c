#include "tty.h"

int print_code = 0x0E;
int set_cursor_code = 0x0200;
int zero = 0x00;
char hex_chars[] = "0123456789ABCDEF";


void clear_screen() {
	interrupt(0x10, 0x0200, 0, 0, 0);
	interrupt(0x10, 0x0600, 0x0f00, 0, 0x184f);
}

void set_resolution(int mode) {
	interrupt(0x10, mode, 0, 0, 0);
}

void print_char(int c) {
	if(c == '\t') {
		print_string("    ");
		return;
	}

	if(c == '\n')
		interrupt(0x10, 0x0E00 + '\r', 0, 0, 0);
	
	interrupt(0x10, 0x0E00 + c, 0, 0, 0);
}

void print_stringn(char* str, int n) {
	int i;
	for(i=0 ; i<n ; i++) {
		print_char(str[i]);
	};
}

void print_string(char* str) {
    char* c;
    for(c=str ; *c != 0 ; ++c)
        print_char(*c);
}

void print_hex(int n) { // TODO Improve this to handle > 2 bytes.
    print_string("0x");
    print_char(hex_chars[(n & 0xF00)>>8]);
    print_char(hex_chars[(n & 0xF0)>>4]);
    print_char(hex_chars[(n & 0xF)>>0]);
}

#asm
_getch:
	push bp
	mov bp, sp
    xor ax, ax
    int 0x16
	pop bp
	ret
#endasm
