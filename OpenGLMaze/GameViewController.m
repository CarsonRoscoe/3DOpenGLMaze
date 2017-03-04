//
//  GameViewController.m
//  OpenGLMaze
//
//  Created by Carson Roscoe on 2017-03-02.
//  Copyright © 2017 CEDJ. All rights reserved.
//

#import "GameViewController.h"
#import <OpenGLES/ES2/glext.h>

#define BUFFER_OFFSET(i) ((char *)NULL + (i))

// Uniform index.
enum
{
    UNIFORM_MODELVIEWPROJECTION_MATRIX,
    UNIFORM_NORMAL_MATRIX,
    NUM_UNIFORMS
};
GLint uniforms[NUM_UNIFORMS];

// Attribute index.
enum
{
    ATTRIB_VERTEX,
    ATTRIB_NORMAL,
    NUM_ATTRIBUTES
};

//Remove later when linked to C++
struct MazeCell
{
    bool northWallPresent;
    bool southWallPresent;
    bool eastWallPresent;
    bool westWallPresent;
};

@interface Textures: NSObject {
    @public GLuint textureOne;
    @public GLuint textureTwo;
    @public GLuint textureThree;
    @public GLuint textureFour;
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

//UV Coordinates go (0,0) to (1,0) where (0,0) is top left and (1,1) is top right
GLfloat quadTextureCoordinates[8] = {
    0.0f, 1.0f,
    1.0f, 1.0f,
    0.0f, 0.0f,
    1.0f, 0.0f
};


GLfloat gCubeVertexData[216] =
{
    // Data layout for each line below is:
    // positionX, positionY, positionZ,     normalX, normalY, normalZ,
    0.5f, -0.5f, -0.5f,        1.0f, 0.0f, 0.0f,
    0.5f, 0.5f, -0.5f,         1.0f, 0.0f, 0.0f,
    0.5f, -0.5f, 0.5f,         1.0f, 0.0f, 0.0f,
    0.5f, -0.5f, 0.5f,         1.0f, 0.0f, 0.0f,
    0.5f, 0.5f, -0.5f,          1.0f, 0.0f, 0.0f,
    0.5f, 0.5f, 0.5f,         1.0f, 0.0f, 0.0f,
    
    0.5f, 0.5f, -0.5f,         0.0f, 1.0f, 0.0f,
    -0.5f, 0.5f, -0.5f,        0.0f, 1.0f, 0.0f,
    0.5f, 0.5f, 0.5f,          0.0f, 1.0f, 0.0f,
    0.5f, 0.5f, 0.5f,          0.0f, 1.0f, 0.0f,
    -0.5f, 0.5f, -0.5f,        0.0f, 1.0f, 0.0f,
    -0.5f, 0.5f, 0.5f,         0.0f, 1.0f, 0.0f,
    
    -0.5f, 0.5f, -0.5f,        -1.0f, 0.0f, 0.0f,
    -0.5f, -0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,
    -0.5f, 0.5f, 0.5f,         -1.0f, 0.0f, 0.0f,
    -0.5f, 0.5f, 0.5f,         -1.0f, 0.0f, 0.0f,
    -0.5f, -0.5f, -0.5f,       -1.0f, 0.0f, 0.0f,
    -0.5f, -0.5f, 0.5f,        -1.0f, 0.0f, 0.0f,
    
    -0.5f, -0.5f, -0.5f,       0.0f, -1.0f, 0.0f,
    0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,
    -0.5f, -0.5f, 0.5f,        0.0f, -1.0f, 0.0f,
    -0.5f, -0.5f, 0.5f,        0.0f, -1.0f, 0.0f,
    0.5f, -0.5f, -0.5f,        0.0f, -1.0f, 0.0f,
    0.5f, -0.5f, 0.5f,         0.0f, -1.0f, 0.0f,
    
    0.5f, 0.5f, 0.5f,          0.0f, 0.0f, 1.0f,
    -0.5f, 0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    0.5f, -0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    -0.5f, 0.5f, 0.5f,         0.0f, 0.0f, 1.0f,
    -0.5f, -0.5f, 0.5f,        0.0f, 0.0f, 1.0f,
    
    0.5f, -0.5f, -0.5f,        0.0f, 0.0f, -1.0f,
    -0.5f, -0.5f, -0.5f,       0.0f, 0.0f, -1.0f,
    0.5f, 0.5f, -0.5f,         0.0f, 0.0f, -1.0f,
    0.5f, 0.5f, -0.5f,         0.0f, 0.0f, -1.0f,
    -0.5f, -0.5f, -0.5f,       0.0f, 0.0f, -1.0f,
    -0.5f, 0.5f, -0.5f,        0.0f, 0.0f, -1.0f
};

@interface GameViewController () {
    GLuint _program;
    
