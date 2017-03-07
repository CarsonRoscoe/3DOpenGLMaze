//
//  GameViewController.m
//
//  Created by Borna Noureddin.
//  Copyright (c) 2015 BCIT. All rights reserved.
//

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

//Remove later when linked to C++
struct MazeCell
{
    bool northWallPresent;
    bool southWallPresent;
    bool eastWallPresent;
    bool westWallPresent;
};

@interface Textures: NSObject {\
@public GLuint textureOne;
@public GLuint textureTwo;
@public GLuint textureThree;
@public GLuint textureFour;
@public GLuint textureFloor;
} @end
@implementation Textures @end

// Maze object
@interface MazeTile : NSObject {
@public int column;
@public int row;
@public GLKMatrix3 northNormalMatrix;
@public GLKMatrix3 southNormalMatrix;
@public GLKMatrix3 eastNormalMatrix;
@public GLKMatrix3 westNormalMatrix;
@public GLKMatrix4 northModelProjectionMatrix;
@public GLKMatrix4 southModelProjectionMatrix;
@public GLKMatrix4 eastModelProjectionMatrix;
@public GLKMatrix4 westModelProjectionMatrix;
@public struct MazeCell mazeCell;
} @end
@implementation MazeTile @end

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
    bool _dayTime;
    
    // Floor
    GLKMatrix3 _floorNormalMatrix;
    GLKMatrix4 _floorModelProjectionMatrix;
    
    // Movement
    float _x;
    float _z;
    Direction _direction;
}

@property (strong, nonatomic) EAGLContext *context;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
- (void)setLighting:(bool)isDay;
- (void)takeStep;
- (void)turnLeft;
- (void)turnRight;
- (void)renderCube:(GLKMatrix4)projection normal:(GLKMatrix3)normal texture:(GLuint)texture;
- (GLKMatrix4)generateModelViewMatrix:(float)xPos zPos:(float)zPos xScale:(float)xScale zScale:(float)zScale;

@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    _direction = NORTH;
    _dayTime = true;
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
    
    _mazeWidth = 1;
    _mazeHeight = 1;
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
    _dayTime = !_dayTime;
}

- (IBAction)doRotate:(UIPanGestureRecognizer *)recognizer
{
    if (recognizer.state != UIGestureRecognizerStateEnded) {
        CGPoint newPt = [recognizer locationInView:self.view];
        _rotation = (newPt.x - dragStart.x) * M_PI / 180;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    // Set up base model view matrix (place camera)
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0f, 0.0);
    //baseModelViewMatrix = GLKMatrix4RotateY(baseModelViewMatrix, _rotation);

    // Calculate projection matrix
    float aspect = fabsf(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    //Floor
    GLKMatrix4 floorModelViewMatrix = GLKMatrix4MakeTranslation(0.0, 0.0, 0.0);
    floorModelViewMatrix = GLKMatrix4RotateY(floorModelViewMatrix, _rotation);
    floorModelViewMatrix = GLKMatrix4Scale(floorModelViewMatrix, _mazeWidth * 2, 1, _mazeHeight * 2);
    floorModelViewMatrix = GLKMatrix4Translate(floorModelViewMatrix, 0, -1.0, 0);
    floorModelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, floorModelViewMatrix);
    _floorNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(floorModelViewMatrix), NULL);
    _floorModelProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, floorModelViewMatrix);
    
    //_modelViewProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, _modelViewMatrix);
    
    [_mazeTiles removeAllObjects];
    for(int col = 0; col < _mazeWidth; col++) {
        for(int row = 0; row < _mazeHeight; row++) {
            struct MazeCell mazeCell;
            mazeCell.eastWallPresent = true;
            mazeCell.westWallPresent = true;
            mazeCell.northWallPresent = false;
            mazeCell.southWallPresent = false;
            GLKMatrix3 northNormalMatrix;
            GLKMatrix3 southNormalMatrix;
            GLKMatrix3 eastNormalMatrix;
            GLKMatrix3 westNormalMatrix;
            GLKMatrix4 northProjectionMatrix;
            GLKMatrix4 southProjectionMatrix;
            GLKMatrix4 eastProjectionMatrix;
            GLKMatrix4 westProjectionMatrix;
            
            MazeTile *mazeTile = [[MazeTile alloc] init];
            mazeTile->column = col;
            mazeTile->row = row;
            
            if (mazeCell.northWallPresent) {
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:col zPos:(row * 10 + 4.0f) xScale:1 zScale:0.1f];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                northNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                northProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                mazeTile->northNormalMatrix = northNormalMatrix;
                mazeTile->northModelProjectionMatrix = northProjectionMatrix;
            }
            if (mazeCell.southWallPresent) {
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:col zPos:(row * 10 - 4.0f) xScale:1 zScale:0.1f];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                southNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                southProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                mazeTile->southNormalMatrix = southNormalMatrix;
                mazeTile->southModelProjectionMatrix = southProjectionMatrix;
            }
            if (mazeCell.eastWallPresent) {
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:(col * 10 + 4.0f) zPos:row xScale:0.1f zScale:1.0];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                eastNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                eastProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                mazeTile->eastNormalMatrix = eastNormalMatrix;
                mazeTile->eastModelProjectionMatrix = eastProjectionMatrix;
            }
            if (mazeCell.westWallPresent) {
                GLKMatrix4 modelViewMatrix = [self generateModelViewMatrix:(col * 10 - 4.0f) zPos:row xScale:0.1f zScale:1.0];
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                westNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                westProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                mazeTile->westNormalMatrix = westNormalMatrix;
                mazeTile->westModelProjectionMatrix = westProjectionMatrix;
            }
            
            mazeTile->mazeCell = mazeCell;
            [_mazeTiles addObject:mazeTile];
        }
    }
}

