const UINT32_MAX: u32 = 0xffffffffu;
const FLT_MAX: f32 = 1.0e+10;
const PI: f32 = 3.14159f;
const PROBE_IMAGE_SIZE: u32 = 8u;
const VALIDATION_STEP: u32 = 16u;
const RAY_LENGTH: f32 = 10.0f;
const kMaxAmbientOcclusionCount: f32 = 50.0f;

struct RandomResult 
{
    mfNum: f32,
    miSeed: u32,
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

struct VertexInput 
{
    @location(0) pos : vec4<f32>,
    @location(1) texCoord: vec2<f32>,
    @location(2) normal : vec4<f32>
};
struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};
struct FragmentOutput 
{
    @location(0) radianceOutput : vec4<f32>,
    @location(1) temporalReservoir: vec4<f32>,
    @location(2) hitPosition: vec4<f32>,
    @location(3) hitNormal: vec4<f32>,
    @location(4) sampleRayHitPosition: vec4<f32>,
    @location(5) sampleRayHitNormal: vec4<f32>,
    @location(6) sampleRayDirection: vec4<f32>
};

struct UniformData
{
    miNumTemporalRestirSamplePermutations: i32,
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
    mIntersectionResult: IntersectBVHResult,
    mRandomResult: RandomResult,
    mfNumValidSamples: f32,
};

struct ReservoirResult
{
    mReservoir: vec4<f32>,
    mbExchanged: bool
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

struct DisocclusionResult
{
    mBackProjectScreenCoord: vec2<i32>,
    mbDisoccluded: bool,
};

struct DirectSunLightResult
{
    mReservoir: vec4<f32>,
    mRadiance: vec3<f32>,
    mRandomResult: RandomResult,
};

struct IrradianceCacheEntry
{
    mPosition: vec4<f32>,
    mSampleCount: vec4<f32>,
    mSphericalHarmonics0: vec4<f32>,
    mSphericalHarmonics1: vec4<f32>,
    mSphericalHarmonics2: vec4<f32>
};

struct SHOutput 
{
    mCoefficients0: vec4<f32>,
    mCoefficients1: vec4<f32>,
    mCoefficients2: vec4<f32>
};

struct IrradianceCacheQueueEntry
{
    mPosition: vec4<f32>,
    mNormal: vec4<f32>
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

struct MeshTrianglerRange
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
    mLightDirection: vec4<f32>
};

@group(0) @binding(0)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(1)
var normalTexture: texture_2d<f32>;

@group(0) @binding(2)
var texCoordTexture: texture_2d<f32>;

@group(0) @binding(3)
var materialTexture: texture_2d<f32>;

@group(0) @binding(4)
var skyTexture: texture_2d<f32>;

@group(0) @binding(5)
var prevTemporalReservoirTexture: texture_2d<f32>;

@group(0) @binding(6)
var prevTemporalRadianceTexture: texture_2d<f32>;

@group(0) @binding(7)
var prevTemporalHitPositionTexture: texture_2d<f32>;

@group(0) @binding(8)
var prevTemporalHitNormalTexture: texture_2d<f32>;

@group(0) @binding(9)
var prevWorldPositionTexture: texture_2d<f32>;

@group(0) @binding(10)
var prevNormalTexture: texture_2d<f32>;

@group(0) @binding(11)
var motionVectorTexture: texture_2d<f32>;

@group(0) @binding(12)
var prevMotionVectorTexture: texture_2d<f32>;

@group(0) @binding(13)
var directRadianceTexture: texture_2d<f32>;

@group(0) @binding(14)
var<storage, read> irradianceCache: array<IrradianceCacheEntry>;

@group(1) @binding(0)
var<uniform> uniformData: UniformData;


@group(1) @binding(1)
var<storage, read> aSceneBVHNodes: array<BVHNode2>;

@group(1) @binding(2)
var<storage, read> aSceneVertexPositions: array<VertexFormat>;

@group(1) @binding(3)
var<storage, read> aiSceneTriangleIndices: array<u32>;

@group(1) @binding(4)
var blueNoiseTexture: texture_2d<f32>;

@group(1) @binding(5)
var sampleRadianceTexture: texture_storage_2d<rgba32float, write>;

@group(1) @binding(6)
var hitTriangleTexture: texture_storage_2d<rgba32float, write>;

@group(1) @binding(7)
var<storage, read> meshTrianglerRanges: array<MeshTrianglerRange>;

@group(1) @binding(8)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(9)
var textureSampler: sampler;

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
    var fReservoirSize: f32 = 8.0f;

    var out: FragmentOutput;

    if(defaultUniformBuffer.miFrame < 1)
    {
        return out;
    }

    let origScreenCoord: vec2<i32> = vec2<i32>(
        i32(in.uv.x * f32(defaultUniformBuffer.miScreenWidth)),
        i32(in.uv.y * f32(defaultUniformBuffer.miScreenHeight)));

    var randomResult: RandomResult = initRand(
        u32(in.uv.x * 100.0f + in.uv.y * 200.0f) + u32(defaultUniformBuffer.mfRand0 * 100.0f),
        u32(in.pos.x * 10.0f + in.pos.z * 20.0f) + u32(defaultUniformBuffer.mfRand0 * 100.0f),
        10u);

    let worldPosition: vec4<f32> = textureLoad(
        worldPositionTexture, 
        origScreenCoord, 
        0);

    let normal: vec3<f32> = textureLoad(
        normalTexture, 
        origScreenCoord, 
        0).xyz;

