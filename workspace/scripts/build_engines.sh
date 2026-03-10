#!/bin/bash
set -e

WS=${ISAAC_ROS_WS:-/workspaces/isaac_ros_ws}
MODEL_DIR="$WS/models/onnx"
ENGINE_DIR="$WS/models/engines"
RTDETR_ONNX_DIR="$WS/models/onnx"

# NGC credentials — set NGC_API_KEY in the environment or pass as argument.
# Usage: build_engines.sh [NGC_API_KEY]
NGC_API_KEY="${1:-${NGC_API_KEY:-}}"

# trtexec — on PATH when installed via 'apt install tensorrt', fallback to NGC container path.
TRTEXEC=$(command -v trtexec 2>/dev/null || echo /usr/src/tensorrt/bin/trtexec)

mkdir -p "$ENGINE_DIR" "$MODEL_DIR"

# ---------------------------------------------------------------------------
# Helper: download a file from NGC if it does not already exist locally.
# Usage: ngc_download <dest_path> <url_path>
# ---------------------------------------------------------------------------
ngc_download() {
    local dest="$1"
    local url="$2"
    if [[ -f "$dest" ]]; then
        echo "[skip] $(basename "$dest") already exists."
        return 0
    fi
    if [[ -z "$NGC_API_KEY" ]]; then
        echo "ERROR: NGC_API_KEY is not set. Cannot download $(basename "$dest")."
        echo "  Set it with: export NGC_API_KEY=<your-key>"
        echo "  Or pass it as: build_engines.sh <your-key>"
        exit 1
    fi
    echo "Downloading $(basename "$dest")..."
    curl -fL \
        -H "Authorization: Bearer $NGC_API_KEY" \
        "$url" \
        -o "$dest"
}

# ---------------------------------------------------------------------------
# 1. FoundationPose ONNX models
# ---------------------------------------------------------------------------
ngc_download "$MODEL_DIR/refine_model.onnx" \
    "https://api.ngc.nvidia.com/v2/models/nvidia/isaac/foundationpose/versions/1.0.1_onnx/files/refine_model.onnx"

ngc_download "$MODEL_DIR/score_model.onnx" \
    "https://api.ngc.nvidia.com/v2/models/nvidia/isaac/foundationpose/versions/1.0.1_onnx/files/score_model.onnx"

# ---------------------------------------------------------------------------
# 2. RT-DETR (SyntheticaDETR) ONNX model
# ---------------------------------------------------------------------------
ngc_download "$RTDETR_ONNX_DIR/sdetr_grasp.onnx" \
    "https://api.ngc.nvidia.com/v2/models/nvidia/isaac/synthetica_detr/versions/1.0.0_onnx/files/sdetr_grasp.onnx"

# ---------------------------------------------------------------------------
# 3. Build TensorRT engines
# ---------------------------------------------------------------------------
echo ""
echo "Generating TensorRT engines (this may take 10-20 minutes)..."
echo ""

# FoundationPose — refine model
# FP16 omitted: TensorRT 10.3+ has precision loss for FoundationPose (Isaac ROS docs).
if [[ ! -f "$ENGINE_DIR/refine.plan" ]]; then
    echo "[1/3] Building refine.plan..."
    "$TRTEXEC" \
        --onnx="$MODEL_DIR/refine_model.onnx" \
        --saveEngine="$ENGINE_DIR/refine.plan" \
        --minShapes=input1:1x160x160x6,input2:1x160x160x6 \
        --optShapes=input1:1x160x160x6,input2:1x160x160x6 \
        --maxShapes=input1:42x160x160x6,input2:42x160x160x6
else
    echo "[skip] refine.plan already exists."
fi

# FoundationPose — score model
if [[ ! -f "$ENGINE_DIR/score.plan" ]]; then
    echo "[2/3] Building score.plan..."
    "$TRTEXEC" \
        --onnx="$MODEL_DIR/score_model.onnx" \
        --saveEngine="$ENGINE_DIR/score.plan" \
        --minShapes=input1:1x160x160x6,input2:1x160x160x6 \
        --optShapes=input1:1x160x160x6,input2:1x160x160x6 \
        --maxShapes=input1:252x160x160x6,input2:252x160x160x6
else
    echo "[skip] score.plan already exists."
fi

# RT-DETR — sdetr_grasp
# Dynamic shapes taken from the Isaac ROS RT-DETR documentation.
if [[ ! -f "$ENGINE_DIR/sdetr_grasp.plan" ]]; then
    echo "[3/3] Building sdetr_grasp.plan..."
    "$TRTEXEC" \
        --onnx="$RTDETR_ONNX_DIR/sdetr_grasp.onnx" \
        --saveEngine="$ENGINE_DIR/sdetr_grasp.plan" \
        --minShapes=images:1x3x640x640 \
        --optShapes=images:1x3x640x640 \
        --maxShapes=images:1x3x640x640 \
        --fp16
else
    echo "[skip] sdetr_grasp.plan already exists."
fi

echo ""
echo "Done. Engines written to:"
echo "  $ENGINE_DIR/refine.plan"
echo "  $ENGINE_DIR/score.plan"
echo "  $ENGINE_DIR/sdetr_grasp.plan"
