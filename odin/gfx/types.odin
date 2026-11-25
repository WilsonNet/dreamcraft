// raylib-compatible types (mirrors vendor:raylib so client code compiles unchanged).
// Copied from Odin's vendor:raylib bindings (zlib/libpng license, see vendor/raylib/LICENSE).
package gfx

import "core:c"


VERSION_MAJOR :: 6
VERSION_MINOR :: 2
VERSION_PATCH :: 0
VERSION :: "6.2"

PI :: 3.14159265358979323846
DEG2RAD :: PI/180.0
RAD2DEG :: 180.0/PI


// Some Basic Colors
// NOTE: Custom raylib color palette for amazing visuals on WHITE background
LIGHTGRAY  :: Color{ 200, 200, 200, 255 }   // Light Gray
GRAY       :: Color{ 130, 130, 130, 255 }   // Gray
DARKGRAY   :: Color{ 80, 80, 80, 255 }      // Dark Gray
YELLOW     :: Color{ 253, 249, 0, 255 }     // Yellow
GOLD       :: Color{ 255, 203, 0, 255 }     // Gold
ORANGE     :: Color{ 255, 161, 0, 255 }     // Orange
PINK       :: Color{ 255, 109, 194, 255 }   // Pink
RED        :: Color{ 230, 41, 55, 255 }     // Red
MAROON     :: Color{ 190, 33, 55, 255 }     // Maroon
GREEN      :: Color{ 0, 228, 48, 255 }      // Green
LIME       :: Color{ 0, 158, 47, 255 }      // Lime
DARKGREEN  :: Color{ 0, 117, 44, 255 }      // Dark Green
SKYBLUE    :: Color{ 102, 191, 255, 255 }   // Sky Blue
BLUE       :: Color{ 0, 121, 241, 255 }     // Blue
DARKBLUE   :: Color{ 0, 82, 172, 255 }      // Dark Blue
PURPLE     :: Color{ 200, 122, 255, 255 }   // Purple
VIOLET     :: Color{ 135, 60, 190, 255 }    // Violet
DARKPURPLE :: Color{ 112, 31, 126, 255 }    // Dark Purple
BEIGE      :: Color{ 211, 176, 131, 255 }   // Beige
BROWN      :: Color{ 127, 106, 79, 255 }    // Brown
DARKBROWN  :: Color{ 76, 63, 47, 255 }      // Dark Brown

WHITE      :: Color{ 255, 255, 255, 255 }   // White
BLACK      :: Color{ 0, 0, 0, 255 }         // Black
BLANK      :: Color{ 0, 0, 0, 0 }           // Blank (Transparent)
MAGENTA    :: Color{ 255, 0, 255, 255 }     // Magenta
RAYWHITE   :: Color{ 245, 245, 245, 255 }   // My own White (raylib logo)

// Vector2 type
Vector2 :: [2]f32
// Vector3 type
Vector3 :: [3]f32
// Vector4 type
Vector4 :: [4]f32

// Quaternion type
Quaternion :: quaternion128

// Matrix type (right handed, stored row major)
Matrix :: #row_major matrix[4, 4]f32


// Color, 4 components, R8G8B8A8 (32bit)
//
// Note: In Raylib this is a struct. But here we use a fixed array, so that .rgba swizzling etc work.
Color :: distinct [4]u8

// Rectangle, 4 components
Rectangle :: struct {
	x:      f32,                  // Rectangle top-left corner position x
	y:      f32,                  // Rectangle top-left corner position y
	width:  f32,                  // Rectangle width
	height: f32,                  // Rectangle height
}

// Image, pixel data stored in CPU memory (RAM)
Image :: struct {
	data:    rawptr,              // Image raw data
	width:   c.int,               // Image base width
	height:  c.int,               // Image base height
	mipmaps: c.int,               // Mipmap levels, 1 by default
	format:  PixelFormat,         // Data format (PixelFormat type)
}

// Texture, tex data stored in GPU memory (VRAM)
Texture :: struct {
	id:      c.uint,              // OpenGL texture id
	width:   c.int,               // Texture base width
	height:  c.int,               // Texture base height
	mipmaps: c.int,               // Mipmap levels, 1 by default
	format:  PixelFormat,         // Data format (PixelFormat type)
}

// Texture2D, same as Texture
Texture2D :: Texture

// TextureCubemap, same as Texture
TextureCubemap :: Texture

