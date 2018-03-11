#define _CRT_SECURE_NO_WARNINGS


#include <cstdio>
#include <iostream>
#include <string> 
#include <vector>
#include <map>
#include <algorithm>
#include <queue>

using namespace std;
const int maxn = 1000011;
int n, a[maxn], T[maxn];
int main() {
	if (freopen("testcase.txt", "r", stdin) == NULL) {
		fprintf(stderr, "error redirecting stdout\n");
	}
	scanf("%d", &n);
	static priority_queue<long long>q;
	long long S = 0, ans;
	for (int i = 1; i <= n; ++i) scanf("%d", a + i);
	for (int i = 1; i <= n; ++i) scanf("%d", T + i);
	for (int i = 1; i <= n; ++i) {
		q.push(-(a[i] + S)); S += T[i];
		ans = 0;
		while (!q.empty() && -q.top() <= S) {
			ans += -q.top() - S + T[i]; q.pop();
		}
		ans += q.size()*T[i];
		printf("%lld ", ans);
	}
	int k;
}
