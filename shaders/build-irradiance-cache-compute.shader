const UINT32_MAX: u32 = 0xffffffffu;
const FLT_MAX: f32 = 1.0e+10;
const PI: f32 = 3.14159f;
const PROBE_IMAGE_SIZE: u32 = 8u;
const VALIDATION_STEP: u32 = 16u;
const RAY_LENGTH: f32 = 10.0f;

struct IrradianceCacheQueueEntry
{
    mPosition: vec4<f32>,
    mNormal: vec4<f32>
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

struct VertexFormat
{
    mPosition: vec4<f32>,
    mTexCoord: vec4<f32>,
    mNormal: vec4<f32>
};

struct IrradianceCacheEntry
{
    mPosition: vec4<f32>,
    mSampleCount: vec4<f32>,
    mSphericalHarmonics0: vec4<f32>,
    mSphericalHarmonics1: vec4<f32>,
    mSphericalHarmonics2: vec4<f32>
};

struct Ray
{
    mOrigin: vec4<f32>,
    mDirection: vec4<f32>,
    mfT: vec4<f32>,
};

struct RandomResult 
{
    mfNum: f32,
    miSeed: u32
};

struct UpdateIrradianceCacheResult
{
    mRandomResult: RandomResult,
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
var<storage, read_write> irradianceCache: array<IrradianceCacheEntry>;

@group(0) @binding(1)
var hitPositionTexture: texture_2d<f32>;

@group(0) @binding(2)
var hitNormalTexture: texture_2d<f32>;

@group(0) @binding(3)
var skyTexture: texture_2d<f32>;

@group(0) @binding(4)
var sunLightTexture: texture_2d<f32>;

@group(0) @binding(5)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(6)
var normalTexture: texture_2d<f32>;

@group(1) @binding(0)
var<storage, read_write> aiCounterBuffer: array<u32>;

@group(1) @binding(1)
var<storage, read_write> irradianceCacheIndexQueue: array<u32>;

@group(1) @binding(2)
var<storage, read_write> irradianceCacheQueue: array<IrradianceCacheQueueEntry>;

@group(1) @binding(3)
var<storage, read> aSceneBVHNodes: array<BVHNode2>;

@group(1) @binding(4)
var<storage, read> aSceneVertexPositions: array<VertexFormat>;

@group(1) @binding(5)
var<storage, read> aiSceneTriangleIndices: array<u32>;

@group(1) @binding(6) 
var<uniform> defaultUniformBuffer: DefaultUniformData;

const iNumThreads = 256u;

/*
**
*/
@compute
@workgroup_size(iNumThreads)
fn cs_main(
    @builtin(num_workgroups) numWorkGroups: vec3<u32>,
    @builtin(local_invocation_index) iLocalThreadIndex: u32,
    @builtin(workgroup_id) workGroup: vec3<u32>)
{
    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);

    let iTotalThreadIndex: u32 = iLocalThreadIndex + workGroup.x * iNumThreads + workGroup.y * numWorkGroups.x * iNumThreads;
    let iX: u32 = iTotalThreadIndex % textureSize.x;
    let iY: u32 = iTotalThreadIndex / textureSize.x;
    
    if(iX >= textureSize.x || iY >= textureSize.y)
    {
        return;
    }

    var imageCoord: vec2<u32> = vec2<u32>(iX, iY);
    let worldPosition: vec4<f32> = textureLoad(
        worldPositionTexture,
        imageCoord,
        0
    );

    if(worldPosition.w <= 0.0f)
    {
        return;
    }

    let normal: vec4<f32> = textureLoad(normalTexture,
        imageCoord,
        0
    );
    let hitPosition: vec4<f32> = textureLoad(
        hitPositionTexture,
        imageCoord,
        0
    );
    let hitNormal: vec4<f32> = textureLoad(
        hitNormalTexture,
        imageCoord,
        0
    );

