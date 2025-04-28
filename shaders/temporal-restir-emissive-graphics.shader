const UINT32_MAX: u32 = 0xffffffffu;
const FLT_MAX: f32 = 1.0e+10;
const PI: f32 = 3.14159f;
const RAY_LENGTH: f32 = 50.0f;

struct RandomResult 
{
    mfNum: f32,
    miSeed: u32,
};

struct TemporalRestirResult
{
    mRadiance: vec4<f32>,
    mReservoir: vec4<f32>,
    mRayDirection: vec4<f32>,
    mSampleRadiance: vec4<f32>,
    mAmbientOcclusion: vec4<f32>,
    mHitPosition: vec4<f32>,
    mHitNormal: vec4<f32>,
    mDirectSunLight: vec4<f32>,
    mRandomResult: RandomResult,
    mfNumValidSamples: f32,
    miHitTriangle: u32,
};

struct Material
{
    mDiffuse: vec4<f32>,
    mSpecular: vec4<f32>,
    mEmissive: vec4<f32>,

    miID: u32,
    miAlbedoTextureID: u32,
    miNormalTextureID: u32,
    miEmissiveTextureID: u32
};

struct ReservoirResult
{
    mReservoir: vec4<f32>,
    mbExchanged: bool
};

struct MeshTriangleRange
{
    miStart: u32,
    miEnd: u32,
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

struct Ray
{
    mOrigin: vec4<f32>,
    mDirection: vec4<f32>,
    mfT: vec4<f32>,
};

struct Tri
{
    miV0 : u32,
    miV1 : u32,
    miV2 : u32,
    mPadding : u32,

    mCentroid : vec4<f32>
};

struct VertexFormat
{
    mPosition : vec4<f32>,
    mTexCoord : vec4<f32>,
    mNormal : vec4<f32>, 
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

struct UniformData
{
    mfEmissiveValue: f32,
};

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

@group(0) @binding(0)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(1)
var normalTexture: texture_2d<f32>;

@group(0) @binding(2)
var texCoordTexture: texture_2d<f32>;

@group(0) @binding(3)
var hitPositionTexture: texture_2d<f32>;

@group(0) @binding(4)
var hitNormalTexture: texture_2d<f32>;

@group(0) @binding(5)
var rayDirectionTexture: texture_2d<f32>;

@group(0) @binding(6)
var prevTemporalReservoirTexture: texture_2d<f32>;

@group(0) @binding(7)
var prevTemporalRadianceTexture: texture_2d<f32>;

@group(0) @binding(8)
var prevHitPositionTexture: texture_2d<f32>;

@group(0) @binding(9)
var prevHitNormalTexture: texture_2d<f32>;

@group(0) @binding(10)
var prevWorldPositionTexture: texture_2d<f32>;

@group(0) @binding(11)
var prevNormalTexture: texture_2d<f32>;

@group(0) @binding(12)
var motionVectorTexture: texture_2d<f32>;

@group(0) @binding(13)
var prevMotionVectorTexture: texture_2d<f32>;

@group(1) @binding(0)
var<uniform> uniformBuffer: UniformData;

@group(1) @binding(1)
var hitTriangleTexture: texture_2d<f32>;

@group(1) @binding(2)
var<storage, read> aMeshTriangleIndexRanges: array<MeshTriangleRange>;

@group(1) @binding(3)
var<storage, read> aMeshMaterials: array<Material>;

@group(1) @binding(4)
var<storage, read> aSceneBVHNodes: array<BVHNode2>;

@group(1) @binding(5)
var<storage, read> aSceneVertexPositions: array<VertexFormat>;

@group(1) @binding(6)
var<storage, read> aiSceneTriangleIndices: array<u32>;

@group(1) @binding(7)
var blueNoiseTexture: texture_2d<f32>;

@group(1) @binding(8)
var sampleRadianceTexture: texture_storage_2d<rgba32float, write>;

@group(1) @binding(9)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(10)
var textureSampler: sampler;

struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f
};

struct FragmentOutput 
{
    @location(0) mRadiance: vec4<f32>,
    @location(1) mReservoir: vec4<f32>,
    @location(2) mHitPosition: vec4<f32>,
    @location(3) mHitNormal: vec4<f32>
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

