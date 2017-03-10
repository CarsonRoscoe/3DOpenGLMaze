//
//  GameViewController.m
//
//  Created by Borna Noureddin.
//  Copyright (c) 2015 BCIT. All rights reserved.
//

/*
 TODO:
 - Fix clipping placement of walls
 - Add floating rotating cube
 - Add fog shading
 - Fix rotation-glitchy visual bug
 - Flashlight
 - Console/Map
 */

#import "GameViewController.h"
#import <OpenGLES/ES2/glext.h>

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Shader uniform indices
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    UNIFORM_MODELVIEW_MATRIX,
    /* more uniforms needed here... */
    UNIFORM_TEXTURE,
    UNIFORM_FLASHLIGHT_POSITION,
    UNIFORM_DIFFUSE_LIGHT_POSITION,
    UNIFORM_SHININESS,
    UNIFORM_AMBIENT_COMPONENT,
    UNIFORM_DIFFUSE_COMPONENT,
    UNIFORM_SPECULAR_COMPONENT,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

typedef enum {
    NORTH, SOUTH, EAST, WEST
} Direction;


@interface Textures: NSObject {
@public
    GLuint textureOne;
    GLuint textureTwo;
    GLuint textureThree;
    GLuint textureFour;
    GLuint textureFloor;
    GLuint texturePlayer;
    GLuint textureMiniMap;
} @end
@implementation Textures @end

@interface GameViewController () {
    GLuint _program;
    
    // Shader uniforms
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix4 _modelViewMatrix;
    GLKMatrix3 _normalMatrix;
    
    // Lighting parameters
    /* specify lighting parameters here...e.g., GLKVector3 flashlightPosition; */
    GLKVector3 flashlightPosition;
    GLKVector3 diffuseLightPosition;
    GLKVector4 diffuseComponent;
    float shininess;
    GLKVector4 specularComponent;
    GLKVector4 ambientComponent;
    
    // Transformation parameters
    float _rotation;
    float xRot, yRot;
    CGPoint dragStart;
    
    // Shape vertices, etc. and textures
    GLfloat *vertices, *normals, *texCoords;
    GLuint numIndices, *indices;
    
    // GLES buffer IDs
    GLuint _vertexArray;
    GLuint _vertexBuffers[3];
    GLuint _indexBuffer;
    
    int _mazeWidth;
    int _mazeHeight;
    NSMutableArray *_mazeTiles;
    Textures *_textures;
    MazeManager *_mazeManager;
    
    // Floor
    GLKMatrix3 _floorNormalMatrix;
    GLKMatrix4 _floorModelProjectionMatrix;
    
    // Movement
    float _xToBe;
    float _zToBe;
    float _x;
    float _z;
    Direction _direction;
    float _rotationToBe;
    bool _canMove;
    bool _consoleOn;
    GLKMatrix3 _playerNormalMatrix;
    GLKMatrix4 _playerModelProjectionMatrix;
}

@property (strong, nonatomic) EAGLContext *context;
@property (weak, nonatomic) IBOutlet UISwitch *dayNightToggle;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
- (void)setLighting:(bool)isDay;
- (void)takeStepForward;
- (void)takeStepBackward;
- (void)turnLeft;
- (void)turnRight;
- (void)renderCube:(GLKMatrix4)projection normal:(GLKMatrix3)normal texture:(GLuint)texture;
- (GLKMatrix4)generateModelViewMatrix:(float)xPos zPos:(float)zPos xScale:(float)xScale zScale:(float)zScale isTopDown:(bool)isTopDown;
- (void)updateMovement;
- (int)getWallCount:(MazeTile*)MazeTile direction:(Direction)direction;
- (GLuint) getTexture:(int)adjacentWallCount;


@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _mazeManager = [[MazeManager alloc] init];
    [_mazeManager createMaze];
    _direction = NORTH;
    _rotation = 0;
    _z = 3;
    _x = 0;
    _xToBe = _x;
    _zToBe = _z;
    _rotationToBe = _rotation;
    _canMove = true;
    _consoleOn = true;
    // Set up iOS gesture recognizers
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(doSingleTap:)];
    singleTap.numberOfTapsRequired = 1;
    [self.view addGestureRecognizer:singleTap];
    
    UIPanGestureRecognizer *rotObj = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(doRotate:)];
    rotObj.minimumNumberOfTouches = 1;
    rotObj.maximumNumberOfTouches = 1;
    [self.view addGestureRecognizer:rotObj];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    
    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
    // Set up UI parameters
    xRot = yRot = 30 * M_PI / 180;
    
    // Set up GL
    [self setupGL];
}

