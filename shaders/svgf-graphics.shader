const FLT_MAX: f32 = 1000000.0f;
const NUM_HISTORY: f32 = 60.0f;

struct UniformData
{
    mData: vec4<f32>,
}

struct SVGFFilterResult
{
    mRadiance: vec3<f32>,
    mMoments: vec3<f32>,
};

struct DefaultdefaultUniformBuffer
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
var radianceTexture: texture_2d<f32>;

@group(1) @binding(0) 
var momentTexture: texture_2d<f32>;

@group(1) @binding(1)
var<uniform> uniformBuffer: UniformData;

@group(1) @binding(2) 
var<uniform> defaultUniformBuffer: DefaultdefaultUniformBuffer;

@group(1) @binding(3) 
var textureSampler: sampler;

struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};

struct FragmentOutput 
{
    @location(0) mRadiance : vec4<f32>,
    @location(1) mMoments : vec4<f32>,
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
    var out: FragmentOutput;

    let textureSize: vec2<u32> = textureDimensions(radianceTexture);
    let fOneOverWidth: f32 = 1.0f / f32(textureSize.x);
    let fOneOverHeight: f32 = 1.0f / f32(textureSize.y);

    let uv: vec2<f32> = vec2<f32>(
        in.uv.x,
        in.uv.y
    );

    let screenCoord: vec2<i32> = vec2<i32>(
        i32(in.uv.x * f32(textureSize.x)),
        i32(in.uv.y * f32(textureSize.y))
    );

    let iStep: i32 = i32(uniformBuffer.mData.x);

    let svgfFilterResult: SVGFFilterResult = svgFilter(
        screenCoord.x,
        screenCoord.y,
        iStep,
        10.0f,
        0.001f);

    out.mRadiance = vec4<f32>(svgfFilterResult.mRadiance, 1.0f);
    out.mMoments = vec4<f32>(svgfFilterResult.mMoments.xyz, 1.0f);

    return out;
}

