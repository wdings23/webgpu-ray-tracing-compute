const FLT_MAX: f32 = 1.0e+10;
const RAY_LENGTH: f32 = 10.0f;
const UINT32_MAX: u32 = 0xffffffffu;


struct DefaultUniformData
{
    miScreenWidth: i32,
    miScreenHeight: i32,
    miFrame: i32,
    miNumMeshes: u32,

    mfRand0: f32,
    mfRand1: f32,
    mfRand2: f32,
    mfRand3: f32,

    mViewProjectionMatrix: mat4x4<f32>,
    mPrevViewProjectionMatrix: mat4x4<f32>,
    mViewMatrix: mat4x4<f32>,
    mProjectionMatrix: mat4x4<f32>,

    mJitteredViewProjectionMatrix: mat4x4<f32>,
    mPrevJitteredViewProjectionMatrix: mat4x4<f32>,

    mCameraPosition: vec4<f32>,
    mCameraLookDir: vec4<f32>,

    mLightRadiance: vec4<f32>,
    mLightDirection: vec4<f32>,
};

struct Ray
{
    mOrigin: vec4<f32>,
    mDirection: vec4<f32>,
    mfT: vec4<f32>,
};

struct BVHNode2
{
    mMinBound: vec4<f32>,
    mMaxBound: vec4<f32>,
    mCentroid: vec4<f32>,
    
    miChildren0: u32,
    miChildren1: u32,
    miPrimitiveID: u32,
    miMeshID: u32,
};

struct VertexFormat
{
    mPosition : vec4<f32>,
    mTexCoord : vec4<f32>,
    mNormal : vec4<f32> 
};

struct IntersectBVHResult
{
    mHitPosition: vec3<f32>,
    mHitNormal: vec3<f32>,
    miHitTriangle: u32,
    mBarycentricCoordinate: vec3<f32>,
};

struct RayTriangleIntersectionResult
{
    mIntersectPosition: vec3<f32>,
    mIntersectNormal: vec3<f32>,
    mBarycentricCoordinate: vec3<f32>,
};

@group(0) @binding(0)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(1)
var normalTexture: texture_2d<f32>;

@group(0) @binding(2)
var sunLightTexture: texture_2d<f32>;

@group(1) @binding(0)
var<storage, read> aSceneBVHNodes: array<BVHNode2>;

@group(1) @binding(1)
var<storage, read> aSceneVertexPositions: array<VertexFormat>;

@group(1) @binding(2)
var<storage, read> aiSceneTriangleIndices: array<u32>;

@group(1) @binding(3)
var blueNoiseTexture: texture_2d<f32>;

@group(1) @binding(4)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(5)
var textureSampler: sampler;

struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f
};

struct FragmentOutput 
{
    @location(0) directRadiance: vec4<f32>,
};

@vertex
fn vs_main(@builtin(vertex_index) i : u32) -> VertexOutput 
{
    const pos = array(vec2f(-1, 3), vec2f(-1, -1), vec2f(3, -1));
    const uv = array(vec2f(0, -1), vec2f(0, 1), vec2f(2, 1));
    var output: VertexOutput;
    output.pos = vec4f(pos[i], 0.0f, 1.0f);
    output.uv = uv[i];        

    return output;
}

