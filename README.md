# webgpu-ray-tracing-compute

WebGPU implementation of ray tracing using compute shader. It uses ReSTIR technique for indirect diffuse and emissive lighting.

# Get Dawn
git submodule add https://dawn.googlesource.com/dawn

# Build the app with CMake.
cmake -B build -DCURL_LIBRARY=<curl library directory> -DCURL_INCLUDE_DIR=<curl include directory> && cmake --build build -j4

# Build the app with Emscripten.
emcmake cmake -B build-web && cmake --build build-web -j4

# Mesh Assets are built separately, converting OBJ files to binary format for faster loading. It uses a local version of obj2binary application.

# Controls
Keyboard Button
    W - Move forward
    A - Strafe left
    S - Move backward
    D - Strafe right
    H - Hide selected mesh (mesh with yellow highlight)
    J - Reveal last hidden mesh

Mouse
    Left click - selects mesh, rotate camera if held down with mouse movement 
    Right Click - pans the camera if held down with mouse movement 

# http server for assets
npx http-server --cors -p 8080

# http server for web version
npx http-server -p 8000

# local url
http://localhost:8000/app.html

# link
[http://](https://wdings23.github.io/webgpu-ray-tracing-compute.html)

