#ifndef PER_OBJECT_SHADOW_SAMPLING_INCLUDED
#define PER_OBJECT_SHADOW_SAMPLING_INCLUDED

// #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

// ---------- REQUIRED UNIFORMS (must exist in the including shader) ----------
TEXTURE2D(_CharacterShadowAtlas);
SAMPLER(sampler_CharacterShadowAtlas);
float4   _CharacterShadowAtlas_TexelSize;
float4x4 _CharacterShadowMatrix[9];
float4   _CharacterUVClamp[9];
int      _CharacterShadowCount;
float4   _PerObjectShadowBias;
float4   _DepthRanges[9];
int      _Unit;
float _LightWorldSize;

// ----------------------------------------------------------------------------------
// GetShadowStoredDepth
// ----------------------------------------------------------------------------------
float GetShadowStoredDepth(float2 uv, float receiverZ, int idx)
{
    float4 uvClamp = _CharacterUVClamp[idx];

    float isInside = (uv.x >= uvClamp.x) && (uv.x <= uvClamp.y) &&
                     (uv.y >= uvClamp.z) && (uv.y <= uvClamp.w) &&
                     (receiverZ >= 0.0) && (receiverZ <= 1.0);

    float halfTexelWidth  = _CharacterShadowAtlas_TexelSize.x * 0.5;
    float halfTexelHeight = _CharacterShadowAtlas_TexelSize.y * 0.5;

    float2 clampedUV;
    clampedUV.x = clamp(uv.x, uvClamp.x + halfTexelWidth,  uvClamp.y - halfTexelWidth);
    clampedUV.y = clamp(uv.y, uvClamp.z + halfTexelHeight, uvClamp.w - halfTexelHeight);

    float rawZ = SAMPLE_TEXTURE2D(_CharacterShadowAtlas, sampler_PointClamp, clampedUV).r;

    float storedZ = rawZ;
    #if UNITY_REVERSED_Z
        storedZ = 1.0 - rawZ;
    #endif

    return lerp(receiverZ, storedZ, isInside);
}

// ----------------------------------------------------------------------------------
// SampleShadow (hard compare)
// ----------------------------------------------------------------------------------
float SampleShadow(float2 uv, float receiverZ, int idx, float depthBias)
{
    float storedZ = GetShadowStoredDepth(uv, receiverZ, idx);
    return (receiverZ <= storedZ + depthBias) ? 1.0 : 0.0;
}

// ----------------------------------------------------------------------------------
// Poisson data + helpers
// ----------------------------------------------------------------------------------
static const int POISSON_SAMPLES = 32;
static const float2 s_Poisson32[32] =
{
    float2(-0.94201624, -0.39906216),
    float2( 0.94558609, -0.76890725),
    float2(-0.09418410, -0.92938870),
    float2( 0.34495938,  0.29387760),
    float2(-0.91588581,  0.45771432),
    float2(-0.81544232, -0.87912464),
    float2(-0.38277543,  0.27676845),
    float2( 0.97484398,  0.75648379),
    float2( 0.44323325, -0.97511554),
    float2( 0.53742981, -0.47373420),
    float2(-0.26496911, -0.41893023),
    float2( 0.79197514,  0.19090188),
    float2(-0.24188840,  0.99706507),
    float2(-0.81409955,  0.91437590),
    float2( 0.19984126,  0.78641367),
    float2( 0.14383161, -0.14100790),

    float2(-0.88809884,  0.02058852),
    float2( 0.70292258, -0.09018974),
    float2(-0.55714446,  0.61322955),
    float2( 0.11109862,  0.74864245),
    float2(-0.98051202, -0.16243701),
    float2(-0.68032428, -0.29347673),
    float2( 0.28457730, -0.33090300),
    float2( 0.41060600,  0.11706176),
    float2( 0.61537490,  0.78264920),
    float2(-0.23523625,  0.45585488),
    float2(-0.32212450, -0.64219750),
    float2( 0.10082215, -0.92399920),
    float2( 0.79821920, -0.58319210),
    float2( 0.52511720,  0.06186800),
    float2(-0.51752720, -0.81912500),
    float2( 0.92315000,  0.32125000)
};

float2 Rotate2D(float2 p, float a)
{
    float s = sin(a);
    float c = cos(a);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

// ----------------------------------------------------------------------------------
// Poisson PCF (unit = radiusTexel)
// ----------------------------------------------------------------------------------
float SampleShadowPoissonPCF(float2 centerUV, float receiverZ, int idx, float depthBias, int unit)
{
    float2 texelSize = _CharacterShadowAtlas_TexelSize.xy;

    float radiusTexel = (float)unit;
    float2 radiusUV = radiusTexel * texelSize;

    const float PI2 = 6.283185307179586;
    float fi = (float)idx;
    float random = frac(sin(dot(centerUV * 173.37 + float2(fi * 13.1, fi * 7.7), float2(12.9898, 78.233))) * 43758.5453);
    float angle = random * PI2;

    float shadowSum = 0.0;

    UNITY_LOOP
    for (int i = 0; i < POISSON_SAMPLES; i++)
    {
        float2 offset = Rotate2D(s_Poisson32[i], angle) * radiusUV;
        float storedZ = GetShadowStoredDepth(centerUV + offset, receiverZ, idx);
        shadowSum += (receiverZ <= storedZ + depthBias) ? 1.0 : 0.0;
    }

    return shadowSum / (float)POISSON_SAMPLES;
}

// ----------------------------------------------------------------------------------
// 单次采样函数
// ----------------------------------------------------------------------------------
void SampleShadowSingle(float3 positionWS, int idx, float depthBias, out float vis)
{
    // --- 坐标变换 ---
    float4 rawCoord = mul(_CharacterShadowMatrix[idx], float4(positionWS, 1.0));
    float3 shadowCoord = rawCoord.xyz; 
    
    // --- 直接调用函数获取最终结果 ---
    vis = SampleShadowPoissonPCF(shadowCoord.xy, shadowCoord.z, idx, depthBias, _Unit);
}


// ----------------------------------------------------------------------------------
// 主计算函数 (循环混合)
// ----------------------------------------------------------------------------------
float ComputePerObjectShadow(float3 positionWS, float3 normalWS)
{
    // --- 准备工作: Normal Bias ---
    float globalDepthBias  = _PerObjectShadowBias.x;
    float globalNormalBias = _PerObjectShadowBias.y;
    
    // 沿法线推挤顶点，防止自阴影 artifacts
    float3 shadowPosWS = positionWS + normalWS * globalNormalBias;
    
    int count = _CharacterShadowCount;
    float finalVis = 1.0; // 默认全亮

    if (count > 0)
    {
        UNITY_LOOP // 展开循环
        for (int idx = 0; idx < 10; idx++) // 假设最大支持 10 个 (或匹配你的 maxTargets)
        {
            if (idx >= count) break;

            float vis;
            
            // 调用采样函数
            SampleShadowSingle(shadowPosWS, idx, globalDepthBias, vis);

            // --- 混合逻辑 ---
            // 直接取最小值。
            // 逻辑说明：如果当前 idx 的 ShadowMap 没覆盖到这个像素，SampleShadowSingle 会返回 1.0。
            // min(finalVis, 1.0) 还是 finalVis，结果不变。这是正确的。
            finalVis = min(finalVis, vis);
        }
    }
    
    return finalVis;
}

#endif // PER_OBJECT_SHADOW_SAMPLING_INCLUDED
