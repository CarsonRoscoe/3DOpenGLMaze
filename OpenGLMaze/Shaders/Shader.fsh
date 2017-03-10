//
//  Shader.fsh
//  OpenGLMaze
//
//  Created by Carson Roscoe on 2017-03-02.
//  Copyright © 2017 CEDJ. All rights reserved.
//


precision mediump float;
 
varying vec3 eyeNormal;
varying vec4 eyePos;
varying vec2 texCoordOut;
//set up a uniform sampler2D to get texture
uniform sampler2D texture;

//set up uniforms for lighting parameters
uniform vec3 flashlightPosition;
uniform vec3 diffuseLightPosition;
uniform vec4 diffuseComponent;
uniform float shininess;
uniform vec4 specularComponent;
uniform vec4 ambientComponent;

//Raw screen coordinate x/y
uniform vec2 screenSizeComponent;

void main()
{
    vec4 ambient = ambientComponent;
    
    vec3 N = normalize(eyeNormal);
    float nDotVP = max(1.0, dot(N, normalize(diffuseLightPosition)));
    vec4 diffuse = diffuseComponent * nDotVP;
    
    vec3 E = normalize(-eyePos.xyz);
    vec3 L = normalize(flashlightPosition - eyePos.xyz);
    vec3 H = normalize(L+E);
    float Ks = pow(max(dot(N, H), 0.0), shininess);
    vec4 specular = Ks * specularComponent;
    if( dot(L, N) < 0.0 ) {
        specular = vec4(0.1, 0.1, 0.1, 1.0);
    }
    
    //Flashlight logic
    float lightValue = 1.0;
    if (screenSizeComponent.x != -1.0) {
        vec2 screen = vec2(screenSizeComponent.x * 3.0, screenSizeComponent.y * 3.0);
        vec2 glFragCoord = vec2(gl_FragCoord.x / screen.x, gl_FragCoord.y / screen.y);
        float dist = distance(glFragCoord, vec2(0.5, 0.5));
        if (dist < 0.2) {
            lightValue = 1.0 + (0.2 - dist) * 10.0;
        }
    }
    
    //Fog logic
    /*vec3 pixelPosition = vec3(eyePos.x, eyePos.y, eyePos.z);
    float distanceToPlayer = distance(flashlightPosition, pixelPosition);
    vec3 fogColor = vec3(0.5, 0.5, 0.5);
    if (distanceToPlayer > 1.0) {
        
    } else {
        
    }*/
    
    //add ambient and specular components here as in:
    gl_FragColor = ((ambient + diffuse + specular) * texture2D(texture, texCoordOut)) * lightValue;
    
    gl_FragColor.a = 1.0;
}
 
