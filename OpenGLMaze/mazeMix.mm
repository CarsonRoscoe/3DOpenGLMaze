
#import "mazeMix.h"
#include "maze.h"

struct MazeStruct {
    Maze maze;
};

@implementation MazeManager

- (id)init
{
    mazeWidth = 9;
    mazeHeight = 9;
    self = [super init];
    maze = new Maze(mazeWidth, mazeHeight);
    return self;
}

- (MazeTile *)getMazePosition:(int)x y:(int)y {
    MazeCell sq = maze->GetCell(y, x);
    MazeTile *mazeTile = [[MazeTile alloc] init];
    mazeTile->north = sq.northWallPresent;
    mazeTile->east = sq.eastWallPresent;
    mazeTile->west = sq.westWallPresent;
    mazeTile->south = sq.southWallPresent;
    return mazeTile;
}

-(void)createMaze {
    maze->Create();
}


@end