    if(worldPosition.w <= 0.0f)
    {
        out.radianceOutput = vec4<f32>(0.0f, 0.0f, 1.0f, 0.0f);
        out.temporalReservoir = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);
        return out;
    }

    var ambientOcclusionSample: vec4<f32>;

    let fCenterDepth: f32 = fract(worldPosition.w);
    let iCenterMeshID: i32 = i32(worldPosition.w - fCenterDepth);

    // check for disocclusion for previous history pixel
    var fDisocclusion: f32 = 0.0f;
    let prevScreenUV: vec2<f32> = getPreviousScreenUV(in.uv);
    if(isPrevUVOutOfBounds(in.uv))
    {
        fDisocclusion = 1.0f;
    }
    else
    {
        fDisocclusion = f32(isDisoccluded2(in.uv, prevScreenUV));
    }
    let fValidHistory: f32 = 1.0f - fDisocclusion;

    let prevScreenCoord: vec2<u32> = vec2<u32>(
        u32(prevScreenUV.x * f32(defaultUniformBuffer.miScreenWidth)),
        u32(prevScreenUV.y * f32(defaultUniformBuffer.miScreenHeight))
    );

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
        prevTemporalHitPositionTexture,
        prevScreenCoord,
        0) * fValidHistory;
    result.mHitNormal = textureLoad(
        prevTemporalHitNormalTexture,
        prevScreenCoord,
        0) * fValidHistory;
    result.mIntersectionResult.miHitTriangle = UINT32_MAX;
    result.mfNumValidSamples = 0.0f;

    // more samples for disoccluded pixel
    var iNumCenterSamples: i32 = 1;
    if(fDisocclusion >= 1.0f || result.mReservoir.z <= 1.0f)
    {
        iNumCenterSamples = 4;
    }
    
    var fNumValidSamples: f32 = 0.0f;

    var screenCoord: vec2<u32> = vec2<u32>(
        u32(in.uv.x * f32(defaultUniformBuffer.miScreenWidth)),
        u32(in.uv.y * f32(defaultUniformBuffer.miScreenHeight))
    );

    let iCurrIndex: u32 = u32(defaultUniformBuffer.miFrame) * u32(iNumCenterSamples);
    let iCoordIndex: u32 = screenCoord.y * u32(defaultUniformBuffer.miScreenWidth) + screenCoord.x;

    let blueNoiseTextureSize: vec2<u32> = textureDimensions(blueNoiseTexture);

    // switch tile every frame as shown in iTileIndex
    let iTileSize: u32 = 32u;
    let iNumTilesX: u32 = (blueNoiseTextureSize.x / iTileSize);
    let iNumTilesY: u32 = (blueNoiseTextureSize.y / iTileSize);
    let iNumTotalTiles: u32 = iNumTilesX * iNumTilesY; 
    var iTileIndex: u32 = (u32(defaultUniformBuffer.miFrame) % (iNumTilesX * iNumTilesY)); 
    var iTileIndexX: u32 = iTileIndex % iNumTilesX;
    var iTileIndexY: u32 = (iTileIndex / iNumTilesX) % iNumTilesY; 

    // center pixel sample
    var fReservoirWeight: f32 = 1.0f;
    for(var iSample: i32 = 0; iSample < iNumCenterSamples; iSample++)
    {
        var sampleRayDirection: vec3f = vec3f(0.0f, 0.0f, 0.0f);
        {
            let iTotalSampleIndex: u32 = u32(defaultUniformBuffer.miFrame) * 4u + u32(iSample);
            var iOffsetX: u32 = (iTotalSampleIndex % iTileSize) + iTileIndexX * iTileSize;
            var iOffsetY: u32 = ((iTotalSampleIndex / iTileSize) % iTileSize) + iTileIndexY * iTileSize;
            var blueNoiseSampleScreenCoord: vec2<u32> = vec2<u32>(
                ((u32(origScreenCoord.x) + iOffsetX) % u32(blueNoiseTextureSize.x)),
                ((u32(origScreenCoord.y) + iOffsetY) % u32(blueNoiseTextureSize.y))
            );

            let blueNoise: vec4f = textureLoad(
                blueNoiseTexture,
                blueNoiseSampleScreenCoord,
                0);

            let ray: Ray = uniformSampling(
                worldPosition.xyz,
                normal.xyz,
                blueNoise.x,
                blueNoise.y);
            sampleRayDirection = ray.mDirection.xyz;
        }

        var rayOrigin: vec3<f32> = worldPosition.xyz;

        // restir
        result.mIntersectionResult.miHitTriangle = UINT32_MAX;
        result = temporalRestir(
            result,

            rayOrigin,
            normal,
            in.uv,
            sampleRayDirection,

            fReservoirSize,
            1.0f,
            randomResult,
            0u,
            1.0f, 
            true);

        result.mReservoir.w = clamp(result.mReservoir.x / max(result.mReservoir.z * result.mReservoir.y, 0.001f), 0.0f, 1.0f);
        ambientOcclusionSample = result.mAmbientOcclusion;

        // record intersection triangle in w component
        var fIntersection: f32 = 0.0f;
        if(result.mIntersectionResult.miHitTriangle != UINT32_MAX)
        {
            fIntersection = f32(result.mIntersectionResult.miHitTriangle);
        }
        //out.rayDirection = vec4<f32>(sampleRayDirection.xyz, fIntersection);
        out.sampleRayHitPosition = vec4<f32>(result.mIntersectionResult.mHitPosition, fIntersection);
        out.sampleRayHitNormal = vec4<f32>(result.mIntersectionResult.mHitNormal, fIntersection);
        out.sampleRayDirection = vec4<f32>(sampleRayDirection, fIntersection);
    
        textureStore(
            sampleRadianceTexture, 
            screenCoord,
            result.mSampleRadiance);

        var iHitMesh: u32 = UINT32_MAX; 
        if(result.mIntersectionResult.miHitTriangle != UINT32_MAX) 
        {
            iHitMesh = getMeshForTriangleIndex(result.mIntersectionResult.miHitTriangle);
        }
        textureStore(
            hitTriangleTexture,
            screenCoord,
            vec4<f32>(fIntersection, f32(iHitMesh), 0.0f, 0.0f)
        );
    }

    var firstResult: TemporalRestirResult = result;

    let fPlaneD: f32 = -dot(worldPosition.xyz, normal.xyz);

    // permutation samples
    let iNumPermutations: i32 = uniformData.miNumTemporalRestirSamplePermutations + 1;
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
            if(fDP <=  0.6f)
            {
                continue;
            }

            // neightbor depth difference check
            let fSampleDepth: f32 = fract(sampleWorldPosition.w);
            //let fDepthDiff: f32 = abs(fCenterDepth - fSampleDepth);
            //if(fDepthDiff >= 0.05f)
            //{
            //    continue;
            //} 

            let fPlaneDistance: f32 = dot(normal.xyz, sampleWorldPosition.xyz) + fPlaneD;
            if(abs(fPlaneDistance) >= 0.2f)
            {
                continue;
            }

            // mesh id difference check
            let iSampleMeshID: i32 = i32(floor((sampleWorldPosition.w - fSampleDepth) + 0.5f));
            if(iSampleMeshID != iCenterMeshID)
            {
                continue;
            }

            // hit point and hit normal for jacobian
            let sampleHitPoint: vec3<f32> = textureLoad(
                prevTemporalHitPositionTexture,
                screenCoord,
                0).xyz;

            if(checkClipSpaceBlock(
                worldPosition.xyz, 
                normalize(worldPosition.xyz - sampleHitPoint)))
            {
                continue;
            }

            var neighborHitNormal: vec3<f32> = textureLoad(
                prevTemporalHitNormalTexture,
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

        result.mIntersectionResult.miHitTriangle = UINT32_MAX;
        result = temporalRestir(
            result,

            worldPosition.xyz,
            normal,
            sampleUV,
            sampleRayDirection,

            fReservoirSize,
            fJacobian,
            randomResult,
            u32(iSample),
            1.0f, 
            false);

        if(result.mIntersectionResult.miHitTriangle != UINT32_MAX) 
        {
            var iHitMesh: u32 = getMeshForTriangleIndex(result.mIntersectionResult.miHitTriangle);
            textureStore(
                hitTriangleTexture,
                screenCoord,
                vec4<f32>(f32(result.mIntersectionResult.miHitTriangle), f32(iHitMesh), 0.0f, 0.0f)
            );
        }
        

    }   // for sample = 0 to num permutation samples   

    // intersection check to see if the neighbor's ray direction is blocked
    if(iNumPermutations > 0)
    {
        var ray: Ray;
        ray.mDirection = vec4<f32>(result.mRayDirection.xyz, 1.0f);
        ray.mOrigin = vec4<f32>(worldPosition.xyz + result.mRayDirection.xyz * 0.01f, 1.0f);
        var intersectionInfo: IntersectBVHResult;
        intersectionInfo = intersectBVH4(ray, 0u);
        if((length(result.mHitPosition.xyz) >= RAY_LENGTH && abs(intersectionInfo.mHitPosition.x) < RAY_LENGTH) || 
        (length(result.mHitPosition.xyz) < RAY_LENGTH && abs(intersectionInfo.mHitPosition.x) >= RAY_LENGTH))
        {
            result = firstResult;
        }
    }

    result.mReservoir.w = clamp(result.mReservoir.x / max(result.mReservoir.z * result.mReservoir.y, 0.001f), 0.0f, 1.0f);

    //var fReservoirWeight: f32 = result.mReservoir.w;
    
    out.radianceOutput = result.mRadiance * fReservoirWeight;
    out.temporalReservoir = result.mReservoir;
    //out.rayDirection = result.mRayDirection;

    // debug disocclusion
    var prevInputTexCoord: vec2<f32> = getPreviousScreenUV(in.uv);
    //out.rayDirection.w = f32(isDisoccluded2(in.uv, prevInputTexCoord));

    let fAO: f32 = 1.0f - (ambientOcclusionSample.x / ambientOcclusionSample.y);
    
    //out.ambientOcclusionOutput = vec4<f32>(ambientOcclusionSample.x, ambientOcclusionSample.y, fAO, 1.0f);
    out.hitPosition = result.mHitPosition;
    out.hitNormal = result.mHitNormal;
    
    out.hitPosition.w = ambientOcclusionSample.x;
    out.hitNormal.w = ambientOcclusionSample.y;
    out.sampleRayDirection.w = fAO;