    let worldPosition: vec4<f32> = textureSample(
        worldPositionTexture,
        textureSampler,
        in.uv.xy
    );

    let normal: vec4<f32> = textureSample(
        normalTexture,
        textureSampler,
        in.uv.xy
    );

    let hitPosition: vec4<f32> = textureSample(
        hitPositionTexture,
        textureSampler,
        in.uv.xy
    );

    let screenCoord: vec2<u32> = vec2<u32>(
        u32(in.uv.x * f32(defaultUniformBuffer.miScreenWidth)),
        u32(in.uv.y * f32(defaultUniformBuffer.miScreenHeight)) 
    );

    var randomResult: RandomResult = initRand(
        u32(in.uv.x * 100.0f + in.uv.y * 200.0f) + u32(defaultUniformBuffer.mfRand0 * 100.0f),
        u32(in.pos.x * 10.0f + in.pos.z * 20.0f) + u32(defaultUniformBuffer.mfRand0 * 100.0f),
        10u);

    var prevScreenUV: vec2<f32> = getPreviousScreenUV(in.uv.xy);
    let prevScreenCoord: vec2<u32> = vec2<u32>(
        u32(prevScreenUV.x * f32(defaultUniformBuffer.miScreenWidth)),
        u32(prevScreenUV.y * f32(defaultUniformBuffer.miScreenHeight))
    );

    var fDisocclusion: f32 = 0.0f;
    if(isPrevUVOutOfBounds(in.uv))
    {
        fDisocclusion = 1.0f;
    }
    else
    {
        fDisocclusion = f32(isDisoccluded2(in.uv, prevScreenUV));
    }
    let fValidHistory: f32 = 1.0f - fDisocclusion;

    var result: TemporalRestirResult;
    result.mReservoir = textureLoad(
        prevTemporalReservoirTexture,
        prevScreenCoord,
        0) * fValidHistory;
    result.mRadiance = textureLoad(
        prevTemporalRadianceTexture,
        prevScreenCoord,
        0) * fValidHistory;
    result.mHitPosition = textureLoad(
        prevHitPositionTexture,
        prevScreenCoord,
        0) * fValidHistory;
    result.mHitNormal = textureLoad(
        prevHitNormalTexture,
        prevScreenCoord,
        0) * fValidHistory;

    var bTraceRay: bool = false;
    var rayDirection: vec3<f32> = normalize(hitPosition.xyz - worldPosition.xyz);
    if(defaultUniformBuffer.miFrame > 0 && defaultUniformBuffer.miFrame % 6 == 0)
    {
        rayDirection = normalize(result.mHitPosition.xyz - worldPosition.xyz);
        bTraceRay = true;
    }

//bTraceRay = false;

    let fPerSampleSize: f32 = 0.1f;
    let fReservoirSize: f32 = 10.0f;
    result = temporalRestir(
        result,
        worldPosition.xyz,
        normal.xyz,
        in.uv.xy,
        rayDirection,
        fReservoirSize,
        1.0f,
        randomResult,
        0u,
        fPerSampleSize,
        bTraceRay
    );

    let iMesh: u32 = u32(floor(ceil(worldPosition.w - fract(worldPosition.w) - 0.5f)));

    result = permutationSampling(
        result,
        vec2i(i32(screenCoord.x), i32(screenCoord.y)),
        worldPosition.xyz,
        normal.xyz,
        i32(iMesh),
        fReservoirSize,
        randomResult,
        fPerSampleSize * 0.1f
    );

    result.mReservoir.w = clamp(result.mReservoir.x / max(result.mReservoir.z * result.mReservoir.y, 0.001f), 0.0f, 1.0f);
    output.mRadiance = result.mRadiance * result.mReservoir.w;
    output.mReservoir = result.mReservoir;
    output.mHitPosition = result.mHitPosition;
    output.mHitNormal = result.mHitNormal;
    output.mHitNormal.w = f32(result.miHitTriangle);

