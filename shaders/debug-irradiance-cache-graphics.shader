
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
var<storage, read> irradianceCache: array<IrradianceCacheEntry>;

@group(0) @binding(1)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(2)
var normalTexture: texture_2d<f32>;

@group(1) @binding(0)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(1)
var textureSampler: sampler;

struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f
};

struct FragmentOutput 
{
    @location(0) mRadiance: vec4<f32>
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

    let iHitIrradianceCacheIndex: u32 = fetchIrradianceCacheIndex(worldPosition.xyz);
    let ret: vec3<f32> = getRadianceFromIrradianceCacheProbe(
        normal.xyz,
        iHitIrradianceCacheIndex
    );
    
    output.mRadiance = vec4<f32>(ret.xyz, f32(iHitIrradianceCacheIndex));
    return output;
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