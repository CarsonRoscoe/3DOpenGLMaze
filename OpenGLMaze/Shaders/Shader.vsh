//
//  Shader.vsh
//  OpenGLMaze
//
//  Created by Carson Roscoe on 2017-03-02.
//  Copyright © 2017 CEDJ. All rights reserved.
//

attribute vec4 position;
attribute vec3 normal;
//attribute vec2 textureCoordinate;

varying lowp vec4 colorVarying;

uniform mat4 modelViewProjectionMatrix;
uniform mat3 normalMatrix;

//attribute vec2 TexCoordIn; // New
//varying vec2 TexCoordOut; // New

//varying vec2 textureCoordinateInterpolated;

void main()
{
    vec3 eyeNormal = normalize(normalMatrix * normal);
    vec3 lightPosition = vec3(0.0, 0.0, 1.0);
    vec4 diffuseColor = vec4(0.4, 0.4, 1.0, 1.0);
    
    float nDotVP = max(0.0, dot(eyeNormal, normalize(lightPosition)));
                 
    colorVarying = diffuseColor * nDotVP;
    
    gl_Position = modelViewProjectionMatrix * position;
    //TexCoordOut = TexCoordIn; // New
    //textureCoordinateInterpolated = textureCoordinate;
}

/*
 precision mediump float;
 
 attribute vec4 position;
 attribute vec3 normal;
 attribute vec2 texCoordIn;
 
 varying vec3 eyeNormal;
 varying vec4 eyePos;
 varying vec2 texCoordOut;
 
 uniform mat4 modelViewProjectionMatrix;
 uniform mat4 modelViewMatrix;
 uniform mat3 normalMatrix;
 
 void main()
 {
 // Calculate normal vector in eye coordinates
 eyeNormal = (normalMatrix * normal);
 
 // Calculate vertex position in view coordinates
 eyePos = modelViewMatrix * position;
 
 // Pass through texture coordinate
 texCoordOut = texCoordIn;
 
 // Set gl_Position with transformed vertex position
 gl_Position = modelViewProjectionMatrix * position;
 }
 */