// RenderTexture, fbo for texture rendering
RenderTexture :: struct {
	id:       c.uint,             // OpenGL framebuffer object id
	texture: Texture,             // Color buffer attachment texture
	depth:   Texture,             // Depth buffer attachment texture
}

// RenderTexture2D type, same as RenderTexture
RenderTexture2D :: RenderTexture

// NPatchInfo, n-patch layout info
NPatchInfo :: struct {
	source: Rectangle,            // Texture source rectangle
	left:   c.int,                // Left border offset
	top:    c.int,                // Top border offset
	right:  c.int,                // Right border offset
	bottom: c.int,                // Bottom border offset
	layout: NPatchLayout,         // Layout of the n-patch: 3x3, 1x3 or 3x1
}

// GlyphInfo, font characters glyphs info
GlyphInfo :: struct {
	value:    rune,               // Character value (Unicode)
	offsetX:  c.int,              // Character offset X when drawing
	offsetY:  c.int,              // Character offset Y when drawing
	advanceX: c.int,              // Character advance position X
	image:    Image,              // Character image data
}

// Font, font texture and GlyphInfo array data
Font :: struct {
	baseSize:     c.int,          // Base size (default chars height)
	glyphCount:   c.int,          // Number of characters
	glyphPadding: c.int,          // Padding around the chars
	texture:      Texture2D,      // Characters texture atlas
	recs:         [^]Rectangle,   // Characters rectangles in texture
	glyphs:       [^]GlyphInfo,   // Characters info data
}

// Camera, defines position/orientation in 3d space
Camera3D :: struct {
	position:   Vector3,          // Camera position
	target:     Vector3,          // Camera target it looks-at
	up:         Vector3,          // Camera up vector (rotation over its axis)
	fovy:       f32,              // Camera field-of-view aperture in Y (degrees) in perspective, used as near plane height in world units in orthographic
	projection: CameraProjection, // Camera projection: `.PERSPECTIVE` or `.ORTHOGRAPHIC`
}

Camera :: Camera3D                    // Camera type fallback, defaults to Camera3D

// Camera2D, defines position/orientation in 2d space
Camera2D :: struct {
	offset:   Vector2,            // Camera offset (displacement from target)
	target:   Vector2,            // Camera target (rotation and zoom origin)
	rotation: f32,                // Camera rotation in degrees
	zoom:     f32,                // Camera zoom (scaling), should be 1.0f by default
}

// Mesh, vertex data and vao/vbo
// NOTE: Data stored in CPU memory (and GPU)
Mesh :: struct {
	vertexCount:   c.int,         // Number of vertices stored in arrays
	triangleCount: c.int,         // Number of triangles stored (indexed or not)

	// Default vertex data
	vertices:     [^]f32,         // Vertex position (XYZ - 3 components per vertex) (shader-location = 0)
	texcoords:    [^]f32,         // Vertex texture coordinates (UV - 2 components per vertex) (shader-location = 1)
	texcoords2:   [^]f32,         // Vertex second texture coordinates (useful for lightmaps) (shader-location = 5)
	normals:      [^]f32,         // Vertex normals (XYZ - 3 components per vertex) (shader-location = 2)
	tangents:     [^]f32,         // Vertex tangents (XYZW - 4 components per vertex) (shader-location = 4)
	colors:       [^]u8,          // Vertex colors (RGBA - 4 components per vertex) (shader-location = 3)
	indices:      [^]u16,         // Vertex indices (in case vertex data comes indexed)

	// Skin data for animation
	boneCount:    c.int,          // Number of bones (MAX: 256 bones)
	boneIndices:  [^]u8,          // Vertex bone indices, up to 4 bones influence by vertex (skinning) (shader-location = 6)
	boneWeights:  [^]f32,         // Vertex bone weight, up to 4 bones influence by vertex (skinning) (shader-location = 7)

	// Runtime animation vertex data (CPU skinning)
	// NOTE: In case of GPU skinning, not used, pointers are NULL
	animVertices: [^]f32,         // Animated vertex positions (after bones transformations)
	animNormals:  [^]f32,         // Animated normals (after bones transformations)

	// OpenGL identifiers
	vaoId:        u32,            // OpenGL Vertex Array Object id
	vboId:        [^]u32,         // OpenGL Vertex Buffer Objects id (default vertex data)
}

// Shader
Shader :: struct {
	id:   c.uint,                 // Shader program id
	locs: [^]c.int,               // Shader locations array (MAX_SHADER_LOCATIONS)
}

// MaterialMap
MaterialMap :: struct {
	texture: Texture2D,           // Material map texture
	color:   Color,               // Material map color
	value:   f32,                 // Material map value
}