/*
    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);
    let screenImageCoord: vec2<u32> = vec2<u32>(
        u32(in.uv.x * f32(textureSize.x)),
        u32(in.uv.y * f32(textureSize.y))
    );
    let worldPosition: vec4<f32> = textureLoad(
        worldPositionTexture,
        screenImageCoord,
        0);
    if(worldPosition.w <= 0.0f)
    {
        out.radianceOutput = vec4<f32>(0.0f, 0.0f, 0.3f, 0.0f);
    }
    else 
    {
        out.radianceOutput = vec4<f32>(testDirectLighting(in.uv), 1.0f);
    }
*/
    return out;
}

///// 
fn testDirectLighting(uv: vec2<f32>) -> vec3<f32>
{
    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);

    let screenImageCoord: vec2<u32> = vec2<u32>(
        u32(uv.x * f32(textureSize.x)),
        u32(uv.y * f32(textureSize.y))
    );
    let worldPosition: vec4<f32> = textureLoad(
        worldPositionTexture,
        screenImageCoord,
        0
    );

    let rayDirection = normalize(vec3<f32>(1.0f, 1.0f, 1.0f));

    var origin: vec3<f32> = worldPosition.xyz + rayDirection * 0.001f;

    var ray: Ray;
    ray.mOrigin = vec4<f32>(origin + defaultUniformBuffer.mLightDirection.xyz * 0.01f, 1.0f);
    ray.mDirection = vec4<f32>(defaultUniformBuffer.mLightDirection.xyz, 1.0f);

    var ret: vec3<f32> = vec3<f32>(1.0f, 1.0f, 1.0f);
    var intersectionInfo: IntersectBVHResult = intersectBVH4(ray, 0u);
    if(intersectionInfo.miHitTriangle != UINT32_MAX)
    {
        ret = vec3<f32>(0.0f, 0.0f, 0.0f);
    }

    return ret;
}