@fragment
fn fs_main(in: VertexOutput) -> FragmentOutput 
{
    var output: FragmentOutput;

    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);
    let worldPosition: vec4f = textureSample(
        worldPositionTexture,
        textureSampler,
        in.uv
    );

    let normal: vec4f = textureSample(
        normalTexture,
        textureSampler,
        in.uv
    );

    var ret: vec3<f32> = textureSample(
        sunLightTexture,
        textureSampler,
        vec2<f32>(0.0f, 0.0f)
    ).xyz;

    let blueNoiseTextureSize: vec2<u32> = textureDimensions(blueNoiseTexture);
    var screenCoord: vec2<u32> = vec2<u32>(
        u32(in.uv.x * f32(defaultUniformBuffer.miScreenWidth)),
        u32(in.uv.y * f32(defaultUniformBuffer.miScreenHeight))
    );
    screenCoord.x = (screenCoord.x + u32(defaultUniformBuffer.miFrame)) % u32(blueNoiseTextureSize.x);
    screenCoord.y = (screenCoord.y + u32(defaultUniformBuffer.miFrame / defaultUniformBuffer.miScreenWidth)) % u32(blueNoiseTextureSize.y);
    
    var blueNoise: vec4<f32> = textureLoad(
        blueNoiseTexture,
        screenCoord,
        0
    );

    // ray direction in disc of given radius size
    let fLightRadius: f32 = 4.0f;
    var up: vec3<f32> = vec3<f32>(0.0f, 1.0f, 0.0f);
    if(abs(defaultUniformBuffer.mLightDirection.y) >= 0.99f)
    {
        up = vec3<f32>(1.0f, 0.0f, 0.0f);
    }
    let tangent: vec3f = cross(up, defaultUniformBuffer.mLightDirection.xyz);
    let binormal: vec3f = cross(defaultUniformBuffer.mLightDirection.xyz, tangent);
    let fAngle: f32 = 2.0f * 3.14159f * blueNoise.x;
    let rotation: vec3<f32> = (tangent.xyz * cos(fAngle) + binormal.xyz * sin(fAngle)) * fLightRadius;
    let rayEnd: vec3<f32> = worldPosition.xyz + defaultUniformBuffer.mLightDirection.xyz * 100.0f + rotation;  
    let rayDirection: vec3<f32> = normalize(rayEnd - worldPosition.xyz);

    var ray: Ray;
    ray.mOrigin = vec4<f32>(worldPosition.xyz + rayDirection * 0.01f, 1.0f);
    ray.mDirection = vec4<f32>(rayDirection, 1.0f);

    var intersectionInfo: IntersectBVHResult = intersectBVH4(ray, 0u);
    if(intersectionInfo.miHitTriangle != UINT32_MAX)
    {
        ret = vec3<f32>(0.0f, 0.0f, 0.0f);
    }

    output.directRadiance = vec4<f32>(ret, 1.0f);

    return output;
}

struct Triangle
{
    miV0 : u32,
    miV1 : u32,
    miV2 : u32,
    mPadding : u32,

    mCentroid : vec4<f32>
};

struct LeafNode
{
    miTriangleIndex: u32,
};

struct IntermediateNode
{
    mCentroid: vec4<f32>,
    mMinBounds: vec4<f32>,
    mMaxBounds: vec4<f32>,

    miLeftNodeIndex: u32,
    miRightNodeIndex: u32,
    miLeafNode: u32,
    miMortonCode: u32,
};

struct BVHProcessInfo
{
    miStep: u32,
    miStartNodeIndex: u32,
    miEndNodeIndex: u32,
    miNumMeshes: u32, 
};

/////
fn intersectTri4(
    ray: Ray,
    iTriangleIndex: u32) -> RayTriangleIntersectionResult
{
    let iIndex0: u32 = aiSceneTriangleIndices[iTriangleIndex * 3];
    let iIndex1: u32 = aiSceneTriangleIndices[iTriangleIndex * 3 + 1];
    let iIndex2: u32 = aiSceneTriangleIndices[iTriangleIndex * 3 + 2];

    var pos0: vec4<f32> = aSceneVertexPositions[iIndex0].mPosition;
    var pos1: vec4<f32> = aSceneVertexPositions[iIndex1].mPosition;
    var pos2: vec4<f32> = aSceneVertexPositions[iIndex2].mPosition;

    var iIntersected: u32 = 0;
    var fT: f32 = FLT_MAX;
    let intersectionInfo: RayTriangleIntersectionResult = rayTriangleIntersection(
        ray.mOrigin.xyz,
        ray.mOrigin.xyz + ray.mDirection.xyz * RAY_LENGTH,
        pos0.xyz,
        pos1.xyz,
        pos2.xyz);
    
    return intersectionInfo;
}