    GLKMatrix4 _modelViewProjectionMatrix;
    GLKMatrix3 _normalMatrix;
    
    GLuint _vertexArray;
    GLuint _vertexBuffer;
    int _mazeWidth;
    int _mazeHeight;
    NSMutableArray *_mazeTiles;
    Textures *_textures;
}
@property (strong, nonatomic) EAGLContext *context;
@property (strong, nonatomic) GLKBaseEffect *effect;

- (void)setupGL;
- (void)tearDownGL;

- (BOOL)loadShaders;
- (BOOL)compileShader:(GLuint *)shader type:(GLenum)type file:(NSString *)file;
- (BOOL)linkProgram:(GLuint)prog;
- (BOOL)validateProgram:(GLuint)prog;
@end

@implementation GameViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];

    if (!self.context) {
        NSLog(@"Failed to create ES context");
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    
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

    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)setupGL
{
    [EAGLContext setCurrentContext:self.context];
    
    [self loadShaders];
    
    _mazeWidth = 10;
    _mazeHeight = 10;
    _mazeTiles = [[NSMutableArray alloc] initWithCapacity:(_mazeWidth * _mazeHeight)];
    //Generate maze
    _textures = [[Textures alloc] init];
    //Path to image
    /*NSString *path = [[NSBundle mainBundle] pathForResource:@"Texture1" ofType:@"png"];
    
    //Set eaglContext
    [EAGLContext setCurrentContext:[[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2]];
    
    //Create texture
    NSError *theError;
    GLKTextureInfo *texture = [GLKTextureLoader textureWithContentsOfFile:path options:nil error:&theError];
    _textures->textureOne = texture.name;*/
    /* TODO:
    load textures and store into _textures structure
     http://stackoverflow.com/questions/3387132/how-to-load-and-display-image-in-opengl-es-for-iphone
    */
    
    self.effect = [[GLKBaseEffect alloc] init];
    self.effect.light0.enabled = GL_TRUE;
    self.effect.light0.diffuseColor = GLKVector4Make(1.0f, 0.4f, 0.4f, 1.0f);
    
    glEnable(GL_DEPTH_TEST);
    
    glGenVertexArraysOES(1, &_vertexArray);
    glBindVertexArrayOES(_vertexArray);
    
    glGenBuffers(1, &_vertexBuffer);
    glBindBuffer(GL_ARRAY_BUFFER, _vertexBuffer);
    glBufferData(GL_ARRAY_BUFFER, sizeof(gCubeVertexData), gCubeVertexData, GL_STATIC_DRAW);
    
    //Position
    glEnableVertexAttribArray(GLKVertexAttribPosition);
    glVertexAttribPointer(GLKVertexAttribPosition, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(0));
    //Normal
    glEnableVertexAttribArray(GLKVertexAttribNormal);
    glVertexAttribPointer(GLKVertexAttribNormal, 3, GL_FLOAT, GL_FALSE, 24, BUFFER_OFFSET(12));
    //Texture data
    /*glEnableVertexAttribArray(2);
    glVertexAttribPointer(2, 2, GL_FLOAT, GL_FALSE, 0, quadTextureCoordinates);*/
    
    glBindVertexArrayOES(0);
}

- (void)tearDownGL
{
    [EAGLContext setCurrentContext:self.context];
    
    glDeleteBuffers(1, &_vertexBuffer);
    glDeleteVertexArraysOES(1, &_vertexArray);
    
    self.effect = nil;
    
    if (_program) {
        glDeleteProgram(_program);
        _program = 0;
    }
}

#pragma mark - GLKView and GLKViewController delegate methods

