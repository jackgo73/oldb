#define _CRT_SECURE_NO_WARNINGS

#include <cstdio>
#include <iostream>
#include <vector>
#include <algorithm>
#include <queue>


using namespace std;

int temperature[1000000], snow_volume[1000000], n, i; //N 1 - 10^5
priority_queue<long long, vector <long long>, greater<long long> > heap;
long long t = 0, res;

int main() {
    if (freopen("testcase.txt", "r", stdin) == NULL) {
        fprintf(stderr, "error redirecting stdout\n");
    }
    scanf("%d", &n);
    
    for (i = 0; i < n; ++i) {
        scanf("%d", snow_volume + i);
    }
    for (i = 0; i < n; ++i) {
        scanf("%d", temperature + i);
    }
    for (i = 0; i < n; ++i) {
        heap.push(snow_volume[i] + t);
        t += temperature[i];
        for (res = 0; !heap.empty() && heap.top() <= t; heap.pop()) {
            res += heap.top() - t + temperature[i];
        }
        res += temperature[i] * heap.size();
        printf("%I64d ", res);
    }
}
