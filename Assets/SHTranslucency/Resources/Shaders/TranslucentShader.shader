Shader "Translucency/TranslucentShader"
{
	Properties
	{
		//TRANSLUCENCY
		_Absorption("Absorption", Color) = (1,1,1,1)
		_ThicknessPower("Thickness Power", Float) = 1
		
		//REFRACTION
		_Refraction("Index of Refraction", Range(1, 1.2)) = 1
		_RefractionRoughness("Refraction Roughness", Range(0, 10)) = 0
		
		//POINT LIGHT
		_PointLightHardness("Point Light Hardness", Float) = 1
		_PointLightIntensity("Point Light Intensity", Float) = 1
		
		//GGX SPECULAR
		_Roughness("Roughness", Range(0, 1)) = 0
		_Metalness("Metalness", Range(0, 1)) = 0.04
		_Envmap("Envmap", Cube) = "white" {}
		_BRDF("BRDF", 2D) = "white" {}
	}
	SubShader
	{
		Tags{ "RenderType" = "Opaque" "LightMode" = "ForwardBase" }
		LOD 100

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			
			#include "UnityCG.cginc"
			#include "SH_Utils.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
				float2 uv2 : TEXCOORD1;
				float2 uv3 : TEXCOORD2;
				float2 uv4 : TEXCOORD3;
				float4 color : COLOR;
				float3 normal : NORMAL;
			};

			struct v2f
			{
				float4 vertex : SV_POSITION;
				float2 uv : TEXCOORD0;
				float4 sh_0 : TEXCOORD1;
				float4 sh_1 : TEXCOORD2;
				float4 world_position : TEXCOORD3; //w is for the last sh coefficient
				float3 normal : TEXCOORD4;
			};

			float4 _Absorption;
			float _ThicknessPower;

			float _Refraction;
			float _RefractionRoughness;

			float _PointLightHardness;
			float _PointLightIntensity;

			float _Roughness;
			float _Metalness;
			samplerCUBE _Envmap;
			sampler2D _BRDF;

			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;
				o.sh_0 = v.color;
				o.sh_1 = float4(v.uv2.xy, v.uv3.xy);
				o.world_position = mul(unity_ObjectToWorld, v.vertex);
				o.world_position.w = v.uv4.x;
				o.normal = UnityObjectToWorldNormal(v.normal);
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				//some vectors
				float3 V = normalize(i.world_position.xyz - _WorldSpaceCameraPos.xyz);
				float3 N = normalize(i.normal);
				float3 R = refract(V, N, 1.0 / _Refraction);
				float3 r = reflect(V, N);

				//transmitted environment
				float4 env = texCUBElod(_Envmap, float4(R, _RefractionRoughness));

				//indirect specular
				float NdotV = saturate(dot(N, -V));
				float2 brdfUV = float2(NdotV, _Roughness);
				float2 preBRDF = tex2D(_BRDF, brdfUV).xy;
				float4 indirectSpecular = texCUBElod(_Envmap, float4(r, _Roughness * 5)) * (_Metalness * preBRDF.x + preBRDF.y);

				//point lights
				float3 light_position = float3(unity_4LightPosX0.x, unity_4LightPosY0.x, unity_4LightPosZ0.x);
				float3 L = normalize(light_position - i.world_position.xyz);
				float point_light = pow(saturate(dot(V, L)), _PointLightHardness) * _PointLightIntensity;

				//translucency
				float4 sh0 = float4(Y0(V), Y1(V), Y2(V), Y3(V));
				float4 sh1 = float4(Y4(V), Y5(V), Y6(V), Y7(V));
				float thickness = max(0, dot(sh0, i.sh_0) + dot(sh1, i.sh_1) + Y8(V) * i.world_position.w);
				float4 absorption = exp(-pow(thickness, _ThicknessPower) * _Absorption.a * 20) * _Absorption;

				return absorption * (env/* + point_light*/) + indirectSpecular;
			}
			ENDCG
		}
	}
}
