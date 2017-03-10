//
//  MixTest.h
//  MixedLanguages
//
//  Created by Borna Noureddin on 2013-10-09.
//  Copyright (c) 2013 Borna Noureddin. All rights reserved.
//

#ifndef MazeManager_h
#define MazeManager_h

#include "MazeTile.h"

struct MazeStruct;

@interface MazeManager : NSObject {
@private
    struct Maze *maze;
    
@public
    int mazeWidth;
    int mazeHeight;
}

- (MazeTile *)getMazePosition:(int)x y:(int)y;
- (void)createMaze;

@end

#endif /* MazeManager_h */