- (void)dealloc
{
    [self tearDownGL];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    
    if ([self isViewLoaded] && ([[self view] window] == nil)) {
        self.view = nil;
        
        [self tearDownGL];
        
        if ([EAGLContext currentContext] == self.context) {
            [EAGLContext setCurrentContext:nil];
        }
        self.context = nil;
    }
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // Load shaders
    [self loadShaders];
    
    _mazeWidth = _mazeManager->mazeWidth;
    _mazeHeight = _mazeManager->mazeHeight;
    _mazeTiles = [[NSMutableArray alloc] initWithCapacity:(_mazeWidth * _mazeHeight)];
    //Generate maze
    _textures = [[Textures alloc] init];
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    uniforms[UNIFORM_MODELVIEW_MATRIX] = glGetUniformLocation(_program, "modelViewMatrix");
    /* more needed here... */
    uniforms[UNIFORM_TEXTURE] = glGetUniformLocation(_program, "texture");
    uniforms[UNIFORM_FLASHLIGHT_POSITION] = glGetUniformLocation(_program, "flashlightPosition");
    uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION] = glGetUniformLocation(_program, "diffuseLightPosition");
    uniforms[UNIFORM_SHININESS] = glGetUniformLocation(_program, "shininess");
    uniforms[UNIFORM_AMBIENT_COMPONENT] = glGetUniformLocation(_program, "ambientComponent");
    uniforms[UNIFORM_DIFFUSE_COMPONENT] = glGetUniformLocation(_program, "diffuseComponent");
    uniforms[UNIFORM_SPECULAR_COMPONENT] = glGetUniformLocation(_program, "specularComponent");
    
    // Set up lighting parameters
    /* set values, e.g., flashlightPosition = GLKVector3Make(0.0, 0.0, 1.0); */
    flashlightPosition = GLKVector3Make(0.0, 0.0, 1.0);
    diffuseLightPosition = GLKVector3Make(0.0, 1.0, 0.0);
    [self setLighting:true];
    
    // Initialize GL and get buffers
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(3, _vertexBuffers);
    glGenBuffers(1, &_indexBuffer);
    
    // Generate vertices
    int numVerts;
    numIndices = generateCube(1.5, &vertices, &normals, &texCoords, &indices, &numVerts);
    
    // Set up GL buffers
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[0]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, vertices, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[1]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, normals, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 3*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffers[2]);
    glBufferData(GL_ARRAY_BUFFER, sizeof(GLfloat)*3*numVerts, texCoords, GL_STATIC_DRAW);
    glEnableVertexAttribArray(GLKVertexAttribTexCoord0);
    glVertexAttribPointer(GLKVertexAttribTexCoord0, 2, GL_FLOAT, GL_FALSE, 2*sizeof(float), BUFFER_OFFSET(0));
    
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(int)*numIndices, indices, GL_STATIC_DRAW);
    
    glBindVertexArrayOES(0);
    
    // Load in and set texture
    /* use setupTexture to create crate texture */
    _textures->textureOne = [self setupTexture:@"Texture1.png"];
    _textures->textureTwo = [self setupTexture:@"Texture2.png"];
    _textures->textureThree = [self setupTexture:@"Texture3.png"];
    _textures->textureFour = [self setupTexture:@"Texture4.png"];
    _textures->textureFloor = [self setupTexture:@"Floor.png"];
    _textures->texturePlayer = [self setupTexture:@"Player.png"];
    _textures->textureMiniMap = [self setupTexture:@"MinimapWall.png"];
    glActiveTexture(GL_TEXTURE0);
    glUniform1i(uniforms[UNIFORM_TEXTURE], 0);
}

