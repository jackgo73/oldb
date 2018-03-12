#define _CRT_SECURE_NO_WARNINGS

#include <cstdio>
#include <iostream>

#define BASE26 26
#define ASCII_OFFSET_26_10 64


int main() {
	int n, x, y, k, i, borrow = 0;
	char s[64], m1[64], *p;

	for (scanf("%d", &n); n--;) {
		scanf("%s", s);
		k = sscanf(s, "%[a-zA-Z]%d%*[a-zA-z]%d", m1, &x, &y);
		if (k == 3)
		{
			// R23C55 --> BC23
			// m1, k are free now
			for (i = 0; y; ++i) {
				k = y % BASE26;
				borrow = (k == 0) ? 1 : 0;
				y = y / BASE26 - borrow;
				m1[i] = k + ASCII_OFFSET_26_10 + borrow * 26;
			}
			for (--i; i >= 0; --i) {
				printf("%c", m1[i]);
			}
			printf("%d\n", x);
		}
		else {
			// m1 x
			// BC 23 --> R23C55
			// B --26to10--> 2  C --26to10--> 3
			for (y = 0, p = m1; *p; ++p) {
				y = y * BASE26 + *p - ASCII_OFFSET_26_10;
			}
			printf("R%dC%d\n", x, y);
		}
	}
	return 0;
}
