
struct UniformData
{
    mInverseProjectionMatrix: mat4x4<f32>,
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
var directRadianceTexture: texture_2d<f32>;

@group(0) @binding(1)
var diffuseRadianceTexture: texture_2d<f32>;

@group(0) @binding(2)
var emissiveRadianceTexture: texture_2d<f32>;

@group(0) @binding(3)
var rayDirectionTexture: texture_2d<f32>;

@group(0) @binding(4)
var materialTexture: texture_2d<f32>;

@group(0) @binding(5)
var worldPositionTexture: texture_2d<f32>;

@group(0) @binding(6)
var skyTexture: texture_2d<f32>;

@group(1) @binding(0)
var<uniform> uniformBuffer: UniformData;

@group(1) @binding(1)
var<uniform> defaultUniformBuffer: DefaultUniformData;

@group(1) @binding(2)
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

    let emissiveRadiance: vec4<f32> = textureSample(
        emissiveRadianceTexture,
        textureSampler,
        in.uv.xy
    );

    let material: vec4<f32> = textureSample(
        materialTexture,
        textureSampler,
        in.uv.xy
    );

    output.mRadiance = vec4<f32>(
        material.xyz * ((directRadiance.xyz + diffuseRadiance.xyz + emissiveRadiance.xyz) * rayDirection.w), 
        1.0f
    );

    let worldScreenCoord: vec2<u32> = vec2<u32>(
        u32(in.uv.x * f32(defaultUniformBuffer.miScreenWidth)),
        u32(in.uv.y * f32(defaultUniformBuffer.miScreenHeight))
    );
    let worldPosition: vec4<f32> = textureLoad(
        worldPositionTexture,
        worldScreenCoord,
        0
    );
    if(worldPosition.w <= 0.0f)
    {
        var direction: vec4<f32> = vec4<f32>(in.uv.x, 1.0f - in.uv.y, 1.0f, 1.0f) * uniformBuffer.mInverseProjectionMatrix;
        var fOneOverW: f32 = 1.0f / direction.w;
        direction.x *= fOneOverW;
        direction.y *= fOneOverW;
        direction.z *= fOneOverW;

        let skyTextureSize: vec2<u32> = textureDimensions(skyTexture); 
        let uv: vec2<f32> = octahedronMap2(direction.xyz);
        let screenCoord: vec2<u32> = vec2<u32>(
            u32(uv.x * f32(skyTextureSize.x)),
            u32(uv.y * f32(skyTextureSize.y)) 
        );
        var sky: vec4<f32> = textureLoad(
            skyTexture,
            screenCoord,
            0
        );
        output.mRadiance = vec4<f32>(sky.xyz / 50.0f, 1.0f);
    }

    return output;
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