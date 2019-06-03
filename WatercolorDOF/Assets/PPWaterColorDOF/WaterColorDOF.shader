Shader "Drahsid/Watercolor DOF"
{
    Properties
    {
        _MainTex("Texture", 2D) = "white" {}
		[Toggle] displayCoC("Display CoC", Range(0, 1)) = 0
		samples("Iterations", Range(0.1, 4)) = 0.1
    }

    CGINCLUDE
        #include "UnityCG.cginc"
		#pragma target 5.0

        sampler2D _MainTex, _CameraDepthTexture, _WaterColorTex;
        float4 _MainTex_ST, _MainTex_TexelSize;
		float _FocusDistance, _FocusRange, _MaxBlur;
 
        struct v2f {
            float4 vertex : SV_POSITION;
            float2 uv : TEXCOORD0;
		};

        v2f vert(appdata_base v) {
            v2f o;
            o.vertex = UnityObjectToClipPos(v.vertex);
            o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
            return o;
        };

		float cocCalc(v2f i) {
			float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, i.uv));
			float coc = (depth - _FocusDistance) * _FocusRange / max(depth, 1e-5);
			return saturate(coc * 0.5 * _MaxBlur + 0.5);
		}

    ENDCG

    SubShader
    {
        ZTest Always ZWrite Off

		Pass //Water Color Blur
		{
		CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			int samples;

			float2 p;
			float3 color2;
			float sig2;
			static const float4x4 ditherTable = float4x4
			(
				-4.0, 0.0, -3.0, 1.0,
				2.0, -2.0, 3.0, -1.0,
				-3.0, 1.0, -4.0, 0.0,
				3.0, -1.0, 2.0, -2.0
			);

			float4 frag(v2f i) : SV_Target 
			{
				float ditherCoef = 0.1;
				float hfr = _FocusRange * 0.5;
				float div = pow(samples + 1, 2);
				float min = 1;	

				float2 uv = i.uv;
				float4 color = tex2D(_MainTex, uv);
				
				float idepth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));
				
				float depth = idepth;
				depth = clamp(cocCalc(i), 0, _MaxBlur);

				float3 f30 = float3(0, 0, 0);
				float3 mean[17] = { f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30 };
				float3 sig[17] = { f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30, f30 };
				float2 offset[17] = {
					{0, 0},
					{-depth, -depth},
					{-depth, 0},
					{0, -depth},
					{depth, depth},
					{depth, 0},
					{0, depth},
					{depth, -depth},
					{-depth, depth},
					{-samples, -samples},
					{-samples, 0},
					{0, -samples},
					{samples, samples},
					{samples, 0},
					{0, samples},
					{samples, -samples},
					{-samples, samples},
				};

				for (int listIndex = 0; listIndex < 17; listIndex++)
				{
					for (int sx = 0; sx <= samples; sx++) 
					{
						for (int sy = 0; sy <= samples; sy++) 
						{
							p = float2(sx, sy) + offset[listIndex];
							color2 = tex2Dlod(_MainTex, float4(uv + float2(p.x * _MainTex_TexelSize.x, p.y * _MainTex_TexelSize.y), 0, 0)).rgb;
							mean[listIndex] += color2;
							sig[listIndex] = (sig[listIndex] + (color2 * color2)) / depth;
						}
					}
				}

				for (int listIndex = 0; listIndex < 17; listIndex++)
				{
					mean[listIndex] /= div;
					sig[listIndex] = abs( (sig[listIndex] / div) - (mean[listIndex] * mean[listIndex]) );
					sig2 = sig[listIndex].r + sig[listIndex].g + sig[listIndex].b;

					// Update min and set to mean
					if (sig2 < min) 
					{
						min = sig2;
						color.rgb = mean[listIndex].rgb;
					}
				}

				// Don't dither extremely far off objects, such as the skybox
				if (idepth > 50000) {
					return color;
				}

				depth = clamp(cocCalc(i), -1, 1);	
				ditherCoef = clamp(smoothstep(ditherCoef, depth, 0.16), 0, 0.03);

				uint2 pixelCoord = uv * _ScreenParams.xy;
				color += ditherTable[pixelCoord.x % 4][pixelCoord.y % 4] * ditherCoef;

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

				float hfr = _FocusRange * 0.5;
				float depth = LinearEyeDepth(SAMPLE_DEPTH_TEXTURE(_CameraDepthTexture, uv));

				float coc = clamp((depth - _FocusDistance + hfr) / _FocusRange, -1, 1);
				
				if (displayCoC == 1) {
					return float4(coc, coc, coc, color.a);
				}

				return lerp(color, watercolor, coc);
			}
		ENDCG
		}
    }
}