// Material, includes shader and maps
Material :: struct {
	shader: Shader,               // Material shader
	maps:   [^]MaterialMap,       // Material maps array (MAX_MATERIAL_MAPS)
	params: [4]f32,               // Material generic parameters (if required)
}

// Transform, vertex transformation data
Transform :: struct {
	translation: Vector3,         // Translation
	rotation:    Quaternion,      // Rotation
	scale:       Vector3,         // Scale
}

// Anim pose, an array of Transform[]
ModelAnimPose :: [^]Transform

// Bone, skeletal animation bone
BoneInfo :: struct {
	name:   [32]byte `fmt:"s,0"`, // Bone name
	parent: c.int,                // Bone parent
}

// Skeleton, animation bones hierarchy
ModelSkeleton :: struct {
	boneCount: c.uint,            // Number of bones
	bones:     [^]BoneInfo,       // Bones information (skeleton)
	bindPose:  ModelAnimPose,     // Bones base transformation (Transform[])
}

// Model, meshes, materials and animation data
Model :: struct #align(align_of(uintptr)) {
	transform: Matrix,            // Local transform matrix

	meshCount:     c.int,         // Number of meshes
	materialCount: c.int,         // Number of materials
	meshes:        [^]Mesh,       // Meshes array
	materials:     [^]Material,   // Materials array
	meshMaterial:  [^]c.int,      // Mesh material number

	// Animation data
	skeleton:      ModelSkeleton, // Skeleton for animation

	// Runtime animation data (CPU/GPU skinning)
	currentPose:   ModelAnimPose, // Current animation pose (Transform[])
	boneMatrices:  [^]Matrix,     // Bones animated transformation matrices
}

// ModelAnimation, contains a full animation sequence
ModelAnimation :: struct {
	name:          [32]byte `fmt:"s,0"`, // Animation name

	boneCount:     c.uint,               // Number of bones (per pose)
	keyframeCount: c.int,                // Number of animation key frames
	keyframePoses: [^][^]Transform,      // Animation sequence keyframe poses [keyframe][pose]
}

// Ray, ray for raycasting
Ray :: struct {
	position:  Vector3,           // Ray position (origin)
	direction: Vector3,           // Ray direction (normalized)
}

// RayCollision, ray hit information
RayCollision :: struct {
	hit:      bool,               // Did the ray hit something?
	distance: f32,                // Distance to nearest hit
	point:    Vector3,            // Point of the nearest hit
	normal:   Vector3,            // Surface normal of hit
}

// Bounding box type
BoundingBox :: struct {
	min: Vector3,                 // Minimum vertex box-corner
	max: Vector3,                 // Maximum vertex box-corner
}

// By default all flags are set to 0
ConfigFlag :: enum c.int {
	VSYNC_HINT               = 6,     // Set to try enabling V-Sync on GPU
	FULLSCREEN_MODE          = 1,     // Set to run program in fullscreen
	WINDOW_RESIZABLE         = 2,     // Set to allow resizable window
	WINDOW_UNDECORATED       = 3,     // Set to disable window decoration (frame and buttons)
	WINDOW_HIDDEN            = 7,     // Set to hide window
	WINDOW_MINIMIZED         = 9,     // Set to minimize window (iconify)
	WINDOW_MAXIMIZED         = 10,    // Set to maximize window (expanded to monitor)
	WINDOW_UNFOCUSED         = 11,    // Set to window non focused
	WINDOW_TOPMOST           = 12,    // Set to window always on top
	WINDOW_ALWAYS_RUN        = 8,     // Set to allow windows running while minimized
	WINDOW_TRANSPARENT       = 4,     // Set to allow transparent framebuffer
	WINDOW_HIGHDPI           = 13,    // Set to support HighDPI
	WINDOW_MOUSE_PASSTHROUGH = 14,    // Set to support mouse passthrough, only supported when FLAG_WINDOW_UNDECORATED
	BORDERLESS_WINDOWED_MODE = 15,    // Set to run program in borderless windowed mode
	MSAA_4X_HINT             = 5,     // Set to try enabling MSAA 4X
	INTERLACED_HINT          = 16,    // Set to try enabling interlaced video format (for V3D)
}
ConfigFlags :: distinct bit_set[ConfigFlag; c.int]