/////
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
    var prevAmbientOcclusion: vec4<f32> = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);
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
        prevTemporalHitPositionTexture,
        prevImageCoord,
        0
    );

    var prevHitNormal: vec4<f32> = textureLoad(
        prevTemporalHitNormalTexture,
        prevImageCoord,
        0
    );

    var fAmbientOcclusionHit: f32 = prevHitPosition.w;
    var fAmbientOcclusionCount: f32 = prevHitNormal.w + 1.0f;

    
    if(fAmbientOcclusionCount > kMaxAmbientOcclusionCount)
    {
        let fPct: f32 = kMaxAmbientOcclusionCount / fAmbientOcclusionCount;
        fAmbientOcclusionHit *= fPct;
        fAmbientOcclusionCount = kMaxAmbientOcclusionCount;
    }

    fAmbientOcclusionHit *= f32(iDisoccluded == 0);
    fAmbientOcclusionCount *= f32(iDisoccluded == 0);
    fAmbientOcclusionCount = max(fAmbientOcclusionCount, 1.0f);

    var ray: Ray;
    ray.mOrigin = vec4<f32>(worldPosition + rayDirection * 0.01f, 1.0f);
    ray.mDirection = vec4<f32>(rayDirection, 1.0f);

    var intersectionInfo: IntersectBVHResult;
    if(bTraceRay)
    {
        intersectionInfo = intersectBVH4(ray, 0u);
    }

    var candidateHitPosition: vec4<f32> = vec4<f32>(intersectionInfo.mHitPosition.xyz, 1.0f);
    var candidateHitNormal: vec4<f32> = vec4<f32>(intersectionInfo.mHitNormal.xyz, 1.0f);

    if(!bTraceRay)
    {
        candidateHitPosition = textureLoad(
            prevTemporalHitPositionTexture,
            inputImageCoord,
            0
        );
        candidateHitNormal = textureLoad(
            prevTemporalHitNormalTexture,
            inputImageCoord,
            0
        );

        intersectionInfo.miHitTriangle = u32(floor(candidateHitPosition.w));
        if(length(candidateHitPosition.xyz) >= RAY_LENGTH)
        {
            intersectionInfo.miHitTriangle = UINT32_MAX;
        }
    }

    var candidateRadiance: vec4<f32> = vec4<f32>(0.0f, 0.0f, 0.0f, 1.0f);
    var candidateRayDirection: vec4<f32> = vec4<f32>(rayDirection, 1.0f);
    var fRadianceDP: f32 = max(dot(normal, ray.mDirection.xyz), 0.0f);
    var fDistanceAttenuation: f32 = 1.0f;
    if(intersectionInfo.miHitTriangle == UINT32_MAX)
    {
        let skyTextureSize: vec2<u32> = textureDimensions(skyTexture);

        // didn't hit anything, use skylight
        let skyUV: vec2<f32> = octahedronMap2(ray.mDirection.xyz);
        let skyImageCoord: vec2<u32> = vec2<u32>(
            u32(skyUV.x * f32(skyTextureSize.x)),
            u32(skyUV.y * f32(skyTextureSize.y))
        );

        candidateRadiance = textureLoad(
            skyTexture,
            skyImageCoord,
            0);

        candidateHitNormal = ray.mDirection * -1.0f;
        candidateHitPosition.x = worldPosition.x + ray.mDirection.x * 50000.0f;
        candidateHitPosition.y = worldPosition.y + ray.mDirection.y * 50000.0f;
        candidateHitPosition.z = worldPosition.z + ray.mDirection.z * 50000.0f;
    }
    else
    {
        var hitPosition: vec3<f32> = intersectionInfo.mHitPosition.xyz;
        
        // distance for on-screen radiance and ambient occlusion
        var fDistance: f32 = length(hitPosition - worldPosition);
        if(fDistance < 1.0f)
        {
            fAmbientOcclusionHit += 1.0f;
        }

        fDistanceAttenuation = 1.0f / max(fDistance * fDistance, 1.0f);
        if(fDistance < 1.0f)
        {
            fDistanceAttenuation = fDistance;
        }

        // get on-screen radiance if there's any
        var clipSpacePosition: vec4<f32> = vec4<f32>(hitPosition, 1.0) * defaultUniformBuffer.mViewProjectionMatrix;
        clipSpacePosition.x /= clipSpacePosition.w;
        clipSpacePosition.y /= clipSpacePosition.w;
        clipSpacePosition.z /= clipSpacePosition.w;
        clipSpacePosition.x = clipSpacePosition.x * 0.5f + 0.5f;
        clipSpacePosition.y = (clipSpacePosition.y * 0.5f + 0.5f);
        clipSpacePosition.z = clipSpacePosition.z * 0.5f + 0.5f;
        
        let imageCoord: vec2u = vec2u(
            u32(clipSpacePosition.x * f32(textureSize.x)),
            u32(clipSpacePosition.y * f32(textureSize.y))
        );

        let worldSpaceHitPosition: vec4<f32> = textureLoad(
            worldPositionTexture,
            imageCoord,
            0);
        var hitPositionClipSpace: vec4<f32> = vec4<f32>(worldSpaceHitPosition.xyz, 1.0f) * defaultUniformBuffer.mViewProjectionMatrix;
        hitPositionClipSpace.x /= hitPositionClipSpace.w;
        hitPositionClipSpace.y /= hitPositionClipSpace.w;
        hitPositionClipSpace.z /= hitPositionClipSpace.w;
        hitPositionClipSpace.x = hitPositionClipSpace.x * 0.5f + 0.5f;
        hitPositionClipSpace.y = (hitPositionClipSpace.y * 0.5f + 0.5f);
        hitPositionClipSpace.z = hitPositionClipSpace.z * 0.5f + 0.5f;

        let fDepthDiff: f32 = abs(hitPositionClipSpace.z - clipSpacePosition.z);

        if(clipSpacePosition.x >= 0.0f && clipSpacePosition.x <= 1.0f &&
           clipSpacePosition.y >= 0.0f && clipSpacePosition.y <= 1.0f && 
           fDepthDiff <= 0.01f)
        {
            // on screen

            let prevOnScreenUV: vec2<f32> = getPreviousScreenUV(clipSpacePosition.xy);
            let prevOnScreenImageCoord: vec2<u32> = vec2<u32>(
                u32(prevOnScreenUV.x * f32(defaultUniformBuffer.miScreenWidth)),
                u32(prevOnScreenUV.y * f32(defaultUniformBuffer.miScreenHeight))
            );
            candidateRadiance = textureLoad(
                directRadianceTexture,
                imageCoord.xy,
                0);
            candidateRadiance += textureLoad(
                prevTemporalRadianceTexture,
                prevOnScreenImageCoord.xy,
                0
            );
            let material: vec4<f32> = textureLoad(
                materialTexture,
                imageCoord.xy,
                0
            );
            candidateRadiance *= material;

            //candidateRadiance += textureSample(
            //    prevEmissiveRadianceTexture,
            //    textureSampler,
            //    prevOnScreenUV.xy);

            let fReflectivity: f32 = 1.0f;

            // distance attenuation
            let diff: vec3<f32> = hitPosition.xyz - worldPosition.xyz;
            let fDistanceAttenuation: f32 = 1.0f / max(dot(diff, diff), 1.0f);
            candidateRadiance *= fDistanceAttenuation;
            candidateRadiance *= fReflectivity;

            // debug
            //candidateRayDirection = vec4<f32>(
            //    clipSpacePosition.x,
            //    clipSpacePosition.y,
            //    clipSpacePosition.z,
            //    1.0f);
        }
        else 
        {
            let fReflectivity: f32 = 0.2f;

            // not on screen, check irradiance cache
            let iHitIrradianceCacheIndex: u32 = fetchIrradianceCacheIndex(hitPosition);
            let irradianceCachePosition: vec4<f32> = getIrradianceCachePosition(iHitIrradianceCacheIndex);
            if(irradianceCachePosition.w > 0.0f)
            {
                let positionToCacheDirection: vec3<f32> = normalize(irradianceCachePosition.xyz - worldPosition) * -1.0f; 
                let irradianceCacheProbeRadiance: vec3<f32> = getRadianceFromIrradianceCacheProbe(
                    positionToCacheDirection, 
                    iHitIrradianceCacheIndex);

                candidateRadiance.x = irradianceCacheProbeRadiance.x * fReflectivity;
                candidateRadiance.y = irradianceCacheProbeRadiance.y * fReflectivity;
                candidateRadiance.z = irradianceCacheProbeRadiance.z * fReflectivity;
            }
        }
    }    

    candidateRadiance.x = candidateRadiance.x * fJacobian * fRadianceDP * fDistanceAttenuation * fOneOverPDF;
    candidateRadiance.y = candidateRadiance.y * fJacobian * fRadianceDP * fDistanceAttenuation * fOneOverPDF;
    candidateRadiance.z = candidateRadiance.z * fJacobian * fRadianceDP * fDistanceAttenuation * fOneOverPDF;
    
    ret.mSampleRadiance = candidateRadiance;

    // reservoir
    let fLuminance: f32 = computeLuminance(
        ToneMapFilmic_Hejl2015(
            candidateRadiance.xyz, 
            max(max(defaultUniformBuffer.mLightRadiance.x, defaultUniformBuffer.mLightRadiance.y), defaultUniformBuffer.mLightRadiance.z)
        )
    );

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
    ret.mAmbientOcclusion = vec4<f32>(fAmbientOcclusionHit, fAmbientOcclusionCount, f32(iDisoccluded), 0.0f);
    ret.mIntersectionResult = intersectionInfo;

    ret.mfNumValidSamples += fM * f32(fLuminance > 0.0f);
    
    return ret;
}

