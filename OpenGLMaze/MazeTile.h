//
//  MazeTile.h
//  OpenGLMaze
//
//  Created by Carson Roscoe on 2017-03-08.
//  Copyright © 2017 CEDJ. All rights reserved.
//
#ifndef MazeTile_h
#define MazeTile_h


#import <GLKit/GLKit.h>

// Maze object
@interface MazeTile : NSObject {
@public
    int column;
    int row;
    bool north;
    bool south;
    bool east;
    bool west;
    GLKMatrix3 northNormalMatrix;
    GLKMatrix3 southNormalMatrix;
    GLKMatrix3 eastNormalMatrix;
    GLKMatrix3 westNormalMatrix;
    GLKMatrix3 floorNormalMatrix;
    GLKMatrix4 northModelProjectionMatrix;
    GLKMatrix4 southModelProjectionMatrix;
    GLKMatrix4 eastModelProjectionMatrix;
    GLKMatrix4 westModelProjectionMatrix;
    GLKMatrix4 floorModelProjectionMatrix;
    
    GLKMatrix3 mapNorthNormalMatrix;
    GLKMatrix3 mapSouthNormalMatrix;
    GLKMatrix3 mapEastNormalMatrix;
    GLKMatrix3 mapWestNormalMatrix;
    GLKMatrix4 mapNorthModelProjectionMatrix;
    GLKMatrix4 mapSouthModelProjectionMatrix;
    GLKMatrix4 mapEastModelProjectionMatrix;
    GLKMatrix4 mapWestModelProjectionMatrix;
} @end



/*@interface MazeTile : NSObject {
@public
    bool right;
    bool up;
    bool left;
    bool down;
    
    GLKMatrix4 upVertecies;
    GLKMatrix3 upNormals;
    
    GLKMatrix4 downVertecies;
    GLKMatrix3 downNormals;
    
    GLKMatrix4 leftVertecies;
    GLKMatrix3 leftNormals;
    
    GLKMatrix4 rightVertecies;
    GLKMatrix3 rightNormals;
    
    GLKMatrix4 upMinimapVerticies;
    GLKMatrix3 upMinimapNormals;
    
    GLKMatrix4 downMinimapVerticies;
    GLKMatrix3 downMinimapNormals;
    
    GLKMatrix4 leftMinimapVerticies;
    GLKMatrix3 leftMinimapNormals;
    
    GLKMatrix4 rightMinimapVerticies;
    GLKMatrix3 rightMinimapNormals;
}

- (id)init:(bool)r left:(bool)l up:(bool)u down:(bool)d;
//- (GLKMatrix4)getVerteciesOfSide:(enum SIDE)side;

@end*/


#endif /* MazeTile_h */