- (void)setLighting:(bool)isDay {
    if (isDay) {
        diffuseComponent = GLKVector4Make(0.3, 0.2, 0.2, 1.0);
        shininess = 200.0;
        specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
        ambientComponent = GLKVector4Make(0.5, 0.4, 0.4, 1.0);
    } else {
        diffuseComponent = GLKVector4Make(0.1, 0.1, 0.3, 1.0);
        shininess = 200.0;
        specularComponent = GLKVector4Make(1.0, 1.0, 1.0, 1.0);
        ambientComponent = GLKVector4Make(0.2, 0.2, 0.4, 1.0);
    }
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    // Delete GL buffers
    glDeleteBuffers(3, _vertexBuffers);
    glDeleteBuffers(1, &_indexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    // Delete vertices buffers
    if (vertices)
        free(vertices);
    if (indices)
        free(indices);
    if (normals)
        free(normals);
    if (texCoords)
        free(texCoords);
    
    // Delete shader program
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}


#pragma mark - iOS gesture events

- (IBAction)doSingleTap:(UITapGestureRecognizer *)recognizer
{
    dragStart = [recognizer locationInView:self.view];
}

- (IBAction)doRotate:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state == UIGestureRecognizerStateBegan ) {
        dragStart = [recognizer locationInView:self.view];
    }
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        CGPoint newPt = [recognizer locationInView:self.view];
        float yDrag = newPt.y - dragStart.y;
        float xDrag = newPt.x - dragStart.x;
        if (xDrag > 60) {
            [self rotateRight];
            dragStart = [recognizer locationInView:self.view];
        }
        if (xDrag < -60) {
            [self rotateLeft];
            dragStart = [recognizer locationInView:self.view];
        }
        if (yDrag > 60) {
            [self takeStepBackward];
            dragStart = [recognizer locationInView:self.view];
        }
        if (yDrag < -60) {
            [self takeStepForward];
            dragStart = [recognizer locationInView:self.view];
        }
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    [self calculateMatrices];
    [self updateMovement];
    [self setLighting:_dayNightToggle.isOn];
}

- (void)calculateMatrices {
    // Set up base model view matrix (place camera)
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0f, 0.0);
    GLKMatrix4 baseMapModelViewMatrix = GLKMatrix4MakeTranslation(-_mazeHeight/2.0, _mazeWidth/2.0, -20.0f);
    baseMapModelViewMatrix = GLKMatrix4RotateX(baseMapModelViewMatrix, M_PI / 2);
    //baseModelViewMatrix = GLKMatrix4RotateY(baseModelViewMatrix, _rotation);
    
    // Calculate projection matrix
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:_x * 2 zPos:_z * 2 xScale:0.5 zScale:0.5 isTopDown:true];
    modelViewMatrix = GLKMatrix4Multiply(baseMapModelViewMatrix, modelViewMatrix);
    _playerNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
    _playerModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
    
    [_mazeTiles removeAllObjects];
    for(int col = 0; col < _mazeWidth; col++) {
        for(int row = 0; row < _mazeHeight; row++) {
            MazeTile *mazeTile = [_mazeManager getMazePosition:col y:row];
            mazeTile->column = col;
            mazeTile->row = row;
            
            if (mazeTile->north) {
                //Regular Map
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:col zPos:row - 0.5 xScale:0.8 zScale:0.2f isTopDown:false];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                mazeTile->northNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->northModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                
                //Minimap
                modelViewMatrix = [self generateModelViewMatrix:col zPos:row - 0.5 xScale:0.8 zScale:0.2f isTopDown:true];
                modelViewMatrix = GLKMatrix4Multiply(baseMapModelViewMatrix, modelViewMatrix);
                mazeTile->mapNorthNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->mapNorthModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            }
            if (mazeTile->south) {
                //Regular Map
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:col zPos:row + 0.5 xScale:0.8 zScale:0.2f isTopDown:false];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                mazeTile->southNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->southModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                
                //Minimap
                modelViewMatrix = [self generateModelViewMatrix:col zPos:row + 0.5 xScale:0.8 zScale:0.2f isTopDown:true];
                modelViewMatrix = GLKMatrix4Multiply(baseMapModelViewMatrix, modelViewMatrix);
                mazeTile->mapSouthNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->mapSouthModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            }
            if (mazeTile->east) {
                //Regular Map
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:col + 0.5 zPos:row xScale:0.2f zScale:0.8 isTopDown:false];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                mazeTile->eastNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->eastModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                
                //Minimap
                modelViewMatrix = [self generateModelViewMatrix:col + 0.5 zPos:row xScale:0.2f zScale:0.8 isTopDown:true];
                modelViewMatrix = GLKMatrix4Multiply(baseMapModelViewMatrix, modelViewMatrix);
                mazeTile->mapEastNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->mapEastModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            }
            if (mazeTile->west) {
                //Regular Map
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:col - 0.5 zPos:row xScale:0.2f zScale:0.8 isTopDown:false];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                mazeTile->westNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->westModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                
                //Minimap
                modelViewMatrix = [self generateModelViewMatrix:col - 0.5 zPos:row xScale:0.2f zScale:0.8 isTopDown:true];
                modelViewMatrix = GLKMatrix4Multiply(baseMapModelViewMatrix, modelViewMatrix);
                mazeTile->mapWestNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                mazeTile->mapWestModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            }
            
            GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
            modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, GLKMathDegreesToRadians(_rotation));
            modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 1, 0.1, 1);
            modelViewMatrix = GLKMatrix4Translate(modelViewMatrix, col, -10.0, row);
            modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
            mazeTile->floorNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
            mazeTile->floorModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
            
            [_mazeTiles addObject:mazeTile];
        }
    }
}