    // emissive surface itself
    let meshMaterial: Material = aMeshMaterials[iMesh];
    if(dot(meshMaterial.mEmissive.xyz, meshMaterial.mEmissive.xyz) > 0.0f)
    {
        output.mRadiance = vec4<f32>(meshMaterial.mEmissive.xyz * uniformBuffer.mfEmissiveValue, 1.0f);
        output.mReservoir = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);
    }

    textureStore(
        sampleRadianceTexture,
        screenCoord,
        result.mSampleRadiance
    );

    return output;
}

/*
**
*/
fn temporalRestir(
    prevResult: TemporalRestirResult,

    worldPosition: vec3<f32>,
    normal: vec3<f32>,
    inputTexCoord: vec2<f32>,
    rayDirection: vec3<f32>,

    fMaxTemporalReservoirSamples: f32,
    fJacobian: f32,
    randomResult: RandomResult,
    iSampleIndex: u32,
    fM: f32,
    bTraceRay: bool) -> TemporalRestirResult
{
    var ret: TemporalRestirResult = prevResult;

    let textureSize: vec2u = textureDimensions(worldPositionTexture);
    let inputImageCoord: vec2u = vec2u(
        u32(inputTexCoord.x * f32(textureSize.x)),
        u32(inputTexCoord.y * f32(textureSize.y))
    );

    let fOneOverPDF: f32 = 1.0f / PI;
    ret.mRandomResult = randomResult;
    
    ret.mRandomResult = nextRand(ret.mRandomResult.miSeed);
    let fRand0: f32 = ret.mRandomResult.mfNum;
    ret.mRandomResult = nextRand(ret.mRandomResult.miSeed);
    let fRand1: f32 = ret.mRandomResult.mfNum;
    ret.mRandomResult = nextRand(ret.mRandomResult.miSeed);
    let fRand2: f32 = ret.mRandomResult.mfNum;

    var intersectionInfo: IntersectBVHResult;
    if(bTraceRay)
    {
        var ray: Ray;
        ray.mOrigin = vec4<f32>(worldPosition + rayDirection * 0.01f, 1.0f);
        ray.mDirection = vec4<f32>(rayDirection, 1.0f);
        intersectionInfo.miHitTriangle = UINT32_MAX;
        intersectionInfo = intersectBVH4(ray, 0u);
        if(length(intersectionInfo.mHitPosition.xyz) >= RAY_LENGTH)
        {
            intersectionInfo.miHitTriangle = UINT32_MAX;
        }
    }
    
    // get the non-disoccluded and non-out-of-bounds pixel
    var iDisoccluded: i32 = 1;
    var prevInputTexCoord: vec2<f32> = getPreviousScreenUV(inputTexCoord);
    let prevImageCoord: vec2<u32> = vec2<u32>(
        u32(prevInputTexCoord.x * f32(textureSize.x)),
        u32(prevInputTexCoord.y * f32(textureSize.y))
    );
    if(!isPrevUVOutOfBounds(inputTexCoord) && !isDisoccluded2(inputTexCoord, prevInputTexCoord))
    {
        iDisoccluded = 0;
    }

    var candidateHitPosition: vec4<f32> = textureLoad(
        hitPositionTexture,
        inputImageCoord,
        0
    );
    var candidateHitNormal: vec4<f32> = textureLoad(
        hitNormalTexture,
        inputImageCoord,
        0
    );

    // hit triangle from intersection info or load from hit triangle info texture
    var iHitTriangle: u32 = u32(candidateHitPosition.w);
    if(bTraceRay)
    {
        candidateHitPosition = vec4<f32>(intersectionInfo.mHitPosition, f32(intersectionInfo.miHitTriangle));
        candidateHitNormal = vec4<f32>(intersectionInfo.mHitNormal, 1.0f);
        iHitTriangle = intersectionInfo.miHitTriangle;
    }
    else 
    {
        var hitInfo: vec4<f32> = textureLoad(
            hitTriangleTexture,
            inputImageCoord,
            0
        );
        iHitTriangle = u32(hitInfo.x);
    }
    
    var candidateRadiance: vec4<f32> = vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f);
    var candidateRayDirection: vec4<f32> = vec4<f32>(rayDirection, 1.0f);
    var fRadianceDP: f32 = max(dot(normal, rayDirection), 0.0f);
    var fDistanceAttenuation: f32 = 1.0f;
    if(iHitTriangle != UINT32_MAX)
    {
        let iHitMesh: u32 = getMeshForTriangleIndex(iHitTriangle);
        let material: Material = aMeshMaterials[iHitMesh];
        candidateRadiance = vec4<f32>(material.mEmissive.xyz * uniformBuffer.mfEmissiveValue, 1.0f);

        // distance for on-screen radiance and ambient occlusion
        var fDistance: f32 = length(candidateHitPosition.xyz - worldPosition.xyz);
        fDistanceAttenuation = max(1.0f / max(fDistance * fDistance, 1.0f), 1.0f);
    }    

    candidateRadiance.x = candidateRadiance.x * fJacobian * fRadianceDP * fDistanceAttenuation * fOneOverPDF;
    candidateRadiance.y = candidateRadiance.y * fJacobian * fRadianceDP * fDistanceAttenuation * fOneOverPDF;
    candidateRadiance.z = candidateRadiance.z * fJacobian * fRadianceDP * fDistanceAttenuation * fOneOverPDF;
    
    ret.mSampleRadiance = candidateRadiance;

    // reservoir
    let fLuminance: f32 = computeLuminance(candidateRadiance.xyz);

    var fPHat: f32 = clamp(fLuminance, 0.0f, 1.0f);
    var updateResult: ReservoirResult = updateReservoir(
        prevResult.mReservoir,
        fPHat,
        fM,
        fRand2);
    
    if(updateResult.mbExchanged)
    {
        ret.mRadiance = candidateRadiance;
        ret.mHitPosition = candidateHitPosition;
        ret.mHitNormal = candidateHitNormal;
        ret.mRayDirection = candidateRayDirection;
    }

    // clamp reservoir
    if(updateResult.mReservoir.z > fMaxTemporalReservoirSamples)
    {
        let fPct: f32 = fMaxTemporalReservoirSamples / updateResult.mReservoir.z;
        updateResult.mReservoir.x *= fPct;
        updateResult.mReservoir.z = fMaxTemporalReservoirSamples;
    }
    
    ret.mReservoir = updateResult.mReservoir;
    ret.mfNumValidSamples += fM * f32(fLuminance > 0.0f);
    
    ret.miHitTriangle = iHitTriangle;

    return ret;
}

