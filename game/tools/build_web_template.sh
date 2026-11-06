#!/usr/bin/env bash
# Builds the stripped Web export template (Story 1.3 Task 3, NFR4 size budget).
# Not run by CI. Needs: git, a Python 3.10+ for emsdk, network. Installs emsdk, SCons
# and the Godot source into WORK_DIR (default: a temp dir), never into the repo.
#   bash game/tools/build_web_template.sh [WORK_DIR]
# Output: WORK_DIR/godot/bin/godot.web.template_release.wasm32.nothreads.dlink.zip
# Use it for a local export by setting custom_template/release in the Web preset to that
# absolute path (do not commit the path or the zip).
set -euo pipefail

GODOT_TAG="4.7.2-stable"
EM_VERSION="4.0.11" # emscripten version in Godot's web_builds.yml at $GODOT_TAG
WORK_DIR="${1:-$(mktemp -d)}"
PY="${EMSDK_PYTHON:-$(command -v python3.11 || command -v python3.12 || command -v python3)}"
mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

[ -d emsdk ] || git clone -q --depth 1 https://github.com/emscripten-core/emsdk.git
EMSDK_PYTHON="$PY" ./emsdk/emsdk install "$EM_VERSION"
EMSDK_PYTHON="$PY" ./emsdk/emsdk activate "$EM_VERSION"
# shellcheck disable=SC1091
EMSDK_PYTHON="$PY" source ./emsdk/emsdk_env.sh

[ -d venv ] || "$PY" -m venv venv
./venv/bin/pip install -q scons

[ -d godot ] || git clone -q --depth 1 --branch "$GODOT_TAG" https://github.com/godotengine/godot.git
cat > godot/custom.py << 'PYCFG'
# 2D only, Latin text (fallback text server), OGG/Vorbis audio, PNG/WebP/JPG images.
disable_3d = "yes"
module_text_server_adv_enabled = "no"
module_text_server_fb_enabled = "yes"
for _m in ["astcenc", "basis_universal", "bcdec", "betsy", "bmp", "camera", "csg", "cvtt", "dds", "enet", "etcpak", "fbx",
           "glslang", "gltf", "godot_physics_3d", "gridmap", "hdr", "interactive_music", "jolt_physics", "jsonrpc", "ktx",
           "lightmapper_rd", "mbedtls", "meshoptimizer", "mobile_vr", "mp3", "msdfgen", "multiplayer", "navigation_2d",
           "navigation_3d", "noise", "objectdb_profiler", "openxr", "raycast", "svg", "tga", "theora", "tinyexr", "upnp",
           "vhacd", "webrtc", "websocket", "webxr", "xatlas_unwrap", "zip", "mono"]:
    globals()["module_%s_enabled" % _m] = "no"
del _m
PYCFG

cd godot
../venv/bin/scons platform=web target=template_release threads=no dlink_enabled=yes \
	optimize=size_extra debug_symbols=no use_closure_compiler=yes -j"$(getconf _NPROCESSORS_ONLN)"
ls -la bin/godot.web.template_release.wasm32.nothreads.dlink.zip