- (void)update
{
    float aspect = fabs(self.view.bounds.size.width / self.view.bounds.size.height);
    GLKMatrix4 projectionMatrix = GLKMatrix4MakePerspective(GLKMathDegreesToRadians(65.0f), aspect, 0.1f, 100.0f);
    
    self.effect.transform.projectionMatrix = projectionMatrix;
    
    GLKMatrix4 baseModelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, -20.0f);
    baseModelViewMatrix = GLKMatrix4RotateX(baseModelViewMatrix, 0.4f);
    
    // Compute the model view matrix for the object rendered with ES2
    /*GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(0.0f, 0.0f, 1.5f);
    modelViewMatrix = GLKMatrix4Rotate(modelViewMatrix, _rotation, 1.0f, 1.0f, 1.0f);
    modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
    
    _normalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);*/
    
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
            float widthOffset = -_mazeWidth / 2.0f;
            
            if (mazeCell.northWallPresent) {
                GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(col + widthOffset, 1.0, row + 0.4f);
                modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 1, 0.2f, 1);
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                northNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                
                northProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                
                mazeTile->northNormalMatrix = northNormalMatrix;
                mazeTile->northModelProjectionMatrix = northProjectionMatrix;
            }
            if (mazeCell.southWallPresent) {
                GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(col + widthOffset, 1.0, row + 0.4f);
                modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 1, 0.2f, 1);
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                southNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                southProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                mazeTile->southNormalMatrix = southNormalMatrix;
                mazeTile->southModelProjectionMatrix = southProjectionMatrix;
            }
            if (mazeCell.eastWallPresent) {
                GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(col + 0.4f + widthOffset, 1.0, row);
                modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 0.2f, 1, 1);
                modelViewMatrix = GLKMatrix4Multiply(baseModelViewMatrix, modelViewMatrix);
                eastNormalMatrix = GLKMatrix3InvertAndTranspose(GLKMatrix4GetMatrix3(modelViewMatrix), NULL);
                eastProjectionMatrix = GLKMatrix4Multiply(projectionMatrix, modelViewMatrix);
                mazeTile->eastNormalMatrix = eastNormalMatrix;
                mazeTile->eastModelProjectionMatrix = eastProjectionMatrix;
            }
            if (mazeCell.westWallPresent) {
                GLKMatrix4 modelViewMatrix = GLKMatrix4MakeTranslation(col - 0.4f + widthOffset, 1.0, row);
                modelViewMatrix = GLKMatrix4Scale(modelViewMatrix, 0.2f, 1, 1);
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

- (void)glkView:(GLKView *)view drawInRect:(CGRect)rect
{
    glClearColor(0.65f, 0.65f, 0.65f, 1.0f);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    glBindVertexArrayOES(_vertexArray);
    
    glUseProgram(_program);
    
    for(MazeTile* mazeTile in _mazeTiles) {
        if (mazeTile->mazeCell.northWallPresent) {
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, mazeTile->northModelProjectionMatrix.m);
            glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, (mazeTile->northNormalMatrix).m);
            /*glUniform1i(glGetUniformLocation(_program, "textureUnit"), 0);
            glBindTexture(GL_TEXTURE_2D, _textures->textureOne);*/
            //set texture to north texture
            glDrawArrays(GL_TRIANGLES, 0, 36);
        }
        if (mazeTile->mazeCell.southWallPresent) {
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, mazeTile->southModelProjectionMatrix.m);
            glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, (mazeTile->southNormalMatrix).m);
            /*glUniform1i(glGetUniformLocation(_program, "textureUnit"), 0);
            glBindTexture(GL_TEXTURE_2D, _textures->textureOne);*/
            //set texture to south texture
            glDrawArrays(GL_TRIANGLES, 0, 36);
        }
        if (mazeTile->mazeCell.eastWallPresent) {
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, mazeTile->eastModelProjectionMatrix.m);
            glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, (mazeTile->eastNormalMatrix).m);
            /*glUniform1i(glGetUniformLocation(_program, "textureUnit"), 0);
            glBindTexture(GL_TEXTURE_2D, _textures->textureOne);*/
            //set texture to east texture
            glDrawArrays(GL_TRIANGLES, 0, 36);
        }
        if (mazeTile->mazeCell.westWallPresent) {
            glUniformMatrix4fv(uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX], 1, 0, mazeTile->westModelProjectionMatrix.m);
            glUniformMatrix3fv(uniforms[UNIFORM_NORMAL_MATRIX], 1, 0, (mazeTile->westNormalMatrix).m);
            /*glUniform1i(glGetUniformLocation(_program, "textureUnit"), 0);
            glBindTexture(GL_TEXTURE_2D, _textures->textureOne);*/
            //set texture to west texture
            glDrawArrays(GL_TRIANGLES, 0, 36);
        }
    }
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
    
    // Get uniform locations.
    uniforms[UNIFORM_MODELVIEWPROJECTION_MATRIX] = glGetUniformLocation(_program, "modelViewProjectionMatrix");
    uniforms[UNIFORM_NORMAL_MATRIX] = glGetUniformLocation(_program, "normalMatrix");
    
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
@end