/////
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

/////
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

/////
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

/////
fn computeLuminance(
    radiance: vec3<f32>) -> f32
{
    return dot(radiance, vec3<f32>(0.2126f, 0.7152f, 0.0722f));
}

/////
fn octahedronMap2(direction: vec3<f32>) -> vec2<f32>
{
    let fDP: f32 = dot(vec3<f32>(1.0f, 1.0f, 1.0f), abs(direction));
    let newDirection: vec3<f32> = vec3<f32>(direction.x, direction.z, direction.y) / fDP;

    var ret: vec2<f32> =
        vec2<f32>(
            (1.0f - abs(newDirection.z)) * sign(newDirection.x),
            (1.0f - abs(newDirection.x)) * sign(newDirection.z));
       
    if(newDirection.y < 0.0f)
    {
        ret = vec2<f32>(
            newDirection.x, 
            newDirection.z);
    }

    ret = ret * 0.5f + vec2<f32>(0.5f, 0.5f);
    ret.y = 1.0f - ret.y;

    return ret;
}

/////
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


/////
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

/////
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



/////
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

/////
fn isDisoccluded(
    inputTexCoord: vec2<f32>) -> bool
{
    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);
    let inputScreenCoord: vec2<u32> = vec2<u32>(
        u32(inputTexCoord.x * f32(textureSize.x)),
        u32(inputTexCoord.y * f32(textureSize.y))
    );

    // world position, normal, and motion vector
    let worldPosition = textureLoad(
        worldPositionTexture,
        inputScreenCoord,
        0);
    let normal = textureLoad(
        normalTexture,
        inputScreenCoord,
        0);
    var motionVector: vec4<f32> = textureLoad(
        motionVectorTexture,
        inputScreenCoord,
        0);
    
    let iMesh: u32 = u32(ceil(motionVector.z - 0.5f)) - 1;

    // world position, normal, motion vector from previous frame with back projected uv
    var backProjectedScreenUV: vec2<f32> = inputTexCoord - motionVector.xy;
    if(backProjectedScreenUV.x < 0.0f || backProjectedScreenUV.y < 0.0f || 
       backProjectedScreenUV.x > 1.0f || backProjectedScreenUV.y > 1.0f)
    {
        return true;
    }

    let backProjectedScreenCoord: vec2<u32> = vec2<u32>(
        u32(backProjectedScreenUV.x * f32(textureSize.x)),
        u32(backProjectedScreenUV.y * f32(textureSize.y))
    );

    var prevWorldPosition: vec4<f32> = textureLoad(
        prevWorldPositionTexture,
        backProjectedScreenCoord,
        0
    );
    var prevNormal: vec4<f32> = textureLoad(
        prevNormalTexture,
        backProjectedScreenCoord,
        0
    );
    var prevMotionVectorAndMeshIDAndDepth: vec4<f32> = textureLoad(
        prevMotionVectorTexture,
        backProjectedScreenCoord,
        0
    );

    var fOneOverScreenHeight: f32 = 1.0f / f32(defaultUniformBuffer.miScreenHeight);
    var fOneOverScreenWidth: f32 = 1.0f / f32(defaultUniformBuffer.miScreenWidth);

    var bestBackProjectedScreenUV: vec2<f32> = backProjectedScreenUV;
    var fShortestWorldDistance: f32 = FLT_MAX;
    for(var iY: i32 = -1; iY <= 1; iY++)
    {
        var fSampleY: f32 = backProjectedScreenUV.y + f32(iY) * fOneOverScreenHeight;
        fSampleY = clamp(fSampleY, 0.0f, 1.0f);
        for(var iX: i32 = -1; iX <= 1; iX++)
        {
            var fSampleX: f32 = backProjectedScreenUV.x + f32(iX) * fOneOverScreenWidth;
            fSampleX = clamp(fSampleX, 0.0f, 1.0f);

            let sampleUV: vec2<f32> = vec2<f32>(fSampleX, fSampleY);
            let sampleScreenCoord: vec2<u32> = vec2<u32>(
                u32(sampleUV.x * f32(textureSize.x)),
                u32(sampleUV.y * f32(textureSize.y))
            );

            var checkPrevWorldPosition: vec4<f32> = textureLoad(
                prevWorldPositionTexture,
                sampleScreenCoord,
                0
            );

            var checkPrevNormal: vec4<f32> = textureLoad(
                prevNormalTexture,
                sampleScreenCoord,
                0
            );

            var worldPositionDiff: vec3<f32> = checkPrevWorldPosition.xyz - worldPosition.xyz;
            var fCheckWorldPositionDistance: f32 = dot(worldPositionDiff, worldPositionDiff);
            var fCheckNormalDP: f32 = abs(dot(checkPrevNormal.xyz, normal.xyz));
            if(fCheckWorldPositionDistance < fShortestWorldDistance && fCheckNormalDP >= 0.98f)
            {
                fShortestWorldDistance = fCheckWorldPositionDistance;
                bestBackProjectedScreenUV = sampleUV;
            }
        }
    }

    backProjectedScreenUV = bestBackProjectedScreenUV;
    prevWorldPosition = textureLoad(
        prevWorldPositionTexture,
        backProjectedScreenCoord,
        0
    );
    prevNormal = textureLoad(
        prevNormalTexture,
        backProjectedScreenCoord,
        0
    );
    prevMotionVectorAndMeshIDAndDepth = textureLoad(
        prevMotionVectorTexture,
        backProjectedScreenCoord,
        0
    );
    
    let toCurrentDir: vec3<f32> = worldPosition.xyz - prevWorldPosition.xyz;
    //let fPlaneDistance: f32 = abs(dot(toCurrentDir, normal.xyz)); 
    let fPrevPlaneDistance: f32 = abs(dot(prevWorldPosition.xyz, normal.xyz)) - abs(dot(worldPosition.xyz, normal.xyz));

    // compute difference in world position, depth, and angle from previous frame
    
    var fDepth: f32 = motionVector.w;
    var fPrevDepth: f32 = prevMotionVectorAndMeshIDAndDepth.w;
    var fCheckDepth: f32 = abs(fDepth - fPrevDepth);
    var worldPositionDiff: vec3<f32> = prevWorldPosition.xyz - worldPosition.xyz;
    var fCheckDP: f32 = abs(dot(normalize(normal.xyz), normalize(prevNormal.xyz)));
    let iPrevMesh: u32 = u32(ceil(prevMotionVectorAndMeshIDAndDepth.z - 0.5f)) - 1;
    var fCheckWorldPositionDistance: f32 = dot(worldPositionDiff, worldPositionDiff);

    return !(iMesh == iPrevMesh && fCheckDepth <= 0.004f && fCheckWorldPositionDistance <= 0.001f && fCheckDP >= 0.99f);
    //return !(iMesh == iPrevMesh && fCheckWorldPositionDistance <= 0.00025f && fCheckDP >= 0.99f);
    //return !(iMesh == iPrevMesh && fPrevPlaneDistance <= 0.008f && fCheckDP >= 0.99f);
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

