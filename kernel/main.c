#include "../lib/stdint.h"
#include "../lib/kernel/print.h"
int main(void) {
	put_char('k');
	put_char('e');
	put_char('r');
	put_char('n');
	put_char('e');
	put_char('l');
	put_char('\n');
	put_char('1');
	put_char('2');
	put_char('\b');
	put_char('3');
	put_str("\r\nI am kernel by put_str\n");
    put_int(0);
    put_char('\n');
	put_int(9);
	put_char('\n');
	put_int(0x00021a3f);
	put_char('\n');
	put_int(0x12345678);
	put_char('\n');
	put_int(0x00000000);
	while(1);
	return 0;
}
