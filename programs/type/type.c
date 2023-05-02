#include <stdio.h>

#define CHUNK_SIZE 512

int entry(int argc, char** argv) { return main(argc, argv); }

int type(char* file) {
	int n;
	char buffer[CHUNK_SIZE+1];
	int fh;
	
	fh = open(file);
	
	read(fh, &buffer, CHUNK_SIZE);
	
	close(fh);
	
	printf("%s\n", buffer);
}

int main(int argc, char** argv) {
	int i;
	
	for(i=1 ; i<argc ; i++) {
		type(argv[i]);
	}
	
	return 0;
}