/*
    for(var iY: i32 = -1; iY <= 1; iY++)
    {
        for(var iX: i32 = -1; iX <= 1; iX++)
        {
            var sampleUV: vec2<f32> = prevScreenUV + vec2<f32>(
                f32(iX) * fOneOverScreenWidth,
                f32(iY) * fOneOverScreenHeight 
            );

            sampleUV.x = clamp(sampleUV.x, 0.0f, 1.0f);
            sampleUV.y = clamp(sampleUV.y, 0.0f, 1.0f);

            let sampleScreenCoord: vec2<u32> = vec2<u32>(
                u32(sampleUV.x * f32(textureSize.x)),
                u32(sampleUV.y * f32(textureSize.y)) 
            );

            var checkWorldPosition: vec3<f32> = textureLoad(
                prevWorldPositionTexture,
                sampleScreenCoord,
                0
            ).xyz;
            var checkNormal: vec3<f32> = textureLoad(
                prevNormalTexture,
                sampleScreenCoord,
                0
            ).xyz;
            var fNormalDP: f32 = abs(dot(checkNormal, normal));

            var worldPositionDiff: vec3<f32> = checkWorldPosition - worldPosition;
            var fLengthSquared: f32 = dot(worldPositionDiff, worldPositionDiff);
            if(fNormalDP >= 0.99f && fShortestWorldDistance > fLengthSquared)
            {
                fShortestWorldDistance = fLengthSquared;
                closestScreenUV = sampleUV;
            }
        }
    }
*/

    return closestScreenUV;
}