// Trace log level
// NOTE: Organized by priority level
TraceLogLevel :: enum c.int {
	ALL = 0,                          // Display all logs
	TRACE,                            // Trace logging, intended for internal use only
	DEBUG,                            // Debug logging, used for internal debugging, it should be disabled on release builds
	INFO,                             // Info logging, used for program execution info
	WARNING,                          // Warning logging, used on recoverable failures
	ERROR,                            // Error logging, used on unrecoverable failures
	FATAL,                            // Fatal logging, used to abort program: exit(EXIT_FAILURE)
	NONE,                             // Disable logging
}

// Keyboard keys (US keyboard layout)
// NOTE: Use GetKeyPressed() to allow redefining required keys for alternative layouts
KeyboardKey :: enum c.int {
	KEY_NULL         = 0,             // Key: NULL, used for no key pressed
	// Alphanumeric keys
	APOSTROPHE      = 39,             // Key: '
	COMMA           = 44,             // Key: ,
	MINUS           = 45,             // Key: -
	PERIOD          = 46,             // Key: .
	SLASH           = 47,             // Key: /
	ZERO            = 48,             // Key: 0
	ONE             = 49,             // Key: 1
	TWO             = 50,             // Key: 2
	THREE           = 51,             // Key: 3
	FOUR            = 52,             // Key: 4
	FIVE            = 53,             // Key: 5
	SIX             = 54,             // Key: 6
	SEVEN           = 55,             // Key: 7
	EIGHT           = 56,             // Key: 8
	NINE            = 57,             // Key: 9
	SEMICOLON       = 59,             // Key: ;
	EQUAL           = 61,             // Key: =
	A               = 65,             // Key: A | a
	B               = 66,             // Key: B | b
	C               = 67,             // Key: C | c
	D               = 68,             // Key: D | d
	E               = 69,             // Key: E | e
	F               = 70,             // Key: F | f
	G               = 71,             // Key: G | g
	H               = 72,             // Key: H | h
	I               = 73,             // Key: I | i
	J               = 74,             // Key: J | j
	K               = 75,             // Key: K | k
	L               = 76,             // Key: L | l
	M               = 77,             // Key: M | m
	N               = 78,             // Key: N | n
	O               = 79,             // Key: O | o
	P               = 80,             // Key: P | p
	Q               = 81,             // Key: Q | q
	R               = 82,             // Key: R | r
	S               = 83,             // Key: S | s
	T               = 84,             // Key: T | t
	U               = 85,             // Key: U | u
	V               = 86,             // Key: V | v
	W               = 87,             // Key: W | w
	X               = 88,             // Key: X | x
	Y               = 89,             // Key: Y | y
	Z               = 90,             // Key: Z | z
	LEFT_BRACKET    = 91,             // Key: [
	BACKSLASH       = 92,             // Key: '\'
	RIGHT_BRACKET   = 93,             // Key: ]
	GRAVE           = 96,             // Key: `
	// Function keys
	SPACE           = 32,             // Key: Space
	ESCAPE          = 256,            // Key: Esc
	ENTER           = 257,            // Key: Enter
	TAB             = 258,            // Key: Tab
	BACKSPACE       = 259,            // Key: Backspace
	INSERT          = 260,            // Key: Ins
	DELETE          = 261,            // Key: Del
	RIGHT           = 262,            // Key: Cursor right
	LEFT            = 263,            // Key: Cursor left
	DOWN            = 264,            // Key: Cursor down
	UP              = 265,            // Key: Cursor up
	PAGE_UP         = 266,            // Key: Page up
	PAGE_DOWN       = 267,            // Key: Page down
	HOME            = 268,            // Key: Home
	END             = 269,            // Key: End
	CAPS_LOCK       = 280,            // Key: Caps lock
	SCROLL_LOCK     = 281,            // Key: Scroll down
	NUM_LOCK        = 282,            // Key: Num lock
	PRINT_SCREEN    = 283,            // Key: Print screen
	PAUSE           = 284,            // Key: Pause
	F1              = 290,            // Key: F1
	F2              = 291,            // Key: F2
	F3              = 292,            // Key: F3
	F4              = 293,            // Key: F4
	F5              = 294,            // Key: F5
	F6              = 295,            // Key: F6
	F7              = 296,            // Key: F7
	F8              = 297,            // Key: F8
	F9              = 298,            // Key: F9
	F10             = 299,            // Key: F10
	F11             = 300,            // Key: F11
	F12             = 301,            // Key: F12
	LEFT_SHIFT      = 340,            // Key: Shift left
	LEFT_CONTROL    = 341,            // Key: Control left
	LEFT_ALT        = 342,            // Key: Alt left
	LEFT_SUPER      = 343,            // Key: Super left
	RIGHT_SHIFT     = 344,            // Key: Shift right
	RIGHT_CONTROL   = 345,            // Key: Control right
	RIGHT_ALT       = 346,            // Key: Alt right
	RIGHT_SUPER     = 347,            // Key: Super right
	KB_MENU         = 348,            // Key: KB menu
	// Keypad keys
	KP_0            = 320,            // Key: Keypad 0
	KP_1            = 321,            // Key: Keypad 1
	KP_2            = 322,            // Key: Keypad 2
	KP_3            = 323,            // Key: Keypad 3
	KP_4            = 324,            // Key: Keypad 4
	KP_5            = 325,            // Key: Keypad 5
	KP_6            = 326,            // Key: Keypad 6
	KP_7            = 327,            // Key: Keypad 7
	KP_8            = 328,            // Key: Keypad 8
	KP_9            = 329,            // Key: Keypad 9
	KP_DECIMAL      = 330,            // Key: Keypad .
	KP_DIVIDE       = 331,            // Key: Keypad /
	KP_MULTIPLY     = 332,            // Key: Keypad *
	KP_SUBTRACT     = 333,            // Key: Keypad -
	KP_ADD          = 334,            // Key: Keypad +
	KP_ENTER        = 335,            // Key: Keypad Enter
	KP_EQUAL        = 336,            // Key: Keypad =
	// Android key buttons
	BACK            = 4,              // Key: Android back button
	MENU            = 5,              // Key: Android menu button
	VOLUME_UP       = 24,             // Key: Android volume up button
	VOLUME_DOWN     = 25,             // Key: Android volume down button
}

