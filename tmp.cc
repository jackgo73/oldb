#include <cstdio>
#include <iostream>
#include <string> 
#include <vector>
#include <map>
#include <algorithm>


//#define _DEBUG_VER
/***********OJ_TEMPLATE_BY_MUTEX73***********/
typedef int int32;
typedef unsigned int uint32;
typedef long long int64;
typedef unsigned long long uint64;
/***********SPECIFIC*************************/

class Player {
public:
    Player(std::string _name, int32 _score) { 
        name = _name; 
        score = _score; 
        score_history.push_back(std::pair<int32, int32>(0, score));
    }

    bool operator < (const Player& rhs) const {
        if (score > rhs.score) {
            return true;
        } else if (score < rhs.score) {
            return false;
        } else {
            int a = 0;
            int b = 0;
            while(score_history[a].second < score)
                a++;
            while(rhs.score_history[b].second < score)
                b++;
            return score_history[a].first < rhs.score_history[b].first;
        }
    }

    std::string name;
    int32 score;
    std::vector<std::pair<int32, int32> > score_history;
};


int main()
{
#ifdef _DEBUG_VER
    if(freopen("testcase.txt", "r", stdin) == NULL) {
        fprintf(stderr,"error redirecting stdout\n");
    }	
#endif
    int32 n, score, i, index;
    std::vector<Player> players;
    std::map<std::string, int32> players_index;
    std::map<std::string, int32>::iterator iter;

    std::string name;
    std::ios::sync_with_stdio(false);
    std::cin >> n;

    index = 0;
    for(i = 0; i < n; ++i) {
        std::cin >> name >> score;
        iter = players_index.find(name);
        if (iter == players_index.end()) {
            players_index.insert(std::map<std::string, int32>::value_type(name, index++));
            players.push_back(Player(name, score));      
        } else {
            players[iter->second].score += score;
            players[iter->second].score_history.push_back(std::pair<int32, int32>(i, players[iter->second].score));
        }
    }
    sort(players.begin(), players.end());

    std::cout << players[0].name << std::endl;

    return 0;
}