- (GLKMatrix4)generateModelViewMatrix:(float)xPos zPos:(float)zPos xScale:(float)xScale zScale:(float)zScale isTopDown:(bool)isTopDown
{
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    if(!isTopDown) {
        modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, GLKMathDegreesToRadians(_rotation));
    }
    modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, xScale, 1, zScale);
    return GLKMatrix4Translate(modelViewMatrix, (xPos + _x) * 1/xScale, 0.0, (zPos + _z) * 1/zScale);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.5f, 0.5f, 0.5f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    glBindVertexArrayOES(_vertexArray);
    glUseProgram(_program);
    
    [self renderMaze];
    if (_consoleOn) {
        [self renderMinimap];
    }

}

- (void)renderMaze {
    // Set up uniforms
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _modelViewMatrix.m);
    /* set lighting parameters... */
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    
    // Floor
    [self renderCube:_floorModelProjectionMatrix normal:_floorNormalMatrix texture:_textures->textureFloor];
    
    // Maze tiles
    for(MazeTile* mazeTile in _mazeTiles) {
        if (mazeTile->north) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:NORTH]];
            [self renderCube:mazeTile->northModelProjectionMatrix normal:mazeTile->northNormalMatrix texture:texture];
        }
        if (mazeTile->south) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:SOUTH]];
            [self renderCube:mazeTile->southModelProjectionMatrix normal:mazeTile->southNormalMatrix texture:texture];
        }
        if (mazeTile->east) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:EAST]];
            [self renderCube:mazeTile->eastModelProjectionMatrix normal:mazeTile->eastNormalMatrix texture:texture];
        }
        if (mazeTile->west) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:WEST]];
            [self renderCube:mazeTile->westModelProjectionMatrix normal:mazeTile->westNormalMatrix texture:texture];
        }
        [self renderCube:mazeTile->floorModelProjectionMatrix normal:mazeTile->floorNormalMatrix texture:_textures->textureFloor];
    }
}

