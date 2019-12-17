Shader "Drahsid/Watercolor DOF"
{
	Properties
	{
		_MainTex("Texture", 2D) = "white" {}
		[Toggle] displayCoC("Display CoC", Range(0, 1)) = 0
		[Toggle] visualizeWatercolor("Visualize Watercolor", Range(0, 1)) = 0
		[Toggle] hideWatercolor("Hide Watercolor", Range(0, 1)) = 0
		[Toggle] hideDither("Hide Dither", Range(0, 1)) = 0
		iterations("iterations", Range(1, 24)) = 1
		maxDitherDist("maxDitherDistance", Range(0, 102400)) = 50000
		minDitherDist("minDitherDistance", Range(0, 102400)) = 0
		ditherPower("ditherPower", Range(0, 1)) = 0.16
		ditherCoef("ditherCoef", Range(0, 1)) = 0.1
		maxBlur("maxBlur", Range(0, 1)) = 0.98
		focusDistance("focusDistance", Range(0, 102400)) = 6
		focusRange("focusRange", Range(0, 64)) = 11.6
	}

	CGINCLUDE
	#include "UnityCG.cginc"
	#pragma target 5.0

	sampler2D _MainTex, _CameraDepthTexture, _WaterColorTex;
	float4 _MainTex_ST, _MainTex_TexelSize;
	float focusDistance, focusRange, maxBlur, maxDitherDist, minDitherDist;
	float visualizeWatercolor, hideDither, hideWatercolor;
	float ditherPower, ditherCoef;
	int iterations;

	float2 vUv = float2(0, 0);

	struct v2f {
		float4 vertex : SV_POSITION;
		float2 uv : TEXCOORD0;
	};

	static const float3 f30 = float3(0, 0, 0);
	static const float4x4 ditherTable = float4x4
	(
		-4.0, 0.0, -3.0, 1.0,
		2.0, -2.0, 3.0, -1.0,
		-3.0, 1.0, -4.0, 0.0,
		3.0, -1.0, 2.0, -2.0
	);

	v2f vert(appdata_base v) {
		v2f o;
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
		return o;
	};

	inline float cocCalc(v2f i) {
		float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
		//float coc = (depth - focusDistance) * focusRange / max(depth, 1e-5);
		//return saturate(coc * 0.5 * maxBlur + 0.5);
		float hfr = focusRange * 0.5;
		float coc = clamp((depth - focusDistance + hfr) / focusRange, -1, 1);
		return coc;
	}

	inline float4 watercolorCalc(float4 color, float2 uv, float depth)
	{
		if (hideWatercolor) return color;
		float3 mean[9] = { f30, f30, f30, f30, f30, f30, f30, f30, f30 };
		float3 sig[9] = { f30, f30, f30, f30, f30, f30, f30, f30, f30 };
		float2 offset[9] = {
			float2(0, 0),
			float2(-depth, -depth),
			float2(-depth, 0),
			float2(0, -depth),
			float2(depth, depth),
			float2(depth, 0),
			float2(0, depth),
			float2(depth, -depth),
			float2(-depth, depth)
		};

		float2 p;
		float3 color2;
		float sig2 = 0;
		float div = pow(iterations + 1, 2);
		float min = 1;
		int listIndex = 0;

		for (listIndex = 0; listIndex < 9; listIndex++)
		{
			for (int sx = 0; sx <= iterations; sx++)
			{
				for (int sy = 0; sy <= iterations; sy++)
				{
					p = float2(sx, sy) + offset[listIndex];
					color2 = tex2Dlod(_MainTex, float4(uv + float2(p.x * _MainTex_TexelSize.x, p.y * _MainTex_TexelSize.y), 0, 0)).rgb;
					mean[listIndex] += color2;
					sig[listIndex] = (sig[listIndex] + (color2 * color2)) / depth;
				}
			}

			mean[listIndex] /= div;
			sig[listIndex] = abs((sig[listIndex] / div) - (mean[listIndex] * mean[listIndex]));
			sig2 = sig[listIndex].r + sig[listIndex].g + sig[listIndex].b;

			// Update min and set to mean
			if (sig2 < min)
			{
				min = sig2;
				if (visualizeWatercolor) color.rgb = (color.rgb * 0.5) + (mean[listIndex].rgb * -0.5);
				else color.rgb = mean[listIndex].rgb;
			}
		}

		return color;
	}

	inline float4 ditherCalc(float4 color, float2 uv, float idepth, v2f i) {
		if (hideDither) return color;
		float hfr = focusRange * 0.5;
		
		if (idepth >= maxDitherDist || idepth <= minDitherDist 
			&& idepth < (focusDistance + hfr) && idepth > (focusDistance - hfr) 
			|| hideDither) return color;

		float depth = cocCalc(i);
		ditherCoef = clamp(smoothstep(ditherCoef, depth, ditherPower), 0, 0.03);

		uint2 pixelCoord = uv * _ScreenParams.xy;
		color += ditherTable[pixelCoord.x % 4][pixelCoord.y % 4] * ditherCoef;

		return color;
	}

	ENDCG

	SubShader
	{
		ZTest Always ZWrite Off

		Pass
		{
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float4 frag(v2f i) : SV_Target
			{
				float2 uv = i.uv;
				float4 color = tex2D(_MainTex, uv);

				float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));

				float rel = depth - focusDistance + (focusRange * 0.5);
				float bdepth = clamp(rel, 0, maxBlur);

				color = watercolorCalc(color, uv, bdepth);
				color = ditherCalc(color, uv, bdepth, i);

				return color;
			}
		ENDCG
		}

		Pass //Combine
		{
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			float displayCoC;

			float4 frag(v2f i) : SV_Target
			{
				float2 uv = i.uv;
				float4 color = tex2D(_MainTex, uv);
				float4 watercolor = tex2D(_WaterColorTex, uv);

				float coc = cocCalc(i);

				if (displayCoC) return float4(color.r * coc, color.g * coc, color.b * coc, color.a);

				return lerp(color, watercolor, coc);
				//return watercolor;
			}
		ENDCG
		}
	}
}



