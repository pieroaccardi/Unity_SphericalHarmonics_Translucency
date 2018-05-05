using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEditor;

public class ThicknessCompute : EditorWindow
{
    //PUBLIC FIELDS
    public MeshFilter to_compute;

    //PRIVATE FIELDS
    private SerializedObject so;
    private SerializedProperty sp_to_compute;

    [MenuItem("Window/ThicknessCompute")]
    public static void ShowWindow()
    {
        ThicknessCompute window = (ThicknessCompute)EditorWindow.GetWindow(typeof(ThicknessCompute));
        window.Show();
    }

    private void OnFocus()
    {
        Initialize();
    }

    private void OnEnable()
    {
        Initialize();
    }

    private void Initialize()
    {
        if (so == null)
        {
            so = new SerializedObject(this);
            sp_to_compute = so.FindProperty("to_compute");
        }
    }

    private void OnGUI()
    {
        EditorGUILayout.PropertyField(sp_to_compute);
        so.ApplyModifiedProperties();
        EditorGUILayout.Space();
        
        if (to_compute != null && GUILayout.Button("Compute Thickness"))
        {
            //create the folder with saved mesh assets
            if (!AssetDatabase.IsValidFolder("Assets/TranslucentMeshes"))
            {
                AssetDatabase.CreateFolder("Assets", "TranslucentMeshes");
            }
            
            GameObject tmp_camera_object = new GameObject("tmp_camera");
            Camera tmp_camera = tmp_camera_object.AddComponent<Camera>();
            tmp_camera.clearFlags = CameraClearFlags.Color;
            tmp_camera.backgroundColor = Color.black;
            tmp_camera.nearClipPlane = 0.01f;
            tmp_camera.farClipPlane = 300;

            GameObject clone = Instantiate(to_compute.gameObject);
            Mesh mesh = Instantiate(to_compute.sharedMesh);
            Vector3[] vertices = mesh.vertices;
            Vector3[] normals = mesh.normals;
            Vector2[] uv2 = new Vector2[mesh.vertexCount];
            Vector2[] uv3 = new Vector2[mesh.vertexCount];
            Vector2[] uv4 = new Vector2[mesh.vertexCount];
            Color[] colors = new Color[mesh.vertexCount];

            //temporary storage for the sh coefficients
            Vector4[] coefficients = new Vector4[9];

            //64x64 cubemap should be enough
            Cubemap thickness_cubemap = new Cubemap(128, TextureFormat.RGBA32, false); //TODO: usare formato float

            for (int v = 0; v < mesh.vertexCount; ++v)
            {
                //vertices in the mesh are in local space, transform to world coordinate
                Vector3 vertex_world_position = vertices[v];// clone.transform.localToWorldMatrix.MultiplyPoint(vertices[v]); //TODO: al posto di lavorare in world space, lavorare in local
                Vector3 world_normal = normals[v];// clone.transform.localToWorldMatrix.MultiplyVector(normals[v]);
                tmp_camera.transform.position = vertex_world_position - world_normal * 0.011f;
                tmp_camera.RenderToCubemap(thickness_cubemap);

                //project the cubemap to the spherical harmonic basis
                SphericalHarmonics.GPU_Project_Uniform_9Coeff(thickness_cubemap, coefficients);

                //put 4 coefficients in the vertex color, 2 in the uv2 and 2 in the uv3 and 1 in uv4
                colors[v] = new Color(coefficients[0].x, coefficients[1].x, coefficients[2].x, coefficients[3].x);
                uv2[v] = new Vector2(coefficients[4].x, coefficients[5].x);
                uv3[v] = new Vector2(coefficients[6].x, coefficients[7].x);
                uv4[v] = new Vector2(coefficients[8].x, 0);

                for (int i = 0; i < 9; ++i)
                    coefficients[i] = Vector4.zero;
            }

            mesh.colors = colors;
            mesh.uv2 = uv2;
            mesh.uv3 = uv3;
            mesh.uv4 = uv4;
            mesh.UploadMeshData(true);

            //save the mesh
            AssetDatabase.CreateAsset(mesh, "Assets/TranslucentMeshes/" + to_compute.name + ".asset");

            clone.GetComponent<MeshFilter>().sharedMesh = mesh;

            Object.DestroyImmediate(tmp_camera_object);

            to_compute.gameObject.SetActive(false);
        }
    }
}
