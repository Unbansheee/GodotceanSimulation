using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Linq;
using System.Numerics;
using Godot;
using Godot.Collections;
using Array = System.Array;

[GlobalClass]
public partial class ButterflyGeneratorSharp : Node
{
    public RenderingDevice RD = RenderingServer.GetRenderingDevice();
	
    public Rid ButterflyTexture;
    public Rid TextureUniforms;

    public Rid IndicesBuffer;
    public int[] Indices;
    public Rid IndicesUniform;

    public Rid UniformBuffer;
    public Rid ParamsUniform;

    public Rid Shader;
    public Rid Pipeline;

    [Export] public RDShaderFile ShaderFile;
    [Export] public int N;
	
    // Called when the node enters the scene tree for the first time.
    public override void _Ready()
    {
    }

    // Called every frame. 'delta' is the elapsed time since the previous frame.
    public override void _Process(double delta)
    {
    }

    public void Setup()
    {
		SetupPipeline();
        ButterflyTexture = CreateSimTexture(BitOperations.Log2((uint)N), N);
        var arr = new Array<Rid>();
        arr.Add(ButterflyTexture);
        TextureUniforms = CreateTextureUniformSet(arr, 0, 0);

        Indices = InitBitReversedIndices();
        
        byte[] result = new byte[Indices.Length * sizeof(int)];
        Buffer.BlockCopy(Indices, 0, result, 0, result.Length);
        
        IndicesBuffer = CreateStorageBuffer(result);
        IndicesUniform = CreateUniformSet([IndicesBuffer], 1, 0, RenderingDevice.UniformType.StorageBuffer);

        List<byte> uniformBytes = new List<byte>();
        uniformBytes.AddRange(BitConverter.GetBytes(N));
        for (int i = 0; i < 12; i++)
        {
            uniformBytes.Add(0);
        }
        UniformBuffer = CreateUniformBuffer(uniformBytes.ToArray());
        ParamsUniform = CreateUniformSet([UniformBuffer], 2, 0, RenderingDevice.UniformType.UniformBuffer);
    }

    public void Execute()
    {
        int x_groups = BitOperations.Log2((uint)N);
        int y_groups = N / 16;

        var computeList = RD.ComputeListBegin();
        RD.ComputeListBindComputePipeline(computeList, Pipeline);
        RD.ComputeListBindUniformSet(computeList, TextureUniforms, 0);
        RD.ComputeListBindUniformSet(computeList, IndicesUniform, 1);
        RD.ComputeListBindUniformSet(computeList, ParamsUniform, 2);
        RD.ComputeListDispatch(computeList, (uint)x_groups, (uint)y_groups, 1);
        RD.ComputeListEnd();
    }

    public void SetupPipeline()
    {
        Shader = LoadShader(RD, ShaderFile);
        Pipeline = RD.ComputePipelineCreate(Shader);
    }

    public Rid LoadShader(RenderingDevice rd, RDShaderFile res)
    {
        var spirv = res.GetSpirV();
        GD.Print(spirv.CompileErrorCompute);
        var rid = rd.ShaderCreateFromSpirV(spirv);
        return rid;
    }

    public Rid CreateSimTexture(int w, int h)
    {
        Rid texID;
        RDTextureFormat tf = new RDTextureFormat();
        tf.Format = RenderingDevice.DataFormat.R32G32B32A32Sfloat;
        tf.TextureType = RenderingDevice.TextureType.Type2D;
        tf.Width = (uint)w;
        tf.Height = (uint)h;
        tf.Depth = 1;
        tf.ArrayLayers = 1;
        tf.Mipmaps = 1;
        tf.UsageBits = RenderingDevice.TextureUsageBits.SamplingBit |
                       RenderingDevice.TextureUsageBits.ColorAttachmentBit |
                       RenderingDevice.TextureUsageBits.StorageBit | RenderingDevice.TextureUsageBits.CanUpdateBit |
                       RenderingDevice.TextureUsageBits.CanCopyToBit;

        texID = RD.TextureCreate(tf, new RDTextureView(), null);
        RD.TextureClear(texID, new Color(0.0f, 0.0f, 0.0f, 0.0f), 0, 1, 0, 1);
        return texID;
    }

    public Rid CreateTextureUniformSet(Array<Rid> textures, uint setId, int binding,
        RenderingDevice.UniformType type = RenderingDevice.UniformType.Image)
    {
        Array<RDUniform> uniforms = new Array<RDUniform>();
        var idx = 0;
        foreach (var tex in textures)
        {
            var uniform = new RDUniform();
            uniform.UniformType = type;
            uniform.Binding = binding + idx;
            uniform.AddId(tex);
            uniforms.Add(uniform);
            idx++;
        }

        return RD.UniformSetCreate(uniforms, Shader, setId);
    }

    int[] InitBitReversedIndices()
    {
        int bits = BitOperations.Log2((uint)N);
        int[] BitReversedIndices = new int[N];
        for (int i = 0; i < N; i++)
        {
            var rev = ReverseBits(i);
            var rotated = RotateLeft(rev, bits);
            BitReversedIndices[i] = rotated;
        }

        return BitReversedIndices;
    }

    public int ReverseBits(int num)
    {
        int x = num;
        int k = BitOperations.Log2((uint)32);
        
        // Binary representation of x of length k
        string binaryString = Convert.ToString(x, 2).PadLeft(32, '0');
        
        int reversed = Convert.ToInt32(Reverse(binaryString), 2);
        return reversed;
    }
    
    public static string Reverse( string s )
    {
        char[] charArray = s.ToCharArray();
        Array.Reverse( charArray );
        return new string( charArray );
    }
    
    public static int RotateLeft(int value, int count)
    {
        
        return Int32.RotateLeft(value, count);
    }

    public Rid CreateStorageBuffer(byte[] bytes)
    {
        return RD.StorageBufferCreate((uint)bytes.Length, bytes);
    }
    
    public Rid CreateUniformBuffer(byte[] bytes)
    {
        return RD.UniformBufferCreate((uint)bytes.Length, bytes);
    }

    public Rid CreateUniformSet(Array<Rid> buffers, uint setId, int binding, RenderingDevice.UniformType usage)
    {
        Array<RDUniform> uniforms = new Array<RDUniform>();
        var idx = 0;
        foreach (var buf in buffers)
        {
            var uniform = new RDUniform();
            uniform.UniformType = usage;
            uniform.Binding = binding + idx;
            uniform.AddId(buf);
            uniforms.Add(uniform);
            idx++;
        }
        return RD.UniformSetCreate(uniforms, Shader, setId);
    }
}