// Mouse buttons
MouseButton :: enum c.int {
	LEFT    = 0,                      // Mouse button left
	RIGHT   = 1,                      // Mouse button right
	MIDDLE  = 2,                      // Mouse button middle (pressed wheel)
	SIDE    = 3,                      // Mouse button side (advanced mouse device)
	EXTRA   = 4,                      // Mouse button extra (advanced mouse device)
	FORWARD = 5,                      // Mouse button forward (advanced mouse device)
	BACK    = 6,                      // Mouse button back (advanced mouse device)
}

// Mouse cursor
MouseCursor :: enum c.int {
	DEFAULT       = 0,                // Default pointer shape
	ARROW         = 1,                // Arrow shape
	IBEAM         = 2,                // Text writing cursor shape
	CROSSHAIR     = 3,                // Cross shape
	POINTING_HAND = 4,                // Pointing hand cursor
	RESIZE_EW     = 5,                // Horizontal resize/move arrow shape
	RESIZE_NS     = 6,                // Vertical resize/move arrow shape
	RESIZE_NWSE   = 7,                // Top-left to bottom-right diagonal resize/move arrow shape
	RESIZE_NESW   = 8,                // The top-right to bottom-left diagonal resize/move arrow shape
	RESIZE_ALL    = 9,                // The omnidirectional resize/move cursor shape
	NOT_ALLOWED   = 10,               // The operation-not-allowed shape
}

// Gamepad buttons
GamepadButton :: enum c.int {
	UNKNOWN = 0,                      // Unknown button, just for error checking
	LEFT_FACE_UP,                     // Gamepad left DPAD up button
	LEFT_FACE_RIGHT,                  // Gamepad left DPAD right button
	LEFT_FACE_DOWN,                   // Gamepad left DPAD down button
	LEFT_FACE_LEFT,                   // Gamepad left DPAD left button
	RIGHT_FACE_UP,                    // Gamepad right button up (i.e. PS3: Triangle, Xbox: Y)
	RIGHT_FACE_RIGHT,                 // Gamepad right button right (i.e. PS3: Circle, Xbox: B)
	RIGHT_FACE_DOWN,                  // Gamepad right button down (i.e. PS3: Cross, Xbox: A)
	RIGHT_FACE_LEFT,                  // Gamepad right button left (i.e. PS3: Square, Xbox: X)
	LEFT_TRIGGER_1,                   // Gamepad top/back trigger left (first), it could be a trailing button
	LEFT_TRIGGER_2,                   // Gamepad top/back trigger left (second), it could be a trailing button
	RIGHT_TRIGGER_1,                  // Gamepad top/back trigger right (first), it could be a trailing button
	RIGHT_TRIGGER_2,                  // Gamepad top/back trigger right (second), it could be a trailing button
	MIDDLE_LEFT,                      // Gamepad center buttons, left one (i.e. PS3: Select)
	MIDDLE,                           // Gamepad center buttons, middle one (i.e. PS3: PS, Xbox: XBOX)
	MIDDLE_RIGHT,                     // Gamepad center buttons, right one (i.e. PS3: Start)
	LEFT_THUMB,                       // Gamepad joystick pressed button left
	RIGHT_THUMB,                      // Gamepad joystick pressed button right
}

