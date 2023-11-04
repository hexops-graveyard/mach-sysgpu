const std = @import("std");
const c = @import("c.zig");

var libgl: std.DynLib = undefined;

fn removeOptional(comptime T: type) type {
    return switch (@typeInfo(T)) {
        .Optional => |opt| opt.child,
        else => T,
    };
}

fn getProcAddress(name_ptr: [*:0]const u8) c.PROC {
    var name = std.mem.span(name_ptr);
    return libgl.lookup(removeOptional(c.PROC), name);
}

pub fn init() !void {
    libgl = try std.DynLib.openZ("opengl32.dll");
}

pub fn deinit() void {
    libgl.close();
}

pub const InstanceWGL = struct {
    GetExtensionsStringARB: removeOptional(c.PFNWGLGETEXTENSIONSSTRINGARBPROC),
    CreateContextAttribsARB: removeOptional(c.PFNWGLCREATECONTEXTATTRIBSARBPROC),
    ChoosePixelFormatARB: removeOptional(c.PFNWGLCHOOSEPIXELFORMATARBPROC),

    pub fn load(wgl: *InstanceWGL) void {
        wgl.GetExtensionsStringARB = @ptrCast(c.wglGetProcAddress("wglGetExtensionsStringARB"));
        wgl.CreateContextAttribsARB = @ptrCast(c.wglGetProcAddress("wglCreateContextAttribsARB"));
        wgl.ChoosePixelFormatARB = @ptrCast(c.wglGetProcAddress("wglChoosePixelFormatARB"));
    }
};

pub const AdapterGL = struct {
    GetString: removeOptional(c.PFNGLGETSTRINGPROC),

    pub fn load(gl: *AdapterGL) void {
        gl.GetString = @ptrCast(getProcAddress("glGetString"));
    }
};

