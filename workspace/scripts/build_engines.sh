#!/bin/bash
set -e

MODEL_DIR=${ISAAC_ROS_WS:-/workspaces/isaac_ros_ws}/models
ENGINE_DIR=${ISAAC_ROS_WS:-/workspaces/isaac_ros_ws}/models/engines

mkdir -p $ENGINE_DIR

echo "Generating TensorRT engines..."

# trtexec is on PATH when installed via 'apt-get install tensorrt'.
# Fall back to the samples path used in older NVIDIA NGC TensorRT containers.
TRTEXEC=$(command -v trtexec 2>/dev/null || echo /usr/src/tensorrt/bin/trtexec)

# FoundationPose requires explicit dynamic shape bounds.
# --fp16 is intentionally omitted: TensorRT 10.3+ has FP16 precision loss
# for FoundationPose (per Isaac ROS documentation). FP32 is used instead.

"$TRTEXEC" \
  --onnx="$MODEL_DIR/refine_model.onnx" \
  --saveEngine="$ENGINE_DIR/refine.plan" \
  --minShapes=input1:1x160x160x6,input2:1x160x160x6 \
  --optShapes=input1:1x160x160x6,input2:1x160x160x6 \
  --maxShapes=input1:42x160x160x6,input2:42x160x160x6

"$TRTEXEC" \
  --onnx="$MODEL_DIR/score_model.onnx" \
  --saveEngine="$ENGINE_DIR/score.plan" \
  --minShapes=input1:1x160x160x6,input2:1x160x160x6 \
  --optShapes=input1:1x160x160x6,input2:1x160x160x6 \
  --maxShapes=input1:252x160x160x6,input2:252x160x160x6

echo "Done."