// Gamepad axes
GamepadAxis :: enum c.int {
	LEFT_X        = 0,                // Gamepad left stick X axis
	LEFT_Y        = 1,                // Gamepad left stick Y axis
	RIGHT_X       = 2,                // Gamepad right stick X axis
	RIGHT_Y       = 3,                // Gamepad right stick Y axis
	LEFT_TRIGGER  = 4,                // Gamepad back trigger left, pressure level: [1..-1]
	RIGHT_TRIGGER = 5,                // Gamepad back trigger right, pressure level: [1..-1]
}

// Material map index
MaterialMapIndex :: enum c.int {
	ALBEDO = 0,                       // Albedo material (same as: MATERIAL_MAP_DIFFUSE)
	METALNESS,                        // Metalness material (same as: MATERIAL_MAP_SPECULAR)
	NORMAL,                           // Normal material
	ROUGHNESS,                        // Roughness material
	OCCLUSION,                        // Ambient occlusion material
	EMISSION,                         // Emission material
	HEIGHT,                           // Heightmap material
	CUBEMAP,                          // Cubemap material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
	IRRADIANCE,                       // Irradiance material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
	PREFILTER,                        // Prefilter material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
	BRDF,                             // Brdf material
}

// Shader location index
// NOTE: Some locations are tried to be set automatically on shader loading,
// but only if default attributes/uniforms names are found, check config.h for names
ShaderLocationIndex :: enum c.int {
	VERTEX_POSITION = 0,              // Shader location: vertex attribute: position
	VERTEX_TEXCOORD01,                // Shader location: vertex attribute: texcoord01
	VERTEX_TEXCOORD02,                // Shader location: vertex attribute: texcoord02
	VERTEX_NORMAL,                    // Shader location: vertex attribute: normal
	VERTEX_TANGENT,                   // Shader location: vertex attribute: tangent
	VERTEX_COLOR,                     // Shader location: vertex attribute: color
	MATRIX_MVP,                       // Shader location: matrix uniform: model-view-projection
	MATRIX_VIEW,                      // Shader location: matrix uniform: view (camera transform)
	MATRIX_PROJECTION,                // Shader location: matrix uniform: projection
	MATRIX_MODEL,                     // Shader location: matrix uniform: model (transform)
	MATRIX_NORMAL,                    // Shader location: matrix uniform: normal
	VECTOR_VIEW,                      // Shader location: vector uniform: view
	COLOR_DIFFUSE,                    // Shader location: vector uniform: diffuse color
	COLOR_SPECULAR,                   // Shader location: vector uniform: specular color
	COLOR_AMBIENT,                    // Shader location: vector uniform: ambient color
	MAP_ALBEDO,                       // Shader location: sampler2d texture: albedo (same as: SHADER_LOC_MAP_DIFFUSE)
	MAP_METALNESS,                    // Shader location: sampler2d texture: metalness (same as: SHADER_LOC_MAP_SPECULAR)
	MAP_NORMAL,                       // Shader location: sampler2d texture: normal
	MAP_ROUGHNESS,                    // Shader location: sampler2d texture: roughness
	MAP_OCCLUSION,                    // Shader location: sampler2d texture: occlusion
	MAP_EMISSION,                     // Shader location: sampler2d texture: emission
	MAP_HEIGHT,                       // Shader location: sampler2d texture: heightmap
	MAP_CUBEMAP,                      // Shader location: samplerCube texture: cubemap
	MAP_IRRADIANCE,                   // Shader location: samplerCube texture: irradiance
	MAP_PREFILTER,                    // Shader location: samplerCube texture: prefilter
	MAP_BRDF,                         // Shader location: sampler2d texture: brdf
	VERTEX_BONEIDS,                   // Shader location: vertex attribute: bone indices
	VERTEX_BONEWEIGHTS,               // Shader location: vertex attribute: bone weights
	MATRIX_BONETRANSFORMS,            // Shader location: matrix attribute: bone transforms (animation)
	VERTEX_INSTANCETRANSFORM,         // Shader location: vertex attribute: instance transforms
}