/////
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

///// 
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

/////
fn ToneMapFilmic_Hejl2015(
    hdr: vec3<f32>, 
    whitePt: f32) -> vec3<f32>
{
    let vh: vec4<f32> = vec4<f32>(hdr, whitePt);
    let va: vec4<f32> = (vh * 1.425f) + 0.05f;
    let vf: vec4<f32> = ((vh * va + 0.004f) / ((vh * (va + 0.55f) + 0.0491f))) - vec4<f32>(0.0821f);
    var ret: vec3<f32> = vf.rgb / vf.w;

    return clamp(ret, vec3<f32>(0.0f, 0.0f, 0.0f), vec3<f32>(1.0f, 1.0f, 1.0f));
}

/////
fn convertToSRGB(
    radiance: vec3<f32>) -> vec3<f32>
{
    let maxComp: f32 = max(max(radiance.x, radiance.y), radiance.z);
    let maxRadiance: vec3<f32> = max(radiance, 
        vec3<f32>(0.01f * maxComp));
    let linearRadiance: vec3<f32> = ACESFilm(maxRadiance);

    return linearToSRGB(linearRadiance);
}

/////
fn ACESFilm(
    radiance: vec3<f32>) -> vec3<f32>
{
    let fA: f32 = 2.51f;
    let fB: f32 = 0.03f;
    let fC: f32 = 2.43f;
    let fD: f32 = 0.59f;
    let fE: f32 = 0.14f;

    return saturate((radiance * (fA * radiance + fB)) / (radiance * (fC * radiance + fD) + fE));
}

/////
fn linearToSRGB(
    x: vec3<f32>) -> vec3<f32>
{
    var bCond: bool = (x.x < 0.0031308f || x.y < 0.0031308f || x.z < 0.0031308f);
    var ret: vec3<f32> = x * 12.92f;
    if(!bCond) 
    {
        ret = vec3<f32>(
            pow(x.x, 1.0f / 2.4f) * 1.055f - 0.055f,
            pow(x.y, 1.0f / 2.4f) * 1.055f - 0.055f,
            pow(x.z, 1.0f / 2.4f) * 1.055f - 0.055f
        );
    }

    return ret;
}

//////
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