- (void)renderMinimap {
    // Set up uniforms
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, _modelViewProjectionMatrix.m);
    //glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, _normalMatrix.m);
    //glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEW_MATRIX], 1, 0, _modelViewMatrix.m);
    /* set lighting parameters... */
    glUniform3fv(uniforms[UNIFORM_FLASHLIGHT_POSITION], 1, flashlightPosition.v);
    glUniform3fv(uniforms[UNIFORM_DIFFUSE_LIGHT_POSITION], 1, diffuseLightPosition.v);
    glUniform4fv(uniforms[UNIFORM_DIFFUSE_COMPONENT], 1, diffuseComponent.v);
    glUniform1f(uniforms[UNIFORM_SHININESS], shininess);
    glUniform4fv(uniforms[UNIFORM_SPECULAR_COMPONENT], 1, specularComponent.v);
    glUniform4fv(uniforms[UNIFORM_AMBIENT_COMPONENT], 1, ambientComponent.v);
    
    //Player
    [self renderCube:_playerModelProjectionMatrix normal:_playerNormalMatrix texture:_textures->texturePlayer];
    
    for(MazeTile* mazeTile in _mazeTiles) {
        if (mazeTile->north) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:NORTH]];
            [self renderCube:mazeTile->mapNorthModelProjectionMatrix normal:mazeTile->mapNorthNormalMatrix texture:texture];
        }
        if (mazeTile->south) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:SOUTH]];
            [self renderCube:mazeTile->mapSouthModelProjectionMatrix normal:mazeTile->mapSouthNormalMatrix texture:texture];
        }
        if (mazeTile->east) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:EAST]];
            [self renderCube:mazeTile->mapEastModelProjectionMatrix normal:mazeTile->mapEastNormalMatrix texture:texture];
        }
        if (mazeTile->west) {
            GLuint texture = [self getTexture:[self getWallCount:mazeTile direction:WEST]];
            [self renderCube:mazeTile->mapWestModelProjectionMatrix normal:mazeTile->mapWestNormalMatrix texture:texture];
        }
    }
}

- (void)renderCube:(GLKMatrix4)projection normal:(GLKMatrix3)normal texture:(GLuint)texture {
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, projection.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, normal.m);
    glBindTexture(GL_TEXTURE_2D, texture);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0);
}

- (void)updateMovement {
    if (_rotation < _rotationToBe) {
        _rotation += 15;
    } else if (_rotation > _rotationToBe) {
        _rotation -= 15;
    }
    /*float moveSpeed = 0.05;
    float rotationSpeed = 90 / 5;
    if (_z < _zToBe) {
        _z += moveSpeed;
    } else if (_z > _zToBe) {
        _z -= moveSpeed;
    } else {
        _canMove = true;
        _z = _zToBe;
    }
    if (_x < _xToBe) {
        _x += moveSpeed;
    } else if (_x > _xToBe) {
        _x -= moveSpeed;
    } else {
        _canMove = true;
        _x = _xToBe;
    }
    if (fabsf(_rotation - _rotationToBe) < 5) {
        _rotation = _rotationToBe;
        _canMove = true;
    } else {
        if (_rotation < _rotationToBe) {
            _rotation += rotationSpeed;
        } else if (_rotation > _rotationToBe) {
            _rotation -= rotationSpeed;
        } else {
            NSLog(@"updateMovement->Unreachable Code");
        }
    }*/
}

- (void)takeStepForward {
    switch((int)_rotation % 360) {
        case 0:
            _z += 1;
            break;
        case 90:
        case -270:
            _x -= 1;
            break;
        case 180:
        case -180:
            _z -= 1;
            break;
        case 270:
        case -90:
            _x += 1;
            break;
    }
    /*_canMove = false;
    switch (_direction) {
        case NORTH:
            _zToBe = _z + 0.5;
            break;
        case SOUTH:
            _zToBe = _z - 0.5;
            break;
        case EAST:
            _xToBe = _x - 0.5;
            break;
        case WEST:
            _xToBe = _x + 0.5;
            break;
        default:
            break;
    }*/
}

- (void)takeStepBackward {
    switch((int)_rotation % 360) {
        case 0:
            _z -= 1;
            break;
        case 90:
        case -270:
            _x += 1;
            break;
        case 180:
        case -180:
            _z += 1;
            break;
        case 270:
        case -90:
            _x -= 1;
            break;
    }
    /*_canMove = false;
    switch (_direction) {
        case NORTH:
            _zToBe = _z - 0.5;
            break;
        case SOUTH:
            _zToBe = _z + 0.5;
            break;
        case EAST:
            _xToBe = _x + 0.5;
            break;
        case WEST:
            _xToBe = _x - 0.5;
            break;
        default:
            break;
    }*/
}

- (GLuint) getTexture:(int)adjacentWallCount {
    GLuint texture = 0;
    switch (adjacentWallCount) {
        case 0:
            texture = _textures->textureOne;
            break;
        case 1:
            texture = _textures->textureTwo;
            break;
        case 2:
            texture = _textures->textureThree;
            break;
        case 3:
            texture = _textures->textureFour;
            break;
        default:
            break;
    }
    return texture;
}