// Shader uniform data type
ShaderUniformDataType :: enum c.int {
	FLOAT = 0,                        // Shader uniform type: float
	VEC2,                             // Shader uniform type: vec2 (2 float)
	VEC3,                             // Shader uniform type: vec3 (3 float)
	VEC4,                             // Shader uniform type: vec4 (4 float)
	INT,                              // Shader uniform type: int
	IVEC2,                            // Shader uniform type: ivec2 (2 int)
	IVEC3,                            // Shader uniform type: ivec3 (3 int)
	IVEC4,                            // Shader uniform type: ivec4 (4 int)
	UINT,                             // Shader uniform type: unsigned int
	UIVEC2,                           // Shader uniform type: uivec2 (2 unsigned int)
	UIVEC3,                           // Shader uniform type: uivec3 (3 unsigned int)
	UIVEC4,                           // Shader uniform type: uivec4 (4 unsigned int)
	SAMPLER2D,                        // Shader uniform type: sampler2d
}

// Shader attribute data types
ShaderAttributeDataType :: enum c.int {
	FLOAT = 0,                        // Shader attribute type: float
	VEC2,                             // Shader attribute type: vec2 (2 float)
	VEC3,                             // Shader attribute type: vec3 (3 float)
	VEC4,                             // Shader attribute type: vec4 (4 float)
}

// Pixel formats
// NOTE: Support depends on OpenGL version and platform
PixelFormat :: enum c.int {
	UNKNOWN = 0,
	UNCOMPRESSED_GRAYSCALE = 1,       // 8 bit per pixel (no alpha)
	UNCOMPRESSED_GRAY_ALPHA,          // 8*2 bpp (2 channels)
	UNCOMPRESSED_R5G6B5,              // 16 bpp
	UNCOMPRESSED_R8G8B8,              // 24 bpp
	UNCOMPRESSED_R5G5B5A1,            // 16 bpp (1 bit alpha)
	UNCOMPRESSED_R4G4B4A4,            // 16 bpp (4 bit alpha)
	UNCOMPRESSED_R8G8B8A8,            // 32 bpp
	UNCOMPRESSED_R32,                 // 32 bpp (1 channel - float)
	UNCOMPRESSED_R32G32B32,           // 32*3 bpp (3 channels - float)
	UNCOMPRESSED_R32G32B32A32,        // 32*4 bpp (4 channels - float)
	UNCOMPRESSED_R16,                 // 16 bpp (1 channel - float)
	UNCOMPRESSED_R16G16B16,           // 16*3 bpp (3 channels - float)
	UNCOMPRESSED_R16G16B16A16,        // 16*4 bpp (4 channels - float)
	COMPRESSED_DXT1_RGB,              // 4 bpp (no alpha)
	COMPRESSED_DXT1_RGBA,             // 4 bpp (1 bit alpha)
	COMPRESSED_DXT3_RGBA,             // 8 bpp
	COMPRESSED_DXT5_RGBA,             // 8 bpp
	COMPRESSED_ETC1_RGB,              // 4 bpp
	COMPRESSED_ETC2_RGB,              // 4 bpp
	COMPRESSED_ETC2_EAC_RGBA,         // 8 bpp
	COMPRESSED_PVRT_RGB,              // 4 bpp
	COMPRESSED_PVRT_RGBA,             // 4 bpp
	COMPRESSED_ASTC_4x4_RGBA,         // 8 bpp
	COMPRESSED_ASTC_8x8_RGBA,         // 2 bpp
}

// Texture parameters: filter mode
// NOTE 1: Filtering considers mipmaps if available in the texture
// NOTE 2: Filter is accordingly set for minification and magnification
TextureFilter :: enum c.int {
	POINT = 0,                        // No filter, just pixel approximation
	BILINEAR,                         // Linear filtering
	TRILINEAR,                        // Trilinear filtering (linear with mipmaps)
	ANISOTROPIC_4X,                   // Anisotropic filtering 4x
	ANISOTROPIC_8X,                   // Anisotropic filtering 8x
	ANISOTROPIC_16X,                  // Anisotropic filtering 16x
}

// Texture parameters: wrap mode
TextureWrap :: enum c.int {
	REPEAT = 0,                       // Repeats texture in tiled mode
	CLAMP,                            // Clamps texture to edge pixel in tiled mode
	MIRROR_REPEAT,                    // Mirrors and repeats the texture in tiled mode
	MIRROR_CLAMP,                      // Mirrors and clamps to border the texture in tiled mode
}

