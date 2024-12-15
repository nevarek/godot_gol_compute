#[compute]
#version 450
// Godot Version 4.4.dev.custom_build [7f5c46929]

const int GRID_SIZE_PX = 1024;

const vec4 ALIVE_COLOR = vec4(1.0, 1.0, 1.0, 1.0);
const vec4 DEAD_COLOR = vec4(0.0, 0.0, 0.0, 1.0);


// Docs https://docs.godotengine.org/en/4.3/tutorials/shaders/compute_shaders.html

// invocation (threads) layout, defines the size of the chunks sent to GPU
layout (local_size_x = 32, local_size_y = 32, local_size_z = 1) in;

// describe format for input/output images, assign them bindings, sets, and format
// we are using r8 because we are expecting to read 8 bits of red pixel data
layout (set = 0, binding = 0, r8) restrict uniform readonly image2D _inputImage;
layout (set = 0, binding = 1, r8) restrict uniform writeonly image2D _outputImage;

bool isCellAlive(int x, int y) {
    // check bounds before calling this function
    vec4 pixel = imageLoad(_inputImage, ivec2(x, y));
    return pixel.r > 0.5;
}

int getNumLiveNeighbors(int x, int y) {
    // total the live cells in a 9x9 area
    int total = 0;
    for (int xOffset = -1; xOffset <= 1; xOffset++) {
        for (int yOffset = -1; yOffset <= 1; yOffset++) {
            // exclude self
            if (xOffset == 0 && yOffset == 0) continue; 

            int neighborX = x + xOffset;
            int neighborY = y + yOffset;

            // check bounds before querying cell
            if (    neighborX >= 0 && neighborX < GRID_SIZE_PX &&
                    neighborY >= 0 && neighborY < GRID_SIZE_PX     ) {
                total += int(isCellAlive(neighborX, neighborY));
            }
        }
    }

    return total;
}

void main() {
    ivec2 _cellIndex = ivec2(gl_GlobalInvocationID.xy);

    // check bounds
    if (_cellIndex.x >= GRID_SIZE_PX || _cellIndex.y >= GRID_SIZE_PX){
        vec4 nextCellColor = DEAD_COLOR;
        imageStore(_outputImage, _cellIndex, nextCellColor);
        return;
    }

    // count neighbors
    int numLiveNeighbors = getNumLiveNeighbors(_cellIndex.x, _cellIndex.y);
    
    // update state -- in this case we write directly to output as the buffer
    /* NOTE:    
        - the CPU dispatcher will take care of swapping buffer data
            - is this a wise decision? idk I am too lazy to handle another buffer rn :3
    */
    bool isCurrentCellAlive = isCellAlive(_cellIndex.x, _cellIndex.y);
    bool _nextState = isCurrentCellAlive;
    if (isCurrentCellAlive == true && (numLiveNeighbors < 2 || numLiveNeighbors > 3)) {
        _nextState = false; // dead
    } else if (isCurrentCellAlive == false && numLiveNeighbors == 3) {
        _nextState = true; // alive
    }

    // apply the color to output image
    vec4 nextCellColor = _nextState ? ALIVE_COLOR : DEAD_COLOR;
    imageStore(_outputImage, _cellIndex, nextCellColor);
}