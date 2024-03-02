using UnityEngine;
using UnityEngine.Rendering;

/// <summary>
/// Converts the camera's (x,y,bloom) to (r,g,b).
/// </summary>
/// <remarks>
/// <para>
/// Colors in this project are unusual. Instead of working with regular
/// RGB, the first two indices represent the coordinates on a dynamic color
/// texture, while B represents bloom.
/// </para>
/// <para>
/// This class applies the conversion to regular color data.
/// </para>
/// </remarks>
[RequireComponent(typeof(Camera))]
[ExecuteInEditMode]
public class ColorConverterBehaviour : MonoBehaviour {

    new private Camera camera;
    private CommandBuffer cb;
    private ComputeBuffer updateColormapBuffer; // (Disposing is this class' responsibility)

    public Material ColorMapMaterial;
    public RenderTexture ColorMapRenderTexture;
    public ColorMap ColorMap;
    [Range(1,10)]
    public int BloomIters = 1;

    static readonly int colorMapID = Shader.PropertyToID("_color_map");
    static readonly int cameraActiveID2 = Shader.PropertyToID("_camera_active2");
    static readonly int bloomTempID = Shader.PropertyToID("_bloom_temp");
    static readonly int bloomTempID2 = Shader.PropertyToID("_bloom_temp2");

    private void Setup() {
        camera = GetComponent<Camera>();
        camera.RemoveAllCommandBuffers();
    }

    private void Awake() {
        SetupCommandBuffer();
    }

    private void Update() {
        // this could b done betterly mayhaps
#if UNITY_EDITOR
        if (Bypass)
            camera.RemoveAllCommandBuffers();
        else
#endif
            SetupCommandBuffer();
    }

    private void SetupCommandBuffer() {
        if (camera == null)
            Setup();

        camera.RemoveCommandBuffers(CameraEvent.BeforeImageEffects);

        updateColormapBuffer?.Dispose();
        cb?.Dispose();
        cb = new CommandBuffer() { name = "ColorConverter" };

        // Set the color map.
        // Bit wasteful to recalculate it every frame, but it's tiny.
        ColorMap.FillTextureGPU(cb, ColorMapRenderTexture, ColorMapMaterial, 6, out updateColormapBuffer);

        // You'd 𝘵𝘩𝘪𝘯𝘬 using Screen.[width|height] works for the game view.
        // But no, when the game's not running it instead gets the size of
        // the current editor thing in focus, i.e. the inspector.
        // Good to know, but 𝘸𝘩𝘺...
        int width = camera.pixelWidth;
        int height = camera.pixelHeight;

        // First, with the current frame as input, copy the unprocessed
        // screen into a temporary texture.
        // Also prepare a second texture for later.
        int scale = 4;
        cb.GetTemporaryRT(bloomTempID, width / scale, height / scale, depthBuffer: 0, FilterMode.Bilinear, RenderTextureFormat.Default);
        cb.GetTemporaryRT(bloomTempID2, width / scale, height / scale, depthBuffer: 0, FilterMode.Bilinear, RenderTextureFormat.Default);
        cb.Blit(camera.activeTexture, bloomTempID, ColorMapMaterial, 5); // Custom blit because the scale/offset overload doesn't work :l

        // Now, convert the current frame into proper colors.
        cb.SetGlobalTexture(colorMapID, ColorMapRenderTexture);
        cb.GetTemporaryRT(cameraActiveID2, width, height, depthBuffer: 0, FilterMode.Bilinear, RenderTextureFormat.Default);
        cb.Blit(camera.activeTexture, cameraActiveID2, ColorMapMaterial, 0);

        // Using the fact that __camera_active2 now has the correct colors,
        // turn __bloom_temp into the correct colours as well.
        cb.Blit(bloomTempID, bloomTempID2, ColorMapMaterial, 1);

        // Now do two blur passes.
        // NOTE: If you want more bloom, just do more blur.
        for (int i = 0; i < BloomIters; i++) {
            cb.Blit(bloomTempID2, bloomTempID, ColorMapMaterial, 2);
            cb.Blit(bloomTempID, bloomTempID2, ColorMapMaterial, 3);
        }

        // Merge the bloom additively with the regular result.
        // Use that bloom is in __bloom_temp2.
        cb.Blit(cameraActiveID2, camera.activeTexture, ColorMapMaterial, 4);

        // (Done!)

        camera.AddCommandBuffer(CameraEvent.BeforeImageEffects, cb);
    }

    private void OnDestroy() {
        updateColormapBuffer?.Dispose();
        cb?.Dispose();
    }

#if UNITY_EDITOR
    [Header("Editor Test Utilities")]
    public bool Refresh;
    public bool Bypass;
    public bool LiveUpdates;
    [Space(5f)]
    public bool SetRandomColorMap;
    [Range(0,32)]
    public int RandomColorMapCount;

    [Space(5f)]
    public ColorMap a;
    public ColorMap b;
    [Range(0,1)]
    public float interpolation;
    public bool InterpolateToMap;
    public bool MapToA;
    public bool MapToB;

    private void OnValidate() {
        if (SetRandomColorMap) {
            SetRandomColorMap = false;
            ColorMap.Clear();
            for (int i = 0; i < RandomColorMapCount; i++) {
                var pos = new Vector2(Random.Range(0f, 1f), Random.Range(0f,1f));
                var col = Random.ColorHSV();
                ColorMap.Add(new(pos, col));
            }

            Refresh = true;
        }

        if (MapToA) {
            MapToA = false;
            ColorMap.DeepCopy(ColorMap, a);
        }
        if (MapToB) {
            MapToB = false;
            ColorMap.DeepCopy(ColorMap, b);
        }
        if (InterpolateToMap) {
            InterpolateToMap = LiveUpdates;
            ColorMap.Morph(a, b, interpolation, ColorMap);
            Refresh = true;
        }

        if (Refresh || LiveUpdates) {
            Refresh = false;
            SetupCommandBuffer();
        }
    }

#endif
}