    // get on-screen radiance if there's any
    var clipSpacePosition: vec4<f32> = vec4<f32>(hitPosition.xyz, 1.0) * defaultUniformBuffer.mViewProjectionMatrix;
    clipSpacePosition.x /= clipSpacePosition.w;
    clipSpacePosition.y /= clipSpacePosition.w;
    clipSpacePosition.z /= clipSpacePosition.w;
    clipSpacePosition.x = clipSpacePosition.x * 0.5f + 0.5f;
    clipSpacePosition.y = (clipSpacePosition.y * 0.5f + 0.5f);
    clipSpacePosition.z = clipSpacePosition.z * 0.5f + 0.5f;
    
    imageCoord = vec2u(
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

    if(clipSpacePosition.x > 1.0f || clipSpacePosition.x < 0.0f || 
       clipSpacePosition.y > 1.0f || clipSpacePosition.y < 0.0f || 
       fDepthDiff > 0.01f)
    {
        var randomResult: RandomResult = initRand(
            u32(f32(iLocalThreadIndex + workGroup.y) * 100.0f + f32(iLocalThreadIndex + workGroup.x) * 200.0f) + u32(defaultUniformBuffer.mfRand0 * 100.0f),
            u32(f32(workGroup.x) * 10.0f + f32(iLocalThreadIndex * workGroup.y) * 20.0f) + u32(defaultUniformBuffer.mfRand1 * 100.0f),
            10u);

        updateIrradianceCache(
            hitPosition.xyz,
            hitNormal.xyz,
            randomResult,
            iX,
            iY
        );
    }
}

/*
**
*/
fn updateIrradianceCache(
    hitPosition: vec3<f32>,
    hitNormal: vec3<f32>,
    randomResult: RandomResult,
    iThreadX: u32,
    iThreadY: u32
) -> UpdateIrradianceCacheResult
{
    let textureSize: vec2<u32> = textureDimensions(worldPositionTexture);

    var ret: UpdateIrradianceCacheResult;
    var randomResultCopy: RandomResult = randomResult;

    // create new irradiance cache entry if non-existent
    var iCurrIrradianceCacheEntry: u32 = fetchIrradianceCacheIndex(hitPosition);
    if(irradianceCache[iCurrIrradianceCacheEntry].mPosition.w <= 0.0f)
    {
        iCurrIrradianceCacheEntry = createIrradianceCacheEntry(hitPosition);
    }

    // sample ray for the center sample
    randomResultCopy = nextRand(randomResultCopy.miSeed);
    let fRand0: f32 = randomResultCopy.mfNum;
    randomResultCopy = nextRand(randomResultCopy.miSeed);
    let fRand1: f32 = randomResultCopy.mfNum;
    
    // hit position and hit normal
    var intersectionInfo: IntersectBVHResult;
    intersectionInfo.miHitTriangle = UINT32_MAX;

    var ray: Ray =  uniformSampling(
        hitPosition,
        hitNormal,
        fRand0,
        fRand1);
    intersectionInfo = intersectBVH4(ray, 0u);
    if(intersectionInfo.miHitTriangle != UINT32_MAX)
    {
        let iTri0: u32 = aiSceneTriangleIndices[intersectionInfo.miHitTriangle * 3];
        let iTri1: u32 = aiSceneTriangleIndices[intersectionInfo.miHitTriangle * 3 + 1];
        let iTri2: u32 = aiSceneTriangleIndices[intersectionInfo.miHitTriangle * 3 + 2];

        let v0: VertexFormat = aSceneVertexPositions[iTri0];
        let v1: VertexFormat = aSceneVertexPositions[iTri1];
        let v2: VertexFormat = aSceneVertexPositions[iTri2];

        intersectionInfo.mHitPosition =
            v0.mPosition.xyz * intersectionInfo.mBarycentricCoordinate +
            v1.mPosition.xyz * intersectionInfo.mBarycentricCoordinate +
            v2.mPosition.xyz * intersectionInfo.mBarycentricCoordinate;

        intersectionInfo.mHitNormal =
            v0.mNormal.xyz * intersectionInfo.mBarycentricCoordinate +
            v1.mNormal.xyz * intersectionInfo.mBarycentricCoordinate +
            v2.mNormal.xyz * intersectionInfo.mBarycentricCoordinate;
    }
    else
    {
        intersectionInfo.miHitTriangle = UINT32_MAX;
        intersectionInfo.mHitPosition = ray.mDirection.xyz * 1000.0f;
        intersectionInfo.mHitNormal = vec3<f32>(0.0f, 0.0f, 0.0f);
        intersectionInfo.mBarycentricCoordinate = vec3<f32>(0.0f, 0.0f, 0.0f);
    }

    let candidateHitPosition: vec4<f32> = vec4<f32>(intersectionInfo.mHitPosition.xyz, 1.0f);
    let candidateHitNormal: vec4<f32> = vec4<f32>(intersectionInfo.mHitNormal.xyz, 1.0f);

    let fRayLength: f32 = length(intersectionInfo.mHitPosition.xyz - hitPosition);

    // process intersection
    var cacheRadiance = vec3<f32>(0.0f, 0.0f, 0.0f);
    if(intersectionInfo.miHitTriangle == UINT32_MAX || fRayLength >= 100.0f)
    {
        // didn't hit anything, use skylight
        let fRadianceDP: f32 = max(dot(hitNormal.xyz, ray.mDirection.xyz), 0.0f);
        let skyUV: vec2<f32> = octahedronMap2(ray.mDirection.xyz);

        let skyTextureSize: vec2<u32> = textureDimensions(skyTexture);
        let skyCoord: vec2<i32> = vec2<i32>(
            i32(skyUV.x * f32(skyTextureSize.x)),
            i32(skyUV.y * f32(skyTextureSize.y))
        );
        let skyRadiance: vec3<f32> = textureLoad(
            skyTexture,
            skyCoord,
            0).xyz;
        let sunLight: vec3<f32> = textureLoad(
            sunLightTexture,
            skyCoord,
            0).xyz;
        cacheRadiance = sunLight + skyRadiance * fRadianceDP;

        // update irradiance cache probe with the radiance and ray direction
        updateIrradianceCacheProbe(
            cacheRadiance,
            ray.mDirection.xyz * -1.0f,
            iCurrIrradianceCacheEntry);
    }
    else 
    {
        let iHitTriangleIndex: i32 = i32(intersectionInfo.miHitTriangle);
        //if (intersectionInfo.miHitMesh < defaultUniformBuffer.miNumMeshes)
        //{
        //    let iMaterialID: i32 = materialID[intersectionInfo.miHitMesh] - 1;
        //    let emissiveRadiance: vec3<f32> = materialData[iMaterialID].mEmissive.xyz;
        //    cacheRadiance += emissiveRadiance;
        //}

        // hit another mesh triangle, get the irradiance cache in the vicinity
        let iHitIrradianceCacheIndex: u32 = fetchIrradianceCacheIndex(candidateHitPosition.xyz);
        if(iHitIrradianceCacheIndex != iCurrIrradianceCacheEntry)
        {
            if(irradianceCache[iHitIrradianceCacheIndex].mPosition.w <= 0.0f)
            {
                // no valid irradiance cache here, create a new one
                createIrradianceCacheEntry(candidateHitPosition.xyz);
            }

            // get the radiance from probe image
            let fRadianceDP: f32 = max(dot(hitNormal.xyz, ray.mDirection.xyz), 0.0f);
            cacheRadiance += decodeFromSphericalHarmonicCoefficients(ray.mDirection.xyz * -1.0f, iHitIrradianceCacheIndex) * fRadianceDP;
        
            // update irradiance cache probe with the radiance and ray direction
            if(length(cacheRadiance.xyz) > 0.0f)
            {
                updateIrradianceCacheProbe(
                    cacheRadiance,
                    ray.mDirection.xyz * -1.0f,
                    iCurrIrradianceCacheEntry);
            }
        }
    }
    
    ret.mRandomResult = randomResultCopy;
    return ret;
}

/*
**
*/
fn fetchIrradianceCacheIndex(
    position: vec3<f32>
) -> u32
{
    var scaledPosition: vec3<f32> = position * 10.0f;
    let fSignX: f32 = sign(position.x);
    let fSignY: f32 = sign(position.y);
    let fSignZ: f32 = sign(position.z);
    scaledPosition.x = f32(floor(abs(position.x) + 0.5f)) * 0.1f * fSignX; 
    scaledPosition.y = f32(floor(abs(position.y) + 0.5f)) * 0.1f * fSignY; 
    scaledPosition.z = f32(floor(abs(position.z) + 0.5f)) * 0.1f * fSignZ; 

    let iHashKey: u32 = hash13(
        scaledPosition,
        50000u
    );

    return iHashKey;
}

/*
**
*/
fn createIrradianceCacheEntry(
    position: vec3<f32>
) -> u32
{
    let iIrradianceCacheIndex: u32 = fetchIrradianceCacheIndex(position);

    var scaledPosition: vec3<f32> = position * 10.0f;
    let fSignX: f32 = sign(position.x);
    let fSignY: f32 = sign(position.y);
    let fSignZ: f32 = sign(position.z);
    scaledPosition.x = f32(floor(abs(scaledPosition.x) + 0.5f)) * 0.1f * fSignX;
    scaledPosition.y = f32(floor(abs(scaledPosition.y) + 0.5f)) * 0.1f * fSignY;
    scaledPosition.z = f32(floor(abs(scaledPosition.z) + 0.5f)) * 0.1f * fSignZ; 
    
    irradianceCache[iIrradianceCacheIndex].mPosition = vec4<f32>(scaledPosition, 1.0f);

    irradianceCache[iIrradianceCacheIndex].mSphericalHarmonics0 = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);
    irradianceCache[iIrradianceCacheIndex].mSphericalHarmonics1 = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);
    irradianceCache[iIrradianceCacheIndex].mSphericalHarmonics2 = vec4<f32>(0.0f, 0.0f, 0.0f, 0.0f);

