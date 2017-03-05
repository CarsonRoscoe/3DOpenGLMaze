//
//  Shader.fsh
//  OpenGLMaze
//
//  Created by Carson Roscoe on 2017-03-02.
//  Copyright © 2017 CEDJ. All rights reserved.
//

varying lowp vec4 colorVarying;
/*varying highp vec2 textureCoordinateInterpolated;
uniform sampler2D textureUnit;*/

//varying lowp vec2 TexCoordOut; // New
//uniform sampler2D Texture; // New


void main()
{
    gl_FragColor = colorVarying;
    //gl_FragColor = texture2D(Texture, TexCoordOut); // New
    //gl_FragColor = texture2D(textureUnit, textureCoordinateInterpolated);
}

/*
 precision mediump float;
 
 varying vec3 eyeNormal;
 varying vec4 eyePos;
 varying vec2 texCoordOut;
/*set up a uniform sampler2D to get texture
uniform sampler2D texture;

//set up uniforms for lighting parameters
uniform vec3 flashlightPosition;
uniform vec3 diffuseLightPosition;
uniform vec4 diffuseComponent;
uniform float shininess;
uniform vec4 specularComponent;
uniform vec4 ambientComponent;

void main()
{
    vec4 ambient = ambientComponent;
    
    vec3 N = normalize(eyeNormal);
    float nDotVP = max(0.0, dot(N, normalize(diffuseLightPosition)));
    vec4 diffuse = diffuseComponent * nDotVP;
    
    vec3 E = normalize(-eyePos.xyz);
    vec3 L = normalize(flashlightPosition - eyePos.xyz);
    vec3 H = normalize(L+E);
    float Ks = pow(max(dot(N, H), 0.0), shininess);
    vec4 specular = Ks*specularComponent;
    if( dot(L, N) < 0.0 ) {
        specular = vec4(0.0, 0.0, 0.0, 1.0);
    }
    
    //add ambient and specular components here as in:
    gl_FragColor = (ambient + diffuse + specular) * texture2D(texture, texCoordOut);
    gl_FragColor.a = 1.0;
}
 */