- (int)getWallCount:(MazeTile*)mazeTile direction:(Direction)direction {
    int result = 0;
    switch (direction) {
        case NORTH:
            if (mazeTile->east) {
                result += 1;
            }
            if (mazeTile->west) {
                result += 2;
            }
            break;
        case SOUTH:
            if (mazeTile->east) {
                result += 2;
            }
            if (mazeTile->west) {
                result += 1;
            }
            break;
        case EAST:
            if (mazeTile->north) {
                result += 2;
            }
            if (mazeTile->south) {
                result += 1;
            }
            break;
        case WEST:
            if (mazeTile->north) {
                result += 1;
            }
            if (mazeTile->south) {
                result += 2;
            }
            break;
        default:
            break;
    }
    return result;
}

- (void)rotateLeft {
    _canMove = false;
    _rotationToBe -= 90;
}

- (void)rotateRight {
    _canMove = false;
    _rotationToBe -= 90;
}

#pragma mark -  OpenGL ES 2 shader compilation

- (BOOL)loadShaders
{
    GLuint vertShader, fragShader;
    NSString *vertShaderPathname, *fragShaderPathname;
    
    // Create shader program.
    _program = glCreateProgram();
    
    // Create and compile vertex shader.
    vertShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"vsh"];
    if (![self compileShader:&vertShader type:GL_VERTEX_SHADER file:vertShaderPathname]) {
        NSLog(@"Failed to compile vertex shader");
        return NO;
    }
    
    // Create and compile fragment shader.
    fragShaderPathname = [[NSBundle mainBundle] pathForResource:@"Shader" ofType:@"fsh"];
    if (![self compileShader:&fragShader type:GL_FRAGMENT_SHADER file:fragShaderPathname]) {
        NSLog(@"Failed to compile fragment shader");
        return NO;
    }
    
    // Attach vertex shader to program.
    glAttachShader(_program, vertShader);
    
    // Attach fragment shader to program.
    glAttachShader(_program, fragShader);
    
    // Bind attribute locations.
    // This needs to be done prior to linking.
    glBindAttribLocation(_program, GLKVertexAttribPosition, "position");
    glBindAttribLocation(_program, GLKVertexAttribNormal, "normal");
    glBindAttribLocation(_program, GLKVertexAttribTexCoord0, "texCoordIn");
    
    // Link program.
    if (![self linkProgram:_program]) {
        NSLog(@"Failed to link program: %d", _program);
        
        if (vertShader) {
            glDeleteShader(vertShader);
            vertShader = 0;
        }
        if (fragShader) {
            glDeleteShader(fragShader);
            fragShader = 0;
        }
        if (_program) {
            glDeleteProgram(_program);
            _program = 0;
        }
        
        return NO;
    }
    
    // Release vertex and fragment shaders.
    if (vertShader) {
        glDetachShader(_program, vertShader);
        glDeleteShader(vertShader);
    }
    if (fragShader) {
        glDetachShader(_program, fragShader);
        glDeleteShader(fragShader);
    }
    
    return YES;
}

- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file
{
    GLint status;
    const GLchar *source;
    
    source = (GLchar *)[[NSString stringWithContentsOfFile:file encoding:NSUTF8StringEncoding error:nil] UTF8String];
    if (!source) {
        NSLog(@"Failed to load vertex shader");
        return NO;
    }
    
    *shader = glCreateShader(type);
    glShaderSource(*shader, 1, &source, NULL);
    glCompileShader(*shader);
    
#if defined(DEBUG)
    GLint logLength;
    glGetShaderiv(*shader, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetShaderInfoLog(*shader, logLength, &logLength, log);
        NSLog(@"Shader compile log:\n%s", log);
        free(log);
    }
#endif
    
    glGetShaderiv(*shader, GL_COMPILE_STATUS, &status);
    if (status == 0) {
        glDeleteShader(*shader);
        return NO;
    }
    
    return YES;
}

- (BOOL)linkProgram:(GLuint)prog
{
    GLint status;
    glLinkProgram(prog);
    
#if defined(DEBUG)
    GLint logLength;
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program link log:\n%s", log);
        free(log);
    }