- (GLKMatrix4)generateModelViewMatrix:(float)xPos zPos:(float)zPos xScale:(float)xScale zScale:(float)zScale
{
    GLKMatrix4 modelViewMatrix = GLKMatrix4Identity;
    modelViewMatrix = GLKMatrix4RotateY(modelViewMatrix, _rotation);
    modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, xScale, 1, zScale);
    return GLKMatrix4Translate(modelViewMatrix, xPos, 0.0, zPos);
}

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    // Clear window
    glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    // Select VAO and shaders
    glBindVertexArrayOES(_vertexArray);
    glUseProgram(_program);
    
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
    
    [self setLighting:_dayTime];
    
    // Floor
    [self renderCube:_floorModelProjectionMatrix normal:_floorNormalMatrix texture:_textures->textureFloor];
    
    // Maze tiles
    for(MazeTile* mazeTile in _mazeTiles) {
        if (mazeTile->mazeCell.northWallPresent) {
            [self renderCube:mazeTile->northModelProjectionMatrix normal:mazeTile->northNormalMatrix texture:_textures->textureOne];
        }
        if (mazeTile->mazeCell.southWallPresent) {
            [self renderCube:mazeTile->southModelProjectionMatrix normal:mazeTile->southNormalMatrix texture:_textures->textureTwo];
        }
        if (mazeTile->mazeCell.eastWallPresent) {
            [self renderCube:mazeTile->eastModelProjectionMatrix normal:mazeTile->eastNormalMatrix texture:_textures->textureThree];
        }
        if (mazeTile->mazeCell.westWallPresent) {
            [self renderCube:mazeTile->westModelProjectionMatrix normal:mazeTile->westNormalMatrix texture:_textures->textureFour];
        }
    }
    
    [self takeStep];
}

- (void)renderCube:(GLKMatrix4)projection normal:(GLKMatrix3)normal texture:(GLuint)texture {
    glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, projection.m);
    glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, normal.m);
    glBindTexture(GL_TEXTURE_2D, texture);
    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, _indexBuffer);
    glDrawElements(GL_TRIANGLES, numIndices, GL_UNSIGNED_INT, 0);
}

- (void)takeStep {
    switch (_direction) {
        case NORTH:
            _z += 1.0;
            break;
        case SOUTH:
            _z -= 1.0;
            break;
        case EAST:
            _x -= 1.0;
            break;
        case WEST:
            _x += 1.0;
            break;
        default:
            break;
    }
}

- (void)rotateLeft {
    
}

- (void)rotateRight {
    
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
