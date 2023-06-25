#define ROLL_TYPE_NONE      0
#define ROLL_TYPE_ROLLED    1
#define ROLL_TYPE_STUFFED   2

// called if there is a rolle or stuff
forward void OnTeamRolled(int rollType, bool isMiniRound);