    return iIrradianceCacheIndex;
}

/*
**
*/
fn updateIrradianceCacheProbe(
    radiance: vec3<f32>,
    direction: vec3<f32>,
    iCacheEntryIndex: u32)
{
    // encode to spherical harmonics coefficients
    encodeSphericalHarmonicCoefficients(
        radiance,
        direction,
        iCacheEntryIndex
    );

    irradianceCache[iCacheEntryIndex].mSampleCount.z = f32(defaultUniformBuffer.miFrame);
}

/*
**
*/
fn encodeSphericalHarmonicCoefficients(
    radiance: vec3<f32>,
    direction: vec3<f32>,
    iCacheEntryIndex: u32
)
{
    var SHCoefficent0: vec4<f32> = irradianceCache[iCacheEntryIndex].mSphericalHarmonics0; 
    var SHCoefficent1: vec4<f32> = irradianceCache[iCacheEntryIndex].mSphericalHarmonics1; 
    var SHCoefficent2: vec4<f32> = irradianceCache[iCacheEntryIndex].mSphericalHarmonics2;

    let afC: vec4<f32> = vec4<f32>(
        0.282095f,
        0.488603f,
        0.488603f,
        0.488603f
    );

    let A: vec4<f32> = vec4<f32>(
        0.886227f,
        1.023326f,
        1.023326f,
        1.023326f
    );

    // encode coefficients with direction
    let coefficient: vec4<f32> = vec4<f32>(
        afC.x * A.x,
        afC.y * direction.y * A.y,
        afC.z * direction.z * A.z,
        afC.w * direction.x * A.w
    );

    // encode with radiance
    var aResults: array<vec3<f32>, 4>;
    aResults[0] = radiance.xyz * coefficient.x;
    aResults[1] = radiance.xyz * coefficient.y;
    aResults[2] = radiance.xyz * coefficient.z;
    aResults[3] = radiance.xyz * coefficient.w;

    SHCoefficent0.x += aResults[0].x;
    SHCoefficent0.y += aResults[0].y;
    SHCoefficent0.z += aResults[0].z;
    SHCoefficent0.w += aResults[1].x;

    SHCoefficent1.x += aResults[1].y;
    SHCoefficent1.y += aResults[1].z;
    SHCoefficent1.z += aResults[2].x;
    SHCoefficent1.w += aResults[2].y;

    SHCoefficent2.x += aResults[2].z;
    SHCoefficent2.y += aResults[3].x;
    SHCoefficent2.z += aResults[3].y;
    SHCoefficent2.w += aResults[3].z;

    irradianceCache[iCacheEntryIndex].mSphericalHarmonics0 = SHCoefficent0;
    irradianceCache[iCacheEntryIndex].mSphericalHarmonics1 = SHCoefficent1;
    irradianceCache[iCacheEntryIndex].mSphericalHarmonics2 = SHCoefficent2;

    irradianceCache[iCacheEntryIndex].mSampleCount.x += 1.0f;

    let kfMaxCount: f32 = 30.0f;
    if(irradianceCache[iCacheEntryIndex].mSampleCount.x > kfMaxCount)
    {
        let fPct: f32 = kfMaxCount / irradianceCache[iCacheEntryIndex].mSampleCount.x;
        irradianceCache[iCacheEntryIndex].mSphericalHarmonics0 *= fPct;
        irradianceCache[iCacheEntryIndex].mSphericalHarmonics1 *= fPct;
        irradianceCache[iCacheEntryIndex].mSphericalHarmonics2 *= fPct;

        irradianceCache[iCacheEntryIndex].mSampleCount.x = kfMaxCount;
    }
}