#endif
    
    glGetProgramiv(prog, GL_LINK_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}

- (BOOL)validateProgram:(GLuint)prog
{
    GLint logLength, status;
    
    glValidateProgram(prog);
    glGetProgramiv(prog, GL_INFO_LOG_LENGTH, &logLength);
    if (logLength > 0) {
        GLchar *log = (GLchar *)malloc(logLength);
        glGetProgramInfoLog(prog, logLength, &logLength, log);
        NSLog(@"Program validate log:\n%s", log);
        free(log);
    }
    
    glGetProgramiv(prog, GL_VALIDATE_STATUS, &status);
    if (status == 0) {
        return NO;
    }
    
    return YES;
}



#pragma mark - Utility functions

// Load in and set up texture image (adapted from Ray Wenderlich)
- (GLuint)setupTexture:(NSString *)fileName
{
    CGImageRef spriteImage = [UIImage imageNamed:fileName].CGImage;
    if (!spriteImage) {
        NSLog(@"Failed to load image %@", fileName);
        exit(1);
    }
    
    size_t width = CGImageGetWidth(spriteImage);
    size_t height = CGImageGetHeight(spriteImage);
    
    GLubyte *spriteData = (GLubyte *) calloc(width*height*4, sizeof(GLubyte));
    
    CGContextRef spriteContext = CGBitmapContextCreate(spriteData, width, height, 8, width*4, CGImageGetColorSpace(spriteImage), kCGImageAlphaPremultipliedLast);
    
    CGContextDrawImage(spriteContext, CGRectMake(0, 0, width, height), spriteImage);
    
    CGContextRelease(spriteContext);
    
    GLuint texName;
    glGenTextures(1, &texName);
    glBindTexture(GL_TEXTURE_2D, texName);
    
    glTexParameteri(GL_TEXTURE_2D, GL_TEXTURE_MIN_FILTER, GL_NEAREST);
    
    glTexImage2D(GL_TEXTURE_2D, 0, GL_RGBA, width, height, 0, GL_RGBA, GL_UNSIGNED_BYTE, spriteData);
    
    free(spriteData);
    return texName;
}

