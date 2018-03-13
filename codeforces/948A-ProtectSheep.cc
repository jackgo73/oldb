#define _CRT_SECURE_NO_WARNINGS

#include<cstdio>
int n, m, i, j;
char s[505][505];
int main(){
    if (freopen("948A.txt", "r", stdin) == NULL) {
        fprintf(stderr, "error redirecting stdout\n");
    }
    scanf("%d%d",&n,&m);
    for(i = 1; i < n + 1; ++i) {
        scanf("%s", s[i] + 1);
    }
    for (i = 1; i < n + 1; ++i) {
        for (int j = 1; j < m + 1; ++j) {
            if (s[i][j] == '.') {
                s[i][j] = 'D';
            } else if ( s[i][j] == 'S' && (s[i-1][j] == 'W'|| s[i+1][j] == 'W'|| s[i][j-1] == 'W'|| s[i][j+1] == 'W') ) {
                printf("No\n");
                return 0;
            }
        }
    }
    printf("Yes\n");
    for (int i = 1; i < n + 1; ++i) {
        printf("%s\n",s[i]+1);
    }
} 