/////
fn intersectBVH4(
    ray: Ray,
    iRootNodeIndex: u32) -> IntersectBVHResult
{
    var ret: IntersectBVHResult;

    var iStackTop: i32 = 0;
    var aiStack: array<u32, 32>;
    aiStack[iStackTop] = iRootNodeIndex;

    ret.mHitPosition = vec3<f32>(FLT_MAX, FLT_MAX, FLT_MAX);
    ret.miHitTriangle = UINT32_MAX;
    var fClosestDistance: f32 = FLT_MAX;

    for(var iStep: u32 = 0u; iStep < 1000u; iStep++)
    {
        if(iStackTop < 0)
        {
            break;
        }

        let iNodeIndex: u32 = aiStack[iStackTop];
        iStackTop -= 1;

        //let node: BVHNode2 = aSceneBVHNodes[iNodeIndex];
        if(aSceneBVHNodes[iNodeIndex].miPrimitiveID != UINT32_MAX)
        {
            let intersectionInfo: RayTriangleIntersectionResult = intersectTri4(
                ray,
                aSceneBVHNodes[iNodeIndex].miPrimitiveID);

            if(abs(intersectionInfo.mIntersectPosition.x) < RAY_LENGTH)
            {
                let fDistanceToEye: f32 = length(intersectionInfo.mIntersectPosition.xyz - ray.mOrigin.xyz);
                //if(fDistanceToEye < fClosestDistance)
                {
                    
                    //fClosestDistance = fDistanceToEye;
                    ret.mHitPosition = intersectionInfo.mIntersectPosition.xyz;
                    ret.mHitNormal = intersectionInfo.mIntersectNormal.xyz;
                    ret.miHitTriangle = aSceneBVHNodes[iNodeIndex].miPrimitiveID;
                    ret.mBarycentricCoordinate = intersectionInfo.mBarycentricCoordinate;

                    break;
                }
            }
        }
        else
        {
            let bIntersect: bool = rayBoxIntersect(
                ray.mOrigin.xyz,
                ray.mDirection.xyz,
                aSceneBVHNodes[iNodeIndex].mMinBound.xyz,
                aSceneBVHNodes[iNodeIndex].mMaxBound.xyz);

            // node left and right child to stack
            if(bIntersect)
            {
                iStackTop += 1;
                aiStack[iStackTop] = aSceneBVHNodes[iNodeIndex].miChildren0;
                iStackTop += 1;
                aiStack[iStackTop] = aSceneBVHNodes[iNodeIndex].miChildren1;
            }
        }
    }

    return ret;
}

/*
**
*/
fn barycentric(
    p: vec3<f32>, 
    a: vec3<f32>, 
    b: vec3<f32>, 
    c: vec3<f32>) -> vec3<f32>
{
    let v0: vec3<f32> = b - a;
    let v1: vec3<f32> = c - a;
    let v2: vec3<f32> = p - a;
    let fD00: f32 = dot(v0, v0);
    let fD01: f32 = dot(v0, v1);
    let fD11: f32 = dot(v1, v1);
    let fD20: f32 = dot(v2, v0);
    let fD21: f32 = dot(v2, v1);
    let fOneOverDenom: f32 = 1.0f / (fD00 * fD11 - fD01 * fD01);
    let fV: f32 = (fD11 * fD20 - fD01 * fD21) * fOneOverDenom;
    let fW: f32 = (fD00 * fD21 - fD01 * fD20) * fOneOverDenom;
    let fU: f32 = 1.0f - fV - fW;

    return vec3<f32>(fU, fV, fW);
}

