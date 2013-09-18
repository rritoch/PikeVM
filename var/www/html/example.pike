#include <stdio.h>

import "/lib/httpd/cgi.pike";

int main(int argc, array(string) argv, mixed env) 
{
	
	kernel()->console_write(sprintf("[example] ENV=%O\n",env));
	write("\r\nTest\n");
	kernel()->console_write("[example] After write()\n");
	return 0;
}