//
//  Shader.metal
//  MirrAR
//
//  Created by Bhautik Ziniya on 22/10/18.
//  Copyright © 2018 Magnates Technologies Pvt. Ltd. All rights reserved.
//

#include <metal_stdlib>
using namespace metal;

#include <SceneKit/scn_metal>

struct VertexInput {
    float3 position  [[attribute(SCNVertexSemanticPosition)]];
    float2 texCoords [[attribute(SCNVertexSemanticTexcoord0)]];
};

struct NodeBuffer {
    float4x4 modelViewProjectionTransform;
};

struct ColorInOut
{
    float4 position [[ position ]];
    float2 texCoords;
};

// Distance to the scene
constant float3 normalTopA      = normalize (float3 (0.0, 1.0, 1.4));
constant float3 normalTopB      = normalize (float3 (0.0, 1.0, 1.0));
constant float3 normalTopC      = normalize (float3 (0.0, 1.0, 0.5));
constant float3 normalBottomA   = normalize (float3 (0.0, -1.0, 1.0));
constant float3 normalBottomB   = normalize (float3 (0.0, -1.0, 1.6));

constant float RAY_LENGTH_MAX           = 20.0;
constant float RAY_BOUNCE_MAX           = 10;
constant float RAY_STEP_MAX             = 40;
constant float3 COLOR                   = float3 (0.8, 0.8, 0.9);
constant float ALPHA                    = 0.9;
constant float3 REFRACT_INDEX           = float3 (2.407, 2.426, 2.451);
constant float3 LIGHT                   = float3 (1.0, 1.0, -1.0);
constant float AMBIENT                  = 0.2;
constant float SPECULAR_POWER           = 3.0;
constant float SPECULAR_INTENSITY       = 0.5;
constant float DELTA                    = 0.001;

// Cast a ray for a given color channel (and its corresponding refraction index)
constant float3 lightDirection = normalize (LIGHT);

// Rotation matrix (rotation on the Y axis)
float3 vRotateY (float3 p, float angle) {
    float c = cos (angle);
    float s = sin (angle);
    return float3 (c * p.x - s * p.z, p.y, c * p.z + s * p.x);
}

float getDistance (float3 p) {
    //p = mRotate (vec3 (iTime)) * p;
    //    float PI = 3.14159265359;
    float topCut = p.y - 1.0;
    float angleStep = M_PI_F / (8.0 + floor (18.0));
    float angle = angleStep * (0.5 + floor (atan2 (p.x, p.z) / angleStep));
    float3 q = vRotateY (p, angle);
    float topA = dot (q, normalTopA) - 2.0;
    float topC = dot (q, normalTopC) - 1.5;
    float bottomA = dot (q, normalBottomA) - 1.7;
    q = vRotateY (p, -angleStep * 0.5);
    angle = angleStep * floor (atan2 (q.x, q.z) / angleStep);
    q = vRotateY (p, angle);
    float topB = dot (q, normalTopB) - 1.85;
    float bottomB = dot (q, normalBottomB) - 1.9;
    
    return max (topCut, max (topA, max (topB, max (topC, max (bottomA, bottomB)))));
}

// Normal at a given point
float3 getNormal (float3 p) {
    const float2 h = float2 (DELTA, -DELTA);
    return normalize (
                      h.xxx * getDistance(p + h.xxx) +
                      h.xyy * getDistance(p + h.xyy) +
                      h.yxy * getDistance(p + h.yxy) +
                      h.yyx * getDistance(p + h.yyx)
                      );
}

