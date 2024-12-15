shader_type canvas_item;
// Recommended Format: R8

// textures to render based on the data in a cell (0 = dead, 1 = alive)
uniform sampler2D deadTexture;
uniform sampler2D aliveTexture;

// texture to hold the 2D cell data
uniform sampler2D binaryDataTexture;

// number of cells width/height; using one variable means it's always square
uniform int GRID_SIZE;


const int CELL_SIZE_PX = 8; // number of pixels in a cell, cells are square
const float FADE_DISTANCE = 32.0; //* distance from the border where fading starts


void fragment() {
	//vec2 totalGridSize_px = vec2(float(GRID_SIZE) * float(CELL_SIZE_PX));
	
	vec2 _normalizedUV = UV * float(GRID_SIZE); // fit UV to the grid
	
	// READ CELL
	// get value from data, make some facts about it
	// get UV in "dataspace", the dataspace cell's UV
	ivec2 currentCellIndex = ivec2(floor(_normalizedUV)); // find cell based on normalized UV coords
	// read from data
	vec2 binaryDataUV = vec2(
		float(currentCellIndex.x) / float(GRID_SIZE - 1),
		float(currentCellIndex.y) / float(GRID_SIZE - 1)
	);
	float _binaryDataValue = texture(binaryDataTexture, binaryDataUV).r; // format: R8
	
	// CALCULATE CELL COLOR
	// assign the base color for the bit
	vec2 currentCellUV = fract(_normalizedUV);
	vec4 _cellColor = texture(deadTexture, currentCellUV);
	bool isAlive = _binaryDataValue >= 0.5;
	bool isInsideCell = all(greaterThanEqual(currentCellUV, vec2(0.0))) && all(lessThan(currentCellUV, vec2(1.0))); // 0.0 < currentCellUV < 1.0
	if (isAlive && isInsideCell) {
		_cellColor = texture(aliveTexture, currentCellUV);
	}
	
	// EFFECTS
	// calculate alpha value based on distance to border, trim color off logarithmically	
	float fadeDistanceX = min(_normalizedUV.x, float(GRID_SIZE) - _normalizedUV.x) * float(CELL_SIZE_PX);
	float fadeDistanceY = min(_normalizedUV.y, float(GRID_SIZE) - _normalizedUV.y) * float(CELL_SIZE_PX);
	float fadeDistanceToBorder = min(fadeDistanceX, fadeDistanceY);
	
	// calculate alpha for fade
	float alphaFactor = log(fadeDistanceToBorder * 1.0) / log(FADE_DISTANCE * 1.0);
	_cellColor.a *= alphaFactor;
	
	// apply results to fragment
	COLOR = _cellColor;
}