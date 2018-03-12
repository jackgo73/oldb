#include <iostream>
int main() {

	long long n, m, a, x, y;
	std::cin >> n >> m >> a;
	x = n / a;
	y = m / a;
	if (n%a)
		x++;
	if (m%a)
		y++;
	std::cout << x * y << std::endl;
}