/*
**
*/
fn fetchIrradianceCacheIndex(
    position: vec3<f32>
) -> u32
{
    var scaledPosition: vec3<f32> = position;
    let fSignX: f32 = sign(position.x);
    let fSignY: f32 = sign(position.y);
    let fSignZ: f32 = sign(position.z);
    scaledPosition.x = f32(floor(abs(scaledPosition.x) + 0.5f)) * 0.1f * fSignX;
    scaledPosition.y = f32(floor(abs(scaledPosition.y) + 0.5f)) * 0.1f * fSignY;
    scaledPosition.z = f32(floor(abs(scaledPosition.z) + 0.5f)) * 0.1f * fSignZ; 

    let iHashKey: u32 = hash13(
        scaledPosition,
        50000u
    );

    return iHashKey;
}

/*
**
*/
fn murmurHash13(
    src: vec3<u32>) -> u32
{
    var srcCopy: vec3<u32> = src;
    var M: u32 = 0x5bd1e995u;
    var h: u32 = 1190494759u;
    srcCopy *= M; srcCopy.x ^= srcCopy.x >> 24u; srcCopy.y ^= srcCopy.y >> 24u; srcCopy.z ^= srcCopy.z >> 24u; srcCopy *= M;
    h *= M; h ^= srcCopy.x; h *= M; h ^= srcCopy.y; h *= M; h ^= srcCopy.z;
    h ^= h >> 13u; h *= M; h ^= h >> 15u;
    return h;
}

/*
**
*/
fn hash13(
    src: vec3<f32>,
    iNumSlots: u32) -> u32
{
    let srcU32: vec3<u32> = vec3<u32>(
        bitcast<u32>(src.x),
        bitcast<u32>(src.y),
        bitcast<u32>(src.z)
    );

    let h: u32 = u32(murmurHash13(srcU32));
    var fValue: f32 = bitcast<f32>((h & 0x007ffffffu) | 0x3f800000u) - 1.0f;
    let iRet: u32 = clamp(u32(fValue * f32(iNumSlots - 1)), 0u, iNumSlots - 1);
    return iRet;
}

/*
**
*/
fn getRadianceFromIrradianceCacheProbe(
    rayDirection: vec3<f32>,
    iIrradianceCacheIndex: u32
) -> vec3<f32>
{
    if(irradianceCache[iIrradianceCacheIndex].mPosition.w == 0.0f)
    {
        return vec3<f32>(0.0f, 0.0f, 0.0f);
    }

    var shCoeff: SHOutput;
    shCoeff.mCoefficients0 = irradianceCache[iIrradianceCacheIndex].mSphericalHarmonics0;
    shCoeff.mCoefficients1 = irradianceCache[iIrradianceCacheIndex].mSphericalHarmonics1;
    shCoeff.mCoefficients2 = irradianceCache[iIrradianceCacheIndex].mSphericalHarmonics2; 

    let ret: vec3<f32> = decodeFromSphericalHarmonicCoefficients(
        shCoeff,
        rayDirection * -1.0f,
        vec3<f32>(10.0f, 10.0f, 10.0f),
        irradianceCache[iIrradianceCacheIndex].mSampleCount.x
    );

    return ret;
}

/*
**
*/
fn getIrradianceCachePosition(
    iIrradianceCacheIndex: u32
) -> vec4<f32>
{
    return irradianceCache[iIrradianceCacheIndex].mPosition;
}

/*
**
*/
fn decodeFromSphericalHarmonicCoefficients(
    shOutput: SHOutput,
    direction: vec3<f32>,
    maxRadiance: vec3<f32>,
    fHistoryCount: f32
) -> vec3<f32>
{
    var SHCoefficent0: vec4<f32> = shOutput.mCoefficients0;
    var SHCoefficent1: vec4<f32> = shOutput.mCoefficients1;
    var SHCoefficent2: vec4<f32> = shOutput.mCoefficients2;

    var aTotalCoefficients: array<vec3<f32>, 4>;
    let fFactor: f32 = 1.0f;

    aTotalCoefficients[0] = vec3<f32>(SHCoefficent0.x, SHCoefficent0.y, SHCoefficent0.z) * fFactor;
    aTotalCoefficients[1] = vec3<f32>(SHCoefficent0.w, SHCoefficent1.x, SHCoefficent1.y) * fFactor;
    aTotalCoefficients[2] = vec3<f32>(SHCoefficent1.z, SHCoefficent1.w, SHCoefficent2.x) * fFactor;
    aTotalCoefficients[3] = vec3<f32>(SHCoefficent2.y, SHCoefficent2.z, SHCoefficent2.w) * fFactor;

    let fC1: f32 = 0.42904276540489171563379376569857f;
    let fC2: f32 = 0.51166335397324424423977581244463f;
    let fC3: f32 = 0.24770795610037568833406429782001f;
    let fC4: f32 = 0.88622692545275801364908374167057f;

    var decoded: vec3<f32> =
        aTotalCoefficients[0] * fC4 +
        (aTotalCoefficients[3] * direction.x + aTotalCoefficients[1] * direction.y + aTotalCoefficients[2] * direction.z) *
        fC2 * 2.0f;
    decoded /= fHistoryCount;
    decoded = clamp(decoded, vec3<f32>(0.0f, 0.0f, 0.0f), maxRadiance);

    return decoded;
}

/*
**
*/
fn getMeshForTriangleIndex(iTriangleIndex: u32) -> u32
{
    var iRet: u32 = 0u;
    for(var i: u32 = 0u; i < defaultUniformBuffer.miNumMeshes; i++)
    {
        if(iTriangleIndex >= meshTrianglerRanges[i].miStart && 
           iTriangleIndex <= meshTrianglerRanges[i].miEnd)
        {
            iRet = i;
            break;
        }
    }

    return iRet;
}