/*
**
*/
fn rayPlaneIntersection(
    pt0: vec3<f32>,
    pt1: vec3<f32>,
    planeNormal: vec3<f32>,
    fPlaneDistance: f32) -> f32
{
    var fRet: f32 = FLT_MAX;
    let v: vec3<f32> = pt1 - pt0;

    let fDenom: f32 = dot(v, planeNormal);
    fRet = -(dot(pt0, planeNormal) + fPlaneDistance) / (fDenom + 1.0e-5f);

    return fRet;
}

/*
**
*/
fn rayBoxIntersect(
    rayPosition: vec3<f32>,
    rayDir: vec3<f32>,
    bboxMin: vec3<f32>,
    bboxMax: vec3<f32>) -> bool
{
    //let oneOverRay: vec3<f32> = 1.0f / rayDir.xyz;
    let tMin: vec3<f32> = (bboxMin - rayPosition) / rayDir.xyz;
    let tMax: vec3<f32> = (bboxMax - rayPosition) / rayDir.xyz;

    var fTMin: f32 = min(tMin.x, tMax.x);
    var fTMax: f32 = max(tMin.x, tMax.x);

    fTMin = max(fTMin, min(tMin.y, tMax.y));
    fTMax = min(fTMax, max(tMin.y, tMax.y));

    fTMin = max(fTMin, min(tMin.z, tMax.z));
    fTMax = min(fTMax, max(tMin.z, tMax.z));

    return fTMax >= fTMin;
}

/*
**
*/
fn rayTriangleIntersection(
    rayPt0: vec3<f32>, 
    rayPt1: vec3<f32>, 
    triPt0: vec3<f32>, 
    triPt1: vec3<f32>, 
    triPt2: vec3<f32>) -> RayTriangleIntersectionResult
{
    var ret: RayTriangleIntersectionResult;

    let v0: vec3<f32> = normalize(triPt1 - triPt0);
    let v1: vec3<f32> = normalize(triPt2 - triPt0);
    let cp: vec3<f32> = cross(v0, v1);

    let triNormal: vec3<f32> = normalize(cp);
    let fPlaneDistance: f32 = -dot(triPt0, triNormal);

    let fT: f32 = rayPlaneIntersection(
        rayPt0, 
        rayPt1, 
        triNormal, 
        fPlaneDistance);
    if(fT <= 0.0f)
    {
        ret.mIntersectPosition = vec3<f32>(FLT_MAX, FLT_MAX, FLT_MAX);
        return ret;
    }

    let collisionPt: vec3<f32> = rayPt0 + (rayPt1 - rayPt0) * fT;
    
    let edge0: vec3<f32> = normalize(triPt1 - triPt0);
    let edge1: vec3<f32> = normalize(triPt2 - triPt0);
    let edge2: vec3<f32> = normalize(triPt0 - triPt2);

    // edge 0
    var C: vec3<f32> = cross(edge0, normalize(collisionPt - triPt0));
    if(dot(triNormal, C) < 0.0f)
    {
        ret.mIntersectPosition = vec3<f32>(FLT_MAX, FLT_MAX, FLT_MAX);
        return ret;
    }

    // edge 1
    C = cross(edge1, normalize(collisionPt - triPt1));
    if(dot(triNormal, C) < 0.0f)
    {
        ret.mIntersectPosition = vec3<f32>(FLT_MAX, FLT_MAX, FLT_MAX);
        return ret;
    }

    // edge 2
    C = cross(edge2, normalize(collisionPt - triPt2));
    if(dot(triNormal, C) < 0.0f)
    {
        ret.mIntersectPosition = vec3<f32>(FLT_MAX, FLT_MAX, FLT_MAX);
        return ret;
    }
    
    ret.mBarycentricCoordinate = barycentric(collisionPt, triPt0, triPt1, triPt2);
    ret.mIntersectPosition = (triPt0 * ret.mBarycentricCoordinate.x + triPt1 * ret.mBarycentricCoordinate.y + triPt2 * ret.mBarycentricCoordinate.z);
    ret.mIntersectNormal = triNormal.xyz;

    return ret;
}