/*
**
*/
fn updateReservoir(
    reservoir: vec4<f32>,
    fPHat: f32,
    fM: f32,
    fRand: f32) -> ReservoirResult
{
    var ret: ReservoirResult;
    ret.mReservoir = reservoir;
    ret.mbExchanged = false;

    ret.mReservoir.x += fPHat;

    //var fMult: f32 = clamp(fPHat, 0.3f, 1.0f); 
    ret.mReservoir.z += fM; // * fMult;
    
    var fWeightPct: f32 = fPHat / ret.mReservoir.x;

    if(fRand < fWeightPct || reservoir.z <= 0.0f || reservoir.x <= 0.0f)
    {
        ret.mReservoir.y = fPHat;
        ret.mbExchanged = true;
    }

    return ret;
}


/*
**
*/
fn initRand(
    val0: u32, 
    val1: u32, 
    backoff: u32) -> RandomResult
{
    var retResult: RandomResult;

    var v0: u32 = val0;
    var v1: u32 = val1;
    var s0: u32 = 0u;

    for(var n: u32 = 0; n < backoff; n++)
    {
        s0 += u32(0x9e3779b9);
        v0 += ((v1 << 4) + 0xa341316c) ^ (v1 + s0) ^ ((v1 >> 5) + 0xc8013ea4);
        v1 += ((v0 << 4) + 0xad90777d) ^ (v0 + s0) ^ ((v0 >> 5) + 0x7e95761e);
    }

    retResult.miSeed = v0;
    retResult.mfNum = 0.0f;

    return retResult;
}

/*
**
*/
fn nextRand(s: u32) -> RandomResult
{
    var retResult: RandomResult;

    var sCopy: u32 = s;
    sCopy = (1664525u * sCopy + 1013904223u);
    retResult.mfNum = f32(sCopy & 0x00FFFFFF) / f32(0x01000000);
    retResult.miSeed = sCopy;

    return retResult;
}