/*
**
*/
fn decodeFromSphericalHarmonicCoefficients(
    direction: vec3<f32>,
    iCacheEntryIndex: u32
) -> vec3<f32>
{
    let SHCoefficent0: vec4<f32> = irradianceCache[iCacheEntryIndex].mSphericalHarmonics0;
    let SHCoefficent1: vec4<f32> = irradianceCache[iCacheEntryIndex].mSphericalHarmonics1;
    let SHCoefficent2: vec4<f32> = irradianceCache[iCacheEntryIndex].mSphericalHarmonics2;

    var aTotalCoefficients: array<vec3<f32>, 4>;
    let fFactor: f32 = 1.0f / max(irradianceCache[iCacheEntryIndex].mSampleCount.x, 1.0f);

    aTotalCoefficients[0] = vec3<f32>(SHCoefficent0.x, SHCoefficent0.y, SHCoefficent0.z) * fFactor;
    aTotalCoefficients[1] = vec3<f32>(SHCoefficent0.w, SHCoefficent1.x, SHCoefficent1.y) * fFactor;
    aTotalCoefficients[2] = vec3<f32>(SHCoefficent1.z, SHCoefficent1.w, SHCoefficent2.x) * fFactor;
    aTotalCoefficients[3] = vec3<f32>(SHCoefficent2.y, SHCoefficent2.z, SHCoefficent2.w) * fFactor;

    let fC1: f32 = 0.42904276540489171563379376569857f;
    let fC2: f32 = 0.51166335397324424423977581244463f;
    let fC3: f32 = 0.24770795610037568833406429782001f;
    let fC4: f32 = 0.88622692545275801364908374167057f;

    let decoded: vec3<f32> =
        aTotalCoefficients[0] * fC4 +
        (aTotalCoefficients[3] * direction.x + aTotalCoefficients[1] * direction.y + aTotalCoefficients[2] * direction.z) *
            fC2 * 2.0f;

    return decoded;
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
    ray.mOrigin = vec4<f32>(worldPosition + normal * 0.05f, 1.0f);
    ray.mDirection = vec4<f32>(rayDirection, 1.0f);
    ray.mfT = vec4<f32>(FLT_MAX, FLT_MAX, FLT_MAX, FLT_MAX);

    return ray;
}

/*
**
*/
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

/*
**
*/
fn decodeOctahedronMap(uv: vec2<f32>) -> vec3<f32>
{
    let newUV: vec2<f32> = uv * 2.0f - vec2<f32>(1.0f, 1.0f);

    let absUV: vec2<f32> = vec2<f32>(abs(newUV.x), abs(newUV.y));
    var v: vec3<f32> = vec3<f32>(newUV.x, newUV.y, 1.0f - (absUV.x + absUV.y));

    if(absUV.x + absUV.y > 1.0f) 
    {
        v.x = (abs(newUV.y) - 1.0f) * -sign(newUV.x);
        v.y = (abs(newUV.x) - 1.0f) * -sign(newUV.y);
    }

    v.y *= -1.0f;

    return v;
}

