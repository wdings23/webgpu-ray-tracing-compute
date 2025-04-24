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
var radianceTexture: texture_2d<f32>;

@group(0) @binding(1)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(2)
var normalTexture: texture_2d<f32>;

@group(0) @binding(3)
var texCoordTexture: texture_2d<f32>;

@group(0) @binding(4)
var prevWorldPositionTexture: texture_2d<f32>;

@group(0) @binding(5)
var prevNormalTexture: texture_2d<f32>;

@group(0) @binding(6)
var hitPositionTexture: texture_2d<f32>;

@group(0) @binding(7)
var sampleRayDirectionTexture: texture_2d<f32>;

@group(0) @binding(8)
var prevSphericalHarmonicCoefficientTexture0: texture_2d<f32>;

@group(0) @binding(9)
var prevSphericalHarmonicCoefficientTexture1: texture_2d<f32>;

@group(0) @binding(10)
var prevSphericalHarmonicCoefficientTexture2: texture_2d<f32>;

@group(0) @binding(11)
var prevSphericalHarmonicsRadianceTexture: texture_2d<f32>;

@group(0) @binding(12)
var motionVectorTexture: texture_2d<f32>;

@group(0) @binding(13)
var prevMotionVectorTexture: texture_2d<f32>;

@group(1) @binding(0)
var sampleRadianceTexture: texture_2d<f32>;

@group(1) @binding(1)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(2)
var textureSampler: sampler;

struct SHOutput 
{
    mCoefficients0: vec4<f32>,
    mCoefficients1: vec4<f32>,
    mCoefficients2: vec4<f32>
};

struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f
};

struct FragmentOutput 
{
    @location(0) sphericalHarmonics0: vec4<f32>,
    @location(1) sphericalHarmonics1: vec4<f32>,
    @location(2) sphericalHarmonics2: vec4<f32>,
    @location(3) inverseSphericalHarmonics: vec4<f32>
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

    let radiance: vec4<f32> = textureSample(
        radianceTexture,
        textureSampler,
        in.uv
    );
    let hitPosition: vec4<f32> = textureSample(
        hitPositionTexture,
        textureSampler,
        in.uv
    );
    let rayDirection = normalize(hitPosition.xyz - worldPosition.xyz);

    let sampleRadiance: vec4<f32> = textureSample(
        sampleRadianceTexture,
        textureSampler,
        in.uv
    );
    let sampleRayDirection: vec4<f32> = textureSample(
        sampleRayDirectionTexture,
        textureSampler,
        in.uv
    );

    let motionVector: vec4f = textureSample(
        motionVectorTexture,
        textureSampler,
        in.uv
    );
    var prevScreenUV: vec2<f32> = in.uv.xy - motionVector.xy;

    let screenCoord: vec2<u32> = vec2<u32>(
        u32(in.uv.x * f32(textureSize.x)),
        u32(in.uv.y * f32(textureSize.y))
    );
    let prevScreenCoord: vec2<u32> = vec2<u32>(
        u32(prevScreenUV.x * f32(textureSize.x)),
        u32(prevScreenUV.y * f32(textureSize.y))
    );

    let bDisoccluded: bool = isDisoccluded2(in.uv.xy, prevScreenUV);
    let fDisocclusion: f32 = f32(bDisoccluded == false);

    var fHistoryCount = textureLoad(
        prevSphericalHarmonicsRadianceTexture,
        prevScreenCoord,
        0).w;
    fHistoryCount *= fDisocclusion;
    fHistoryCount = max(fHistoryCount, 1.0f);

    var SHCoefficent0: vec4<f32> = textureLoad(
        prevSphericalHarmonicCoefficientTexture0,
        prevScreenCoord,
        0
    ) * fDisocclusion;
    var SHCoefficent1: vec4<f32> = textureLoad(
        prevSphericalHarmonicCoefficientTexture1,
        prevScreenCoord,
        0
    ) * fDisocclusion;
    var SHCoefficent2: vec4<f32> = textureLoad(
        prevSphericalHarmonicCoefficientTexture2,
        prevScreenCoord,
        0
    ) * fDisocclusion;

    var shOutput: SHOutput = encodeSphericalHarmonics(
        sampleRadiance.xyz,
        sampleRayDirection.xyz,
        SHCoefficent0,
        SHCoefficent1,
        SHCoefficent2
    );
    
    shOutput = encodeSphericalHarmonics(
        radiance.xyz,
        rayDirection.xyz,
        shOutput.mCoefficients0,
        shOutput.mCoefficients1,
        shOutput.mCoefficients2
    );

    let decodedSH: vec3<f32> = decodeFromSphericalHarmonicCoefficients(
        shOutput,
        normal.xyz,
        vec3<f32>(10.0f, 10.0f, 10.0f),
        fHistoryCount
    );

    output.sphericalHarmonics0 = shOutput.mCoefficients0;
    output.sphericalHarmonics1 = shOutput.mCoefficients1;
    output.sphericalHarmonics2 = shOutput.mCoefficients2;
    output.inverseSphericalHarmonics = vec4<f32>(decodedSH.xyz, fHistoryCount + 1.0f);

    return output;
}

/*
**
*/
fn encodeSphericalHarmonics(
    radiance: vec3<f32>,
    direction: vec3<f32>,
    SHCoefficent0: vec4<f32>,
    SHCoefficent1: vec4<f32>,
    SHCoefficent2: vec4<f32>
) -> SHOutput
{
    var output: SHOutput;

    output.mCoefficients0 = SHCoefficent0;
    output.mCoefficients1 = SHCoefficent1;
    output.mCoefficients2 = SHCoefficent2;

    let fDstPct: f32 = 1.0f;
    let fSrcPct: f32 = 1.0f;

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
    aResults[0] = radiance.xyz * coefficient.x * fDstPct;
    aResults[1] = radiance.xyz * coefficient.y * fDstPct;
    aResults[2] = radiance.xyz * coefficient.z * fDstPct;
    aResults[3] = radiance.xyz * coefficient.w * fDstPct;
    output.mCoefficients0.x += aResults[0].x;
    output.mCoefficients0.y += aResults[0].y;
    output.mCoefficients0.z += aResults[0].z;
    output.mCoefficients0.w += aResults[1].x;

    output.mCoefficients1.x += aResults[1].y;
    output.mCoefficients1.y += aResults[1].z;
    output.mCoefficients1.z += aResults[2].x;
    output.mCoefficients1.w += aResults[2].y;

    output.mCoefficients2.x += aResults[2].z;
    output.mCoefficients2.y += aResults[3].x;
    output.mCoefficients2.z += aResults[3].y;
    output.mCoefficients2.w += aResults[3].z;

    return output;
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

    return !((iMesh == iPrevMesh) && (fDepth == fPrevDepth));
}