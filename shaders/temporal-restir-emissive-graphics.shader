const UINT32_MAX: u32 = 0xffffffffu;
const FLT_MAX: f32 = 1.0e+10;
const PI: f32 = 3.14159f;
const RAY_LENGTH: f32 = 10.0f;

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
var prevTemporalReservoirTexture: texture_2d<f32>;

@group(0) @binding(6)
var prevTemporalRadianceTexture: texture_2d<f32>;

@group(0) @binding(7)
var prevHitPositionTexture: texture_2d<f32>;

@group(0) @binding(8)
var prevHitNormalTexture: texture_2d<f32>;

@group(0) @binding(9)
var prevWorldPositionTexture: texture_2d<f32>;

@group(0) @binding(10)
var prevNormalTexture: texture_2d<f32>;

@group(0) @binding(11)
var motionVectorTexture: texture_2d<f32>;

@group(0) @binding(12)
var prevMotionVectorTexture: texture_2d<f32>;

@group(1) @binding(0)
var hitTriangleTexture: texture_2d<f32>;

@group(1) @binding(1)
var<storage, read> aMeshTriangleIndexRanges: array<MeshTriangleRange>;

@group(1) @binding(2)
var<storage, read> aMeshMaterials: array<Material>;

@group(1) @binding(3)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(4)
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

    let rayDirection: vec3<f32> = normalize(hitPosition.xyz - worldPosition.xyz);
    
    temporalRestir(
        result,
        worldPosition.xyz,
        normal.xyz,
        in.uv.xy,
        rayDirection,
        8.0f,
        1.0f,
        randomResult,
        0u,
        1.0f
    );

    result.mReservoir.w = clamp(result.mReservoir.x / max(result.mReservoir.z * result.mReservoir.y, 0.001f), 0.0f, 1.0f);
    output.mRadiance = result.mRadiance * result.mReservoir.w;
    output.mReservoir = result.mReservoir;
    output.mHitPosition = result.mHitPosition;
    output.mHitNormal = result.mHitNormal;

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
    fM: f32) -> TemporalRestirResult
{
    let textureSize: vec2u = textureDimensions(worldPositionTexture);
    let inputImageCoord: vec2u = vec2u(
        u32(inputTexCoord.x * f32(textureSize.x)),
        u32(inputTexCoord.y * f32(textureSize.y))
    );

    let fOneOverPDF: f32 = 1.0f / PI;

    var ret: TemporalRestirResult = prevResult;
    ret.mRandomResult = randomResult;
    
    ret.mRandomResult = nextRand(ret.mRandomResult.miSeed);
    let fRand0: f32 = ret.mRandomResult.mfNum;
    ret.mRandomResult = nextRand(ret.mRandomResult.miSeed);
    let fRand1: f32 = ret.mRandomResult.mfNum;
    ret.mRandomResult = nextRand(ret.mRandomResult.miSeed);
    let fRand2: f32 = ret.mRandomResult.mfNum;

    // reset the ambient occlusion counts on disoccluded pixels
    var iDisoccluded: i32 = 1;

    // get the non-disoccluded and non-out-of-bounds pixel
    var prevInputTexCoord: vec2<f32> = getPreviousScreenUV(inputTexCoord);
    let prevImageCoord: vec2<u32> = vec2<u32>(
        u32(prevInputTexCoord.x * f32(textureSize.x)),
        u32(prevInputTexCoord.y * f32(textureSize.y))
    );
    if(!isPrevUVOutOfBounds(inputTexCoord) && !isDisoccluded2(inputTexCoord, prevInputTexCoord))
    {
        iDisoccluded = 0;
    }

    var prevTemporalReservoir: vec4<f32> = textureLoad(
        prevTemporalReservoirTexture,
        prevImageCoord,
        0
    );

    var prevHitPosition: vec4<f32> = textureLoad(
        prevHitPositionTexture,
        prevImageCoord,
        0
    );

    var prevHitNormal: vec4<f32> = textureLoad(
        prevHitNormalTexture,
        prevImageCoord,
        0
    );

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

    var candidateRadiance: vec4<f32> = vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f);
    var candidateRayDirection: vec4<f32> = vec4<f32>(rayDirection, 1.0f);
    var fRadianceDP: f32 = max(dot(normal, rayDirection), 0.0f);
    var fDistanceAttenuation: f32 = 1.0f;
    if(dot(candidateHitPosition.xyz, candidateHitPosition.xyz) < 100.0f)
    {
        let hitInfo: vec4<f32> = textureLoad(
            hitTriangleTexture,
            inputImageCoord,
            0
        );
        let iHitMesh: u32 = u32(hitInfo.y);
        let material: Material = aMeshMaterials[iHitMesh];
        candidateRadiance = vec4<f32>(material.mEmissive.xyz, 1.0f);

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

    if(fRand < fWeightPct || reservoir.z <= 0.0f)
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