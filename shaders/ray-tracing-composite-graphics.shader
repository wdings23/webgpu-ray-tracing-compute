

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
var directRadianceTexture: texture_2d<f32>;

@group(0) @binding(1)
var diffuseRadianceTexture: texture_2d<f32>;

@group(0) @binding(2)
var rayDirectionTexture: texture_2d<f32>;

@group(0) @binding(3)
var materialTexture: texture_2d<f32>;

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

    let rayDirection: vec4<f32> = textureSample(
        rayDirectionTexture,
        textureSampler,
        in.uv.xy
    );

    let directRadiance: vec4<f32> = textureSample(
        directRadianceTexture,
        textureSampler,
        in.uv.xy
    );

    let diffuseRadiance: vec4<f32> = textureSample(
        diffuseRadianceTexture,
        textureSampler,
        in.uv.xy
    );

    let material: vec4<f32> = textureSample(
        materialTexture,
        textureSampler,
        in.uv.xy
    );

    output.mRadiance = vec4<f32>(
        material.xyz * ((directRadiance.xyz + diffuseRadiance.xyz) * rayDirection.w), 
        1.0f
    );
    return output;
}

