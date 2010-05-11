#include <stdio.h>
#include <strings.h>
#include <netdb.h>
#include <netinet/in.h>

struct hostent *he;
struct in_addr a;

extern int resolve_ip4(char *host, unsigned int *results, int max) {
	int i;
	int num = 0;
	he = gethostbyname(host);
	if(he) {
		printf("name: %s\n", he->h_name);
		while(*he->h_aliases) {
			printf("alias: %s\n", *he->h_aliases++);
		}
	
		//while(he->h_addr_list) {
		if(he->h_addrtype == AF_INET) {
			for(i=0; he->h_addr_list[i]; ++i) {
				bcopy(he->h_addr_list[i], (char *) &a, sizeof(a));
				bcopy(he->h_addr_list[i], results++, sizeof(a));
				//printf("address: %i\n", a);
				//printf("address: %i.%i.%i.%i\n", results[0], results[1], results[2], results[3]);
				num++;
			}
		}
	
		return num;
	}

	return -1;
}
/*
int main() {
	char results[16];
	resolve_ip4("spreadsheets.google.com\0", &results[0], 4);
	return 0;
}
*/