// Cubemap layouts
CubemapLayout :: enum c.int {
	AUTO_DETECT = 0,                  // Automatically detect layout type
	LINE_VERTICAL,                    // Layout is defined by a vertical line with faces
	LINE_HORIZONTAL,                  // Layout is defined by an horizontal line with faces
	CROSS_THREE_BY_FOUR,              // Layout is defined by a 3x4 cross with cubemap faces
	CROSS_FOUR_BY_THREE,              // Layout is defined by a 4x3 cross with cubemap faces
}

// Font type, defines generation method
FontType :: enum c.int {
	DEFAULT = 0,                      // Default font generation, anti-aliased
	BITMAP,                           // Bitmap font generation, no anti-aliasing
	SDF,                              // SDF font generation, requires external shader
}

// Color blending modes (pre-defined)
BlendMode :: enum c.int {
	ALPHA = 0,                        // Blend textures considering alpha (default)
	ADDITIVE,                         // Blend textures adding colors
	MULTIPLIED,                       // Blend textures multiplying colors
	ADD_COLORS,                       // Blend textures adding colors (alternative)
	SUBTRACT_COLORS,                  // Blend textures subtracting colors (alternative)
	ALPHA_PREMULTIPLY,                // Blend premultiplied textures considering alpha
	CUSTOM,                           // Blend textures using custom src/dst factors (use rlSetBlendFactors())
	CUSTOM_SEPARATE,                  // Blend textures using custom rgb/alpha separate src/dst factors (use rlSetBlendFactorsSeparate())
}

// Gestures
// NOTE: It could be used as flags to enable only some gestures
Gesture :: enum c.uint {
	TAP         = 0,                  // Tap gesture
	DOUBLETAP   = 1,                  // Double tap gesture
	HOLD        = 2,                  // Hold gesture
	DRAG        = 3,                  // Drag gesture
	SWIPE_RIGHT = 4,                  // Swipe right gesture
	SWIPE_LEFT  = 5,                  // Swipe left gesture
	SWIPE_UP    = 6,                  // Swipe up gesture
	SWIPE_DOWN  = 7,                  // Swipe down gesture
	PINCH_IN    = 8,                  // Pinch in gesture
	PINCH_OUT   = 9,                  // Pinch out gesture
}
Gestures :: distinct bit_set[Gesture; c.uint]

// Camera speed values
CAMERA_MOVE_SPEED :: 5.4
CAMERA_ROTATION_SPEED :: 0.03
CAMERA_PAN_SPEED :: 0.2

// Camera mouse movement sensitivity
CAMERA_MOUSE_MOVE_SENSITIVITY :: 0.003

// Camera orbital speed in CAMERA_ORBITAL mode
CAMERA_ORBITAL_SPEED :: 0.5

// Camera system modes
CameraMode :: enum c.int {
	CUSTOM = 0,              // Camera custom, controlled by user (UpdateCamera() does nothing)
	FREE,                    // Camera free mode
	ORBITAL,                 // Camera orbital, around target, zoom supported
	FIRST_PERSON,            // Camera first person
	THIRD_PERSON,            // Camera third person
}

// Camera projection
CameraProjection :: enum c.int {
	PERSPECTIVE = 0,                  // Perspective projection
	ORTHOGRAPHIC,                     // Orthographic projection
}

// N-patch layout
NPatchLayout :: enum c.int {
	NINE_PATCH = 0,          // Npatch layout: 3x3 tiles
	THREE_PATCH_VERTICAL,    // Npatch layout: 1x3 tiles
	THREE_PATCH_HORIZONTAL,  // Npatch layout: 3x1 tiles
}

// Callbacks to hook some internal functions
// WARNING: This callbacks are intended for advanced users

TraceLogCallback     :: #type proc "c" (logLevel: TraceLogLevel, text: cstring, args: ^c.va_list)       // Logging: Redirect trace log messages
LoadFileDataCallback :: #type proc "c"(fileName: cstring, dataSize: ^c.int) -> [^]u8                    // FileIO: Load binary data
SaveFileDataCallback :: #type proc "c" (fileName: cstring, data: rawptr, dataSize: c.int) -> bool       // FileIO: Save binary data
LoadFileTextCallback :: #type proc "c" (fileName: cstring) -> [^]u8                                     // FileIO: Load text data
SaveFileTextCallback :: #type proc "c" (fileName: cstring, text: cstring) -> bool                       // FileIO: Save text data

AudioCallback :: #type proc "c" (bufferData: rawptr, frames: c.uint)