/////
fn getPreviousScreenUV(
    screenUV: vec2<f32>) -> vec2<f32>
{
    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);
    let screenImageCoord: vec2<u32> = vec2<u32>(
        u32(screenUV.x * f32(textureSize.x)),
        u32(screenUV.y * f32(textureSize.y))
    );

    var screenUVCopy: vec2<f32> = screenUV;
    var motionVector: vec2<f32> = textureLoad(
        motionVectorTexture,
        screenImageCoord,
        0).xy;
    var prevScreenUV: vec2<f32> = screenUVCopy - motionVector;

    var worldPosition: vec3<f32> = textureLoad(
        worldPositionTexture,
        screenImageCoord,
        0
    ).xyz;
    var normal: vec3<f32> = textureLoad(
        normalTexture,
        screenImageCoord,
        0
    ).xyz;

    var fOneOverScreenWidth: f32 = 1.0f / f32(defaultUniformBuffer.miScreenWidth);
    var fOneOverScreenHeight: f32 = 1.0f / f32(defaultUniformBuffer.miScreenHeight);

    var fShortestWorldDistance: f32 = FLT_MAX;
    var closestScreenUV: vec2<f32> = prevScreenUV;

    return closestScreenUV;
}

/*
**
*/
fn isDisoccluded2(
    screenUV: vec2<f32>,
    prevScreenUV: vec2<f32>
) -> bool
{
    let textureSize: vec2u = textureDimensions(worldPositionTexture);
    let screenImageCoord: vec2u = vec2u(
        u32(screenUV.x * f32(textureSize.x)),
        u32(screenUV.y * f32(textureSize.y))
    );
    let prevScreenImageCoord: vec2u = vec2u(
        u32(prevScreenUV.x * f32(textureSize.x)),
        u32(prevScreenUV.y * f32(textureSize.y))
    );

    var worldPosition: vec3<f32> = textureLoad(
        worldPositionTexture,
        screenImageCoord,
        0).xyz;

    var prevWorldPosition: vec3<f32> = textureLoad(
        prevWorldPositionTexture,
        prevScreenImageCoord,
        0).xyz;

    var normal: vec3<f32> = textureLoad(
        normalTexture,
        screenImageCoord,
        0).xyz;

    var prevNormal: vec3<f32> = textureLoad(
        prevNormalTexture,
        prevScreenImageCoord,
        0).xyz;

    var motionVector: vec4<f32> = textureLoad(
        motionVectorTexture,
        screenImageCoord,
        0);

    var prevMotionVectorAndMeshIDAndDepth: vec4<f32> = textureLoad(
        prevMotionVectorTexture,
        prevScreenImageCoord,
        0);

    let iMesh = u32(ceil(motionVector.z - 0.5f)) - 1;
    var fDepth: f32 = motionVector.w;
    var fPrevDepth: f32 = prevMotionVectorAndMeshIDAndDepth.w;
    var fCheckDepth: f32 = abs(fDepth - fPrevDepth);
    var worldPositionDiff: vec3<f32> = prevWorldPosition.xyz - worldPosition.xyz;
    var fCheckDP: f32 = abs(dot(normalize(normal.xyz), normalize(prevNormal.xyz)));
    let iPrevMesh: u32 = u32(ceil(prevMotionVectorAndMeshIDAndDepth.z - 0.5f)) - 1;
    var fCheckWorldPositionDistance: f32 = dot(worldPositionDiff, worldPositionDiff);

    return !(iMesh == iPrevMesh && fCheckDepth <= 0.001f && fCheckWorldPositionDistance <= 0.001f && fCheckDP >= 0.99f);
}

/*
**
*/
fn isPrevUVOutOfBounds(inputTexCoord: vec2<f32>) -> bool
{
    let textureSize: vec2u = textureDimensions(motionVectorTexture);
    let screenImageCoord: vec2u = vec2u(
        u32(inputTexCoord.x * f32(textureSize.x)),
        u32(inputTexCoord.y * f32(textureSize.y))
    );
    var motionVector: vec4<f32> = textureLoad(
        motionVectorTexture,
        screenImageCoord,
        0);
    let backProjectedScreenUV: vec2<f32> = inputTexCoord - motionVector.xy;

    return (backProjectedScreenUV.x < 0.0f || backProjectedScreenUV.x > 1.0 || backProjectedScreenUV.y < 0.0f || backProjectedScreenUV.y > 1.0f);
}

