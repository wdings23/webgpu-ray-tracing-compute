const PI: f32 = 3.14159f;

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
    mCameraLookAt: vec4<f32>,

    mLightRadiance: vec4<f32>,
    mLightDirection: vec4<f32>,
};

@group(0) @binding(0)
var worldPositionNoBackFaceTexture: texture_2d<f32>;

@group(0) @binding(1)
var worldPositionWithBackFaceTexture: texture_2d<f32>;

@group(0) @binding(2)
var crossSectionTexture: texture_2d<f32>;

@group(1) @binding(0)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(1)
var textureSampler: sampler;

struct VertexOutput 
{
    @builtin(position) pos: vec4f,
    @location(0) uv: vec2f,
};

struct FragmentOutput 
{
    @location(0) mOutput : vec4<f32>,
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

    let screenCoord: vec2i = vec2i(
        i32(f32(defaultUniformBuffer.miScreenWidth) * in.uv.x),
        i32(f32(defaultUniformBuffer.miScreenHeight) * in.uv.y) 
    );
    let worldPositionNoBackFace: vec4f = textureLoad(
        worldPositionNoBackFaceTexture,
        screenCoord,
        0
    );
    let worldPositionWithBackFace: vec4f = textureLoad(
        worldPositionWithBackFaceTexture,
        screenCoord,
        0
    );
    let crossSection: vec4f = textureLoad(
        crossSectionTexture,
        screenCoord,
        0
    );
    out.mOutput = crossSection;

    let diff: vec3f = worldPositionNoBackFace.xyz - worldPositionWithBackFace.xyz;
    if(dot(diff, diff) >= 1.0e-10f)
    {
        out.mOutput = vec4f(0.0f, 0.0f, 0.0f, 0.0f);
    }

    return out;
}

