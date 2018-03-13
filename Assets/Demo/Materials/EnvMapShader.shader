Shader "PBR/EnvMapShader"
{
	Properties
	{
		_EnvMap ("Texture", Cube) = "white" {}
		_LodLevel("Lod Level", Int) = 0
	}
	SubShader
	{
		Tags { "Queue"="Background" }
		LOD 100

		Pass
		{
			ZWrite Off
			Cull Off

			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float3 uv : TEXCOORD0;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float3 uv : TEXCOORD0;
			};

			samplerCUBE _EnvMap;
			int _LodLevel;
			
			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return texCUBElod(_EnvMap, float4(i.uv, _LodLevel));
			}
			ENDCG
		}
	}
}