/*
**
*/
fn computeLuminance(
    radiance: vec3<f32>) -> f32
{
    return dot(radiance, vec3<f32>(0.2126f, 0.7152f, 0.0722f));
}

/*
**
*/
fn getMeshForTriangleIndex(iTriangleIndex: u32) -> u32
{
    var iRet: u32 = 0u;
    for(var i: u32 = 0u; i < defaultUniformBuffer.miNumMeshes; i++)
    {
        if(iTriangleIndex >= aMeshTriangleIndexRanges[i].miStart / 3 && 
           iTriangleIndex <= aMeshTriangleIndexRanges[i].miEnd / 3)
        {
            iRet = i;
            break;
        }
    }

    return iRet;
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

/*
**
*/
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

/*
**
*/
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

/*
**
*/
fn uniformSampling(
    worldPosition: vec3<f32>,
    normal: vec3<f32>,
    fRand0: f32,
    fRand1: f32) -> Ray
{
    let fPhi: f32 = 2.0f * PI * fRand0;
    let fCosTheta: f32 = 1.0f - fRand1;
    let fSinTheta: f32 = sqrt(1.0f - fCosTheta * fCosTheta);
    let h: vec3<f32> = vec3<f32>(
        cos(fPhi) * fSinTheta,
        sin(fPhi) * fSinTheta,
        fCosTheta);

    var up: vec3<f32> = vec3<f32>(0.0f, 1.0f, 0.0f);
    if(abs(normal.y) > 0.999f)
    {
        up = vec3<f32>(1.0f, 0.0f, 0.0f);
    }
    let tangent: vec3<f32> = normalize(cross(up, normal));
    let binormal: vec3<f32> = normalize(cross(normal, tangent));
    let rayDirection: vec3<f32> = normalize(tangent * h.x + binormal * h.y + normal * h.z);

    var ray: Ray;
    ray.mOrigin = vec4<f32>(worldPosition, 1.0f);
    ray.mDirection = vec4<f32>(rayDirection, 1.0f);
    ray.mfT = vec4<f32>(FLT_MAX, FLT_MAX, FLT_MAX, FLT_MAX);

    return ray;
}

/*
**
*/
fn permutationSampling(
    result: TemporalRestirResult,
    origScreenCoord: vec2<i32>,
    worldPosition: vec3<f32>,
    normal: vec3<f32>,
    iCenterMeshID: i32,
    fReservoirSize : f32,
    randomResult: RandomResult,
    fM: f32
) -> TemporalRestirResult
{
    var ret: TemporalRestirResult = result;
    
    let fPlaneD: f32 = -dot(worldPosition, normal);

    // permutation samples
    //let iNumPermutations: i32 = uniformData.miNumTemporalRestirSamplePermutations + 1;
    for(var iSample: i32 = 1; iSample < 5; iSample++)
    {
        var aXOR: array<vec2<i32>, 4>;
        aXOR[0] = vec2<i32>(3, 3);
        aXOR[1] = vec2<i32>(2, 1);
        aXOR[2] = vec2<i32>(1, 2);
        aXOR[3] = vec2<i32>(3, 3);
        
        var aOffsets: array<vec2<i32>, 4>;
        aOffsets[0] = vec2<i32>(-1, -1);
        aOffsets[1] = vec2<i32>(1, 1);
        aOffsets[2] = vec2<i32>(-1, 1);
        aOffsets[3] = vec2<i32>(1, -1);

        // apply permutation offset to screen coordinate, converting to uv after
        let iFrame: i32 = i32(defaultUniformBuffer.miFrame);
        let iIndex0: i32 = iFrame & 3;
        let iIndex1: i32 = (iSample + (iFrame ^ 1)) & 3;
        let offset: vec2<i32> = aOffsets[iIndex0] + aOffsets[iIndex1];
        let screenCoord: vec2<i32> = (origScreenCoord + offset) ^ aXOR[iFrame & 3]; 
        
        var sampleRayDirection: vec3<f32> = vec3<f32>(0.0f, 0.0f, 0.0f);
        var ray: Ray;

        // permutation uv
        var sampleUV: vec2<f32> = vec2<f32>(
            ceil(f32(screenCoord.x) + 0.5f) / f32(defaultUniformBuffer.miScreenWidth),
            ceil(f32(screenCoord.y) + 0.5f) / f32(defaultUniformBuffer.miScreenHeight));

        // get sample world position, normal, and ray direction
        var fJacobian: f32 = 1.0f;
        {
            // back project to previous frame's screen coordinate
            var motionVector: vec2<f32> = textureLoad(
                motionVectorTexture,
                screenCoord,
                0).xy;
            sampleUV -= motionVector;

            // sample world position
            let sampleWorldPosition: vec4<f32> = textureLoad(
                prevWorldPositionTexture,
                screenCoord,
                0);

            let sampleNormal: vec3<f32> = textureLoad(
                prevNormalTexture,
                screenCoord,
                0).xyz;

            // neighbor normal difference check 
            let fDP: f32 = dot(sampleNormal, normal);
            //if(fDP <=  0.6f)
            //{
            //    continue;
            //}

            // neightbor depth difference check
            let fSampleDepth: f32 = fract(sampleWorldPosition.w);
            //let fDepthDiff: f32 = abs(fCenterDepth - fSampleDepth);
            //if(fDepthDiff >= 0.05f)
            //{
            //    continue;
            //} 

            let fPlaneDistance: f32 = dot(normal.xyz, sampleWorldPosition.xyz) + fPlaneD;
            //if(abs(fPlaneDistance) >= 0.2f)
            //{
            //    continue;
            //}

            // mesh id difference check
            let iSampleMeshID: i32 = i32(floor((sampleWorldPosition.w - fSampleDepth) + 0.5f));
            //if(iSampleMeshID != iCenterMeshID)
            //{
            //    continue;
            //}

            // hit point and hit normal for jacobian
            let sampleHitPoint: vec3<f32> = textureLoad(
                prevHitPositionTexture,
                screenCoord,
                0).xyz;

            //if(checkClipSpaceBlock(
            //    worldPosition.xyz, 
            //    normalize(worldPosition.xyz - sampleHitPoint)))
            //{
            //    continue;
            //}

            var neighborHitNormal: vec3<f32> = textureLoad(
                prevHitNormalTexture,
                screenCoord,
                0).xyz;
            let centerToNeighborHitPointUnNormalized: vec3<f32> = sampleHitPoint - worldPosition.xyz;
            let neighborToNeighborHitPointUnNormalized: vec3<f32> = sampleHitPoint - sampleWorldPosition.xyz;
            let centerToNeighborHitPointNormalized: vec3<f32> = normalize(centerToNeighborHitPointUnNormalized);
            let neighborToNeighborHitPointNormalized: vec3<f32> = normalize(neighborToNeighborHitPointUnNormalized);
            
            // compare normals for jacobian
            let fDP0: f32 = max(dot(neighborHitNormal, centerToNeighborHitPointNormalized * -1.0f), 0.0f);
            var fDP1: f32 = max(dot(neighborHitNormal, neighborToNeighborHitPointNormalized * -1.0f), 1.0e-4f);
            fJacobian = fDP0 / fDP1;

            // compare length for jacobian 
            let fCenterToHitPointLength: f32 = length(centerToNeighborHitPointUnNormalized);
            let fNeighborToHitPointLength: f32 = length(neighborToNeighborHitPointUnNormalized);
            fJacobian *= ((fCenterToHitPointLength * fCenterToHitPointLength) / (fNeighborToHitPointLength * fNeighborToHitPointLength));
            fJacobian = clamp(fJacobian, 0.0f, 1.0f);

            sampleRayDirection = centerToNeighborHitPointNormalized;
        }

        ret.miHitTriangle = UINT32_MAX;
        ret = temporalRestir(
            ret,

            worldPosition.xyz,
            normal,
            sampleUV,
            sampleRayDirection,

            fReservoirSize,
            fJacobian,
            randomResult,
            u32(iSample),
            fM, 
            false);

    }   // for sample = 0 to num permutation samples  

    //ret.mReservoir.z = result.mReservoir.z;

    // check if ray intersects different triangle
    var ray: Ray;
    ray.mDirection = vec4<f32>(ret.mRayDirection.xyz, 1.0f);
    ray.mOrigin = vec4<f32>(worldPosition.xyz + result.mRayDirection.xyz * 0.01f, 1.0f);
    var intersectionInfo: IntersectBVHResult;
    intersectionInfo = intersectBVH4(ray, 0u);
    //if((length(result.mHitPosition.xyz) >= RAY_LENGTH && abs(intersectionInfo.mHitPosition.x) < RAY_LENGTH) || 
    //(length(result.mHitPosition.xyz) < RAY_LENGTH && abs(intersectionInfo.mHitPosition.x) >= RAY_LENGTH))
    let iHitMesh: u32 = getMeshForTriangleIndex(intersectionInfo.miHitTriangle);
    let material: Material = aMeshMaterials[iHitMesh];
    if(dot(material.mEmissive.xyz, material.mEmissive.xyz) <= 0.0f)
    {
        ret = result;
    }

    return ret;
}

/*
**
*/
fn checkClipSpaceBlock(
    centerWorldPosition: vec3<f32>,
    centerToNeighborHitPointNormalized: vec3<f32>
) -> bool
{
    var bBlocked: bool = false;
    let iNumBlockSteps: i32 = 6;
    var currCheckPosition: vec3<f32> = centerWorldPosition;
    var startScreenPosition: vec2<i32> = vec2<i32>(-1, -1);
    var currScreenPosition: vec2<i32> = vec2<i32>(-1, -1);
    for(var iStep: i32 = 0; iStep < iNumBlockSteps; iStep++)
    {
        // convert to clipspace for fetching world position from texture
        var clipSpacePosition: vec4<f32> = vec4<f32>(currCheckPosition, 1.0f) * defaultUniformBuffer.mViewProjectionMatrix;
        clipSpacePosition.x /= clipSpacePosition.w;
        clipSpacePosition.y /= clipSpacePosition.w;
        clipSpacePosition.z /= clipSpacePosition.w;
        currCheckPosition += centerToNeighborHitPointNormalized * 0.05f;

        let currScreenUV = vec2<f32>(
            clipSpacePosition.x * 0.5f + 0.5f,
            1.0f - (clipSpacePosition.y * 0.5f + 0.5f)
        );

        currScreenPosition.x = i32(currScreenUV.x * f32(defaultUniformBuffer.miScreenWidth));
        currScreenPosition.y = i32(currScreenUV.y * f32(defaultUniformBuffer.miScreenHeight));

        // only check the surrounding pixel 
        if(abs(currScreenPosition.x - startScreenPosition.x) > 6 || abs(currScreenPosition.y - startScreenPosition.y) > 6)
        {
            continue;
        }

        // out of bounds
        if(currScreenPosition.x < 0 || currScreenPosition.x >= i32(defaultUniformBuffer.miScreenWidth) || 
            currScreenPosition.y < 0 || currScreenPosition.y >= i32(defaultUniformBuffer.miScreenHeight))
        {
            continue;
        }

        if(iStep == 0)
        {
            // save the starting screen position
            startScreenPosition = currScreenPosition;
            continue;
        }
        else if(startScreenPosition.x >= 0)
        {   
            // still at the same pixel position
            if(currScreenPosition.x == startScreenPosition.x && currScreenPosition.y == startScreenPosition.y)
            {
                iStep -= 1;
                continue;
            }
        }

        // compare depth value, smaller is in front, therefore blocked
        let currWorldPosition: vec4<f32> = textureLoad(
            worldPositionTexture,
            currScreenPosition,
            0);
        if(currWorldPosition.w == 0.0f)
        {
            continue;
        }
        let fCurrDepth: f32 = fract(currWorldPosition.w);
        if(fCurrDepth < clipSpacePosition.z)
        {
            bBlocked = true;

            break;
        }
    }

    return bBlocked;
}