float raycast (float3 origin, float3 direction, float4 normal, float color, float3 channel) {
    
    // The ray continues...
    color *= 1.0 - ALPHA;
    float intensity = ALPHA;
    float distanceFactor = 1.0;
    float refractIndex = dot (REFRACT_INDEX, channel);
    for (int rayBounce = 1; rayBounce < RAY_BOUNCE_MAX; ++rayBounce) {
        
        // Interface with the material
        float3 refraction = refract (direction, normal.xyz, distanceFactor > 0.0 ? 1.0 / refractIndex : refractIndex);
        if (dot (refraction, refraction) < DELTA) {
            direction = reflect (direction, normal.xyz);
            origin += direction * DELTA * 2.0;
        } else {
            direction = refraction;
            distanceFactor = -distanceFactor;
        }
        
        // Ray marching
        float dist = RAY_LENGTH_MAX;
        for (int rayStep = 0; rayStep < RAY_STEP_MAX; ++rayStep) {
            dist = distanceFactor * getDistance (origin);
            float distMin = max (dist, DELTA);
            normal.w += distMin;
            if (dist < 0.0 || normal.w > RAY_LENGTH_MAX) {
                break;
            }
            origin += direction * distMin;
        }
        
        // Check whether we hit something
        if (dist >= 0.0) {
            break;
        }
        
        // Get the normal
        normal.xyz = distanceFactor * getNormal (origin);
        
        // Basic lighting
        if (distanceFactor > 0.0) {
            float relfectionDiffuse = max (0.0, dot (normal.xyz, lightDirection));
            float relfectionSpecular = pow (max (0.0, dot (reflect (direction, normal.xyz), lightDirection)), SPECULAR_POWER) * SPECULAR_INTENSITY;
            float localColor = (AMBIENT + relfectionDiffuse) * dot (COLOR, channel) + relfectionSpecular;
            color += localColor * (1.0 - ALPHA) * intensity;
            intensity *= ALPHA;
        }
    }
    
    // Get the background color
    float backColor = dot (direction, channel);
    
    // Return the intensity of this color channel
    return color + backColor * intensity;
}

vertex ColorInOut vertexShader(VertexInput          in       [[ stage_in ]],
                                  constant NodeBuffer& scn_node [[ buffer(0) ]])
{
    ColorInOut out;
    out.position = scn_node.modelViewProjectionTransform * float4(in.position, 1.0);
    out.texCoords = in.texCoords;
    
    return out;
}

fragment half4 fragmentShader(ColorInOut in          [[ stage_in] ],
                                 constant   float& time [[ buffer(0) ]])
{
    // Define the ray corresponding to this fragment
    float2 frag = 2.0 * in.position.xy;
    float3 direction = normalize (float3 (frag, 2.0));
    
    // Set the camera
    float3 origin = 7.0 * float3 ((cos (time * 0.1)), sin (time * 0.2), sin (time * 0.1));
    float3 forward = -origin;
    float3 up = float3 (sin (time * 0.3), 2.0, 0.0);
    float3x3 rotation;
    rotation [2] = normalize (forward);
    rotation [0] = normalize (cross (up, forward));
    rotation [1] = cross (rotation [2], rotation [0]);
    direction = rotation * direction;
    
    // Cast the initial ray
    float4 normal = float4 (0.0);
    float dist = 20.0;
    for (int rayStep = 0; rayStep < 40; ++rayStep) {
        dist = getDistance (origin);
        float distMin = max (dist, 0.001);
        normal.w += distMin;
        if (dist < 0.0 || normal.w > 20.0) {
            break;
        }
        origin += direction * distMin;
    }
    
    half4 fragColor;
    
    // Check whether we hit something
    if (dist >= 0.0) {
        fragColor.rgb = half3(direction);
    } else {
        
        // Get the normal
        normal.xyz = getNormal (origin);
        
        // Basic lighting
        float relfectionDiffuse = max (0.0, dot (normal.xyz, lightDirection));
        float relfectionSpecular = pow (max (0.0, dot (reflect (direction, normal.xyz), lightDirection)), SPECULAR_POWER) * SPECULAR_INTENSITY;
        fragColor.rgb = half3((AMBIENT + relfectionDiffuse) * COLOR + relfectionSpecular);
        
        // Cast a ray for each color channel
        fragColor.r = raycast (origin, direction, normal, fragColor.r, float3 (1.0, 0.0, 0.0));
        fragColor.g = raycast (origin, direction, normal, fragColor.g, float3 (0.0, 1.0, 0.0));
        fragColor.b = raycast (origin, direction, normal, fragColor.b, float3 (0.0, 0.0, 1.0));
    }
    
    // Set the alpha channel
    fragColor.a = 1.0;
    half3 c = half3(fragColor.r, fragColor.g, fragColor.b);
    return half4(c,1.0);
//    return half4(1.0,0.0,0.0,0.8);
    
}

