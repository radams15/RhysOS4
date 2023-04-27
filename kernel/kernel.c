#include "fat.h"
#include "tty.h"
#include "proc.h"

void main();
void entry() {main();}

void main() {
	int err;

	err = init();

	if(err){
		print_string("\r\nError in kernel, halting!\r\n");
	}

	while(1){}
}

int shell() {
	int ret;
	int size;
	char buf[1024];
    
    read_file(&buf, "/shell.bin");
    
    return run_exe(&buf, sizeof(buf), LOAD_SHELL);
}

int exec(char* file_name) {
	char buf[1024];
    
    if(!read_file(&buf, file_name)) {
	    return run_exe(&buf, sizeof(buf), LOAD_EXE);
    }
    
    return 1;
}

int handleInterrupt21(int ax, int bx, int cx, int dx) {
  switch(ax) {
    case 0:
		print_string((char *)bx);
		break;
	
    case 1:
		return readline(bx);
		break;
		
    case 2:
		return exec(bx);
		break;
      
    default:
		print_string("Unknown interrupt: ");
		print_hex(ax);
		print_string("!\r\n");
		break;
  }
}

int init(){	
	clear_screen();
	
	makeInterrupt21();
	
	shell();
	
	print_string("\n\nDone.");

	return 0;
}
