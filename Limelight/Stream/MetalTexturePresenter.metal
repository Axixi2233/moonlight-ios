#include <metal_stdlib>

using namespace metal;

struct TexturePresenterVertexIn {
    float2 position;
    float2 texCoord;
};

struct TexturePresenterVertexOut {
    float4 position [[position]];
    float2 texCoord;
};

struct TexturePresenterUniforms {
    float2 texelSize;
    float sharpenAmount;
    float padding;
};

vertex TexturePresenterVertexOut metalTexturePresenterVertex(uint vertexID [[vertex_id]],
                                                             constant TexturePresenterVertexIn *vertices [[buffer(0)]]) {
    TexturePresenterVertexOut out;
    out.position = float4(vertices[vertexID].position, 0.0, 1.0);
    out.texCoord = vertices[vertexID].texCoord;
    return out;
}

fragment float4 metalTexturePresenterFragment(TexturePresenterVertexOut in [[stage_in]],
                                              texture2d<float> colorTexture [[texture(0)]],
                                              sampler colorSampler [[sampler(0)]],
                                              constant TexturePresenterUniforms& uniforms [[buffer(0)]]) {
    float2 uv = in.texCoord;
    float4 centerSample = colorTexture.sample(colorSampler, uv);
    if (uniforms.sharpenAmount <= 0.0001) {
        return centerSample;
    }

    float2 dx = float2(uniforms.texelSize.x, 0.0);
    float2 dy = float2(0.0, uniforms.texelSize.y);

    float3 north = colorTexture.sample(colorSampler, uv - dy).rgb;
    float3 south = colorTexture.sample(colorSampler, uv + dy).rgb;
    float3 west = colorTexture.sample(colorSampler, uv - dx).rgb;
    float3 east = colorTexture.sample(colorSampler, uv + dx).rgb;

    float3 center = centerSample.rgb;
    float3 blur = (north + south + west + east) * 0.25;
    float3 detail = center - blur;
    float edgeStrength = smoothstep(0.01, 0.08, length(detail));
    float amount = uniforms.sharpenAmount * edgeStrength;

    return float4(center + detail * amount, centerSample.a);
}