// Generate vertices, normals, texture coordinates and indices for cube
//      Adapted from Dan Ginsburg, Budirijanto Purnomo from the book
//      OpenGL(R) ES 2.0 Programming Guide
int generateCube(float scale, GLfloat **vertices, GLfloat **normals,
                 GLfloat **texCoords, GLuint **indices, int *numVerts)
{
    int i;
    int numVertices = 24;
    int numIndices = 36;
    
    GLfloat cubeVerts[] =
    {
        -0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f,  0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f, -0.5f, -0.5f,
        -0.5f,  0.5f, -0.5f,
        -0.5f,  0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
        0.5f,  0.5f, -0.5f,
        -0.5f, -0.5f, -0.5f,
        -0.5f,  0.5f, -0.5f,
        0.5f,  0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f, 0.5f,
        -0.5f,  0.5f, 0.5f,
        0.5f,  0.5f, 0.5f,
        0.5f, -0.5f, 0.5f,
        -0.5f, -0.5f, -0.5f,
        -0.5f, -0.5f,  0.5f,
        -0.5f,  0.5f,  0.5f,
        -0.5f,  0.5f, -0.5f,
        0.5f, -0.5f, -0.5f,
        0.5f, -0.5f,  0.5f,
        0.5f,  0.5f,  0.5f,
        0.5f,  0.5f, -0.5f,
    };
    
    GLfloat cubeNormals[] =
    {
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, -1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 1.0f, 0.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, -1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        0.0f, 0.0f, 1.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        -1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
        1.0f, 0.0f, 0.0f,
    };
    
    GLfloat cubeTex[] =
    {
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        1.0f, 0.0f,
        1.0f, 1.0f,
        0.0f, 1.0f,
        0.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
        0.0f, 0.0f,
        0.0f, 1.0f,
        1.0f, 1.0f,
        1.0f, 0.0f,
    };
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *vertices, cubeVerts, sizeof ( cubeVerts ) );
        
        for ( i = 0; i < numVertices * 3; i++ )
        {
            ( *vertices ) [i] *= scale;
        }
    }
    
    if ( normals != NULL )
    {
        *normals = malloc ( sizeof ( GLfloat ) * 3 * numVertices );
        memcpy ( *normals, cubeNormals, sizeof ( cubeNormals ) );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = malloc ( sizeof ( GLfloat ) * 2 * numVertices );
        memcpy ( *texCoords, cubeTex, sizeof ( cubeTex ) ) ;
    }
    
    
    // Generate the indices
    if ( indices != NULL )
    {
        GLuint cubeIndices[] =
        {
            0, 2, 1,
            0, 3, 2,
            4, 5, 6,
            4, 6, 7,
            8, 9, 10,
            8, 10, 11,
            12, 15, 14,
            12, 14, 13,
            16, 17, 18,
            16, 18, 19,
            20, 23, 22,
            20, 22, 21
        };
        
        *indices = malloc ( sizeof ( GLuint ) * numIndices );
        memcpy ( *indices, cubeIndices, sizeof ( cubeIndices ) );
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

// Generate vertices, normals, texture coordinates and indices for sphere
//      Adapted from Dan Ginsburg, Budirijanto Purnomo from the book
//      OpenGL(R) ES 2.0 Programming Guide
int generateSphere(int numSlices, float radius, GLfloat **vertices, GLfloat **normals,
                   GLfloat **texCoords, GLuint **indices, int *numVerts)
{
    int i;
    int j;
    int numParallels = numSlices / 2;
    int numVertices = ( numParallels + 1 ) * ( numSlices + 1 );
    int numIndices = numParallels * numSlices * 6;
    float angleStep = ( 2.0f * M_PI ) / ( ( float ) numSlices );
    
    // Allocate memory for buffers
    if ( vertices != NULL )
    {
        *vertices = malloc ( sizeof ( GLfloat ) * 3 * numVertices );
    }
    
    if ( normals != NULL )
    {
        *normals = malloc ( sizeof ( GLfloat ) * 3 * numVertices );
    }
    
    if ( texCoords != NULL )
    {
        *texCoords = malloc ( sizeof ( GLfloat ) * 2 * numVertices );
    }
    
    if ( indices != NULL )
    {
        *indices = malloc ( sizeof ( GLuint ) * numIndices );
    }
    
    for ( i = 0; i < numParallels + 1; i++ )
    {
        for ( j = 0; j < numSlices + 1; j++ )
        {
            int vertex = ( i * ( numSlices + 1 ) + j ) * 3;
            
            if ( vertices )
            {
                ( *vertices ) [vertex + 0] = radius * sinf ( angleStep * ( float ) i ) *
                sinf ( angleStep * ( float ) j );
                ( *vertices ) [vertex + 1] = radius * cosf ( angleStep * ( float ) i );
                ( *vertices ) [vertex + 2] = radius * sinf ( angleStep * ( float ) i ) *
                cosf ( angleStep * ( float ) j );
            }
            
            if ( normals )
            {
                ( *normals ) [vertex + 0] = ( *vertices ) [vertex + 0] / radius;
                ( *normals ) [vertex + 1] = ( *vertices ) [vertex + 1] / radius;
                ( *normals ) [vertex + 2] = ( *vertices ) [vertex + 2] / radius;
            }
            
            if ( texCoords )
            {
                int texIndex = ( i * ( numSlices + 1 ) + j ) * 2;
                ( *texCoords ) [texIndex + 0] = ( float ) j / ( float ) numSlices;
                ( *texCoords ) [texIndex + 1] = ( 1.0f - ( float ) i ) / ( float ) ( numParallels - 1 );
            }
        }
    }
    
    // Generate the indices
    if ( indices != NULL )
    {
        GLuint *indexBuf = ( *indices );
        
        for ( i = 0; i < numParallels ; i++ )
        {
            for ( j = 0; j < numSlices; j++ )
            {
                *indexBuf++  = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                
                *indexBuf++ = i * ( numSlices + 1 ) + j;
                *indexBuf++ = ( i + 1 ) * ( numSlices + 1 ) + ( j + 1 );
                *indexBuf++ = i * ( numSlices + 1 ) + ( j + 1 );
            }
        }
    }
    
    if (numVerts != NULL)
        *numVerts = numVertices;
    return numIndices;
}

// >>>

@end