/*
**
*/
fn svgFilter(
    iX: i32,
    iY: i32,
    iStep: i32,
    fLuminancePhi: f32,
    fEpsilon: f32) -> SVGFFilterResult
{
    var ret: SVGFFilterResult;

    var retRadiance: vec3<f32> = vec3<f32>(0.0f, 0.0f, 0.0f);
    var fRetVariance: f32 = 0.0f;

    // 5x5 A-Trous kernel
    var afKernel: array<f32, 25> = array<f32, 25>
    (
        1.0f / 256.0f, 1.0f / 64.0f, 3.0f / 128.0f, 1.0f / 64.0f, 1.0f / 256.0f,
        1.0f / 64.0f, 1.0f / 16.0f, 3.0f / 32.0f, 1.0f / 16.0f, 1.0f / 64.0f,
        3.0f / 128.0f, 3.0f / 32.0f, 9.0f / 64.0f, 3.0f / 32.0f, 3.0f / 128.0f,
        1.0f / 64.0f, 1.0f / 16.0f, 3.0f / 32.0f, 1.0f / 16.0f, 1.0f / 64.0f,
        1.0f / 256.0f, 1.0f / 64.0f, 3.0f / 128.0f, 1.0f / 64.0f, 1.0f / 256.0f
    );

    let kfNormalPower: f32 = 128.0f;
    let kfDepthPhi: f32 = 1.0e-2f;

    let imageUV: vec2<f32> = vec2<f32>(
        f32(iX) / f32(defaultUniformBuffer.miScreenWidth), 
        f32(iY) / f32(defaultUniformBuffer.miScreenHeight)
    );
    
    let imageCoord: vec2<u32> = vec2<u32>(u32(iX), u32(iY));

    let worldPosition: vec4<f32> = textureLoad(
        worldPositionTexture,
        imageCoord,
        0
    );
    if(worldPosition.w == 0.0f)
    {
        return ret;
    }

    let normal: vec4<f32> = textureLoad(
        normalTexture,
        imageCoord,
        0
    );

    var fDepth: f32 = fract(worldPosition.w);

    var radiance: vec4<f32> = textureLoad(
        radianceTexture,
        imageCoord,
        0
    );
    let fLuminance: f32 = computeLuminance(radiance.xyz);

    var totalRadiance: vec3<f32> = vec3<f32>(0.0f, 0.0f, 0.0f);
    var fTotalWeight: f32 = 0.0f;
    var fTotalSquaredWeight: f32 = 0.0f;
    var fTotalWeightedVariance: f32 = 0.0f;
    let iStepSize: u32 = 1u << u32(iStep);

    var totalMoments: vec3<f32> = vec3<f32>(0.0f, 0.0f, 0.0f);

    for(var iStepY: i32 = -2; iStepY <= 2; iStepY++)
    {
        var iOffsetY: i32 = iStepY * i32(iStepSize);
        var iSampleY: i32 = iY + iOffsetY;
        if(iSampleY < 0 || iSampleY >= i32(defaultUniformBuffer.miScreenHeight))
        {
            continue;
        }

        var iCount: i32 = 0;
        for(var iStepX: i32 = -2; iStepX <= 2; iStepX++)
        {
            var iOffsetX: i32 = iStepX * i32(iStepSize);
            var iSampleX: i32 = iX + iOffsetX;
            if(iSampleX < 0 || iSampleX >= i32(defaultUniformBuffer.miScreenWidth))
            {
                continue;
            }

            let sampleImageCoord: vec2<u32> = vec2<u32>(u32(iSampleX), u32(iSampleY));
            var sampleRadiance: vec4<f32> = textureLoad(
                radianceTexture,
                sampleImageCoord,
                0
            );
            let sampleWorldPosition: vec4<f32> = textureLoad(
                worldPositionTexture,
                sampleImageCoord,
                0
            );
            let sampleNormal: vec4<f32> = textureLoad(
                normalTexture,
                sampleImageCoord,
                0
            );

            let moment: vec4<f32> = textureLoad(
                momentTexture,
                sampleImageCoord,
                0
            );

            let fSampleVariance: f32 = abs(moment.y - moment.x * moment.x);
            let fSampleLuminance: f32 = computeLuminance(sampleRadiance.xyz);

            if(sampleWorldPosition.w == 0.0f)
            {
                continue;
            }

            var fSampleDepth: f32 = fract(sampleWorldPosition.w); 

            let fSampleNormalWeight: f32 = computeSVGFNormalStoppingWeight(
                sampleNormal.xyz,
                normal.xyz,
                kfNormalPower);
            let fSampleDepthWeight: f32 = computeSVGFDepthStoppingWeight(
                fDepth,
                fSampleDepth,
                kfDepthPhi);
            
            let fRetTotalVariance: f32 = 0.0f;
            var fSampleLuminanceWeight: f32 = 1.0f; 
            if(uniformBuffer.mData.y > 0.0f)
            { 
                fSampleLuminanceWeight = computeSVGFLuminanceStoppingWeight(
                    fSampleLuminance,
                    fLuminance,
                    iX,
                    iY,
                    fLuminancePhi,
                    fEpsilon);
            }

            let fSampleWeight: f32 = fSampleNormalWeight * fSampleDepthWeight * fSampleLuminanceWeight;

            let fKernel: f32 = afKernel[iCount];
            iCount += 1;
            let fKernelWeight: f32 = fKernel * fSampleWeight;

            totalRadiance += sampleRadiance.xyz * fKernelWeight;
            fTotalWeight += fKernelWeight;
            fTotalSquaredWeight += fKernelWeight * fKernelWeight;

            fTotalWeightedVariance += fKernelWeight * fSampleVariance;

            totalMoments += moment.xyz * fKernelWeight;
        }
    }

    retRadiance = totalRadiance / (fTotalWeight + 0.0001f);
    fRetVariance = fTotalWeightedVariance / (fTotalSquaredWeight + 0.0001f);

    ret.mRadiance = retRadiance;
    ret.mMoments = totalMoments / (fTotalWeight + 1.0e-4f);

    return ret;
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
fn computeSVGFNormalStoppingWeight(
    sampleNormal: vec3<f32>,
    normal: vec3<f32>,
    fPower: f32) -> f32
{
    let fDP: f32 = clamp(dot(normal, sampleNormal), 0.0f, 1.0f);
    return pow(fDP, fPower);
};

/*
**
*/
fn computeSVGFDepthStoppingWeight(
    fSampleDepth: f32,
    fDepth: f32,
    fPhi: f32) -> f32
{
    let kfEpsilon: f32 = 0.001f;
    return exp(-abs(fDepth - fSampleDepth) / (fPhi + kfEpsilon));
}

/*
**
*/
fn computeSVGFLuminanceStoppingWeight(
    fSampleLuminance: f32,
    fLuminance: f32,
    iX: i32,
    iY: i32,
    fPower: f32,
    fEpsilon: f32) -> f32
{
    let fOneOverSixteen: f32 = 1.0f / 16.0f;
    let fOneOverEight: f32 = 1.0f / 8.0f;
    let fOneOverFour: f32 = 1.0f / 4.0f;
    var afKernel: array<f32, 9> = array<f32, 9>(
        fOneOverSixteen, fOneOverEight, fOneOverSixteen,
        fOneOverEight, fOneOverFour, fOneOverEight,
        fOneOverSixteen, fOneOverEight, fOneOverSixteen,
    );

    // gaussian blur for variance
    var fLuminanceDiff: f32 = abs(fLuminance - fSampleLuminance);
    var fTotalVariance: f32 = 0.0f;
    var fTotalKernel: f32 = 0.0f;
    for(var iOffsetY: i32 = -1; iOffsetY <= 1; iOffsetY++)
    {
        var iSampleY: i32 = iY + iOffsetY;
        if(iSampleY < 0 && iSampleY >= i32(defaultUniformBuffer.miScreenHeight))
        {
            continue;
        }
        for(var iOffsetX: i32 = -1; iOffsetX <= 1; iOffsetX++)
        {
            var iSampleX: i32 = iX + iOffsetX;
            if(iSampleX < 0 && iSampleY >= i32(defaultUniformBuffer.miScreenWidth))
            {
                continue;
            }

            let sampleImageCoord: vec2<u32> = vec2<u32>(u32(iSampleX), u32(iSampleY));
            let moment: vec4<f32> = textureLoad(
                momentTexture,
                sampleImageCoord,
                0);

            let iIndex: i32 = (iOffsetY + 1) * 3 + (iOffsetX + 1);
            fTotalVariance += afKernel[iIndex] * abs(moment.y - moment.x * moment.x);
            fTotalKernel += afKernel[iIndex];
        }
    }

    let fRet: f32 = exp(-fLuminanceDiff / (sqrt(fTotalVariance / fTotalKernel) * fPower + fEpsilon));
    return fRet;
}