pub const DeviceGL = struct {
    // 1.0
    CullFace: removeOptional(c.PFNGLCULLFACEPROC),
    FrontFace: removeOptional(c.PFNGLFRONTFACEPROC),
    Hint: removeOptional(c.PFNGLHINTPROC),
    LineWidth: removeOptional(c.PFNGLLINEWIDTHPROC),
    PointSize: removeOptional(c.PFNGLPOINTSIZEPROC),
    PolygonMode: removeOptional(c.PFNGLPOLYGONMODEPROC),
    Scissor: removeOptional(c.PFNGLSCISSORPROC),
    TexParameterf: removeOptional(c.PFNGLTEXPARAMETERFPROC),
    TexParameterfv: removeOptional(c.PFNGLTEXPARAMETERFVPROC),
    TexParameteri: removeOptional(c.PFNGLTEXPARAMETERIPROC),
    TexParameteriv: removeOptional(c.PFNGLTEXPARAMETERIVPROC),
    TexImage1D: removeOptional(c.PFNGLTEXIMAGE1DPROC),
    TexImage2D: removeOptional(c.PFNGLTEXIMAGE2DPROC),
    DrawBuffer: removeOptional(c.PFNGLDRAWBUFFERPROC),
    Clear: removeOptional(c.PFNGLCLEARPROC),
    ClearColor: removeOptional(c.PFNGLCLEARCOLORPROC),
    ClearStencil: removeOptional(c.PFNGLCLEARSTENCILPROC),
    ClearDepth: removeOptional(c.PFNGLCLEARDEPTHPROC),
    StencilMask: removeOptional(c.PFNGLSTENCILMASKPROC),
    ColorMask: removeOptional(c.PFNGLCOLORMASKPROC),
    DepthMask: removeOptional(c.PFNGLDEPTHMASKPROC),
    Disable: removeOptional(c.PFNGLDISABLEPROC),
    Enable: removeOptional(c.PFNGLENABLEPROC),
    Finish: removeOptional(c.PFNGLFINISHPROC),
    Flush: removeOptional(c.PFNGLFLUSHPROC),
    BlendFunc: removeOptional(c.PFNGLBLENDFUNCPROC),
    LogicOp: removeOptional(c.PFNGLLOGICOPPROC),
    StencilFunc: removeOptional(c.PFNGLSTENCILFUNCPROC),
    StencilOp: removeOptional(c.PFNGLSTENCILOPPROC),
    DepthFunc: removeOptional(c.PFNGLDEPTHFUNCPROC),
    PixelStoref: removeOptional(c.PFNGLPIXELSTOREFPROC),
    PixelStorei: removeOptional(c.PFNGLPIXELSTOREIPROC),
    ReadBuffer: removeOptional(c.PFNGLREADBUFFERPROC),
    ReadPixels: removeOptional(c.PFNGLREADPIXELSPROC),
    GetBooleanv: removeOptional(c.PFNGLGETBOOLEANVPROC),
    GetDoublev: removeOptional(c.PFNGLGETDOUBLEVPROC),
    GetError: removeOptional(c.PFNGLGETERRORPROC),
    GetFloatv: removeOptional(c.PFNGLGETFLOATVPROC),
    GetIntegerv: removeOptional(c.PFNGLGETINTEGERVPROC),
    GetString: removeOptional(c.PFNGLGETSTRINGPROC),
    GetTexImage: removeOptional(c.PFNGLGETTEXIMAGEPROC),
    GetTexParameterfv: removeOptional(c.PFNGLGETTEXPARAMETERFVPROC),
    GetTexParameteriv: removeOptional(c.PFNGLGETTEXPARAMETERIVPROC),
    GetTexLevelParameterfv: removeOptional(c.PFNGLGETTEXLEVELPARAMETERFVPROC),
    GetTexLevelParameteriv: removeOptional(c.PFNGLGETTEXLEVELPARAMETERIVPROC),
    IsEnabled: removeOptional(c.PFNGLISENABLEDPROC),
    DepthRange: removeOptional(c.PFNGLDEPTHRANGEPROC),
    Viewport: removeOptional(c.PFNGLVIEWPORTPROC),

    // 1.1
    DrawArrays: removeOptional(c.PFNGLDRAWARRAYSPROC),
    DrawElements: removeOptional(c.PFNGLDRAWELEMENTSPROC),
    GetPointerv: removeOptional(c.PFNGLGETPOINTERVPROC),
    PolygonOffset: removeOptional(c.PFNGLPOLYGONOFFSETPROC),
    CopyTexImage1D: removeOptional(c.PFNGLCOPYTEXIMAGE1DPROC),
    CopyTexImage2D: removeOptional(c.PFNGLCOPYTEXIMAGE2DPROC),
    CopyTexSubImage1D: removeOptional(c.PFNGLCOPYTEXSUBIMAGE1DPROC),
    CopyTexSubImage2D: removeOptional(c.PFNGLCOPYTEXSUBIMAGE2DPROC),
    TexSubImage1D: removeOptional(c.PFNGLTEXSUBIMAGE1DPROC),
    TexSubImage2D: removeOptional(c.PFNGLTEXSUBIMAGE2DPROC),
    BindTexture: removeOptional(c.PFNGLBINDTEXTUREPROC),
    DeleteTextures: removeOptional(c.PFNGLDELETETEXTURESPROC),
    GenTextures: removeOptional(c.PFNGLGENTEXTURESPROC),
    IsTexture: removeOptional(c.PFNGLISTEXTUREPROC),

    // 1.2
    DrawRangeElements: removeOptional(c.PFNGLDRAWRANGEELEMENTSPROC),
    TexImage3D: removeOptional(c.PFNGLTEXIMAGE3DPROC),
    TexSubImage3D: removeOptional(c.PFNGLTEXSUBIMAGE3DPROC),
    CopyTexSubImage3D: removeOptional(c.PFNGLCOPYTEXSUBIMAGE3DPROC),

    // 1.3
    ActiveTexture: removeOptional(c.PFNGLACTIVETEXTUREPROC),
    SampleCoverage: removeOptional(c.PFNGLSAMPLECOVERAGEPROC),
    CompressedTexImage3D: removeOptional(c.PFNGLCOMPRESSEDTEXIMAGE3DPROC),
    CompressedTexImage2D: removeOptional(c.PFNGLCOMPRESSEDTEXIMAGE2DPROC),
    CompressedTexImage1D: removeOptional(c.PFNGLCOMPRESSEDTEXIMAGE1DPROC),
    CompressedTexSubImage3D: removeOptional(c.PFNGLCOMPRESSEDTEXSUBIMAGE3DPROC),
    CompressedTexSubImage2D: removeOptional(c.PFNGLCOMPRESSEDTEXSUBIMAGE2DPROC),
    CompressedTexSubImage1D: removeOptional(c.PFNGLCOMPRESSEDTEXSUBIMAGE1DPROC),
    GetCompressedTexImage: removeOptional(c.PFNGLGETCOMPRESSEDTEXIMAGEPROC),

    // 1.4
    BlendFuncSeparate: removeOptional(c.PFNGLBLENDFUNCSEPARATEPROC),
    MultiDrawArrays: removeOptional(c.PFNGLMULTIDRAWARRAYSPROC),
    MultiDrawElements: removeOptional(c.PFNGLMULTIDRAWELEMENTSPROC),
    PointParameterf: removeOptional(c.PFNGLPOINTPARAMETERFPROC),
    PointParameterfv: removeOptional(c.PFNGLPOINTPARAMETERFVPROC),
    PointParameteri: removeOptional(c.PFNGLPOINTPARAMETERIPROC),
    PointParameteriv: removeOptional(c.PFNGLPOINTPARAMETERIVPROC),
    BlendColor: removeOptional(c.PFNGLBLENDCOLORPROC),
    BlendEquation: removeOptional(c.PFNGLBLENDEQUATIONPROC),

    // 1.5
    GenQueries: removeOptional(c.PFNGLGENQUERIESPROC),
    DeleteQueries: removeOptional(c.PFNGLDELETEQUERIESPROC),
    IsQuery: removeOptional(c.PFNGLISQUERYPROC),
    BeginQuery: removeOptional(c.PFNGLBEGINQUERYPROC),
    EndQuery: removeOptional(c.PFNGLENDQUERYPROC),
    GetQueryiv: removeOptional(c.PFNGLGETQUERYIVPROC),
    GetQueryObjectiv: removeOptional(c.PFNGLGETQUERYOBJECTIVPROC),
    GetQueryObjectuiv: removeOptional(c.PFNGLGETQUERYOBJECTUIVPROC),
    BindBuffer: removeOptional(c.PFNGLBINDBUFFERPROC),
    DeleteBuffers: removeOptional(c.PFNGLDELETEBUFFERSPROC),
    GenBuffers: removeOptional(c.PFNGLGENBUFFERSPROC),
    IsBuffer: removeOptional(c.PFNGLISBUFFERPROC),
    BufferData: removeOptional(c.PFNGLBUFFERDATAPROC),
    BufferSubData: removeOptional(c.PFNGLBUFFERSUBDATAPROC),
    GetBufferSubData: removeOptional(c.PFNGLGETBUFFERSUBDATAPROC),
    MapBuffer: removeOptional(c.PFNGLMAPBUFFERPROC),
    UnmapBuffer: removeOptional(c.PFNGLUNMAPBUFFERPROC),
    GetBufferParameteriv: removeOptional(c.PFNGLGETBUFFERPARAMETERIVPROC),
    GetBufferPointerv: removeOptional(c.PFNGLGETBUFFERPOINTERVPROC),

    // 2.0
    BlendEquationSeparate: removeOptional(c.PFNGLBLENDEQUATIONSEPARATEPROC),
    DrawBuffers: removeOptional(c.PFNGLDRAWBUFFERSPROC),
    StencilOpSeparate: removeOptional(c.PFNGLSTENCILOPSEPARATEPROC),
    StencilFuncSeparate: removeOptional(c.PFNGLSTENCILFUNCSEPARATEPROC),
    StencilMaskSeparate: removeOptional(c.PFNGLSTENCILMASKSEPARATEPROC),
    AttachShader: removeOptional(c.PFNGLATTACHSHADERPROC),
    BindAttribLocation: removeOptional(c.PFNGLBINDATTRIBLOCATIONPROC),
    CompileShader: removeOptional(c.PFNGLCOMPILESHADERPROC),
    CreateProgram: removeOptional(c.PFNGLCREATEPROGRAMPROC),
    CreateShader: removeOptional(c.PFNGLCREATESHADERPROC),
    DeleteProgram: removeOptional(c.PFNGLDELETEPROGRAMPROC),
    DeleteShader: removeOptional(c.PFNGLDELETESHADERPROC),
    DetachShader: removeOptional(c.PFNGLDETACHSHADERPROC),
    DisableVertexAttribArray: removeOptional(c.PFNGLDISABLEVERTEXATTRIBARRAYPROC),
    EnableVertexAttribArray: removeOptional(c.PFNGLENABLEVERTEXATTRIBARRAYPROC),
    GetActiveAttrib: removeOptional(c.PFNGLGETACTIVEATTRIBPROC),
    GetActiveUniform: removeOptional(c.PFNGLGETACTIVEUNIFORMPROC),
    GetAttachedShaders: removeOptional(c.PFNGLGETATTACHEDSHADERSPROC),
    GetAttribLocation: removeOptional(c.PFNGLGETATTRIBLOCATIONPROC),
    GetProgramiv: removeOptional(c.PFNGLGETPROGRAMIVPROC),
    GetProgramInfoLog: removeOptional(c.PFNGLGETPROGRAMINFOLOGPROC),
    GetShaderiv: removeOptional(c.PFNGLGETSHADERIVPROC),
    GetShaderInfoLog: removeOptional(c.PFNGLGETSHADERINFOLOGPROC),
    GetShaderSource: removeOptional(c.PFNGLGETSHADERSOURCEPROC),
    GetUniformLocation: removeOptional(c.PFNGLGETUNIFORMLOCATIONPROC),
    GetUniformfv: removeOptional(c.PFNGLGETUNIFORMFVPROC),
    GetUniformiv: removeOptional(c.PFNGLGETUNIFORMIVPROC),
    GetVertexAttribdv: removeOptional(c.PFNGLGETVERTEXATTRIBDVPROC),
    GetVertexAttribfv: removeOptional(c.PFNGLGETVERTEXATTRIBFVPROC),
    GetVertexAttribiv: removeOptional(c.PFNGLGETVERTEXATTRIBIVPROC),
    GetVertexAttribPointerv: removeOptional(c.PFNGLGETVERTEXATTRIBPOINTERVPROC),
    IsProgram: removeOptional(c.PFNGLISPROGRAMPROC),
    IsShader: removeOptional(c.PFNGLISSHADERPROC),
    LinkProgram: removeOptional(c.PFNGLLINKPROGRAMPROC),
    ShaderSource: removeOptional(c.PFNGLSHADERSOURCEPROC),
    UseProgram: removeOptional(c.PFNGLUSEPROGRAMPROC),
    Uniform1f: removeOptional(c.PFNGLUNIFORM1FPROC),
    Uniform2f: removeOptional(c.PFNGLUNIFORM2FPROC),
    Uniform3f: removeOptional(c.PFNGLUNIFORM3FPROC),
    Uniform4f: removeOptional(c.PFNGLUNIFORM4FPROC),
    Uniform1i: removeOptional(c.PFNGLUNIFORM1IPROC),
    Uniform2i: removeOptional(c.PFNGLUNIFORM2IPROC),
    Uniform3i: removeOptional(c.PFNGLUNIFORM3IPROC),
    Uniform4i: removeOptional(c.PFNGLUNIFORM4IPROC),
    Uniform1fv: removeOptional(c.PFNGLUNIFORM1FVPROC),
    Uniform2fv: removeOptional(c.PFNGLUNIFORM2FVPROC),
    Uniform3fv: removeOptional(c.PFNGLUNIFORM3FVPROC),
    Uniform4fv: removeOptional(c.PFNGLUNIFORM4FVPROC),
    Uniform1iv: removeOptional(c.PFNGLUNIFORM1IVPROC),
    Uniform2iv: removeOptional(c.PFNGLUNIFORM2IVPROC),
    Uniform3iv: removeOptional(c.PFNGLUNIFORM3IVPROC),
    Uniform4iv: removeOptional(c.PFNGLUNIFORM4IVPROC),
    UniformMatrix2fv: removeOptional(c.PFNGLUNIFORMMATRIX2FVPROC),
    UniformMatrix3fv: removeOptional(c.PFNGLUNIFORMMATRIX3FVPROC),
    UniformMatrix4fv: removeOptional(c.PFNGLUNIFORMMATRIX4FVPROC),
    ValidateProgram: removeOptional(c.PFNGLVALIDATEPROGRAMPROC),
    VertexAttrib1d: removeOptional(c.PFNGLVERTEXATTRIB1DPROC),
    VertexAttrib1dv: removeOptional(c.PFNGLVERTEXATTRIB1DVPROC),
    VertexAttrib1f: removeOptional(c.PFNGLVERTEXATTRIB1FPROC),
    VertexAttrib1fv: removeOptional(c.PFNGLVERTEXATTRIB1FVPROC),
    VertexAttrib1s: removeOptional(c.PFNGLVERTEXATTRIB1SPROC),
    VertexAttrib1sv: removeOptional(c.PFNGLVERTEXATTRIB1SVPROC),
    VertexAttrib2d: removeOptional(c.PFNGLVERTEXATTRIB2DPROC),
    VertexAttrib2dv: removeOptional(c.PFNGLVERTEXATTRIB2DVPROC),
    VertexAttrib2f: removeOptional(c.PFNGLVERTEXATTRIB2FPROC),
    VertexAttrib2fv: removeOptional(c.PFNGLVERTEXATTRIB2FVPROC),
    VertexAttrib2s: removeOptional(c.PFNGLVERTEXATTRIB2SPROC),
    VertexAttrib2sv: removeOptional(c.PFNGLVERTEXATTRIB2SVPROC),
    VertexAttrib3d: removeOptional(c.PFNGLVERTEXATTRIB3DPROC),
    VertexAttrib3dv: removeOptional(c.PFNGLVERTEXATTRIB3DVPROC),
    VertexAttrib3f: removeOptional(c.PFNGLVERTEXATTRIB3FPROC),
    VertexAttrib3fv: removeOptional(c.PFNGLVERTEXATTRIB3FVPROC),
    VertexAttrib3s: removeOptional(c.PFNGLVERTEXATTRIB3SPROC),
    VertexAttrib3sv: removeOptional(c.PFNGLVERTEXATTRIB3SVPROC),
    VertexAttrib4Nbv: removeOptional(c.PFNGLVERTEXATTRIB4NBVPROC),
    VertexAttrib4Niv: removeOptional(c.PFNGLVERTEXATTRIB4NIVPROC),
    VertexAttrib4Nsv: removeOptional(c.PFNGLVERTEXATTRIB4NSVPROC),
    VertexAttrib4Nub: removeOptional(c.PFNGLVERTEXATTRIB4NUBPROC),
    VertexAttrib4Nubv: removeOptional(c.PFNGLVERTEXATTRIB4NUBVPROC),
    VertexAttrib4Nuiv: removeOptional(c.PFNGLVERTEXATTRIB4NUIVPROC),
    VertexAttrib4Nusv: removeOptional(c.PFNGLVERTEXATTRIB4NUSVPROC),
    VertexAttrib4bv: removeOptional(c.PFNGLVERTEXATTRIB4BVPROC),
    VertexAttrib4d: removeOptional(c.PFNGLVERTEXATTRIB4DPROC),
    VertexAttrib4dv: removeOptional(c.PFNGLVERTEXATTRIB4DVPROC),
    VertexAttrib4f: removeOptional(c.PFNGLVERTEXATTRIB4FPROC),
    VertexAttrib4fv: removeOptional(c.PFNGLVERTEXATTRIB4FVPROC),
    VertexAttrib4iv: removeOptional(c.PFNGLVERTEXATTRIB4IVPROC),
    VertexAttrib4s: removeOptional(c.PFNGLVERTEXATTRIB4SPROC),
    VertexAttrib4sv: removeOptional(c.PFNGLVERTEXATTRIB4SVPROC),
    VertexAttrib4ubv: removeOptional(c.PFNGLVERTEXATTRIB4UBVPROC),
    VertexAttrib4uiv: removeOptional(c.PFNGLVERTEXATTRIB4UIVPROC),
    VertexAttrib4usv: removeOptional(c.PFNGLVERTEXATTRIB4USVPROC),
    VertexAttribPointer: removeOptional(c.PFNGLVERTEXATTRIBPOINTERPROC),

    // 2.1
    UniformMatrix2x3fv: removeOptional(c.PFNGLUNIFORMMATRIX2X3FVPROC),
    UniformMatrix3x2fv: removeOptional(c.PFNGLUNIFORMMATRIX3X2FVPROC),
    UniformMatrix2x4fv: removeOptional(c.PFNGLUNIFORMMATRIX2X4FVPROC),
    UniformMatrix4x2fv: removeOptional(c.PFNGLUNIFORMMATRIX4X2FVPROC),
    UniformMatrix3x4fv: removeOptional(c.PFNGLUNIFORMMATRIX3X4FVPROC),
    UniformMatrix4x3fv: removeOptional(c.PFNGLUNIFORMMATRIX4X3FVPROC),

    // 3.0
    ColorMaski: removeOptional(c.PFNGLCOLORMASKIPROC),
    GetBooleani_v: removeOptional(c.PFNGLGETBOOLEANI_VPROC),
    GetIntegeri_v: removeOptional(c.PFNGLGETINTEGERI_VPROC),
    Enablei: removeOptional(c.PFNGLENABLEIPROC),
    Disablei: removeOptional(c.PFNGLDISABLEIPROC),
    IsEnabledi: removeOptional(c.PFNGLISENABLEDIPROC),
    BeginTransformFeedback: removeOptional(c.PFNGLBEGINTRANSFORMFEEDBACKPROC),
    EndTransformFeedback: removeOptional(c.PFNGLENDTRANSFORMFEEDBACKPROC),
    BindBufferRange: removeOptional(c.PFNGLBINDBUFFERRANGEPROC),
    BindBufferBase: removeOptional(c.PFNGLBINDBUFFERBASEPROC),
    TransformFeedbackVaryings: removeOptional(c.PFNGLTRANSFORMFEEDBACKVARYINGSPROC),
    GetTransformFeedbackVarying: removeOptional(c.PFNGLGETTRANSFORMFEEDBACKVARYINGPROC),
    ClampColor: removeOptional(c.PFNGLCLAMPCOLORPROC),
    BeginConditionalRender: removeOptional(c.PFNGLBEGINCONDITIONALRENDERPROC),
    EndConditionalRender: removeOptional(c.PFNGLENDCONDITIONALRENDERPROC),
    VertexAttribIPointer: removeOptional(c.PFNGLVERTEXATTRIBIPOINTERPROC),
    GetVertexAttribIiv: removeOptional(c.PFNGLGETVERTEXATTRIBIIVPROC),
    GetVertexAttribIuiv: removeOptional(c.PFNGLGETVERTEXATTRIBIUIVPROC),
    VertexAttribI1i: removeOptional(c.PFNGLVERTEXATTRIBI1IPROC),
    VertexAttribI2i: removeOptional(c.PFNGLVERTEXATTRIBI2IPROC),
    VertexAttribI3i: removeOptional(c.PFNGLVERTEXATTRIBI3IPROC),
    VertexAttribI4i: removeOptional(c.PFNGLVERTEXATTRIBI4IPROC),
    VertexAttribI1ui: removeOptional(c.PFNGLVERTEXATTRIBI1UIPROC),
    VertexAttribI2ui: removeOptional(c.PFNGLVERTEXATTRIBI2UIPROC),
    VertexAttribI3ui: removeOptional(c.PFNGLVERTEXATTRIBI3UIPROC),
    VertexAttribI4ui: removeOptional(c.PFNGLVERTEXATTRIBI4UIPROC),
    VertexAttribI1iv: removeOptional(c.PFNGLVERTEXATTRIBI1IVPROC),
    VertexAttribI2iv: removeOptional(c.PFNGLVERTEXATTRIBI2IVPROC),
    VertexAttribI3iv: removeOptional(c.PFNGLVERTEXATTRIBI3IVPROC),
    VertexAttribI4iv: removeOptional(c.PFNGLVERTEXATTRIBI4IVPROC),
    VertexAttribI1uiv: removeOptional(c.PFNGLVERTEXATTRIBI1UIVPROC),
    VertexAttribI2uiv: removeOptional(c.PFNGLVERTEXATTRIBI2UIVPROC),
    VertexAttribI3uiv: removeOptional(c.PFNGLVERTEXATTRIBI3UIVPROC),
    VertexAttribI4uiv: removeOptional(c.PFNGLVERTEXATTRIBI4UIVPROC),
    VertexAttribI4bv: removeOptional(c.PFNGLVERTEXATTRIBI4BVPROC),
    VertexAttribI4sv: removeOptional(c.PFNGLVERTEXATTRIBI4SVPROC),
    VertexAttribI4ubv: removeOptional(c.PFNGLVERTEXATTRIBI4UBVPROC),
    VertexAttribI4usv: removeOptional(c.PFNGLVERTEXATTRIBI4USVPROC),
    GetUniformuiv: removeOptional(c.PFNGLGETUNIFORMUIVPROC),
    BindFragDataLocation: removeOptional(c.PFNGLBINDFRAGDATALOCATIONPROC),
    GetFragDataLocation: removeOptional(c.PFNGLGETFRAGDATALOCATIONPROC),
    Uniform1ui: removeOptional(c.PFNGLUNIFORM1UIPROC),
    Uniform2ui: removeOptional(c.PFNGLUNIFORM2UIPROC),
    Uniform3ui: removeOptional(c.PFNGLUNIFORM3UIPROC),
    Uniform4ui: removeOptional(c.PFNGLUNIFORM4UIPROC),
    Uniform1uiv: removeOptional(c.PFNGLUNIFORM1UIVPROC),
    Uniform2uiv: removeOptional(c.PFNGLUNIFORM2UIVPROC),
    Uniform3uiv: removeOptional(c.PFNGLUNIFORM3UIVPROC),
    Uniform4uiv: removeOptional(c.PFNGLUNIFORM4UIVPROC),
    TexParameterIiv: removeOptional(c.PFNGLTEXPARAMETERIIVPROC),
    TexParameterIuiv: removeOptional(c.PFNGLTEXPARAMETERIUIVPROC),
    GetTexParameterIiv: removeOptional(c.PFNGLGETTEXPARAMETERIIVPROC),
    GetTexParameterIuiv: removeOptional(c.PFNGLGETTEXPARAMETERIUIVPROC),
    ClearBufferiv: removeOptional(c.PFNGLCLEARBUFFERIVPROC),
    ClearBufferuiv: removeOptional(c.PFNGLCLEARBUFFERUIVPROC),
    ClearBufferfv: removeOptional(c.PFNGLCLEARBUFFERFVPROC),
    ClearBufferfi: removeOptional(c.PFNGLCLEARBUFFERFIPROC),
    GetStringi: removeOptional(c.PFNGLGETSTRINGIPROC),
    IsRenderbuffer: removeOptional(c.PFNGLISRENDERBUFFERPROC),
    BindRenderbuffer: removeOptional(c.PFNGLBINDRENDERBUFFERPROC),
    DeleteRenderbuffers: removeOptional(c.PFNGLDELETERENDERBUFFERSPROC),
    GenRenderbuffers: removeOptional(c.PFNGLGENRENDERBUFFERSPROC),
    RenderbufferStorage: removeOptional(c.PFNGLRENDERBUFFERSTORAGEPROC),
    GetRenderbufferParameteriv: removeOptional(c.PFNGLGETRENDERBUFFERPARAMETERIVPROC),
    IsFramebuffer: removeOptional(c.PFNGLISFRAMEBUFFERPROC),
    BindFramebuffer: removeOptional(c.PFNGLBINDFRAMEBUFFERPROC),
    DeleteFramebuffers: removeOptional(c.PFNGLDELETEFRAMEBUFFERSPROC),
    GenFramebuffers: removeOptional(c.PFNGLGENFRAMEBUFFERSPROC),
    CheckFramebufferStatus: removeOptional(c.PFNGLCHECKFRAMEBUFFERSTATUSPROC),
    FramebufferTexture1D: removeOptional(c.PFNGLFRAMEBUFFERTEXTURE1DPROC),
    FramebufferTexture2D: removeOptional(c.PFNGLFRAMEBUFFERTEXTURE2DPROC),
    FramebufferTexture3D: removeOptional(c.PFNGLFRAMEBUFFERTEXTURE3DPROC),
    FramebufferRenderbuffer: removeOptional(c.PFNGLFRAMEBUFFERRENDERBUFFERPROC),
    GetFramebufferAttachmentParameteriv: removeOptional(c.PFNGLGETFRAMEBUFFERATTACHMENTPARAMETERIVPROC),
    GenerateMipmap: removeOptional(c.PFNGLGENERATEMIPMAPPROC),
    BlitFramebuffer: removeOptional(c.PFNGLBLITFRAMEBUFFERPROC),
    RenderbufferStorageMultisample: removeOptional(c.PFNGLRENDERBUFFERSTORAGEMULTISAMPLEPROC),
    FramebufferTextureLayer: removeOptional(c.PFNGLFRAMEBUFFERTEXTURELAYERPROC),
    MapBufferRange: removeOptional(c.PFNGLMAPBUFFERRANGEPROC),
    FlushMappedBufferRange: removeOptional(c.PFNGLFLUSHMAPPEDBUFFERRANGEPROC),
    BindVertexArray: removeOptional(c.PFNGLBINDVERTEXARRAYPROC),
    DeleteVertexArrays: removeOptional(c.PFNGLDELETEVERTEXARRAYSPROC),
    GenVertexArrays: removeOptional(c.PFNGLGENVERTEXARRAYSPROC),
    IsVertexArray: removeOptional(c.PFNGLISVERTEXARRAYPROC),

    // 3.1
    DrawArraysInstanced: removeOptional(c.PFNGLDRAWARRAYSINSTANCEDPROC),
    DrawElementsInstanced: removeOptional(c.PFNGLDRAWELEMENTSINSTANCEDPROC),
    TexBuffer: removeOptional(c.PFNGLTEXBUFFERPROC),
    PrimitiveRestartIndex: removeOptional(c.PFNGLPRIMITIVERESTARTINDEXPROC),
    CopyBufferSubData: removeOptional(c.PFNGLCOPYBUFFERSUBDATAPROC),
    GetUniformIndices: removeOptional(c.PFNGLGETUNIFORMINDICESPROC),
    GetActiveUniformsiv: removeOptional(c.PFNGLGETACTIVEUNIFORMSIVPROC),
    GetActiveUniformName: removeOptional(c.PFNGLGETACTIVEUNIFORMNAMEPROC),
    GetUniformBlockIndex: removeOptional(c.PFNGLGETUNIFORMBLOCKINDEXPROC),
    GetActiveUniformBlockiv: removeOptional(c.PFNGLGETACTIVEUNIFORMBLOCKIVPROC),
    GetActiveUniformBlockName: removeOptional(c.PFNGLGETACTIVEUNIFORMBLOCKNAMEPROC),
    UniformBlockBinding: removeOptional(c.PFNGLUNIFORMBLOCKBINDINGPROC),

    // 3.2
    DrawElementsBaseVertex: removeOptional(c.PFNGLDRAWELEMENTSBASEVERTEXPROC),
    DrawRangeElementsBaseVertex: removeOptional(c.PFNGLDRAWRANGEELEMENTSBASEVERTEXPROC),
    DrawElementsInstancedBaseVertex: removeOptional(c.PFNGLDRAWELEMENTSINSTANCEDBASEVERTEXPROC),
    MultiDrawElementsBaseVertex: removeOptional(c.PFNGLMULTIDRAWELEMENTSBASEVERTEXPROC),
    ProvokingVertex: removeOptional(c.PFNGLPROVOKINGVERTEXPROC),
    FenceSync: removeOptional(c.PFNGLFENCESYNCPROC),
    IsSync: removeOptional(c.PFNGLISSYNCPROC),
    DeleteSync: removeOptional(c.PFNGLDELETESYNCPROC),
    ClientWaitSync: removeOptional(c.PFNGLCLIENTWAITSYNCPROC),
    WaitSync: removeOptional(c.PFNGLWAITSYNCPROC),
    GetInteger64v: removeOptional(c.PFNGLGETINTEGER64VPROC),
    GetSynciv: removeOptional(c.PFNGLGETSYNCIVPROC),
    GetInteger64i_v: removeOptional(c.PFNGLGETINTEGER64I_VPROC),
    GetBufferParameteri64v: removeOptional(c.PFNGLGETBUFFERPARAMETERI64VPROC),
    FramebufferTexture: removeOptional(c.PFNGLFRAMEBUFFERTEXTUREPROC),
    TexImage2DMultisample: removeOptional(c.PFNGLTEXIMAGE2DMULTISAMPLEPROC),
    TexImage3DMultisample: removeOptional(c.PFNGLTEXIMAGE3DMULTISAMPLEPROC),
    GetMultisamplefv: removeOptional(c.PFNGLGETMULTISAMPLEFVPROC),
    SampleMaski: removeOptional(c.PFNGLSAMPLEMASKIPROC),

    // 3.3
    BindFragDataLocationIndexed: removeOptional(c.PFNGLBINDFRAGDATALOCATIONINDEXEDPROC),
    GetFragDataIndex: removeOptional(c.PFNGLGETFRAGDATAINDEXPROC),
    GenSamplers: removeOptional(c.PFNGLGENSAMPLERSPROC),
    DeleteSamplers: removeOptional(c.PFNGLDELETESAMPLERSPROC),
    IsSampler: removeOptional(c.PFNGLISSAMPLERPROC),
    BindSampler: removeOptional(c.PFNGLBINDSAMPLERPROC),
    SamplerParameteri: removeOptional(c.PFNGLSAMPLERPARAMETERIPROC),
    SamplerParameteriv: removeOptional(c.PFNGLSAMPLERPARAMETERIVPROC),
    SamplerParameterf: removeOptional(c.PFNGLSAMPLERPARAMETERFPROC),
    SamplerParameterfv: removeOptional(c.PFNGLSAMPLERPARAMETERFVPROC),
    SamplerParameterIiv: removeOptional(c.PFNGLSAMPLERPARAMETERIIVPROC),
    SamplerParameterIuiv: removeOptional(c.PFNGLSAMPLERPARAMETERIUIVPROC),
    GetSamplerParameteriv: removeOptional(c.PFNGLGETSAMPLERPARAMETERIVPROC),
    GetSamplerParameterIiv: removeOptional(c.PFNGLGETSAMPLERPARAMETERIIVPROC),
    GetSamplerParameterfv: removeOptional(c.PFNGLGETSAMPLERPARAMETERFVPROC),
    GetSamplerParameterIuiv: removeOptional(c.PFNGLGETSAMPLERPARAMETERIUIVPROC),
    QueryCounter: removeOptional(c.PFNGLQUERYCOUNTERPROC),
    GetQueryObjecti64v: removeOptional(c.PFNGLGETQUERYOBJECTI64VPROC),
    GetQueryObjectui64v: removeOptional(c.PFNGLGETQUERYOBJECTUI64VPROC),
    VertexAttribDivisor: removeOptional(c.PFNGLVERTEXATTRIBDIVISORPROC),
    VertexAttribP1ui: removeOptional(c.PFNGLVERTEXATTRIBP1UIPROC),
    VertexAttribP1uiv: removeOptional(c.PFNGLVERTEXATTRIBP1UIVPROC),
    VertexAttribP2ui: removeOptional(c.PFNGLVERTEXATTRIBP2UIPROC),
    VertexAttribP2uiv: removeOptional(c.PFNGLVERTEXATTRIBP2UIVPROC),
    VertexAttribP3ui: removeOptional(c.PFNGLVERTEXATTRIBP3UIPROC),
    VertexAttribP3uiv: removeOptional(c.PFNGLVERTEXATTRIBP3UIVPROC),
    VertexAttribP4ui: removeOptional(c.PFNGLVERTEXATTRIBP4UIPROC),
    VertexAttribP4uiv: removeOptional(c.PFNGLVERTEXATTRIBP4UIVPROC),

    // 4.0
    MinSampleShading: removeOptional(c.PFNGLMINSAMPLESHADINGPROC),
    BlendEquationi: removeOptional(c.PFNGLBLENDEQUATIONIPROC),
    BlendEquationSeparatei: removeOptional(c.PFNGLBLENDEQUATIONSEPARATEIPROC),
    BlendFunci: removeOptional(c.PFNGLBLENDFUNCIPROC),
    BlendFuncSeparatei: removeOptional(c.PFNGLBLENDFUNCSEPARATEIPROC),
    DrawArraysIndirect: removeOptional(c.PFNGLDRAWARRAYSINDIRECTPROC),
    DrawElementsIndirect: removeOptional(c.PFNGLDRAWELEMENTSINDIRECTPROC),
    Uniform1d: removeOptional(c.PFNGLUNIFORM1DPROC),
    Uniform2d: removeOptional(c.PFNGLUNIFORM2DPROC),
    Uniform3d: removeOptional(c.PFNGLUNIFORM3DPROC),
    Uniform4d: removeOptional(c.PFNGLUNIFORM4DPROC),
    Uniform1dv: removeOptional(c.PFNGLUNIFORM1DVPROC),
    Uniform2dv: removeOptional(c.PFNGLUNIFORM2DVPROC),
    Uniform3dv: removeOptional(c.PFNGLUNIFORM3DVPROC),
    Uniform4dv: removeOptional(c.PFNGLUNIFORM4DVPROC),
    UniformMatrix2dv: removeOptional(c.PFNGLUNIFORMMATRIX2DVPROC),
    UniformMatrix3dv: removeOptional(c.PFNGLUNIFORMMATRIX3DVPROC),
    UniformMatrix4dv: removeOptional(c.PFNGLUNIFORMMATRIX4DVPROC),
    UniformMatrix2x3dv: removeOptional(c.PFNGLUNIFORMMATRIX2X3DVPROC),
    UniformMatrix2x4dv: removeOptional(c.PFNGLUNIFORMMATRIX2X4DVPROC),
    UniformMatrix3x2dv: removeOptional(c.PFNGLUNIFORMMATRIX3X2DVPROC),
    UniformMatrix3x4dv: removeOptional(c.PFNGLUNIFORMMATRIX3X4DVPROC),
    UniformMatrix4x2dv: removeOptional(c.PFNGLUNIFORMMATRIX4X2DVPROC),
    UniformMatrix4x3dv: removeOptional(c.PFNGLUNIFORMMATRIX4X3DVPROC),
    GetUniformdv: removeOptional(c.PFNGLGETUNIFORMDVPROC),
    GetSubroutineUniformLocation: removeOptional(c.PFNGLGETSUBROUTINEUNIFORMLOCATIONPROC),
    GetSubroutineIndex: removeOptional(c.PFNGLGETSUBROUTINEINDEXPROC),
    GetActiveSubroutineUniformiv: removeOptional(c.PFNGLGETACTIVESUBROUTINEUNIFORMIVPROC),
    GetActiveSubroutineUniformName: removeOptional(c.PFNGLGETACTIVESUBROUTINEUNIFORMNAMEPROC),
    GetActiveSubroutineName: removeOptional(c.PFNGLGETACTIVESUBROUTINENAMEPROC),
    UniformSubroutinesuiv: removeOptional(c.PFNGLUNIFORMSUBROUTINESUIVPROC),
    GetUniformSubroutineuiv: removeOptional(c.PFNGLGETUNIFORMSUBROUTINEUIVPROC),
    GetProgramStageiv: removeOptional(c.PFNGLGETPROGRAMSTAGEIVPROC),
    PatchParameteri: removeOptional(c.PFNGLPATCHPARAMETERIPROC),
    PatchParameterfv: removeOptional(c.PFNGLPATCHPARAMETERFVPROC),
    BindTransformFeedback: removeOptional(c.PFNGLBINDTRANSFORMFEEDBACKPROC),
    DeleteTransformFeedbacks: removeOptional(c.PFNGLDELETETRANSFORMFEEDBACKSPROC),
    GenTransformFeedbacks: removeOptional(c.PFNGLGENTRANSFORMFEEDBACKSPROC),
    IsTransformFeedback: removeOptional(c.PFNGLISTRANSFORMFEEDBACKPROC),
    PauseTransformFeedback: removeOptional(c.PFNGLPAUSETRANSFORMFEEDBACKPROC),
    ResumeTransformFeedback: removeOptional(c.PFNGLRESUMETRANSFORMFEEDBACKPROC),
    DrawTransformFeedback: removeOptional(c.PFNGLDRAWTRANSFORMFEEDBACKPROC),
    DrawTransformFeedbackStream: removeOptional(c.PFNGLDRAWTRANSFORMFEEDBACKSTREAMPROC),
    BeginQueryIndexed: removeOptional(c.PFNGLBEGINQUERYINDEXEDPROC),
    EndQueryIndexed: removeOptional(c.PFNGLENDQUERYINDEXEDPROC),
    GetQueryIndexediv: removeOptional(c.PFNGLGETQUERYINDEXEDIVPROC),

    // 4.1
    ReleaseShaderCompiler: removeOptional(c.PFNGLRELEASESHADERCOMPILERPROC),
    ShaderBinary: removeOptional(c.PFNGLSHADERBINARYPROC),
    GetShaderPrecisionFormat: removeOptional(c.PFNGLGETSHADERPRECISIONFORMATPROC),
    DepthRangef: removeOptional(c.PFNGLDEPTHRANGEFPROC),
    ClearDepthf: removeOptional(c.PFNGLCLEARDEPTHFPROC),
    GetProgramBinary: removeOptional(c.PFNGLGETPROGRAMBINARYPROC),
    ProgramBinary: removeOptional(c.PFNGLPROGRAMBINARYPROC),
    ProgramParameteri: removeOptional(c.PFNGLPROGRAMPARAMETERIPROC),
    UseProgramStages: removeOptional(c.PFNGLUSEPROGRAMSTAGESPROC),
    ActiveShaderProgram: removeOptional(c.PFNGLACTIVESHADERPROGRAMPROC),
    CreateShaderProgramv: removeOptional(c.PFNGLCREATESHADERPROGRAMVPROC),
    BindProgramPipeline: removeOptional(c.PFNGLBINDPROGRAMPIPELINEPROC),
    DeleteProgramPipelines: removeOptional(c.PFNGLDELETEPROGRAMPIPELINESPROC),
    GenProgramPipelines: removeOptional(c.PFNGLGENPROGRAMPIPELINESPROC),
    IsProgramPipeline: removeOptional(c.PFNGLISPROGRAMPIPELINEPROC),
    GetProgramPipelineiv: removeOptional(c.PFNGLGETPROGRAMPIPELINEIVPROC),
    ProgramUniform1i: removeOptional(c.PFNGLPROGRAMUNIFORM1IPROC),
    ProgramUniform1iv: removeOptional(c.PFNGLPROGRAMUNIFORM1IVPROC),
    ProgramUniform1f: removeOptional(c.PFNGLPROGRAMUNIFORM1FPROC),
    ProgramUniform1fv: removeOptional(c.PFNGLPROGRAMUNIFORM1FVPROC),
    ProgramUniform1d: removeOptional(c.PFNGLPROGRAMUNIFORM1DPROC),
    ProgramUniform1dv: removeOptional(c.PFNGLPROGRAMUNIFORM1DVPROC),
    ProgramUniform1ui: removeOptional(c.PFNGLPROGRAMUNIFORM1UIPROC),
    ProgramUniform1uiv: removeOptional(c.PFNGLPROGRAMUNIFORM1UIVPROC),
    ProgramUniform2i: removeOptional(c.PFNGLPROGRAMUNIFORM2IPROC),
    ProgramUniform2iv: removeOptional(c.PFNGLPROGRAMUNIFORM2IVPROC),
    ProgramUniform2f: removeOptional(c.PFNGLPROGRAMUNIFORM2FPROC),
    ProgramUniform2fv: removeOptional(c.PFNGLPROGRAMUNIFORM2FVPROC),
    ProgramUniform2d: removeOptional(c.PFNGLPROGRAMUNIFORM2DPROC),
    ProgramUniform2dv: removeOptional(c.PFNGLPROGRAMUNIFORM2DVPROC),
    ProgramUniform2ui: removeOptional(c.PFNGLPROGRAMUNIFORM2UIPROC),
    ProgramUniform2uiv: removeOptional(c.PFNGLPROGRAMUNIFORM2UIVPROC),
    ProgramUniform3i: removeOptional(c.PFNGLPROGRAMUNIFORM3IPROC),
    ProgramUniform3iv: removeOptional(c.PFNGLPROGRAMUNIFORM3IVPROC),
    ProgramUniform3f: removeOptional(c.PFNGLPROGRAMUNIFORM3FPROC),
    ProgramUniform3fv: removeOptional(c.PFNGLPROGRAMUNIFORM3FVPROC),
    ProgramUniform3d: removeOptional(c.PFNGLPROGRAMUNIFORM3DPROC),
    ProgramUniform3dv: removeOptional(c.PFNGLPROGRAMUNIFORM3DVPROC),
    ProgramUniform3ui: removeOptional(c.PFNGLPROGRAMUNIFORM3UIPROC),
    ProgramUniform3uiv: removeOptional(c.PFNGLPROGRAMUNIFORM3UIVPROC),
    ProgramUniform4i: removeOptional(c.PFNGLPROGRAMUNIFORM4IPROC),
    ProgramUniform4iv: removeOptional(c.PFNGLPROGRAMUNIFORM4IVPROC),
    ProgramUniform4f: removeOptional(c.PFNGLPROGRAMUNIFORM4FPROC),
    ProgramUniform4fv: removeOptional(c.PFNGLPROGRAMUNIFORM4FVPROC),
    ProgramUniform4d: removeOptional(c.PFNGLPROGRAMUNIFORM4DPROC),
    ProgramUniform4dv: removeOptional(c.PFNGLPROGRAMUNIFORM4DVPROC),
    ProgramUniform4ui: removeOptional(c.PFNGLPROGRAMUNIFORM4UIPROC),
    ProgramUniform4uiv: removeOptional(c.PFNGLPROGRAMUNIFORM4UIVPROC),
    ProgramUniformMatrix2fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX2FVPROC),
    ProgramUniformMatrix3fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX3FVPROC),
    ProgramUniformMatrix4fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX4FVPROC),
    ProgramUniformMatrix2dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX2DVPROC),
    ProgramUniformMatrix3dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX3DVPROC),
    ProgramUniformMatrix4dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX4DVPROC),
    ProgramUniformMatrix2x3fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX2X3FVPROC),
    ProgramUniformMatrix3x2fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX3X2FVPROC),
    ProgramUniformMatrix2x4fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX2X4FVPROC),
    ProgramUniformMatrix4x2fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX4X2FVPROC),
    ProgramUniformMatrix3x4fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX3X4FVPROC),
    ProgramUniformMatrix4x3fv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX4X3FVPROC),
    ProgramUniformMatrix2x3dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX2X3DVPROC),
    ProgramUniformMatrix3x2dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX3X2DVPROC),
    ProgramUniformMatrix2x4dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX2X4DVPROC),
    ProgramUniformMatrix4x2dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX4X2DVPROC),
    ProgramUniformMatrix3x4dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX3X4DVPROC),
    ProgramUniformMatrix4x3dv: removeOptional(c.PFNGLPROGRAMUNIFORMMATRIX4X3DVPROC),
    ValidateProgramPipeline: removeOptional(c.PFNGLVALIDATEPROGRAMPIPELINEPROC),
    GetProgramPipelineInfoLog: removeOptional(c.PFNGLGETPROGRAMPIPELINEINFOLOGPROC),
    VertexAttribL1d: removeOptional(c.PFNGLVERTEXATTRIBL1DPROC),
    VertexAttribL2d: removeOptional(c.PFNGLVERTEXATTRIBL2DPROC),
    VertexAttribL3d: removeOptional(c.PFNGLVERTEXATTRIBL3DPROC),
    VertexAttribL4d: removeOptional(c.PFNGLVERTEXATTRIBL4DPROC),
    VertexAttribL1dv: removeOptional(c.PFNGLVERTEXATTRIBL1DVPROC),
    VertexAttribL2dv: removeOptional(c.PFNGLVERTEXATTRIBL2DVPROC),
    VertexAttribL3dv: removeOptional(c.PFNGLVERTEXATTRIBL3DVPROC),
    VertexAttribL4dv: removeOptional(c.PFNGLVERTEXATTRIBL4DVPROC),
    VertexAttribLPointer: removeOptional(c.PFNGLVERTEXATTRIBLPOINTERPROC),
    GetVertexAttribLdv: removeOptional(c.PFNGLGETVERTEXATTRIBLDVPROC),
    ViewportArrayv: removeOptional(c.PFNGLVIEWPORTARRAYVPROC),
    ViewportIndexedf: removeOptional(c.PFNGLVIEWPORTINDEXEDFPROC),
    ViewportIndexedfv: removeOptional(c.PFNGLVIEWPORTINDEXEDFVPROC),
    ScissorArrayv: removeOptional(c.PFNGLSCISSORARRAYVPROC),
    ScissorIndexed: removeOptional(c.PFNGLSCISSORINDEXEDPROC),
    ScissorIndexedv: removeOptional(c.PFNGLSCISSORINDEXEDVPROC),
    DepthRangeArrayv: removeOptional(c.PFNGLDEPTHRANGEARRAYVPROC),
    DepthRangeIndexed: removeOptional(c.PFNGLDEPTHRANGEINDEXEDPROC),
    GetFloati_v: removeOptional(c.PFNGLGETFLOATI_VPROC),
    GetDoublei_v: removeOptional(c.PFNGLGETDOUBLEI_VPROC),

    // 4.2
    DrawArraysInstancedBaseInstance: removeOptional(c.PFNGLDRAWARRAYSINSTANCEDBASEINSTANCEPROC),
    DrawElementsInstancedBaseInstance: removeOptional(c.PFNGLDRAWELEMENTSINSTANCEDBASEINSTANCEPROC),
    DrawElementsInstancedBaseVertexBaseInstance: removeOptional(c.PFNGLDRAWELEMENTSINSTANCEDBASEVERTEXBASEINSTANCEPROC),
    GetInternalformativ: removeOptional(c.PFNGLGETINTERNALFORMATIVPROC),
    GetActiveAtomicCounterBufferiv: removeOptional(c.PFNGLGETACTIVEATOMICCOUNTERBUFFERIVPROC),
    BindImageTexture: removeOptional(c.PFNGLBINDIMAGETEXTUREPROC),
    MemoryBarrier: removeOptional(c.PFNGLMEMORYBARRIERPROC),
    TexStorage1D: removeOptional(c.PFNGLTEXSTORAGE1DPROC),
    TexStorage2D: removeOptional(c.PFNGLTEXSTORAGE2DPROC),
    TexStorage3D: removeOptional(c.PFNGLTEXSTORAGE3DPROC),
    DrawTransformFeedbackInstanced: removeOptional(c.PFNGLDRAWTRANSFORMFEEDBACKINSTANCEDPROC),
    DrawTransformFeedbackStreamInstanced: removeOptional(c.PFNGLDRAWTRANSFORMFEEDBACKSTREAMINSTANCEDPROC),

    // 4.3
    ClearBufferData: removeOptional(c.PFNGLCLEARBUFFERDATAPROC),
    ClearBufferSubData: removeOptional(c.PFNGLCLEARBUFFERSUBDATAPROC),
    DispatchCompute: removeOptional(c.PFNGLDISPATCHCOMPUTEPROC),
    DispatchComputeIndirect: removeOptional(c.PFNGLDISPATCHCOMPUTEINDIRECTPROC),
    CopyImageSubData: removeOptional(c.PFNGLCOPYIMAGESUBDATAPROC),
    FramebufferParameteri: removeOptional(c.PFNGLFRAMEBUFFERPARAMETERIPROC),
    GetFramebufferParameteriv: removeOptional(c.PFNGLGETFRAMEBUFFERPARAMETERIVPROC),
    GetInternalformati64v: removeOptional(c.PFNGLGETINTERNALFORMATI64VPROC),
    InvalidateTexSubImage: removeOptional(c.PFNGLINVALIDATETEXSUBIMAGEPROC),
    InvalidateTexImage: removeOptional(c.PFNGLINVALIDATETEXIMAGEPROC),
    InvalidateBufferSubData: removeOptional(c.PFNGLINVALIDATEBUFFERSUBDATAPROC),
    InvalidateBufferData: removeOptional(c.PFNGLINVALIDATEBUFFERDATAPROC),
    InvalidateFramebuffer: removeOptional(c.PFNGLINVALIDATEFRAMEBUFFERPROC),
    InvalidateSubFramebuffer: removeOptional(c.PFNGLINVALIDATESUBFRAMEBUFFERPROC),
    MultiDrawArraysIndirect: removeOptional(c.PFNGLMULTIDRAWARRAYSINDIRECTPROC),
    MultiDrawElementsIndirect: removeOptional(c.PFNGLMULTIDRAWELEMENTSINDIRECTPROC),
    GetProgramInterfaceiv: removeOptional(c.PFNGLGETPROGRAMINTERFACEIVPROC),
    GetProgramResourceIndex: removeOptional(c.PFNGLGETPROGRAMRESOURCEINDEXPROC),
    GetProgramResourceName: removeOptional(c.PFNGLGETPROGRAMRESOURCENAMEPROC),
    GetProgramResourceiv: removeOptional(c.PFNGLGETPROGRAMRESOURCEIVPROC),
    GetProgramResourceLocation: removeOptional(c.PFNGLGETPROGRAMRESOURCELOCATIONPROC),
    GetProgramResourceLocationIndex: removeOptional(c.PFNGLGETPROGRAMRESOURCELOCATIONINDEXPROC),
    ShaderStorageBlockBinding: removeOptional(c.PFNGLSHADERSTORAGEBLOCKBINDINGPROC),
    TexBufferRange: removeOptional(c.PFNGLTEXBUFFERRANGEPROC),
    TexStorage2DMultisample: removeOptional(c.PFNGLTEXSTORAGE2DMULTISAMPLEPROC),
    TexStorage3DMultisample: removeOptional(c.PFNGLTEXSTORAGE3DMULTISAMPLEPROC),
    TextureView: removeOptional(c.PFNGLTEXTUREVIEWPROC),
    BindVertexBuffer: removeOptional(c.PFNGLBINDVERTEXBUFFERPROC),
    VertexAttribFormat: removeOptional(c.PFNGLVERTEXATTRIBFORMATPROC),
    VertexAttribIFormat: removeOptional(c.PFNGLVERTEXATTRIBIFORMATPROC),
    VertexAttribLFormat: removeOptional(c.PFNGLVERTEXATTRIBLFORMATPROC),
    VertexAttribBinding: removeOptional(c.PFNGLVERTEXATTRIBBINDINGPROC),
    VertexBindingDivisor: removeOptional(c.PFNGLVERTEXBINDINGDIVISORPROC),
    DebugMessageControl: removeOptional(c.PFNGLDEBUGMESSAGECONTROLPROC),
    DebugMessageInsert: removeOptional(c.PFNGLDEBUGMESSAGEINSERTPROC),
    DebugMessageCallback: removeOptional(c.PFNGLDEBUGMESSAGECALLBACKPROC),
    GetDebugMessageLog: removeOptional(c.PFNGLGETDEBUGMESSAGELOGPROC),
    PushDebugGroup: removeOptional(c.PFNGLPUSHDEBUGGROUPPROC),
    PopDebugGroup: removeOptional(c.PFNGLPOPDEBUGGROUPPROC),
    ObjectLabel: removeOptional(c.PFNGLOBJECTLABELPROC),
    GetObjectLabel: removeOptional(c.PFNGLGETOBJECTLABELPROC),
    ObjectPtrLabel: removeOptional(c.PFNGLOBJECTPTRLABELPROC),
    GetObjectPtrLabel: removeOptional(c.PFNGLGETOBJECTPTRLABELPROC),

    // 4.4
    BufferStorage: removeOptional(c.PFNGLBUFFERSTORAGEPROC),
    ClearTexImage: removeOptional(c.PFNGLCLEARTEXIMAGEPROC),
    ClearTexSubImage: removeOptional(c.PFNGLCLEARTEXSUBIMAGEPROC),
    BindBuffersBase: removeOptional(c.PFNGLBINDBUFFERSBASEPROC),
    BindBuffersRange: removeOptional(c.PFNGLBINDBUFFERSRANGEPROC),
    BindTextures: removeOptional(c.PFNGLBINDTEXTURESPROC),
    BindSamplers: removeOptional(c.PFNGLBINDSAMPLERSPROC),
    BindImageTextures: removeOptional(c.PFNGLBINDIMAGETEXTURESPROC),
    BindVertexBuffers: removeOptional(c.PFNGLBINDVERTEXBUFFERSPROC),

    // 4.5
    ClipControl: removeOptional(c.PFNGLCLIPCONTROLPROC),
    CreateTransformFeedbacks: removeOptional(c.PFNGLCREATETRANSFORMFEEDBACKSPROC),
    TransformFeedbackBufferBase: removeOptional(c.PFNGLTRANSFORMFEEDBACKBUFFERBASEPROC),
    TransformFeedbackBufferRange: removeOptional(c.PFNGLTRANSFORMFEEDBACKBUFFERRANGEPROC),
    GetTransformFeedbackiv: removeOptional(c.PFNGLGETTRANSFORMFEEDBACKIVPROC),
    GetTransformFeedbacki_v: removeOptional(c.PFNGLGETTRANSFORMFEEDBACKI_VPROC),
    GetTransformFeedbacki64_v: removeOptional(c.PFNGLGETTRANSFORMFEEDBACKI64_VPROC),
    CreateBuffers: removeOptional(c.PFNGLCREATEBUFFERSPROC),
    NamedBufferStorage: removeOptional(c.PFNGLNAMEDBUFFERSTORAGEPROC),
    NamedBufferData: removeOptional(c.PFNGLNAMEDBUFFERDATAPROC),
    NamedBufferSubData: removeOptional(c.PFNGLNAMEDBUFFERSUBDATAPROC),
    CopyNamedBufferSubData: removeOptional(c.PFNGLCOPYNAMEDBUFFERSUBDATAPROC),
    ClearNamedBufferData: removeOptional(c.PFNGLCLEARNAMEDBUFFERDATAPROC),
    ClearNamedBufferSubData: removeOptional(c.PFNGLCLEARNAMEDBUFFERSUBDATAPROC),
    MapNamedBuffer: removeOptional(c.PFNGLMAPNAMEDBUFFERPROC),
    MapNamedBufferRange: removeOptional(c.PFNGLMAPNAMEDBUFFERRANGEPROC),
    UnmapNamedBuffer: removeOptional(c.PFNGLUNMAPNAMEDBUFFERPROC),
    FlushMappedNamedBufferRange: removeOptional(c.PFNGLFLUSHMAPPEDNAMEDBUFFERRANGEPROC),
    GetNamedBufferParameteriv: removeOptional(c.PFNGLGETNAMEDBUFFERPARAMETERIVPROC),
    GetNamedBufferParameteri64v: removeOptional(c.PFNGLGETNAMEDBUFFERPARAMETERI64VPROC),
    GetNamedBufferPointerv: removeOptional(c.PFNGLGETNAMEDBUFFERPOINTERVPROC),
    GetNamedBufferSubData: removeOptional(c.PFNGLGETNAMEDBUFFERSUBDATAPROC),
    CreateFramebuffers: removeOptional(c.PFNGLCREATEFRAMEBUFFERSPROC),
    NamedFramebufferRenderbuffer: removeOptional(c.PFNGLNAMEDFRAMEBUFFERRENDERBUFFERPROC),
    NamedFramebufferParameteri: removeOptional(c.PFNGLNAMEDFRAMEBUFFERPARAMETERIPROC),
    NamedFramebufferTexture: removeOptional(c.PFNGLNAMEDFRAMEBUFFERTEXTUREPROC),
    NamedFramebufferTextureLayer: removeOptional(c.PFNGLNAMEDFRAMEBUFFERTEXTURELAYERPROC),
    NamedFramebufferDrawBuffer: removeOptional(c.PFNGLNAMEDFRAMEBUFFERDRAWBUFFERPROC),
    NamedFramebufferDrawBuffers: removeOptional(c.PFNGLNAMEDFRAMEBUFFERDRAWBUFFERSPROC),
    NamedFramebufferReadBuffer: removeOptional(c.PFNGLNAMEDFRAMEBUFFERREADBUFFERPROC),
    InvalidateNamedFramebufferData: removeOptional(c.PFNGLINVALIDATENAMEDFRAMEBUFFERDATAPROC),
    InvalidateNamedFramebufferSubData: removeOptional(c.PFNGLINVALIDATENAMEDFRAMEBUFFERSUBDATAPROC),
    ClearNamedFramebufferiv: removeOptional(c.PFNGLCLEARNAMEDFRAMEBUFFERIVPROC),
    ClearNamedFramebufferuiv: removeOptional(c.PFNGLCLEARNAMEDFRAMEBUFFERUIVPROC),
    ClearNamedFramebufferfv: removeOptional(c.PFNGLCLEARNAMEDFRAMEBUFFERFVPROC),
    ClearNamedFramebufferfi: removeOptional(c.PFNGLCLEARNAMEDFRAMEBUFFERFIPROC),
    BlitNamedFramebuffer: removeOptional(c.PFNGLBLITNAMEDFRAMEBUFFERPROC),
    CheckNamedFramebufferStatus: removeOptional(c.PFNGLCHECKNAMEDFRAMEBUFFERSTATUSPROC),
    GetNamedFramebufferParameteriv: removeOptional(c.PFNGLGETNAMEDFRAMEBUFFERPARAMETERIVPROC),
    GetNamedFramebufferAttachmentParameteriv: removeOptional(c.PFNGLGETNAMEDFRAMEBUFFERATTACHMENTPARAMETERIVPROC),
    CreateRenderbuffers: removeOptional(c.PFNGLCREATERENDERBUFFERSPROC),
    NamedRenderbufferStorage: removeOptional(c.PFNGLNAMEDRENDERBUFFERSTORAGEPROC),
    NamedRenderbufferStorageMultisample: removeOptional(c.PFNGLNAMEDRENDERBUFFERSTORAGEMULTISAMPLEPROC),
    GetNamedRenderbufferParameteriv: removeOptional(c.PFNGLGETNAMEDRENDERBUFFERPARAMETERIVPROC),
    CreateTextures: removeOptional(c.PFNGLCREATETEXTURESPROC),
    TextureBuffer: removeOptional(c.PFNGLTEXTUREBUFFERPROC),
    TextureBufferRange: removeOptional(c.PFNGLTEXTUREBUFFERRANGEPROC),
    TextureStorage1D: removeOptional(c.PFNGLTEXTURESTORAGE1DPROC),
    TextureStorage2D: removeOptional(c.PFNGLTEXTURESTORAGE2DPROC),
    TextureStorage3D: removeOptional(c.PFNGLTEXTURESTORAGE3DPROC),
    TextureStorage2DMultisample: removeOptional(c.PFNGLTEXTURESTORAGE2DMULTISAMPLEPROC),
    TextureStorage3DMultisample: removeOptional(c.PFNGLTEXTURESTORAGE3DMULTISAMPLEPROC),
    TextureSubImage1D: removeOptional(c.PFNGLTEXTURESUBIMAGE1DPROC),
    TextureSubImage2D: removeOptional(c.PFNGLTEXTURESUBIMAGE2DPROC),
    TextureSubImage3D: removeOptional(c.PFNGLTEXTURESUBIMAGE3DPROC),
    CompressedTextureSubImage1D: removeOptional(c.PFNGLCOMPRESSEDTEXTURESUBIMAGE1DPROC),
    CompressedTextureSubImage2D: removeOptional(c.PFNGLCOMPRESSEDTEXTURESUBIMAGE2DPROC),
    CompressedTextureSubImage3D: removeOptional(c.PFNGLCOMPRESSEDTEXTURESUBIMAGE3DPROC),
    CopyTextureSubImage1D: removeOptional(c.PFNGLCOPYTEXTURESUBIMAGE1DPROC),
    CopyTextureSubImage2D: removeOptional(c.PFNGLCOPYTEXTURESUBIMAGE2DPROC),
    CopyTextureSubImage3D: removeOptional(c.PFNGLCOPYTEXTURESUBIMAGE3DPROC),
    TextureParameterf: removeOptional(c.PFNGLTEXTUREPARAMETERFPROC),
    TextureParameterfv: removeOptional(c.PFNGLTEXTUREPARAMETERFVPROC),
    TextureParameteri: removeOptional(c.PFNGLTEXTUREPARAMETERIPROC),
    TextureParameterIiv: removeOptional(c.PFNGLTEXTUREPARAMETERIIVPROC),
    TextureParameterIuiv: removeOptional(c.PFNGLTEXTUREPARAMETERIUIVPROC),
    TextureParameteriv: removeOptional(c.PFNGLTEXTUREPARAMETERIVPROC),
    GenerateTextureMipmap: removeOptional(c.PFNGLGENERATETEXTUREMIPMAPPROC),
    BindTextureUnit: removeOptional(c.PFNGLBINDTEXTUREUNITPROC),
    GetTextureImage: removeOptional(c.PFNGLGETTEXTUREIMAGEPROC),
    GetCompressedTextureImage: removeOptional(c.PFNGLGETCOMPRESSEDTEXTUREIMAGEPROC),
    GetTextureLevelParameterfv: removeOptional(c.PFNGLGETTEXTURELEVELPARAMETERFVPROC),
    GetTextureLevelParameteriv: removeOptional(c.PFNGLGETTEXTURELEVELPARAMETERIVPROC),
    GetTextureParameterfv: removeOptional(c.PFNGLGETTEXTUREPARAMETERFVPROC),
    GetTextureParameterIiv: removeOptional(c.PFNGLGETTEXTUREPARAMETERIIVPROC),
    GetTextureParameterIuiv: removeOptional(c.PFNGLGETTEXTUREPARAMETERIUIVPROC),
    GetTextureParameteriv: removeOptional(c.PFNGLGETTEXTUREPARAMETERIVPROC),
    CreateVertexArrays: removeOptional(c.PFNGLCREATEVERTEXARRAYSPROC),
    DisableVertexArrayAttrib: removeOptional(c.PFNGLDISABLEVERTEXARRAYATTRIBPROC),
    EnableVertexArrayAttrib: removeOptional(c.PFNGLENABLEVERTEXARRAYATTRIBPROC),
    VertexArrayElementBuffer: removeOptional(c.PFNGLVERTEXARRAYELEMENTBUFFERPROC),
    VertexArrayVertexBuffer: removeOptional(c.PFNGLVERTEXARRAYVERTEXBUFFERPROC),
    VertexArrayVertexBuffers: removeOptional(c.PFNGLVERTEXARRAYVERTEXBUFFERSPROC),
    VertexArrayAttribBinding: removeOptional(c.PFNGLVERTEXARRAYATTRIBBINDINGPROC),
    VertexArrayAttribFormat: removeOptional(c.PFNGLVERTEXARRAYATTRIBFORMATPROC),
    VertexArrayAttribIFormat: removeOptional(c.PFNGLVERTEXARRAYATTRIBIFORMATPROC),
    VertexArrayAttribLFormat: removeOptional(c.PFNGLVERTEXARRAYATTRIBLFORMATPROC),
    VertexArrayBindingDivisor: removeOptional(c.PFNGLVERTEXARRAYBINDINGDIVISORPROC),
    GetVertexArrayiv: removeOptional(c.PFNGLGETVERTEXARRAYIVPROC),
    GetVertexArrayIndexediv: removeOptional(c.PFNGLGETVERTEXARRAYINDEXEDIVPROC),
    GetVertexArrayIndexed64iv: removeOptional(c.PFNGLGETVERTEXARRAYINDEXED64IVPROC),
    CreateSamplers: removeOptional(c.PFNGLCREATESAMPLERSPROC),
    CreateProgramPipelines: removeOptional(c.PFNGLCREATEPROGRAMPIPELINESPROC),
    CreateQueries: removeOptional(c.PFNGLCREATEQUERIESPROC),
    GetQueryBufferObjecti64v: removeOptional(c.PFNGLGETQUERYBUFFEROBJECTI64VPROC),
    GetQueryBufferObjectiv: removeOptional(c.PFNGLGETQUERYBUFFEROBJECTIVPROC),
    GetQueryBufferObjectui64v: removeOptional(c.PFNGLGETQUERYBUFFEROBJECTUI64VPROC),
    GetQueryBufferObjectuiv: removeOptional(c.PFNGLGETQUERYBUFFEROBJECTUIVPROC),
    MemoryBarrierByRegion: removeOptional(c.PFNGLMEMORYBARRIERBYREGIONPROC),
    GetTextureSubImage: removeOptional(c.PFNGLGETTEXTURESUBIMAGEPROC),
    GetCompressedTextureSubImage: removeOptional(c.PFNGLGETCOMPRESSEDTEXTURESUBIMAGEPROC),
    GetGraphicsResetStatus: removeOptional(c.PFNGLGETGRAPHICSRESETSTATUSPROC),
    GetnCompressedTexImage: removeOptional(c.PFNGLGETNCOMPRESSEDTEXIMAGEPROC),
    GetnTexImage: removeOptional(c.PFNGLGETNTEXIMAGEPROC),
    GetnUniformdv: removeOptional(c.PFNGLGETNUNIFORMDVPROC),
    GetnUniformfv: removeOptional(c.PFNGLGETNUNIFORMFVPROC),
    GetnUniformiv: removeOptional(c.PFNGLGETNUNIFORMIVPROC),
    GetnUniformuiv: removeOptional(c.PFNGLGETNUNIFORMUIVPROC),
    ReadnPixels: removeOptional(c.PFNGLREADNPIXELSPROC),
    TextureBarrier: removeOptional(c.PFNGLTEXTUREBARRIERPROC),

    // 4.6
    SpecializeShader: removeOptional(c.PFNGLSPECIALIZESHADERPROC),
    MultiDrawArraysIndirectCount: removeOptional(c.PFNGLMULTIDRAWARRAYSINDIRECTCOUNTPROC),
    MultiDrawElementsIndirectCount: removeOptional(c.PFNGLMULTIDRAWELEMENTSINDIRECTCOUNTPROC),
    PolygonOffsetClamp: removeOptional(c.PFNGLPOLYGONOFFSETCLAMPPROC),

    pub fn loadVersion(gl: *DeviceGL, major_version: u32, minor_version: u32) void {
        const version = major_version * 100 + minor_version * 10;

        if (version >= 100) {
            gl.CullFace = @ptrCast(getProcAddress("glCullFace"));
            gl.FrontFace = @ptrCast(getProcAddress("glFrontFace"));
            gl.Hint = @ptrCast(getProcAddress("glHint"));
            gl.LineWidth = @ptrCast(getProcAddress("glLineWidth"));
            gl.PointSize = @ptrCast(getProcAddress("glPointSize"));
            gl.PolygonMode = @ptrCast(getProcAddress("glPolygonMode"));
            gl.Scissor = @ptrCast(getProcAddress("glScissor"));
            gl.TexParameterf = @ptrCast(getProcAddress("glTexParameterf"));
            gl.TexParameterfv = @ptrCast(getProcAddress("glTexParameterfv"));
            gl.TexParameteri = @ptrCast(getProcAddress("glTexParameteri"));
            gl.TexParameteriv = @ptrCast(getProcAddress("glTexParameteriv"));
            gl.TexImage1D = @ptrCast(getProcAddress("glTexImage1D"));
            gl.TexImage2D = @ptrCast(getProcAddress("glTexImage2D"));
            gl.DrawBuffer = @ptrCast(getProcAddress("glDrawBuffer"));
            gl.Clear = @ptrCast(getProcAddress("glClear"));
            gl.ClearColor = @ptrCast(getProcAddress("glClearColor"));
            gl.ClearStencil = @ptrCast(getProcAddress("glClearStencil"));
            gl.ClearDepth = @ptrCast(getProcAddress("glClearDepth"));
            gl.StencilMask = @ptrCast(getProcAddress("glStencilMask"));
            gl.ColorMask = @ptrCast(getProcAddress("glColorMask"));
            gl.DepthMask = @ptrCast(getProcAddress("glDepthMask"));
            gl.Disable = @ptrCast(getProcAddress("glDisable"));
            gl.Enable = @ptrCast(getProcAddress("glEnable"));
            gl.Finish = @ptrCast(getProcAddress("glFinish"));
            gl.Flush = @ptrCast(getProcAddress("glFlush"));
            gl.BlendFunc = @ptrCast(getProcAddress("glBlendFunc"));
            gl.LogicOp = @ptrCast(getProcAddress("glLogicOp"));
            gl.StencilFunc = @ptrCast(getProcAddress("glStencilFunc"));
            gl.StencilOp = @ptrCast(getProcAddress("glStencilOp"));
            gl.DepthFunc = @ptrCast(getProcAddress("glDepthFunc"));
            gl.PixelStoref = @ptrCast(getProcAddress("glPixelStoref"));
            gl.PixelStorei = @ptrCast(getProcAddress("glPixelStorei"));
            gl.ReadBuffer = @ptrCast(getProcAddress("glReadBuffer"));
            gl.ReadPixels = @ptrCast(getProcAddress("glReadPixels"));
            gl.GetBooleanv = @ptrCast(getProcAddress("glGetBooleanv"));
            gl.GetDoublev = @ptrCast(getProcAddress("glGetDoublev"));
            gl.GetError = @ptrCast(getProcAddress("glGetError"));
            gl.GetFloatv = @ptrCast(getProcAddress("glGetFloatv"));
            gl.GetIntegerv = @ptrCast(getProcAddress("glGetIntegerv"));
            gl.GetString = @ptrCast(getProcAddress("glGetString"));
            gl.GetTexImage = @ptrCast(getProcAddress("glGetTexImage"));
            gl.GetTexParameterfv = @ptrCast(getProcAddress("glGetTexParameterfv"));
            gl.GetTexParameteriv = @ptrCast(getProcAddress("glGetTexParameteriv"));
            gl.GetTexLevelParameterfv = @ptrCast(getProcAddress("glGetTexLevelParameterfv"));
            gl.GetTexLevelParameteriv = @ptrCast(getProcAddress("glGetTexLevelParameteriv"));
            gl.IsEnabled = @ptrCast(getProcAddress("glIsEnabled"));
            gl.DepthRange = @ptrCast(getProcAddress("glDepthRange"));
            gl.Viewport = @ptrCast(getProcAddress("glViewport"));
        }

        if (version >= 110) {
            gl.DrawArrays = @ptrCast(getProcAddress("glDrawArrays"));
            gl.DrawElements = @ptrCast(getProcAddress("glDrawElements"));
            gl.GetPointerv = @ptrCast(getProcAddress("glGetPointerv"));
            gl.PolygonOffset = @ptrCast(getProcAddress("glPolygonOffset"));
            gl.CopyTexImage1D = @ptrCast(getProcAddress("glCopyTexImage1D"));
            gl.CopyTexImage2D = @ptrCast(getProcAddress("glCopyTexImage2D"));
            gl.CopyTexSubImage1D = @ptrCast(getProcAddress("glCopyTexSubImage1D"));
            gl.CopyTexSubImage2D = @ptrCast(getProcAddress("glCopyTexSubImage2D"));
            gl.TexSubImage1D = @ptrCast(getProcAddress("glTexSubImage1D"));
            gl.TexSubImage2D = @ptrCast(getProcAddress("glTexSubImage2D"));
            gl.BindTexture = @ptrCast(getProcAddress("glBindTexture"));
            gl.DeleteTextures = @ptrCast(getProcAddress("glDeleteTextures"));
            gl.GenTextures = @ptrCast(getProcAddress("glGenTextures"));
            gl.IsTexture = @ptrCast(getProcAddress("glIsTexture"));
        }

        if (version >= 120) {
            gl.DrawRangeElements = @ptrCast(c.wglGetProcAddress("glDrawRangeElements"));
            gl.TexImage3D = @ptrCast(c.wglGetProcAddress("glTexImage3D"));
            gl.TexSubImage3D = @ptrCast(c.wglGetProcAddress("glTexSubImage3D"));
            gl.CopyTexSubImage3D = @ptrCast(c.wglGetProcAddress("glCopyTexSubImage3D"));
        }

        if (version >= 130) {
            gl.ActiveTexture = @ptrCast(c.wglGetProcAddress("glActiveTexture"));
            gl.SampleCoverage = @ptrCast(c.wglGetProcAddress("glSampleCoverage"));
            gl.CompressedTexImage3D = @ptrCast(c.wglGetProcAddress("glCompressedTexImage3D"));
            gl.CompressedTexImage2D = @ptrCast(c.wglGetProcAddress("glCompressedTexImage2D"));
            gl.CompressedTexImage1D = @ptrCast(c.wglGetProcAddress("glCompressedTexImage1D"));
            gl.CompressedTexSubImage3D = @ptrCast(c.wglGetProcAddress("glCompressedTexSubImage3D"));
            gl.CompressedTexSubImage2D = @ptrCast(c.wglGetProcAddress("glCompressedTexSubImage2D"));
            gl.CompressedTexSubImage1D = @ptrCast(c.wglGetProcAddress("glCompressedTexSubImage1D"));
            gl.GetCompressedTexImage = @ptrCast(c.wglGetProcAddress("glGetCompressedTexImage"));
        }

        if (version >= 140) {
            gl.BlendFuncSeparate = @ptrCast(c.wglGetProcAddress("glBlendFuncSeparate"));
            gl.MultiDrawArrays = @ptrCast(c.wglGetProcAddress("glMultiDrawArrays"));
            gl.MultiDrawElements = @ptrCast(c.wglGetProcAddress("glMultiDrawElements"));
            gl.PointParameterf = @ptrCast(c.wglGetProcAddress("glPointParameterf"));
            gl.PointParameterfv = @ptrCast(c.wglGetProcAddress("glPointParameterfv"));
            gl.PointParameteri = @ptrCast(c.wglGetProcAddress("glPointParameteri"));
            gl.PointParameteriv = @ptrCast(c.wglGetProcAddress("glPointParameteriv"));
            gl.BlendColor = @ptrCast(c.wglGetProcAddress("glBlendColor"));
            gl.BlendEquation = @ptrCast(c.wglGetProcAddress("glBlendEquation"));
        }

        if (version >= 150) {
            gl.GenQueries = @ptrCast(c.wglGetProcAddress("glGenQueries"));
            gl.DeleteQueries = @ptrCast(c.wglGetProcAddress("glDeleteQueries"));
            gl.IsQuery = @ptrCast(c.wglGetProcAddress("glIsQuery"));
            gl.BeginQuery = @ptrCast(c.wglGetProcAddress("glBeginQuery"));
            gl.EndQuery = @ptrCast(c.wglGetProcAddress("glEndQuery"));
            gl.GetQueryiv = @ptrCast(c.wglGetProcAddress("glGetQueryiv"));
            gl.GetQueryObjectiv = @ptrCast(c.wglGetProcAddress("glGetQueryObjectiv"));
            gl.GetQueryObjectuiv = @ptrCast(c.wglGetProcAddress("glGetQueryObjectuiv"));
            gl.BindBuffer = @ptrCast(c.wglGetProcAddress("glBindBuffer"));
            gl.DeleteBuffers = @ptrCast(c.wglGetProcAddress("glDeleteBuffers"));
            gl.GenBuffers = @ptrCast(c.wglGetProcAddress("glGenBuffers"));
            gl.IsBuffer = @ptrCast(c.wglGetProcAddress("glIsBuffer"));
            gl.BufferData = @ptrCast(c.wglGetProcAddress("glBufferData"));
            gl.BufferSubData = @ptrCast(c.wglGetProcAddress("glBufferSubData"));
            gl.GetBufferSubData = @ptrCast(c.wglGetProcAddress("glGetBufferSubData"));
            gl.MapBuffer = @ptrCast(c.wglGetProcAddress("glMapBuffer"));
            gl.UnmapBuffer = @ptrCast(c.wglGetProcAddress("glUnmapBuffer"));
            gl.GetBufferParameteriv = @ptrCast(c.wglGetProcAddress("glGetBufferParameteriv"));
            gl.GetBufferPointerv = @ptrCast(c.wglGetProcAddress("glGetBufferPointerv"));
        }

        if (version >= 200) {
            gl.BlendEquationSeparate = @ptrCast(c.wglGetProcAddress("glBlendEquationSeparate"));
            gl.DrawBuffers = @ptrCast(c.wglGetProcAddress("glDrawBuffers"));
            gl.StencilOpSeparate = @ptrCast(c.wglGetProcAddress("glStencilOpSeparate"));
            gl.StencilFuncSeparate = @ptrCast(c.wglGetProcAddress("glStencilFuncSeparate"));
            gl.StencilMaskSeparate = @ptrCast(c.wglGetProcAddress("glStencilMaskSeparate"));
            gl.AttachShader = @ptrCast(c.wglGetProcAddress("glAttachShader"));
            gl.BindAttribLocation = @ptrCast(c.wglGetProcAddress("glBindAttribLocation"));
            gl.CompileShader = @ptrCast(c.wglGetProcAddress("glCompileShader"));
            gl.CreateProgram = @ptrCast(c.wglGetProcAddress("glCreateProgram"));
            gl.CreateShader = @ptrCast(c.wglGetProcAddress("glCreateShader"));
            gl.DeleteProgram = @ptrCast(c.wglGetProcAddress("glDeleteProgram"));
            gl.DeleteShader = @ptrCast(c.wglGetProcAddress("glDeleteShader"));
            gl.DetachShader = @ptrCast(c.wglGetProcAddress("glDetachShader"));
            gl.DisableVertexAttribArray = @ptrCast(c.wglGetProcAddress("glDisableVertexAttribArray"));
            gl.EnableVertexAttribArray = @ptrCast(c.wglGetProcAddress("glEnableVertexAttribArray"));
            gl.GetActiveAttrib = @ptrCast(c.wglGetProcAddress("glGetActiveAttrib"));
            gl.GetActiveUniform = @ptrCast(c.wglGetProcAddress("glGetActiveUniform"));
            gl.GetAttachedShaders = @ptrCast(c.wglGetProcAddress("glGetAttachedShaders"));
            gl.GetAttribLocation = @ptrCast(c.wglGetProcAddress("glGetAttribLocation"));
            gl.GetProgramiv = @ptrCast(c.wglGetProcAddress("glGetProgramiv"));
            gl.GetProgramInfoLog = @ptrCast(c.wglGetProcAddress("glGetProgramInfoLog"));
            gl.GetShaderiv = @ptrCast(c.wglGetProcAddress("glGetShaderiv"));
            gl.GetShaderInfoLog = @ptrCast(c.wglGetProcAddress("glGetShaderInfoLog"));
            gl.GetShaderSource = @ptrCast(c.wglGetProcAddress("glGetShaderSource"));
            gl.GetUniformLocation = @ptrCast(c.wglGetProcAddress("glGetUniformLocation"));
            gl.GetUniformfv = @ptrCast(c.wglGetProcAddress("glGetUniformfv"));
            gl.GetUniformiv = @ptrCast(c.wglGetProcAddress("glGetUniformiv"));
            gl.GetVertexAttribdv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribdv"));
            gl.GetVertexAttribfv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribfv"));
            gl.GetVertexAttribiv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribiv"));
            gl.GetVertexAttribPointerv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribPointerv"));
            gl.IsProgram = @ptrCast(c.wglGetProcAddress("glIsProgram"));
            gl.IsShader = @ptrCast(c.wglGetProcAddress("glIsShader"));
            gl.LinkProgram = @ptrCast(c.wglGetProcAddress("glLinkProgram"));
            gl.ShaderSource = @ptrCast(c.wglGetProcAddress("glShaderSource"));
            gl.UseProgram = @ptrCast(c.wglGetProcAddress("glUseProgram"));
            gl.Uniform1f = @ptrCast(c.wglGetProcAddress("glUniform1f"));
            gl.Uniform2f = @ptrCast(c.wglGetProcAddress("glUniform2f"));
            gl.Uniform3f = @ptrCast(c.wglGetProcAddress("glUniform3f"));
            gl.Uniform4f = @ptrCast(c.wglGetProcAddress("glUniform4f"));
            gl.Uniform1i = @ptrCast(c.wglGetProcAddress("glUniform1i"));
            gl.Uniform2i = @ptrCast(c.wglGetProcAddress("glUniform2i"));
            gl.Uniform3i = @ptrCast(c.wglGetProcAddress("glUniform3i"));
            gl.Uniform4i = @ptrCast(c.wglGetProcAddress("glUniform4i"));
            gl.Uniform1fv = @ptrCast(c.wglGetProcAddress("glUniform1fv"));
            gl.Uniform2fv = @ptrCast(c.wglGetProcAddress("glUniform2fv"));
            gl.Uniform3fv = @ptrCast(c.wglGetProcAddress("glUniform3fv"));
            gl.Uniform4fv = @ptrCast(c.wglGetProcAddress("glUniform4fv"));
            gl.Uniform1iv = @ptrCast(c.wglGetProcAddress("glUniform1iv"));
            gl.Uniform2iv = @ptrCast(c.wglGetProcAddress("glUniform2iv"));
            gl.Uniform3iv = @ptrCast(c.wglGetProcAddress("glUniform3iv"));
            gl.Uniform4iv = @ptrCast(c.wglGetProcAddress("glUniform4iv"));
            gl.UniformMatrix2fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix2fv"));
            gl.UniformMatrix3fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix3fv"));
            gl.UniformMatrix4fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix4fv"));
            gl.ValidateProgram = @ptrCast(c.wglGetProcAddress("glValidateProgram"));
            gl.VertexAttrib1d = @ptrCast(c.wglGetProcAddress("glVertexAttrib1d"));
            gl.VertexAttrib1dv = @ptrCast(c.wglGetProcAddress("glVertexAttrib1dv"));
            gl.VertexAttrib1f = @ptrCast(c.wglGetProcAddress("glVertexAttrib1f"));
            gl.VertexAttrib1fv = @ptrCast(c.wglGetProcAddress("glVertexAttrib1fv"));
            gl.VertexAttrib1s = @ptrCast(c.wglGetProcAddress("glVertexAttrib1s"));
            gl.VertexAttrib1sv = @ptrCast(c.wglGetProcAddress("glVertexAttrib1sv"));
            gl.VertexAttrib2d = @ptrCast(c.wglGetProcAddress("glVertexAttrib2d"));
            gl.VertexAttrib2dv = @ptrCast(c.wglGetProcAddress("glVertexAttrib2dv"));
            gl.VertexAttrib2f = @ptrCast(c.wglGetProcAddress("glVertexAttrib2f"));
            gl.VertexAttrib2fv = @ptrCast(c.wglGetProcAddress("glVertexAttrib2fv"));
            gl.VertexAttrib2s = @ptrCast(c.wglGetProcAddress("glVertexAttrib2s"));
            gl.VertexAttrib2sv = @ptrCast(c.wglGetProcAddress("glVertexAttrib2sv"));
            gl.VertexAttrib3d = @ptrCast(c.wglGetProcAddress("glVertexAttrib3d"));
            gl.VertexAttrib3dv = @ptrCast(c.wglGetProcAddress("glVertexAttrib3dv"));
            gl.VertexAttrib3f = @ptrCast(c.wglGetProcAddress("glVertexAttrib3f"));
            gl.VertexAttrib3fv = @ptrCast(c.wglGetProcAddress("glVertexAttrib3fv"));
            gl.VertexAttrib3s = @ptrCast(c.wglGetProcAddress("glVertexAttrib3s"));
            gl.VertexAttrib3sv = @ptrCast(c.wglGetProcAddress("glVertexAttrib3sv"));
            gl.VertexAttrib4Nbv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Nbv"));
            gl.VertexAttrib4Niv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Niv"));
            gl.VertexAttrib4Nsv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Nsv"));
            gl.VertexAttrib4Nub = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Nub"));
            gl.VertexAttrib4Nubv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Nubv"));
            gl.VertexAttrib4Nuiv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Nuiv"));
            gl.VertexAttrib4Nusv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4Nusv"));
            gl.VertexAttrib4bv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4bv"));
            gl.VertexAttrib4d = @ptrCast(c.wglGetProcAddress("glVertexAttrib4d"));
            gl.VertexAttrib4dv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4dv"));
            gl.VertexAttrib4f = @ptrCast(c.wglGetProcAddress("glVertexAttrib4f"));
            gl.VertexAttrib4fv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4fv"));
            gl.VertexAttrib4iv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4iv"));
            gl.VertexAttrib4s = @ptrCast(c.wglGetProcAddress("glVertexAttrib4s"));
            gl.VertexAttrib4sv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4sv"));
            gl.VertexAttrib4ubv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4ubv"));
            gl.VertexAttrib4uiv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4uiv"));
            gl.VertexAttrib4usv = @ptrCast(c.wglGetProcAddress("glVertexAttrib4usv"));
            gl.VertexAttribPointer = @ptrCast(c.wglGetProcAddress("glVertexAttribPointer"));
        }

        if (version >= 210) {
            gl.UniformMatrix2x3fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix2x3fv"));
            gl.UniformMatrix3x2fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix3x2fv"));
            gl.UniformMatrix2x4fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix2x4fv"));
            gl.UniformMatrix4x2fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix4x2fv"));
            gl.UniformMatrix3x4fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix3x4fv"));
            gl.UniformMatrix4x3fv = @ptrCast(c.wglGetProcAddress("glUniformMatrix4x3fv"));
        }

        if (version >= 300) {
            gl.ColorMaski = @ptrCast(c.wglGetProcAddress("glColorMaski"));
            gl.GetBooleani_v = @ptrCast(c.wglGetProcAddress("glGetBooleani_v"));
            gl.GetIntegeri_v = @ptrCast(c.wglGetProcAddress("glGetIntegeri_v"));
            gl.Enablei = @ptrCast(c.wglGetProcAddress("glEnablei"));
            gl.Disablei = @ptrCast(c.wglGetProcAddress("glDisablei"));
            gl.IsEnabledi = @ptrCast(c.wglGetProcAddress("glIsEnabledi"));
            gl.BeginTransformFeedback = @ptrCast(c.wglGetProcAddress("glBeginTransformFeedback"));
            gl.EndTransformFeedback = @ptrCast(c.wglGetProcAddress("glEndTransformFeedback"));
            gl.BindBufferRange = @ptrCast(c.wglGetProcAddress("glBindBufferRange"));
            gl.BindBufferBase = @ptrCast(c.wglGetProcAddress("glBindBufferBase"));
            gl.TransformFeedbackVaryings = @ptrCast(c.wglGetProcAddress("glTransformFeedbackVaryings"));
            gl.GetTransformFeedbackVarying = @ptrCast(c.wglGetProcAddress("glGetTransformFeedbackVarying"));
            gl.ClampColor = @ptrCast(c.wglGetProcAddress("glClampColor"));
            gl.BeginConditionalRender = @ptrCast(c.wglGetProcAddress("glBeginConditionalRender"));
            gl.EndConditionalRender = @ptrCast(c.wglGetProcAddress("glEndConditionalRender"));
            gl.VertexAttribIPointer = @ptrCast(c.wglGetProcAddress("glVertexAttribIPointer"));
            gl.GetVertexAttribIiv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribIiv"));
            gl.GetVertexAttribIuiv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribIuiv"));
            gl.VertexAttribI1i = @ptrCast(c.wglGetProcAddress("glVertexAttribI1i"));
            gl.VertexAttribI2i = @ptrCast(c.wglGetProcAddress("glVertexAttribI2i"));
            gl.VertexAttribI3i = @ptrCast(c.wglGetProcAddress("glVertexAttribI3i"));
            gl.VertexAttribI4i = @ptrCast(c.wglGetProcAddress("glVertexAttribI4i"));
            gl.VertexAttribI1ui = @ptrCast(c.wglGetProcAddress("glVertexAttribI1ui"));
            gl.VertexAttribI2ui = @ptrCast(c.wglGetProcAddress("glVertexAttribI2ui"));
            gl.VertexAttribI3ui = @ptrCast(c.wglGetProcAddress("glVertexAttribI3ui"));
            gl.VertexAttribI4ui = @ptrCast(c.wglGetProcAddress("glVertexAttribI4ui"));
            gl.VertexAttribI1iv = @ptrCast(c.wglGetProcAddress("glVertexAttribI1iv"));
            gl.VertexAttribI2iv = @ptrCast(c.wglGetProcAddress("glVertexAttribI2iv"));
            gl.VertexAttribI3iv = @ptrCast(c.wglGetProcAddress("glVertexAttribI3iv"));
            gl.VertexAttribI4iv = @ptrCast(c.wglGetProcAddress("glVertexAttribI4iv"));
            gl.VertexAttribI1uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribI1uiv"));
            gl.VertexAttribI2uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribI2uiv"));
            gl.VertexAttribI3uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribI3uiv"));
            gl.VertexAttribI4uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribI4uiv"));
            gl.VertexAttribI4bv = @ptrCast(c.wglGetProcAddress("glVertexAttribI4bv"));
            gl.VertexAttribI4sv = @ptrCast(c.wglGetProcAddress("glVertexAttribI4sv"));
            gl.VertexAttribI4ubv = @ptrCast(c.wglGetProcAddress("glVertexAttribI4ubv"));
            gl.VertexAttribI4usv = @ptrCast(c.wglGetProcAddress("glVertexAttribI4usv"));
            gl.GetUniformuiv = @ptrCast(c.wglGetProcAddress("glGetUniformuiv"));
            gl.BindFragDataLocation = @ptrCast(c.wglGetProcAddress("glBindFragDataLocation"));
            gl.GetFragDataLocation = @ptrCast(c.wglGetProcAddress("glGetFragDataLocation"));
            gl.Uniform1ui = @ptrCast(c.wglGetProcAddress("glUniform1ui"));
            gl.Uniform2ui = @ptrCast(c.wglGetProcAddress("glUniform2ui"));
            gl.Uniform3ui = @ptrCast(c.wglGetProcAddress("glUniform3ui"));
            gl.Uniform4ui = @ptrCast(c.wglGetProcAddress("glUniform4ui"));
            gl.Uniform1uiv = @ptrCast(c.wglGetProcAddress("glUniform1uiv"));
            gl.Uniform2uiv = @ptrCast(c.wglGetProcAddress("glUniform2uiv"));
            gl.Uniform3uiv = @ptrCast(c.wglGetProcAddress("glUniform3uiv"));
            gl.Uniform4uiv = @ptrCast(c.wglGetProcAddress("glUniform4uiv"));
            gl.TexParameterIiv = @ptrCast(c.wglGetProcAddress("glTexParameterIiv"));
            gl.TexParameterIuiv = @ptrCast(c.wglGetProcAddress("glTexParameterIuiv"));
            gl.GetTexParameterIiv = @ptrCast(c.wglGetProcAddress("glGetTexParameterIiv"));
            gl.GetTexParameterIuiv = @ptrCast(c.wglGetProcAddress("glGetTexParameterIuiv"));
            gl.ClearBufferiv = @ptrCast(c.wglGetProcAddress("glClearBufferiv"));
            gl.ClearBufferuiv = @ptrCast(c.wglGetProcAddress("glClearBufferuiv"));
            gl.ClearBufferfv = @ptrCast(c.wglGetProcAddress("glClearBufferfv"));
            gl.ClearBufferfi = @ptrCast(c.wglGetProcAddress("glClearBufferfi"));
            gl.GetStringi = @ptrCast(c.wglGetProcAddress("glGetStringi"));
            gl.IsRenderbuffer = @ptrCast(c.wglGetProcAddress("glIsRenderbuffer"));
            gl.BindRenderbuffer = @ptrCast(c.wglGetProcAddress("glBindRenderbuffer"));
            gl.DeleteRenderbuffers = @ptrCast(c.wglGetProcAddress("glDeleteRenderbuffers"));
            gl.GenRenderbuffers = @ptrCast(c.wglGetProcAddress("glGenRenderbuffers"));
            gl.RenderbufferStorage = @ptrCast(c.wglGetProcAddress("glRenderbufferStorage"));
            gl.GetRenderbufferParameteriv = @ptrCast(c.wglGetProcAddress("glGetRenderbufferParameteriv"));
            gl.IsFramebuffer = @ptrCast(c.wglGetProcAddress("glIsFramebuffer"));
            gl.BindFramebuffer = @ptrCast(c.wglGetProcAddress("glBindFramebuffer"));
            gl.DeleteFramebuffers = @ptrCast(c.wglGetProcAddress("glDeleteFramebuffers"));
            gl.GenFramebuffers = @ptrCast(c.wglGetProcAddress("glGenFramebuffers"));
            gl.CheckFramebufferStatus = @ptrCast(c.wglGetProcAddress("glCheckFramebufferStatus"));
            gl.FramebufferTexture1D = @ptrCast(c.wglGetProcAddress("glFramebufferTexture1D"));
            gl.FramebufferTexture2D = @ptrCast(c.wglGetProcAddress("glFramebufferTexture2D"));
            gl.FramebufferTexture3D = @ptrCast(c.wglGetProcAddress("glFramebufferTexture3D"));
            gl.FramebufferRenderbuffer = @ptrCast(c.wglGetProcAddress("glFramebufferRenderbuffer"));
            gl.GetFramebufferAttachmentParameteriv = @ptrCast(c.wglGetProcAddress("glGetFramebufferAttachmentParameteriv"));
            gl.GenerateMipmap = @ptrCast(c.wglGetProcAddress("glGenerateMipmap"));
            gl.BlitFramebuffer = @ptrCast(c.wglGetProcAddress("glBlitFramebuffer"));
            gl.RenderbufferStorageMultisample = @ptrCast(c.wglGetProcAddress("glRenderbufferStorageMultisample"));
            gl.FramebufferTextureLayer = @ptrCast(c.wglGetProcAddress("glFramebufferTextureLayer"));
            gl.MapBufferRange = @ptrCast(c.wglGetProcAddress("glMapBufferRange"));
            gl.FlushMappedBufferRange = @ptrCast(c.wglGetProcAddress("glFlushMappedBufferRange"));
            gl.BindVertexArray = @ptrCast(c.wglGetProcAddress("glBindVertexArray"));
            gl.DeleteVertexArrays = @ptrCast(c.wglGetProcAddress("glDeleteVertexArrays"));
            gl.GenVertexArrays = @ptrCast(c.wglGetProcAddress("glGenVertexArrays"));
            gl.IsVertexArray = @ptrCast(c.wglGetProcAddress("glIsVertexArray"));
        }

        if (version >= 310) {
            gl.DrawArraysInstanced = @ptrCast(c.wglGetProcAddress("glDrawArraysInstanced"));
            gl.DrawElementsInstanced = @ptrCast(c.wglGetProcAddress("glDrawElementsInstanced"));
            gl.TexBuffer = @ptrCast(c.wglGetProcAddress("glTexBuffer"));
            gl.PrimitiveRestartIndex = @ptrCast(c.wglGetProcAddress("glPrimitiveRestartIndex"));
            gl.CopyBufferSubData = @ptrCast(c.wglGetProcAddress("glCopyBufferSubData"));
            gl.GetUniformIndices = @ptrCast(c.wglGetProcAddress("glGetUniformIndices"));
            gl.GetActiveUniformsiv = @ptrCast(c.wglGetProcAddress("glGetActiveUniformsiv"));
            gl.GetActiveUniformName = @ptrCast(c.wglGetProcAddress("glGetActiveUniformName"));
            gl.GetUniformBlockIndex = @ptrCast(c.wglGetProcAddress("glGetUniformBlockIndex"));
            gl.GetActiveUniformBlockiv = @ptrCast(c.wglGetProcAddress("glGetActiveUniformBlockiv"));
            gl.GetActiveUniformBlockName = @ptrCast(c.wglGetProcAddress("glGetActiveUniformBlockName"));
            gl.UniformBlockBinding = @ptrCast(c.wglGetProcAddress("glUniformBlockBinding"));
        }

        if (version >= 320) {
            gl.DrawElementsBaseVertex = @ptrCast(c.wglGetProcAddress("glDrawElementsBaseVertex"));
            gl.DrawRangeElementsBaseVertex = @ptrCast(c.wglGetProcAddress("glDrawRangeElementsBaseVertex"));
            gl.DrawElementsInstancedBaseVertex = @ptrCast(c.wglGetProcAddress("glDrawElementsInstancedBaseVertex"));
            gl.MultiDrawElementsBaseVertex = @ptrCast(c.wglGetProcAddress("glMultiDrawElementsBaseVertex"));
            gl.ProvokingVertex = @ptrCast(c.wglGetProcAddress("glProvokingVertex"));
            gl.FenceSync = @ptrCast(c.wglGetProcAddress("glFenceSync"));
            gl.IsSync = @ptrCast(c.wglGetProcAddress("glIsSync"));
            gl.DeleteSync = @ptrCast(c.wglGetProcAddress("glDeleteSync"));
            gl.ClientWaitSync = @ptrCast(c.wglGetProcAddress("glClientWaitSync"));
            gl.WaitSync = @ptrCast(c.wglGetProcAddress("glWaitSync"));
            gl.GetInteger64v = @ptrCast(c.wglGetProcAddress("glGetInteger64v"));
            gl.GetSynciv = @ptrCast(c.wglGetProcAddress("glGetSynciv"));
            gl.GetInteger64i_v = @ptrCast(c.wglGetProcAddress("glGetInteger64i_v"));
            gl.GetBufferParameteri64v = @ptrCast(c.wglGetProcAddress("glGetBufferParameteri64v"));
            gl.FramebufferTexture = @ptrCast(c.wglGetProcAddress("glFramebufferTexture"));
            gl.TexImage2DMultisample = @ptrCast(c.wglGetProcAddress("glTexImage2DMultisample"));
            gl.TexImage3DMultisample = @ptrCast(c.wglGetProcAddress("glTexImage3DMultisample"));
            gl.GetMultisamplefv = @ptrCast(c.wglGetProcAddress("glGetMultisamplefv"));
            gl.SampleMaski = @ptrCast(c.wglGetProcAddress("glSampleMaski"));
        }

        if (version >= 330) {
            gl.BindFragDataLocationIndexed = @ptrCast(c.wglGetProcAddress("glBindFragDataLocationIndexed"));
            gl.GetFragDataIndex = @ptrCast(c.wglGetProcAddress("glGetFragDataIndex"));
            gl.GenSamplers = @ptrCast(c.wglGetProcAddress("glGenSamplers"));
            gl.DeleteSamplers = @ptrCast(c.wglGetProcAddress("glDeleteSamplers"));
            gl.IsSampler = @ptrCast(c.wglGetProcAddress("glIsSampler"));
            gl.BindSampler = @ptrCast(c.wglGetProcAddress("glBindSampler"));
            gl.SamplerParameteri = @ptrCast(c.wglGetProcAddress("glSamplerParameteri"));
            gl.SamplerParameteriv = @ptrCast(c.wglGetProcAddress("glSamplerParameteriv"));
            gl.SamplerParameterf = @ptrCast(c.wglGetProcAddress("glSamplerParameterf"));
            gl.SamplerParameterfv = @ptrCast(c.wglGetProcAddress("glSamplerParameterfv"));
            gl.SamplerParameterIiv = @ptrCast(c.wglGetProcAddress("glSamplerParameterIiv"));
            gl.SamplerParameterIuiv = @ptrCast(c.wglGetProcAddress("glSamplerParameterIuiv"));
            gl.GetSamplerParameteriv = @ptrCast(c.wglGetProcAddress("glGetSamplerParameteriv"));
            gl.GetSamplerParameterIiv = @ptrCast(c.wglGetProcAddress("glGetSamplerParameterIiv"));
            gl.GetSamplerParameterfv = @ptrCast(c.wglGetProcAddress("glGetSamplerParameterfv"));
            gl.GetSamplerParameterIuiv = @ptrCast(c.wglGetProcAddress("glGetSamplerParameterIuiv"));
            gl.QueryCounter = @ptrCast(c.wglGetProcAddress("glQueryCounter"));
            gl.GetQueryObjecti64v = @ptrCast(c.wglGetProcAddress("glGetQueryObjecti64v"));
            gl.GetQueryObjectui64v = @ptrCast(c.wglGetProcAddress("glGetQueryObjectui64v"));
            gl.VertexAttribDivisor = @ptrCast(c.wglGetProcAddress("glVertexAttribDivisor"));
            gl.VertexAttribP1ui = @ptrCast(c.wglGetProcAddress("glVertexAttribP1ui"));
            gl.VertexAttribP1uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribP1uiv"));
            gl.VertexAttribP2ui = @ptrCast(c.wglGetProcAddress("glVertexAttribP2ui"));
            gl.VertexAttribP2uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribP2uiv"));
            gl.VertexAttribP3ui = @ptrCast(c.wglGetProcAddress("glVertexAttribP3ui"));
            gl.VertexAttribP3uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribP3uiv"));
            gl.VertexAttribP4ui = @ptrCast(c.wglGetProcAddress("glVertexAttribP4ui"));
            gl.VertexAttribP4uiv = @ptrCast(c.wglGetProcAddress("glVertexAttribP4uiv"));
        }

        if (version >= 400) {
            gl.MinSampleShading = @ptrCast(c.wglGetProcAddress("glMinSampleShading"));
            gl.BlendEquationi = @ptrCast(c.wglGetProcAddress("glBlendEquationi"));
            gl.BlendEquationSeparatei = @ptrCast(c.wglGetProcAddress("glBlendEquationSeparatei"));
            gl.BlendFunci = @ptrCast(c.wglGetProcAddress("glBlendFunci"));
            gl.BlendFuncSeparatei = @ptrCast(c.wglGetProcAddress("glBlendFuncSeparatei"));
            gl.DrawArraysIndirect = @ptrCast(c.wglGetProcAddress("glDrawArraysIndirect"));
            gl.DrawElementsIndirect = @ptrCast(c.wglGetProcAddress("glDrawElementsIndirect"));
            gl.Uniform1d = @ptrCast(c.wglGetProcAddress("glUniform1d"));
            gl.Uniform2d = @ptrCast(c.wglGetProcAddress("glUniform2d"));
            gl.Uniform3d = @ptrCast(c.wglGetProcAddress("glUniform3d"));
            gl.Uniform4d = @ptrCast(c.wglGetProcAddress("glUniform4d"));
            gl.Uniform1dv = @ptrCast(c.wglGetProcAddress("glUniform1dv"));
            gl.Uniform2dv = @ptrCast(c.wglGetProcAddress("glUniform2dv"));
            gl.Uniform3dv = @ptrCast(c.wglGetProcAddress("glUniform3dv"));
            gl.Uniform4dv = @ptrCast(c.wglGetProcAddress("glUniform4dv"));
            gl.UniformMatrix2dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix2dv"));
            gl.UniformMatrix3dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix3dv"));
            gl.UniformMatrix4dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix4dv"));
            gl.UniformMatrix2x3dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix2x3dv"));
            gl.UniformMatrix2x4dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix2x4dv"));
            gl.UniformMatrix3x2dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix3x2dv"));
            gl.UniformMatrix3x4dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix3x4dv"));
            gl.UniformMatrix4x2dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix4x2dv"));
            gl.UniformMatrix4x3dv = @ptrCast(c.wglGetProcAddress("glUniformMatrix4x3dv"));
            gl.GetUniformdv = @ptrCast(c.wglGetProcAddress("glGetUniformdv"));
            gl.GetSubroutineUniformLocation = @ptrCast(c.wglGetProcAddress("glGetSubroutineUniformLocation"));
            gl.GetSubroutineIndex = @ptrCast(c.wglGetProcAddress("glGetSubroutineIndex"));
            gl.GetActiveSubroutineUniformiv = @ptrCast(c.wglGetProcAddress("glGetActiveSubroutineUniformiv"));
            gl.GetActiveSubroutineUniformName = @ptrCast(c.wglGetProcAddress("glGetActiveSubroutineUniformName"));
            gl.GetActiveSubroutineName = @ptrCast(c.wglGetProcAddress("glGetActiveSubroutineName"));
            gl.UniformSubroutinesuiv = @ptrCast(c.wglGetProcAddress("glUniformSubroutinesuiv"));
            gl.GetUniformSubroutineuiv = @ptrCast(c.wglGetProcAddress("glGetUniformSubroutineuiv"));
            gl.GetProgramStageiv = @ptrCast(c.wglGetProcAddress("glGetProgramStageiv"));
            gl.PatchParameteri = @ptrCast(c.wglGetProcAddress("glPatchParameteri"));
            gl.PatchParameterfv = @ptrCast(c.wglGetProcAddress("glPatchParameterfv"));
            gl.BindTransformFeedback = @ptrCast(c.wglGetProcAddress("glBindTransformFeedback"));
            gl.DeleteTransformFeedbacks = @ptrCast(c.wglGetProcAddress("glDeleteTransformFeedbacks"));
            gl.GenTransformFeedbacks = @ptrCast(c.wglGetProcAddress("glGenTransformFeedbacks"));
            gl.IsTransformFeedback = @ptrCast(c.wglGetProcAddress("glIsTransformFeedback"));
            gl.PauseTransformFeedback = @ptrCast(c.wglGetProcAddress("glPauseTransformFeedback"));
            gl.ResumeTransformFeedback = @ptrCast(c.wglGetProcAddress("glResumeTransformFeedback"));
            gl.DrawTransformFeedback = @ptrCast(c.wglGetProcAddress("glDrawTransformFeedback"));
            gl.DrawTransformFeedbackStream = @ptrCast(c.wglGetProcAddress("glDrawTransformFeedbackStream"));
            gl.BeginQueryIndexed = @ptrCast(c.wglGetProcAddress("glBeginQueryIndexed"));
            gl.EndQueryIndexed = @ptrCast(c.wglGetProcAddress("glEndQueryIndexed"));
            gl.GetQueryIndexediv = @ptrCast(c.wglGetProcAddress("glGetQueryIndexediv"));
        }

        if (version >= 410) {
            gl.ReleaseShaderCompiler = @ptrCast(c.wglGetProcAddress("glReleaseShaderCompiler"));
            gl.ShaderBinary = @ptrCast(c.wglGetProcAddress("glShaderBinary"));
            gl.GetShaderPrecisionFormat = @ptrCast(c.wglGetProcAddress("glGetShaderPrecisionFormat"));
            gl.DepthRangef = @ptrCast(c.wglGetProcAddress("glDepthRangef"));
            gl.ClearDepthf = @ptrCast(c.wglGetProcAddress("glClearDepthf"));
            gl.GetProgramBinary = @ptrCast(c.wglGetProcAddress("glGetProgramBinary"));
            gl.ProgramBinary = @ptrCast(c.wglGetProcAddress("glProgramBinary"));
            gl.ProgramParameteri = @ptrCast(c.wglGetProcAddress("glProgramParameteri"));
            gl.UseProgramStages = @ptrCast(c.wglGetProcAddress("glUseProgramStages"));
            gl.ActiveShaderProgram = @ptrCast(c.wglGetProcAddress("glActiveShaderProgram"));
            gl.CreateShaderProgramv = @ptrCast(c.wglGetProcAddress("glCreateShaderProgramv"));
            gl.BindProgramPipeline = @ptrCast(c.wglGetProcAddress("glBindProgramPipeline"));
            gl.DeleteProgramPipelines = @ptrCast(c.wglGetProcAddress("glDeleteProgramPipelines"));
            gl.GenProgramPipelines = @ptrCast(c.wglGetProcAddress("glGenProgramPipelines"));
            gl.IsProgramPipeline = @ptrCast(c.wglGetProcAddress("glIsProgramPipeline"));
            gl.GetProgramPipelineiv = @ptrCast(c.wglGetProcAddress("glGetProgramPipelineiv"));
            gl.ProgramUniform1i = @ptrCast(c.wglGetProcAddress("glProgramUniform1i"));
            gl.ProgramUniform1iv = @ptrCast(c.wglGetProcAddress("glProgramUniform1iv"));
            gl.ProgramUniform1f = @ptrCast(c.wglGetProcAddress("glProgramUniform1f"));
            gl.ProgramUniform1fv = @ptrCast(c.wglGetProcAddress("glProgramUniform1fv"));
            gl.ProgramUniform1d = @ptrCast(c.wglGetProcAddress("glProgramUniform1d"));
            gl.ProgramUniform1dv = @ptrCast(c.wglGetProcAddress("glProgramUniform1dv"));
            gl.ProgramUniform1ui = @ptrCast(c.wglGetProcAddress("glProgramUniform1ui"));
            gl.ProgramUniform1uiv = @ptrCast(c.wglGetProcAddress("glProgramUniform1uiv"));
            gl.ProgramUniform2i = @ptrCast(c.wglGetProcAddress("glProgramUniform2i"));
            gl.ProgramUniform2iv = @ptrCast(c.wglGetProcAddress("glProgramUniform2iv"));
            gl.ProgramUniform2f = @ptrCast(c.wglGetProcAddress("glProgramUniform2f"));
            gl.ProgramUniform2fv = @ptrCast(c.wglGetProcAddress("glProgramUniform2fv"));
            gl.ProgramUniform2d = @ptrCast(c.wglGetProcAddress("glProgramUniform2d"));
            gl.ProgramUniform2dv = @ptrCast(c.wglGetProcAddress("glProgramUniform2dv"));
            gl.ProgramUniform2ui = @ptrCast(c.wglGetProcAddress("glProgramUniform2ui"));
            gl.ProgramUniform2uiv = @ptrCast(c.wglGetProcAddress("glProgramUniform2uiv"));
            gl.ProgramUniform3i = @ptrCast(c.wglGetProcAddress("glProgramUniform3i"));
            gl.ProgramUniform3iv = @ptrCast(c.wglGetProcAddress("glProgramUniform3iv"));
            gl.ProgramUniform3f = @ptrCast(c.wglGetProcAddress("glProgramUniform3f"));
            gl.ProgramUniform3fv = @ptrCast(c.wglGetProcAddress("glProgramUniform3fv"));
            gl.ProgramUniform3d = @ptrCast(c.wglGetProcAddress("glProgramUniform3d"));
            gl.ProgramUniform3dv = @ptrCast(c.wglGetProcAddress("glProgramUniform3dv"));
            gl.ProgramUniform3ui = @ptrCast(c.wglGetProcAddress("glProgramUniform3ui"));
            gl.ProgramUniform3uiv = @ptrCast(c.wglGetProcAddress("glProgramUniform3uiv"));
            gl.ProgramUniform4i = @ptrCast(c.wglGetProcAddress("glProgramUniform4i"));
            gl.ProgramUniform4iv = @ptrCast(c.wglGetProcAddress("glProgramUniform4iv"));
            gl.ProgramUniform4f = @ptrCast(c.wglGetProcAddress("glProgramUniform4f"));
            gl.ProgramUniform4fv = @ptrCast(c.wglGetProcAddress("glProgramUniform4fv"));
            gl.ProgramUniform4d = @ptrCast(c.wglGetProcAddress("glProgramUniform4d"));
            gl.ProgramUniform4dv = @ptrCast(c.wglGetProcAddress("glProgramUniform4dv"));
            gl.ProgramUniform4ui = @ptrCast(c.wglGetProcAddress("glProgramUniform4ui"));
            gl.ProgramUniform4uiv = @ptrCast(c.wglGetProcAddress("glProgramUniform4uiv"));
            gl.ProgramUniformMatrix2fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix2fv"));
            gl.ProgramUniformMatrix3fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix3fv"));
            gl.ProgramUniformMatrix4fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix4fv"));
            gl.ProgramUniformMatrix2dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix2dv"));
            gl.ProgramUniformMatrix3dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix3dv"));
            gl.ProgramUniformMatrix4dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix4dv"));
            gl.ProgramUniformMatrix2x3fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix2x3fv"));
            gl.ProgramUniformMatrix3x2fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix3x2fv"));
            gl.ProgramUniformMatrix2x4fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix2x4fv"));
            gl.ProgramUniformMatrix4x2fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix4x2fv"));
            gl.ProgramUniformMatrix3x4fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix3x4fv"));
            gl.ProgramUniformMatrix4x3fv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix4x3fv"));
            gl.ProgramUniformMatrix2x3dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix2x3dv"));
            gl.ProgramUniformMatrix3x2dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix3x2dv"));
            gl.ProgramUniformMatrix2x4dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix2x4dv"));
            gl.ProgramUniformMatrix4x2dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix4x2dv"));
            gl.ProgramUniformMatrix3x4dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix3x4dv"));
            gl.ProgramUniformMatrix4x3dv = @ptrCast(c.wglGetProcAddress("glProgramUniformMatrix4x3dv"));
            gl.ValidateProgramPipeline = @ptrCast(c.wglGetProcAddress("glValidateProgramPipeline"));
            gl.GetProgramPipelineInfoLog = @ptrCast(c.wglGetProcAddress("glGetProgramPipelineInfoLog"));
            gl.VertexAttribL1d = @ptrCast(c.wglGetProcAddress("glVertexAttribL1d"));
            gl.VertexAttribL2d = @ptrCast(c.wglGetProcAddress("glVertexAttribL2d"));
            gl.VertexAttribL3d = @ptrCast(c.wglGetProcAddress("glVertexAttribL3d"));
            gl.VertexAttribL4d = @ptrCast(c.wglGetProcAddress("glVertexAttribL4d"));
            gl.VertexAttribL1dv = @ptrCast(c.wglGetProcAddress("glVertexAttribL1dv"));
            gl.VertexAttribL2dv = @ptrCast(c.wglGetProcAddress("glVertexAttribL2dv"));
            gl.VertexAttribL3dv = @ptrCast(c.wglGetProcAddress("glVertexAttribL3dv"));
            gl.VertexAttribL4dv = @ptrCast(c.wglGetProcAddress("glVertexAttribL4dv"));
            gl.VertexAttribLPointer = @ptrCast(c.wglGetProcAddress("glVertexAttribLPointer"));
            gl.GetVertexAttribLdv = @ptrCast(c.wglGetProcAddress("glGetVertexAttribLdv"));
            gl.ViewportArrayv = @ptrCast(c.wglGetProcAddress("glViewportArrayv"));
            gl.ViewportIndexedf = @ptrCast(c.wglGetProcAddress("glViewportIndexedf"));
            gl.ViewportIndexedfv = @ptrCast(c.wglGetProcAddress("glViewportIndexedfv"));
            gl.ScissorArrayv = @ptrCast(c.wglGetProcAddress("glScissorArrayv"));
            gl.ScissorIndexed = @ptrCast(c.wglGetProcAddress("glScissorIndexed"));
            gl.ScissorIndexedv = @ptrCast(c.wglGetProcAddress("glScissorIndexedv"));
            gl.DepthRangeArrayv = @ptrCast(c.wglGetProcAddress("glDepthRangeArrayv"));
            gl.DepthRangeIndexed = @ptrCast(c.wglGetProcAddress("glDepthRangeIndexed"));
            gl.GetFloati_v = @ptrCast(c.wglGetProcAddress("glGetFloati_v"));
            gl.GetDoublei_v = @ptrCast(c.wglGetProcAddress("glGetDoublei_v"));
        }

        if (version >= 420) {
            gl.DrawArraysInstancedBaseInstance = @ptrCast(c.wglGetProcAddress("glDrawArraysInstancedBaseInstance"));
            gl.DrawElementsInstancedBaseInstance = @ptrCast(c.wglGetProcAddress("glDrawElementsInstancedBaseInstance"));
            gl.DrawElementsInstancedBaseVertexBaseInstance = @ptrCast(c.wglGetProcAddress("glDrawElementsInstancedBaseVertexBaseInstance"));
            gl.GetInternalformativ = @ptrCast(c.wglGetProcAddress("glGetInternalformativ"));
            gl.GetActiveAtomicCounterBufferiv = @ptrCast(c.wglGetProcAddress("glGetActiveAtomicCounterBufferiv"));
            gl.BindImageTexture = @ptrCast(c.wglGetProcAddress("glBindImageTexture"));
            gl.MemoryBarrier = @ptrCast(c.wglGetProcAddress("glMemoryBarrier"));
            gl.TexStorage1D = @ptrCast(c.wglGetProcAddress("glTexStorage1D"));
            gl.TexStorage2D = @ptrCast(c.wglGetProcAddress("glTexStorage2D"));
            gl.TexStorage3D = @ptrCast(c.wglGetProcAddress("glTexStorage3D"));
            gl.DrawTransformFeedbackInstanced = @ptrCast(c.wglGetProcAddress("glDrawTransformFeedbackInstanced"));
            gl.DrawTransformFeedbackStreamInstanced = @ptrCast(c.wglGetProcAddress("glDrawTransformFeedbackStreamInstanced"));
        }

        if (version >= 430) {
            gl.ClearBufferData = @ptrCast(c.wglGetProcAddress("glClearBufferData"));
            gl.ClearBufferSubData = @ptrCast(c.wglGetProcAddress("glClearBufferSubData"));
            gl.DispatchCompute = @ptrCast(c.wglGetProcAddress("glDispatchCompute"));
            gl.DispatchComputeIndirect = @ptrCast(c.wglGetProcAddress("glDispatchComputeIndirect"));
            gl.CopyImageSubData = @ptrCast(c.wglGetProcAddress("glCopyImageSubData"));
            gl.FramebufferParameteri = @ptrCast(c.wglGetProcAddress("glFramebufferParameteri"));
            gl.GetFramebufferParameteriv = @ptrCast(c.wglGetProcAddress("glGetFramebufferParameteriv"));
            gl.GetInternalformati64v = @ptrCast(c.wglGetProcAddress("glGetInternalformati64v"));
            gl.InvalidateTexSubImage = @ptrCast(c.wglGetProcAddress("glInvalidateTexSubImage"));
            gl.InvalidateTexImage = @ptrCast(c.wglGetProcAddress("glInvalidateTexImage"));
            gl.InvalidateBufferSubData = @ptrCast(c.wglGetProcAddress("glInvalidateBufferSubData"));
            gl.InvalidateBufferData = @ptrCast(c.wglGetProcAddress("glInvalidateBufferData"));
            gl.InvalidateFramebuffer = @ptrCast(c.wglGetProcAddress("glInvalidateFramebuffer"));
            gl.InvalidateSubFramebuffer = @ptrCast(c.wglGetProcAddress("glInvalidateSubFramebuffer"));
            gl.MultiDrawArraysIndirect = @ptrCast(c.wglGetProcAddress("glMultiDrawArraysIndirect"));
            gl.MultiDrawElementsIndirect = @ptrCast(c.wglGetProcAddress("glMultiDrawElementsIndirect"));
            gl.GetProgramInterfaceiv = @ptrCast(c.wglGetProcAddress("glGetProgramInterfaceiv"));
            gl.GetProgramResourceIndex = @ptrCast(c.wglGetProcAddress("glGetProgramResourceIndex"));
            gl.GetProgramResourceName = @ptrCast(c.wglGetProcAddress("glGetProgramResourceName"));
            gl.GetProgramResourceiv = @ptrCast(c.wglGetProcAddress("glGetProgramResourceiv"));
            gl.GetProgramResourceLocation = @ptrCast(c.wglGetProcAddress("glGetProgramResourceLocation"));
            gl.GetProgramResourceLocationIndex = @ptrCast(c.wglGetProcAddress("glGetProgramResourceLocationIndex"));
            gl.ShaderStorageBlockBinding = @ptrCast(c.wglGetProcAddress("glShaderStorageBlockBinding"));
            gl.TexBufferRange = @ptrCast(c.wglGetProcAddress("glTexBufferRange"));
            gl.TexStorage2DMultisample = @ptrCast(c.wglGetProcAddress("glTexStorage2DMultisample"));
            gl.TexStorage3DMultisample = @ptrCast(c.wglGetProcAddress("glTexStorage3DMultisample"));
            gl.TextureView = @ptrCast(c.wglGetProcAddress("glTextureView"));
            gl.BindVertexBuffer = @ptrCast(c.wglGetProcAddress("glBindVertexBuffer"));
            gl.VertexAttribFormat = @ptrCast(c.wglGetProcAddress("glVertexAttribFormat"));
            gl.VertexAttribIFormat = @ptrCast(c.wglGetProcAddress("glVertexAttribIFormat"));
            gl.VertexAttribLFormat = @ptrCast(c.wglGetProcAddress("glVertexAttribLFormat"));
            gl.VertexAttribBinding = @ptrCast(c.wglGetProcAddress("glVertexAttribBinding"));
            gl.VertexBindingDivisor = @ptrCast(c.wglGetProcAddress("glVertexBindingDivisor"));
            gl.DebugMessageControl = @ptrCast(c.wglGetProcAddress("glDebugMessageControl"));
            gl.DebugMessageInsert = @ptrCast(c.wglGetProcAddress("glDebugMessageInsert"));
            gl.DebugMessageCallback = @ptrCast(c.wglGetProcAddress("glDebugMessageCallback"));
            gl.GetDebugMessageLog = @ptrCast(c.wglGetProcAddress("glGetDebugMessageLog"));
            gl.PushDebugGroup = @ptrCast(c.wglGetProcAddress("glPushDebugGroup"));
            gl.PopDebugGroup = @ptrCast(c.wglGetProcAddress("glPopDebugGroup"));
            gl.ObjectLabel = @ptrCast(c.wglGetProcAddress("glObjectLabel"));
            gl.GetObjectLabel = @ptrCast(c.wglGetProcAddress("glGetObjectLabel"));
            gl.ObjectPtrLabel = @ptrCast(c.wglGetProcAddress("glObjectPtrLabel"));
            gl.GetObjectPtrLabel = @ptrCast(c.wglGetProcAddress("glGetObjectPtrLabel"));
        }

        if (version >= 440) {
            gl.BufferStorage = @ptrCast(c.wglGetProcAddress("glBufferStorage"));
            gl.ClearTexImage = @ptrCast(c.wglGetProcAddress("glClearTexImage"));
            gl.ClearTexSubImage = @ptrCast(c.wglGetProcAddress("glClearTexSubImage"));
            gl.BindBuffersBase = @ptrCast(c.wglGetProcAddress("glBindBuffersBase"));
            gl.BindBuffersRange = @ptrCast(c.wglGetProcAddress("glBindBuffersRange"));
            gl.BindTextures = @ptrCast(c.wglGetProcAddress("glBindTextures"));
            gl.BindSamplers = @ptrCast(c.wglGetProcAddress("glBindSamplers"));
            gl.BindImageTextures = @ptrCast(c.wglGetProcAddress("glBindImageTextures"));
            gl.BindVertexBuffers = @ptrCast(c.wglGetProcAddress("glBindVertexBuffers"));
        }

        if (version >= 450) {
            gl.ClipControl = @ptrCast(c.wglGetProcAddress("glClipControl"));
            gl.CreateTransformFeedbacks = @ptrCast(c.wglGetProcAddress("glCreateTransformFeedbacks"));
            gl.TransformFeedbackBufferBase = @ptrCast(c.wglGetProcAddress("glTransformFeedbackBufferBase"));
            gl.TransformFeedbackBufferRange = @ptrCast(c.wglGetProcAddress("glTransformFeedbackBufferRange"));
            gl.GetTransformFeedbackiv = @ptrCast(c.wglGetProcAddress("glGetTransformFeedbackiv"));
            gl.GetTransformFeedbacki_v = @ptrCast(c.wglGetProcAddress("glGetTransformFeedbacki_v"));
            gl.GetTransformFeedbacki64_v = @ptrCast(c.wglGetProcAddress("glGetTransformFeedbacki64_v"));
            gl.CreateBuffers = @ptrCast(c.wglGetProcAddress("glCreateBuffers"));
            gl.NamedBufferStorage = @ptrCast(c.wglGetProcAddress("glNamedBufferStorage"));
            gl.NamedBufferData = @ptrCast(c.wglGetProcAddress("glNamedBufferData"));
            gl.NamedBufferSubData = @ptrCast(c.wglGetProcAddress("glNamedBufferSubData"));
            gl.CopyNamedBufferSubData = @ptrCast(c.wglGetProcAddress("glCopyNamedBufferSubData"));
            gl.ClearNamedBufferData = @ptrCast(c.wglGetProcAddress("glClearNamedBufferData"));
            gl.ClearNamedBufferSubData = @ptrCast(c.wglGetProcAddress("glClearNamedBufferSubData"));
            gl.MapNamedBuffer = @ptrCast(c.wglGetProcAddress("glMapNamedBuffer"));
            gl.MapNamedBufferRange = @ptrCast(c.wglGetProcAddress("glMapNamedBufferRange"));
            gl.UnmapNamedBuffer = @ptrCast(c.wglGetProcAddress("glUnmapNamedBuffer"));
            gl.FlushMappedNamedBufferRange = @ptrCast(c.wglGetProcAddress("glFlushMappedNamedBufferRange"));
            gl.GetNamedBufferParameteriv = @ptrCast(c.wglGetProcAddress("glGetNamedBufferParameteriv"));
            gl.GetNamedBufferParameteri64v = @ptrCast(c.wglGetProcAddress("glGetNamedBufferParameteri64v"));
            gl.GetNamedBufferPointerv = @ptrCast(c.wglGetProcAddress("glGetNamedBufferPointerv"));
            gl.GetNamedBufferSubData = @ptrCast(c.wglGetProcAddress("glGetNamedBufferSubData"));
            gl.CreateFramebuffers = @ptrCast(c.wglGetProcAddress("glCreateFramebuffers"));
            gl.NamedFramebufferRenderbuffer = @ptrCast(c.wglGetProcAddress("glNamedFramebufferRenderbuffer"));
            gl.NamedFramebufferParameteri = @ptrCast(c.wglGetProcAddress("glNamedFramebufferParameteri"));
            gl.NamedFramebufferTexture = @ptrCast(c.wglGetProcAddress("glNamedFramebufferTexture"));
            gl.NamedFramebufferTextureLayer = @ptrCast(c.wglGetProcAddress("glNamedFramebufferTextureLayer"));
            gl.NamedFramebufferDrawBuffer = @ptrCast(c.wglGetProcAddress("glNamedFramebufferDrawBuffer"));
            gl.NamedFramebufferDrawBuffers = @ptrCast(c.wglGetProcAddress("glNamedFramebufferDrawBuffers"));
            gl.NamedFramebufferReadBuffer = @ptrCast(c.wglGetProcAddress("glNamedFramebufferReadBuffer"));
            gl.InvalidateNamedFramebufferData = @ptrCast(c.wglGetProcAddress("glInvalidateNamedFramebufferData"));
            gl.InvalidateNamedFramebufferSubData = @ptrCast(c.wglGetProcAddress("glInvalidateNamedFramebufferSubData"));
            gl.ClearNamedFramebufferiv = @ptrCast(c.wglGetProcAddress("glClearNamedFramebufferiv"));
            gl.ClearNamedFramebufferuiv = @ptrCast(c.wglGetProcAddress("glClearNamedFramebufferuiv"));
            gl.ClearNamedFramebufferfv = @ptrCast(c.wglGetProcAddress("glClearNamedFramebufferfv"));
            gl.ClearNamedFramebufferfi = @ptrCast(c.wglGetProcAddress("glClearNamedFramebufferfi"));
            gl.BlitNamedFramebuffer = @ptrCast(c.wglGetProcAddress("glBlitNamedFramebuffer"));
            gl.CheckNamedFramebufferStatus = @ptrCast(c.wglGetProcAddress("glCheckNamedFramebufferStatus"));
            gl.GetNamedFramebufferParameteriv = @ptrCast(c.wglGetProcAddress("glGetNamedFramebufferParameteriv"));
            gl.GetNamedFramebufferAttachmentParameteriv = @ptrCast(c.wglGetProcAddress("glGetNamedFramebufferAttachmentParameteriv"));
            gl.CreateRenderbuffers = @ptrCast(c.wglGetProcAddress("glCreateRenderbuffers"));
            gl.NamedRenderbufferStorage = @ptrCast(c.wglGetProcAddress("glNamedRenderbufferStorage"));
            gl.NamedRenderbufferStorageMultisample = @ptrCast(c.wglGetProcAddress("glNamedRenderbufferStorageMultisample"));
            gl.GetNamedRenderbufferParameteriv = @ptrCast(c.wglGetProcAddress("glGetNamedRenderbufferParameteriv"));
            gl.CreateTextures = @ptrCast(c.wglGetProcAddress("glCreateTextures"));
            gl.TextureBuffer = @ptrCast(c.wglGetProcAddress("glTextureBuffer"));
            gl.TextureBufferRange = @ptrCast(c.wglGetProcAddress("glTextureBufferRange"));
            gl.TextureStorage1D = @ptrCast(c.wglGetProcAddress("glTextureStorage1D"));
            gl.TextureStorage2D = @ptrCast(c.wglGetProcAddress("glTextureStorage2D"));
            gl.TextureStorage3D = @ptrCast(c.wglGetProcAddress("glTextureStorage3D"));
            gl.TextureStorage2DMultisample = @ptrCast(c.wglGetProcAddress("glTextureStorage2DMultisample"));
            gl.TextureStorage3DMultisample = @ptrCast(c.wglGetProcAddress("glTextureStorage3DMultisample"));
            gl.TextureSubImage1D = @ptrCast(c.wglGetProcAddress("glTextureSubImage1D"));
            gl.TextureSubImage2D = @ptrCast(c.wglGetProcAddress("glTextureSubImage2D"));
            gl.TextureSubImage3D = @ptrCast(c.wglGetProcAddress("glTextureSubImage3D"));
            gl.CompressedTextureSubImage1D = @ptrCast(c.wglGetProcAddress("glCompressedTextureSubImage1D"));
            gl.CompressedTextureSubImage2D = @ptrCast(c.wglGetProcAddress("glCompressedTextureSubImage2D"));
            gl.CompressedTextureSubImage3D = @ptrCast(c.wglGetProcAddress("glCompressedTextureSubImage3D"));
            gl.CopyTextureSubImage1D = @ptrCast(c.wglGetProcAddress("glCopyTextureSubImage1D"));
            gl.CopyTextureSubImage2D = @ptrCast(c.wglGetProcAddress("glCopyTextureSubImage2D"));
            gl.CopyTextureSubImage3D = @ptrCast(c.wglGetProcAddress("glCopyTextureSubImage3D"));
            gl.TextureParameterf = @ptrCast(c.wglGetProcAddress("glTextureParameterf"));
            gl.TextureParameterfv = @ptrCast(c.wglGetProcAddress("glTextureParameterfv"));
            gl.TextureParameteri = @ptrCast(c.wglGetProcAddress("glTextureParameteri"));
            gl.TextureParameterIiv = @ptrCast(c.wglGetProcAddress("glTextureParameterIiv"));
            gl.TextureParameterIuiv = @ptrCast(c.wglGetProcAddress("glTextureParameterIuiv"));
            gl.TextureParameteriv = @ptrCast(c.wglGetProcAddress("glTextureParameteriv"));
            gl.GenerateTextureMipmap = @ptrCast(c.wglGetProcAddress("glGenerateTextureMipmap"));
            gl.BindTextureUnit = @ptrCast(c.wglGetProcAddress("glBindTextureUnit"));
            gl.GetTextureImage = @ptrCast(c.wglGetProcAddress("glGetTextureImage"));
            gl.GetCompressedTextureImage = @ptrCast(c.wglGetProcAddress("glGetCompressedTextureImage"));
            gl.GetTextureLevelParameterfv = @ptrCast(c.wglGetProcAddress("glGetTextureLevelParameterfv"));
            gl.GetTextureLevelParameteriv = @ptrCast(c.wglGetProcAddress("glGetTextureLevelParameteriv"));
            gl.GetTextureParameterfv = @ptrCast(c.wglGetProcAddress("glGetTextureParameterfv"));
            gl.GetTextureParameterIiv = @ptrCast(c.wglGetProcAddress("glGetTextureParameterIiv"));
            gl.GetTextureParameterIuiv = @ptrCast(c.wglGetProcAddress("glGetTextureParameterIuiv"));
            gl.GetTextureParameteriv = @ptrCast(c.wglGetProcAddress("glGetTextureParameteriv"));
            gl.CreateVertexArrays = @ptrCast(c.wglGetProcAddress("glCreateVertexArrays"));
            gl.DisableVertexArrayAttrib = @ptrCast(c.wglGetProcAddress("glDisableVertexArrayAttrib"));
            gl.EnableVertexArrayAttrib = @ptrCast(c.wglGetProcAddress("glEnableVertexArrayAttrib"));
            gl.VertexArrayElementBuffer = @ptrCast(c.wglGetProcAddress("glVertexArrayElementBuffer"));
            gl.VertexArrayVertexBuffer = @ptrCast(c.wglGetProcAddress("glVertexArrayVertexBuffer"));
            gl.VertexArrayVertexBuffers = @ptrCast(c.wglGetProcAddress("glVertexArrayVertexBuffers"));
            gl.VertexArrayAttribBinding = @ptrCast(c.wglGetProcAddress("glVertexArrayAttribBinding"));
            gl.VertexArrayAttribFormat = @ptrCast(c.wglGetProcAddress("glVertexArrayAttribFormat"));
            gl.VertexArrayAttribIFormat = @ptrCast(c.wglGetProcAddress("glVertexArrayAttribIFormat"));
            gl.VertexArrayAttribLFormat = @ptrCast(c.wglGetProcAddress("glVertexArrayAttribLFormat"));
            gl.VertexArrayBindingDivisor = @ptrCast(c.wglGetProcAddress("glVertexArrayBindingDivisor"));
            gl.GetVertexArrayiv = @ptrCast(c.wglGetProcAddress("glGetVertexArrayiv"));
            gl.GetVertexArrayIndexediv = @ptrCast(c.wglGetProcAddress("glGetVertexArrayIndexediv"));
            gl.GetVertexArrayIndexed64iv = @ptrCast(c.wglGetProcAddress("glGetVertexArrayIndexed64iv"));
            gl.CreateSamplers = @ptrCast(c.wglGetProcAddress("glCreateSamplers"));
            gl.CreateProgramPipelines = @ptrCast(c.wglGetProcAddress("glCreateProgramPipelines"));
            gl.CreateQueries = @ptrCast(c.wglGetProcAddress("glCreateQueries"));
            gl.GetQueryBufferObjecti64v = @ptrCast(c.wglGetProcAddress("glGetQueryBufferObjecti64v"));
            gl.GetQueryBufferObjectiv = @ptrCast(c.wglGetProcAddress("glGetQueryBufferObjectiv"));
            gl.GetQueryBufferObjectui64v = @ptrCast(c.wglGetProcAddress("glGetQueryBufferObjectui64v"));
            gl.GetQueryBufferObjectuiv = @ptrCast(c.wglGetProcAddress("glGetQueryBufferObjectuiv"));
            gl.MemoryBarrierByRegion = @ptrCast(c.wglGetProcAddress("glMemoryBarrierByRegion"));
            gl.GetTextureSubImage = @ptrCast(c.wglGetProcAddress("glGetTextureSubImage"));
            gl.GetCompressedTextureSubImage = @ptrCast(c.wglGetProcAddress("glGetCompressedTextureSubImage"));
            gl.GetGraphicsResetStatus = @ptrCast(c.wglGetProcAddress("glGetGraphicsResetStatus"));
            gl.GetnCompressedTexImage = @ptrCast(c.wglGetProcAddress("glGetnCompressedTexImage"));
            gl.GetnTexImage = @ptrCast(c.wglGetProcAddress("glGetnTexImage"));
            gl.GetnUniformdv = @ptrCast(c.wglGetProcAddress("glGetnUniformdv"));
            gl.GetnUniformfv = @ptrCast(c.wglGetProcAddress("glGetnUniformfv"));
            gl.GetnUniformiv = @ptrCast(c.wglGetProcAddress("glGetnUniformiv"));
            gl.GetnUniformuiv = @ptrCast(c.wglGetProcAddress("glGetnUniformuiv"));
            gl.ReadnPixels = @ptrCast(c.wglGetProcAddress("glReadnPixels"));
            gl.TextureBarrier = @ptrCast(c.wglGetProcAddress("glTextureBarrier"));
        }

        if (version >= 460) {
            gl.SpecializeShader = @ptrCast(c.wglGetProcAddress("glSpecializeShader"));
            gl.MultiDrawArraysIndirectCount = @ptrCast(c.wglGetProcAddress("glMultiDrawArraysIndirectCount"));
            gl.MultiDrawElementsIndirectCount = @ptrCast(c.wglGetProcAddress("glMultiDrawElementsIndirectCount"));
            gl.PolygonOffsetClamp = @ptrCast(c.wglGetProcAddress("glPolygonOffsetClamp"));
        }
    }
};
